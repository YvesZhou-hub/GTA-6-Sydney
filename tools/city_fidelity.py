#!/usr/bin/env python3
"""Compile explicitly mapped pedestrian areas without inventing terrain heights.

Integration, after import_city's existing road/excavation clipping loop::

    from city_fidelity import annotate_pedestrian_areas
    area_report = annotate_pedestrian_areas(out['roads'], out['excavations'])

An accepted road retains its ID, tags, points and all unrelated fields. It gains
``surface_geometry='area'`` and a flat, world-space ``surface_triangles`` array,
compatible with CityMap's existing [x, z] triangle input. The runtime must send
these triangles through its vehicle-road subtraction and pedestrian deduplication
pipeline, then SKIP the area's boundary strip/join/road_segments loop. Map UI must
fill the same area instead of buffering its outline. This compiler clips explicit
excavations only; it does not claim those runtime integration steps are complete.

Only explicit highway=pedestrian + area=yes, at the existing ground layer, is
accepted. A closed roundabout is not a plaza. Bridge/layer/tunnel data never becomes
an invented height. Invalid outlines are rejected, not repaired or shifted.
Optional road['holes'] are absolute [x,z] rings; current import_city does not fetch
highway multipolygon relations, and current road records contain no such holes.

Semantics: https://wiki.openstreetmap.org/wiki/Key:area
           https://wiki.openstreetmap.org/wiki/Tag:highway%3Dpedestrian
Dependency matches tools/import_city.py: Shapely >= 2.1 / GEOS constrained Delaunay.
Run tools/map-runtime/bin/python tools/city_fidelity.py --report <ignored JSON>.
The CLI audits in memory and never modifies the supplied asset.
"""
from __future__ import annotations

import argparse
from collections import Counter
import copy
import hashlib
import json
import math
from pathlib import Path
from typing import Any

import shapely
from shapely import constrained_delaunay_triangles
from shapely.geometry import LineString, Polygon
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parents[1]
STREET_WIDTH = {'motorway': 13.0, 'trunk': 12.0, 'primary': 10.5,
                'secondary': 10.0, 'tertiary': 9.0, 'residential': 7.0,
                'unclassified': 7.0, 'service': 4.0, 'living_street': 5.5,
                'pedestrian': 9.0, 'footway': 2.0, 'path': 2.0,
                'cycleway': 2.8, 'steps': 2.0}
SOURCES = ['https://wiki.openstreetmap.org/wiki/Key:area',
           'https://wiki.openstreetmap.org/wiki/Tag:highway%3Dpedestrian']


class AreaGeometryError(ValueError):
    """A tagged ground area has malformed or unsupported geometry."""


def _numeric(value: Any) -> float | None:
    try:
        number = float(value)
    except (ValueError, TypeError):
        return None
    return number if math.isfinite(number) else None


def ground_road_eligible(road: dict) -> bool:
    """Mirror existing runtime elevation/type gates, without assigning a height."""
    tags = road.get('tags', {})
    return (tags.get('highway') in STREET_WIDTH
            and tags.get('bridge', 'no') == 'no'
            and tags.get('tunnel', 'no') == 'no'
            and _numeric(tags.get('layer', '0')) == 0.0)


def _area_candidate(road: dict) -> bool:
    tags = road.get('tags', {})
    return (tags.get('highway') == 'pedestrian' and tags.get('area') == 'yes'
            and ground_road_eligible(road))


def _ring(points: Any, label: str, require_closed: bool = False) -> list:
    if not isinstance(points, (list, tuple)) or len(points) < 3:
        raise AreaGeometryError(label + ': fewer than three vertices')
    result = []
    for point in points:
        if (not isinstance(point, (list, tuple)) or len(point) != 2
                or any(isinstance(n, bool) or not isinstance(n, (int, float))
                       or not math.isfinite(n) for n in point)):
            raise AreaGeometryError(label + ': expected finite numeric [x,z]')
        result.append(tuple(point))
    if require_closed and (len(result) < 4 or result[0] != result[-1]):
        raise AreaGeometryError(label + ': explicit area way is not closed')
    if len(set(result)) < 3:
        raise AreaGeometryError(label + ': fewer than three distinct vertices')
    return result


def _area_polygon(road: dict) -> Polygon:
    outer = _ring(road.get('points'), str(road.get('id', '?')), True)
    holes = [_ring(ring, 'interior ring') for ring in road.get('holes', [])]
    shape = Polygon(outer, holes)
    if not shape.is_valid or shape.is_empty or shape.area <= 1e-8:
        raise AreaGeometryError(str(road.get('id', '?')) + ': invalid/zero-area polygon')
    return shape


def _excavation_union(excavations: list | tuple):
    polygons = []
    for item in excavations:
        if not isinstance(item, dict) or 'polygon' not in item:
            raise AreaGeometryError('excavation must contain an absolute polygon ring')
        polygon = Polygon(_ring(item['polygon'], 'excavation'))
        if not polygon.is_valid or polygon.area <= 1e-8:
            raise AreaGeometryError('invalid excavation polygon')
        polygons.append(polygon)
    return unary_union(polygons)


def _polygons(geometry):
    if geometry.geom_type == 'Polygon':
        if geometry.area > 1e-8:
            yield geometry
    elif hasattr(geometry, 'geoms'):
        for child in geometry.geoms:
            yield from _polygons(child)


def _triangles(surface) -> list[list[float]]:
    """Constrained triangulation retains concavity and all interior holes."""
    triangles = []
    for part in _polygons(surface):
        for triangle in constrained_delaunay_triangles(part).geoms:
            if triangle.area <= 1e-8:
                continue
            # Explicit containment prevents accidental unconstrained fill if a
            # future dependency behaves differently. Never replace with a hull.
            if not part.covers(triangle):
                raise AreaGeometryError('triangulation escaped the mapped area')
            vertices = [(float(x), float(z)) for x, z in triangle.exterior.coords[:-1]]
            first = min(range(3), key=lambda i: vertices[i])
            vertices = vertices[first:] + vertices[:first]
            # Canonical winding and order yield reproducible JSON without rounding
            # the source boundary or clipping intersections.
            a, b, c = vertices
            if (b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0]) < 0:
                vertices = [a, c, b]
            triangles.append(tuple(vertices))
    triangles.sort()
    return [list(vertex) for triangle in triangles for vertex in triangle]


def _compile(road: dict, cuts) -> dict | None:
    if not _area_candidate(road):
        return None
    polygon = _area_polygon(road)
    surface = polygon.difference(cuts) if not cuts.is_empty else polygon
    triangles = _triangles(surface)
    return {'surface_geometry': 'area', 'surface_triangles': triangles,
            'surface_geometry_source': {
                'method': 'OSM explicit pedestrian area, constrained triangulation',
                'osm_id': road.get('id'), 'source_tags': {'highway': 'pedestrian', 'area': 'yes'},
                'mapped_area_m2': round(polygon.area, 6),
                'rendered_area_m2': round(surface.area, 6),
                'excavation_removed_m2': round(polygon.area-surface.area, 6),
                'interior_ring_count': len(polygon.interiors),
                'triangle_count': len(triangles)//3,
                'elevation': 'existing flat-world road datum; no inferred height',
                'limits': 'Only provided closed-way outline/interior rings; highway multipolygon relations not fetched by current importer.'}}


def compile_pedestrian_area(road: dict, excavations: list | tuple = ()) -> dict | None:
    """Return a mergeable surface patch, None if ineligible; never mutate inputs.

    Malformed geometry on an eligible area raises AreaGeometryError. Existing
    line-buffer surface_triangles are replaced, not intersected: the mapped area
    itself is authoritative, and known excavation polygons are reapplied to it.
    """
    if not _area_candidate(road):
        return None
    return _compile(road, _excavation_union(excavations))


def annotate_pedestrian_areas(roads: list[dict], excavations: list | tuple = ()) -> dict:
    """Add three surface fields; earlier sorted OSM IDs own overlapping area.

    Input list order and source points stay untouched. Area-area deduplication is
    compiled offline; runtime only needs area-vs-linear/vehicle mask subtraction.
    """
    cuts = _excavation_union(excavations)
    report = {'candidate_areas': 0, 'compiled_areas': 0, 'by_region': {},
              'triangles': 0, 'mapped_area_m2': 0.0, 'rendered_area_m2': 0.0,
              'excavation_removed_m2': 0.0, 'overlap_trim_m2': 0.0, 'rejected': []}
    regions = Counter()
    occupied = unary_union([])
    mapped = []
    for road in sorted(roads, key=lambda item: str(item.get('id', ''))):
        if not _area_candidate(road):
            continue
        report['candidate_areas'] += 1
        try:
            patch = _compile(road, cuts)
            polygon = _area_polygon(road)
            surface = polygon.difference(cuts)
            unique = surface.difference(occupied)
            patch['surface_triangles'] = _triangles(unique)
            source = patch['surface_geometry_source']
            source.update({'source_area_m2': source['mapped_area_m2'],
                           'overlap_trim_m2': round(surface.area-unique.area, 6),
                           'overlap_policy': 'Earlier lexicographically sorted OSM ID owns shared area; source points unchanged.',
                           'rendered_area_m2': round(unique.area, 6),
                           'triangle_count': len(patch['surface_triangles'])//3})
        except AreaGeometryError as error:
            report['rejected'].append({'id': road.get('id'), 'reason': str(error)})
            continue
        road.update(patch)
        occupied = unary_union([occupied, surface])
        mapped.append(polygon)
        report['compiled_areas'] += 1
        report['triangles'] += source['triangle_count']
        for key in ['mapped_area_m2', 'rendered_area_m2', 'excavation_removed_m2', 'overlap_trim_m2']:
            report[key] += source[key]
        regions[road.get('region', 'unknown')] += 1
    report['by_region'] = dict(sorted(regions.items()))
    for key in ['mapped_area_m2', 'rendered_area_m2', 'excavation_removed_m2', 'overlap_trim_m2']:
        report[key] = round(report[key], 6)
    report['source_area_sum_m2'] = report['mapped_area_m2']
    report['mapped_area_union_m2'] = round(unary_union(mapped).area, 6)
    report['rendered_area_union_m2'] = round(occupied.area, 6)
    report['excavation_removed_union_m2'] = round(unary_union(mapped).area-occupied.area, 6)
    return report


def audit_field_usage(snapshot: dict) -> dict:
    """Observed source/runtime coverage, not an unsupported survey claim."""
    roads = snapshot['roads']
    ground = [road for road in roads if ground_road_eligible(road)]
    notes = {
        'area': 'Previously ignored: closed pedestrian areas buffered as boundary lines.',
        'surface': 'Preserved in source; current renderer chooses material by highway class only.',
        'oneway': 'Preserved; current visual centre dash and road_segments ignore direction.',
        'lanes': 'Used for width fallback on five major road classes; not for lane-divider count.',
        'lanes:forward': 'Preserved; current runtime does not use directional lane split.',
        'lanes:backward': 'Preserved; current runtime does not use directional lane split.',
        'width': 'Numeric values used and clamped by runtime; road widths are not surveyed here.',
        'layer': 'Nonzero layers skipped; ordinal layer is not a metric elevation.',
        'bridge': 'Non-no bridges skipped; no height inferred from bridge tag.',
        'min_height': 'No such road tags in this snapshot; do not confuse maxheight clearance with elevation.'}
    fields = {key: {'roads_with_tag': sum(key in r['tags'] for r in roads),
                    'ground_renderable_with_tag': sum(key in r['tags'] for r in ground),
                    'runtime_usage': note} for key, note in notes.items()}
    buildings = snapshot['buildings']
    building_fields = {key: sum(key in b['tags'] for b in buildings)
                       for key in ['height', 'min_height', 'building:levels',
                                   'building:min_level', 'roof:direction', 'roof:height']}
    return {'roads': len(roads), 'ground_renderable_roads_before_custom_replacements': len(ground),
            'road_fields': fields, 'building_fields': building_fields,
            'building_field_usage': {
                'height/min_height': 'Already parsed in import_city; missing dimensions remain inferred.',
                'building:levels/building:min_level': 'Already used with assumed storey heights.',
                'roof:direction': 'Not consumed by city_roofs; only nine tagged records, separate future fix.',
                'roof:height': 'Consumed by city_roofs with envelope caps; not independently surveyed.'},
            'loaded_road_records_with_interior_rings': sum(bool(r.get('holes')) for r in roads),
            'highway_multipolygon_relations_loaded': sum(r['id'].startswith('relation/') for r in roads)}


def audit_snapshot(snapshot: dict) -> dict:
    """Compile a copy and quantify local area coverage before runtime merging."""
    roads = copy.deepcopy(snapshot['roads'])
    before = sum(r.get('surface_geometry') == 'area' for r in roads)
    result = annotate_pedestrian_areas(roads, snapshot.get('excavations', []))
    source_areas, legacy_areas, compiled_areas = [], [], []
    examples = []
    cuts = _excavation_union(snapshot.get('excavations', []))
    for road in roads:
        if road.get('surface_geometry') != 'area':
            continue
        area = _area_polygon(road).difference(cuts)
        width = _numeric(road['tags'].get('width'))
        width = min(35.0, max(1.0, width)) if width is not None else 9.0
        legacy = LineString(road['points']).buffer(width/2, cap_style=2, join_style=1, quad_segs=8).difference(cuts)
        values = road['surface_triangles']
        compiled = unary_union([Polygon(values[i:i+3]) for i in range(0, len(values), 3)])
        missing, outside = area.difference(legacy).area, legacy.difference(area).area
        source_areas.append(area)
        legacy_areas.append(legacy)
        compiled_areas.append(compiled)
        examples.append({'id': road['id'], 'name': road['tags'].get('name'),
                         'region': road.get('region'), 'mapped_area_m2': round(area.area, 3),
                         'legacy_unfilled_interior_m2': round(missing, 3)})
    source_union = unary_union(source_areas)
    legacy_union = unary_union(legacy_areas)
    compiled_union = unary_union(compiled_areas)
    return {'source_fields': audit_field_usage(snapshot), 'compiler': result,
            'coverage_before': {'compiled_explicit_areas': before,
                                'unfilled_source_union_m2': round(source_union.difference(legacy_union).area, 6),
                                'buffer_outside_source_union_m2': round(legacy_union.difference(source_union).area, 6)},
            'coverage_after': {'compiled_explicit_areas': result['compiled_areas'],
                               'unfilled_source_union_m2': round(source_union.difference(compiled_union).area, 9),
                               'mesh_outside_source_union_m2': round(compiled_union.difference(source_union).area, 9),
                               'duplicate_area_mesh_m2': round(sum(p.area for p in compiled_areas)-compiled_union.area, 9)},
            'coverage_metric_scope': 'Union of accepted source areas versus union of their legacy rounded boundary buffers, with known excavations removed. Largest-improvement examples are individual-area metrics. This is not whole-city net ground coverage: unrelated road/park meshes and runtime carriageway subtraction are excluded.',
            'largest_improvements': sorted(examples, key=lambda x: (-x['legacy_unfilled_interior_m2'], x['id']))[:15],
            'runtime_integration_required': ['Use area triangles, skip boundary strips/joins/road_segments.',
                                             'Subtract actual vehicle-road masks from all pedestrian surfaces.',
                                             'Deduplicate area + linear pedestrian surfaces together.',
                                             'Fill these areas in 2D map; retain original ID and points for selection.'],
            'sources': SOURCES}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, default=ROOT/'game/assets/city_map.json')
    parser.add_argument('--report', type=Path, default=ROOT/'reports/city-fidelity/audit.json')
    args = parser.parse_args()
    raw = args.input.read_bytes()
    report = audit_snapshot(json.loads(raw))
    report.update({'input_sha256': hashlib.sha256(raw).hexdigest(),
                   'compiler_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                   'shapely_version': shapely.__version__, 'geos_version': shapely.geos_version_string,
                   'input_modified': False})
    if args.input.resolve() == args.report.resolve():
        parser.error('report must not overwrite the map input')
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False)+'\n')
    print(json.dumps({'compiler': report['compiler'], 'before': report['coverage_before'],
                      'after': report['coverage_after'], 'report': str(args.report)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
