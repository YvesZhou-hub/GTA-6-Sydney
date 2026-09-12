#!/usr/bin/env python3
"""Offline source geometry checks; no Godot process or production asset writes."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import sys
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from city_fidelity import (AreaGeometryError, annotate_pedestrian_areas,
                           audit_snapshot, compile_pedestrian_area)
from shapely.geometry import Polygon
from shapely.ops import unary_union


def road(points=None, *, id='way/1', tags=None, holes=None):
    result = {'id': id, 'region': 'city',
              'tags': {'highway': 'pedestrian', 'area': 'yes'},
              'points': points or [[0, 0], [20, 0], [20, 20], [0, 20], [0, 0]]}
    if tags:
        result['tags'].update(tags)
    if holes is not None:
        result['holes'] = holes
    return result


def surface(patch):
    vertices = patch['surface_triangles']
    return unary_union([Polygon(vertices[i:i+3]) for i in range(0, len(vertices), 3)])


class FidelityTests(unittest.TestCase):
    def test_full_square_interior_is_filled(self):
        patch = compile_pedestrian_area(road())
        self.assertEqual(patch['surface_geometry'], 'area')
        self.assertAlmostEqual(surface(patch).area, 400)
        self.assertTrue(surface(patch).covers(Polygon([[5, 5], [15, 5], [15, 15], [5, 15]])))

    def test_concave_area_does_not_become_convex_hull(self):
        source = road([[0, 0], [8, 0], [8, 2], [2, 2], [2, 8], [0, 8], [0, 0]])
        shape = surface(compile_pedestrian_area(source))
        self.assertAlmostEqual(shape.area, 28)
        self.assertLess(shape.symmetric_difference(Polygon(source['points'])).area, 1e-9)

    def test_explicit_interior_ring_remains_a_hole(self):
        hole = [[5, 5], [10, 5], [10, 10], [5, 10]]
        patch = compile_pedestrian_area(road(holes=[hole]))
        self.assertAlmostEqual(surface(patch).area, 375)
        self.assertEqual(surface(patch).intersection(Polygon(hole)).area, 0)
        self.assertEqual(patch['surface_geometry_source']['interior_ring_count'], 1)

    def test_two_excavations_are_actual_removed_geometry(self):
        cuts = [{'polygon': [[5, -1], [8, -1], [8, 21], [5, 21]]},
                {'polygon': [[14, -1], [17, -1], [17, 21], [14, 21]]}]
        patch = compile_pedestrian_area(road(), cuts)
        shape = surface(patch)
        self.assertAlmostEqual(shape.area, 280)
        self.assertEqual(len(shape.geoms), 3)
        for cut in cuts:
            self.assertEqual(shape.intersection(Polygon(cut['polygon'])).area, 0)

    def test_excavation_overlap_with_source_hole_not_double_subtracted(self):
        hole = [[5, 5], [10, 5], [10, 10], [5, 10]]
        cut = {'polygon': [[5, 5], [12, 5], [12, 10], [5, 10]]}
        patch = compile_pedestrian_area(road(holes=[hole]), [cut])
        self.assertAlmostEqual(surface(patch).area, 365)
        self.assertAlmostEqual(patch['surface_geometry_source']['excavation_removed_m2'], 10)

    def test_fully_excavated_area_stays_marked_empty(self):
        patch = compile_pedestrian_area(road(), [{'polygon': [[-1, -1], [21, -1], [21, 21], [-1, 21]]}])
        self.assertEqual(patch['surface_triangles'], [])
        self.assertEqual(patch['surface_geometry'], 'area')

    def test_input_source_and_excavations_are_immutable_for_single_compile(self):
        source = road();source['surface_triangles'] = [[0, 0], [1, 0], [0, 1]]
        cuts = [{'polygon': [[2, 2], [3, 2], [3, 3], [2, 3]]}]
        before = copy.deepcopy((source, cuts))
        patch = compile_pedestrian_area(source, cuts)
        self.assertEqual((source, cuts), before)
        self.assertAlmostEqual(surface(patch).area, 399)

    def test_closed_line_and_roundabout_are_not_inferred_as_areas(self):
        for tags in [{'area': 'no'}, {'area': ''}, {'highway': 'residential'},
                     {'highway': 'service'}, {'highway': 'living_street'}]:
            with self.subTest(tags=tags):
                self.assertIsNone(compile_pedestrian_area(road(tags=tags)))

    def test_elevated_or_underground_areas_do_not_get_flattened(self):
        for tags in [{'bridge': 'yes'}, {'bridge': 'boardwalk'}, {'layer': '1'},
                     {'layer': '-1'}, {'layer': '0.3'}, {'layer': 'unknown'},
                     {'tunnel': 'yes'}]:
            with self.subTest(tags=tags):
                self.assertIsNone(compile_pedestrian_area(road(tags=tags)))

    def test_open_and_self_intersecting_areas_rejected_without_repair(self):
        for points in [[[0, 0], [10, 0], [10, 10], [0, 10]],
                       [[0, 0], [10, 10], [0, 10], [10, 0], [0, 0]]]:
            with self.subTest(points=points), self.assertRaises(AreaGeometryError):
                compile_pedestrian_area(road(points))

    def test_nonfinite_and_three_dimensional_source_coordinates_rejected(self):
        for point in [[float('nan'), 1], [2, float('inf')], [1, 2, 3], [True, 2]]:
            with self.subTest(point=point), self.assertRaises(AreaGeometryError):
                compile_pedestrian_area(road([[0, 0], [10, 0], point, [0, 0]]))

    def test_invalid_excavation_fails_instead_of_sealing_real_hole(self):
        with self.assertRaises(AreaGeometryError):
            annotate_pedestrian_areas([road()], [{'polygon': [[0, 0], [1, 1], [0, 1], [1, 0]]}])

    def test_area_area_overlap_has_stable_id_ownership(self):
        a = road([[0, 0], [10, 0], [10, 10], [0, 10], [0, 0]], id='way/a')
        b = road([[5, 0], [15, 0], [15, 10], [5, 10], [5, 0]], id='way/b')
        records = [b, a]
        result = annotate_pedestrian_areas(records)
        self.assertEqual([item['id'] for item in records], ['way/b', 'way/a'])
        self.assertAlmostEqual(surface(a).area, 100)
        self.assertAlmostEqual(surface(b).area, 50)
        self.assertEqual(surface(a).intersection(surface(b)).area, 0)
        self.assertAlmostEqual(result['rendered_area_union_m2'], 150)
        self.assertAlmostEqual(result['overlap_trim_m2'], 50)
        self.assertEqual(b['surface_geometry_source']['overlap_trim_m2'], 50)

    def test_source_holes_do_not_claim_neighbours_inner_area(self):
        hole = [[5, 5], [10, 5], [10, 10], [5, 10]]
        a = road(id='way/a', holes=[hole])
        b = road(hole+[hole[0]], id='way/b')
        annotate_pedestrian_areas([a, b])
        self.assertAlmostEqual(surface(a).area, 375)
        self.assertAlmostEqual(surface(b).area, 25)

    def test_annotation_is_idempotent_and_only_surface_fields_change(self):
        records = [road(), road(id='way/2', tags={'area': 'no'})]
        before = copy.deepcopy(records)
        annotate_pedestrian_areas(records)
        first = copy.deepcopy(records)
        annotate_pedestrian_areas(records)
        self.assertEqual(records, first)
        for previous, current in zip(before, records):
            for key, value in previous.items():
                self.assertEqual(current[key], value)
        self.assertEqual(records[1], before[1])

    def test_invalid_area_report_does_not_mutate_record(self):
        bad = road([[0, 0], [2, 0], [0, 2]])
        before = copy.deepcopy(bad)
        report = annotate_pedestrian_areas([bad])
        self.assertEqual(report['compiled_areas'], 0)
        self.assertEqual(len(report['rejected']), 1)
        self.assertEqual(bad, before)

    def test_winding_reversal_keeps_same_physical_coverage(self):
        original = road()
        reverse = road(list(reversed(original['points'])))
        a, b = surface(compile_pedestrian_area(original)), surface(compile_pedestrian_area(reverse))
        self.assertEqual(a.symmetric_difference(b).area, 0)

    def test_fidelity_audit_does_not_modify_the_snapshot(self):
        snapshot = {'roads': [road()], 'buildings': [], 'excavations': []}
        before = copy.deepcopy(snapshot)
        report = audit_snapshot(snapshot)
        self.assertEqual(snapshot, before)
        self.assertEqual(report['coverage_after']['unfilled_source_union_m2'], 0)
        self.assertGreater(report['coverage_before']['unfilled_source_union_m2'], 0)


class ProductionSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = ROOT/'game/assets/city_map.json'
        cls.raw = cls.path.read_bytes()
        cls.snapshot = json.loads(cls.raw)
        cls.report = audit_snapshot(cls.snapshot)

    def test_all_106_ground_pedestrian_areas_compile_without_geometry_rejection(self):
        compiler = self.report['compiler']
        self.assertEqual(compiler['candidate_areas'], 106)
        self.assertEqual(compiler['compiled_areas'], 106)
        self.assertEqual(compiler['rejected'], [])
        self.assertEqual(compiler['by_region'], {'city': 97, 'manly': 3, 'north': 6})

    def test_area_union_is_completely_covered_without_double_area(self):
        for key in ['unfilled_source_union_m2', 'mesh_outside_source_union_m2', 'duplicate_area_mesh_m2']:
            self.assertLess(abs(self.report['coverage_after'][key]), 1e-6)
        self.assertGreater(self.report['coverage_before']['unfilled_source_union_m2'], 37000)

    def test_pitt_street_mall_is_full_surface_inside_original_boundary(self):
        source = next(r for r in self.snapshot['roads'] if r['id'] == 'way/353552750')
        patch = compile_pedestrian_area(source, self.snapshot['excavations'])
        self.assertLess(surface(patch).symmetric_difference(Polygon(source['points'])).area, 1e-6)
        self.assertGreater(surface(patch).area, 3800)

    def test_known_excavations_are_still_excluded_from_all_compiled_triangles(self):
        roads = copy.deepcopy(self.snapshot['roads'])
        annotate_pedestrian_areas(roads, self.snapshot['excavations'])
        holes = unary_union([Polygon(hole['polygon']) for hole in self.snapshot['excavations']])
        for item in roads:
            if item.get('surface_geometry') == 'area':
                self.assertLess(surface(item).intersection(holes).area, 1e-8)

    def test_source_asset_bytes_and_source_points_remain_unchanged(self):
        self.assertEqual(self.path.read_bytes(), self.raw)
        roads = copy.deepcopy(self.snapshot['roads'])
        annotate_pedestrian_areas(roads, self.snapshot['excavations'])
        for original, compiled in zip(self.snapshot['roads'], roads):
            for key in ['id', 'tags', 'points']:
                self.assertEqual(compiled[key], original[key])

    def test_missing_relation_holes_are_explicitly_not_claimed(self):
        self.assertEqual(self.report['source_fields']['loaded_road_records_with_interior_rings'], 0)
        self.assertEqual(self.report['source_fields']['highway_multipolygon_relations_loaded'], 0)


if __name__ == '__main__':
    started = time.monotonic()
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    names = []
    def collect(item):
        if isinstance(item, unittest.TestSuite):
            for child in item:
                collect(child)
        else:
            names.append(item.id())
    collect(suite)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    failures = {test.id(): detail for test, detail in result.failures+result.errors}
    report = {'passed': result.wasSuccessful(), 'checks': [{'name': name, 'passed': name not in failures,
               **({'detail': failures[name]} if name in failures else {})} for name in names],
              'count': result.testsRun, 'seconds': round(time.monotonic()-started, 3),
              'hashes': {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                         for path in [Path(__file__), ROOT/'tools/city_fidelity.py', ROOT/'game/assets/city_map.json']},
              'production_coverage': ProductionSnapshotTests.report,
              'engine_or_gpu_run': False, 'production_asset_modified': False}
    target = ROOT/'reports/city-fidelity/checks.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False)+'\n')
    sys.exit(not result.wasSuccessful())
