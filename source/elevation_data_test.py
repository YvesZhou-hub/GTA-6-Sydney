#!/usr/bin/env python3
"""Offline parser/query evidence. Uses tiny synthetic ZIPs and committed samples.

No network, engine, full-city build or large survey archive required. Geographic
conversion tests run when pyproj is available; projected tests always run.
"""
import copy
import importlib.util
import io
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import import_elevation as elevation

HEADER = 'ncols 5\nnrows 5\nxllcorner 100\nyllcorner 200\ncellsize 5\nNODATA_value -9999\n'
ROWS = '\n'.join(' '.join(str(100 * r + c) for c in range(5)) for r in range(5)) + '\n'

class ElevationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.folder = Path(self.tmp.name)
        self.path = self.folder / 'fixture.zip'
        self.write_grid(HEADER + ROWS)
        self.location = {'name': 'center', 'easting': 112.5, 'northing': 212.5}

    def tearDown(self):
        self.tmp.cleanup()

    def write_grid(self, text):
        with zipfile.ZipFile(self.path, 'w', compression=zipfile.ZIP_DEFLATED) as z:
            z.writestr('fixture.asc', text)

    def extract(self, cells=3):
        return elevation.extract_windows(self.path, [self.location], cells)['center']

    def test_north_to_south_window(self):
        result = self.extract()
        self.assertEqual(result['grid']['data'], [[101, 102, 103], [201, 202, 203], [301, 302, 303]])
        self.assertEqual(result['grid']['xllcorner'], 105)
        self.assertEqual(result['grid']['yllcorner'], 205)

    def test_zip_crc_and_source_binding(self):
        source = self.extract()['source']
        self.assertTrue(source['zip_crc_checked'])
        self.assertTrue(source['all_source_rows_checked'])
        self.assertEqual(source['sha256'], elevation.sha256(self.path))

    def test_nearest_cell_and_half_open_bounds(self):
        window = self.extract()
        self.assertEqual(elevation.query(window, 112.5, 212.5), 202)
        self.assertEqual(elevation.query(window, 105, 205), 301)
        for x, y in [(120, 210), (110, 220), (104.99, 210), (110, 204.99)]:
            with self.assertRaises(ValueError): elevation.query(window, x, y)

    def test_bilinear_gradient(self):
        self.assertAlmostEqual(elevation.query(self.extract(), 110, 215, 'bilinear'), 151.5)

    def test_bilinear_edge_does_not_clamp(self):
        with self.assertRaises(ValueError): elevation.query(self.extract(), 105, 205, 'bilinear')

    def test_nodata_nearest_is_not_zero(self):
        window = self.extract(); window['grid']['data'][1][1] = -9999
        with self.assertRaises(ValueError): elevation.query(window, 112.5, 212.5)

    def test_nodata_interpolation_is_not_filled(self):
        window = self.extract(); window['grid']['data'][0][0] = -9999
        with self.assertRaises(ValueError): elevation.query(window, 110, 215, 'bilinear')

    def test_nonfinite_query_rejected(self):
        with self.assertRaises(ValueError): elevation.query(self.extract(), math.nan, 210)

    def test_xllcenter_conversion(self):
        text = HEADER.replace('xllcorner 100', 'xllcenter 102.5').replace('yllcorner 200', 'yllcenter 202.5')
        self.assertEqual(elevation.read_header(io.BytesIO(text.encode()))['xllcorner'], 100)

    def test_invalid_header(self):
        for text in [HEADER.replace('ncols 5', 'ncols 5.5'), HEADER.replace('cellsize 5', 'cellsize 0'), HEADER.replace('cellsize 5', 'cellsize nan')]:
            with self.assertRaises(ValueError): elevation.read_header(io.BytesIO(text.encode()))

    def test_truncated_rows(self):
        self.write_grid(HEADER + '\n'.join(ROWS.splitlines()[:4]) + '\n')
        with self.assertRaises(ValueError): self.extract()

    def test_wrong_row_length_outside_window_still_rejected(self):
        self.write_grid(HEADER + '0 1\n' + '\n'.join(ROWS.splitlines()[1:]) + '\n')
        with self.assertRaises(ValueError): self.extract()

    def test_nonfinite_selected_cell(self):
        self.write_grid((HEADER + ROWS).replace('201 202 203', '201 nan 203'))
        with self.assertRaises(ValueError): self.extract()

    def test_requested_window_out_of_bounds(self):
        with self.assertRaises(ValueError): self.extract(7)

    def test_no_implicit_license(self):
        self.assertIn('UNSPECIFIED', self.extract()['provenance']['redistribution_license'])

    def test_cli_query(self):
        path = self.folder / 'window.json'; path.write_text(json.dumps(self.extract()))
        p = subprocess.run([sys.executable, str(ROOT / 'tools/import_elevation.py'), 'query', str(path), '--easting', '112.5', '--northing', '212.5'], check=True, capture_output=True, text=True)
        self.assertEqual(json.loads(p.stdout)['height_in_source_vertical_datum_m'], 202)

    def test_ambiguous_zip_requires_member(self):
        with zipfile.ZipFile(self.path, 'a') as z: z.writestr('second.asc', HEADER + ROWS)
        with self.assertRaises(ValueError): self.extract()
        result = elevation.extract_windows(self.path, [self.location], 3, member='fixture.asc')
        self.assertEqual(result['center']['grid']['data'][1][1], 202)

    def test_real_three_samples_license_crs_and_values(self):
        expected = {'sydney_circular_quay': 1.780, 'manly': 3.370, 'airport_yssy': 6.352}
        for name, value in expected.items():
            with self.subTest(name=name):
                window = json.loads((ROOT / 'source/elevation-data' / (name + '.json')).read_text())
                self.assertEqual(window['crs']['horizontal_epsg'], 28356)
                self.assertEqual(window['provenance']['license'], 'CC-BY-3.0-AU')
                self.assertIn('AHD71', window['provenance']['vertical_datum'])
                self.assertEqual(window['grid']['ncols'], 101)
                self.assertEqual(window['source']['sha256'], '0b8773943d50eb3c1000c61da27a793538d398d1938ef34bf231b834b851cd14')
                loc = window['selection']
                self.assertAlmostEqual(elevation.query(window, loc['easting'], loc['northing']), value, places=3)

    def test_public_samples_below_two_mb(self):
        size = sum(p.stat().st_size for p in (ROOT / 'source/elevation-data').glob('*.json'))
        self.assertGreater(size, 10000)
        self.assertLess(size, 2_000_000)

    @unittest.skipUnless(importlib.util.find_spec('pyproj'), 'pyproj optional; no geographic conversion claimed without it')
    def test_official_crs_conversion_matches_recorded_samples(self):
        for path in (ROOT / 'source/elevation-data').glob('*.json'):
            window = json.loads(path.read_text())
            if window.get('schema') != elevation.SCHEMA: continue
            loc = window['selection']
            e, n, operation = elevation.project_coordinates(loc['longitude'], loc['latitude'], 4326, 28356)
            self.assertAlmostEqual(e, loc['easting'], places=3)
            self.assertAlmostEqual(n, loc['northing'], places=3)
            lon, lat, _ = elevation.project_coordinates(e, n, 28356, 4326)
            self.assertAlmostEqual(lon, loc['longitude'], places=8)
            self.assertAlmostEqual(lat, loc['latitude'], places=8)
            self.assertFalse(operation['allow_ballpark'])

if __name__ == '__main__': unittest.main(verbosity=2)
