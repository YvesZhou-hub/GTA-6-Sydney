#!/usr/bin/env python3
"""Offline NSW ASCII DEM extraction and queries; never modifies the game world.

Python standard library suffices for projected easting/northing. Geographic
coordinates explicitly require pyproj/PROJ; no approximate datum conversion.
"""
from __future__ import annotations
import argparse
import contextlib
import hashlib
import json
import math
from pathlib import Path
import zipfile

SCHEMA = 'harbourlife.elevation.window/1'
NSW_URL = 'https://portal.spatial.nsw.gov.au/download/dem/56/Sydney-DEM-AHD_56_5m.zip'
SOURCE_EPSG = 28356


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def project_coordinates(x: float, y: float, source_epsg: int, target_epsg: int):
    """Return x/y and actual PROJ operation metadata, with no ballpark fallback."""
    try:
        from pyproj import Transformer
    except ImportError as error:
        raise RuntimeError('Geographic conversion requires pyproj; use --easting/--northing otherwise.') from error
    transformer = Transformer.from_crs(source_epsg, target_epsg, always_xy=True, allow_ballpark=False)
    px, py = transformer.transform(x, y, errcheck=True)
    if not all(math.isfinite(v) for v in (px, py)):
        raise ValueError('Coordinate transformation returned non-finite coordinates')
    # PROJ may defer operation selection until coordinates are known. Record
    # the selected pipeline instead of an 'unavailable' generic transformer.
    try:
        selected = transformer.get_last_used_operation()
    except Exception:
        selected = transformer
    return px, py, {'source_epsg': source_epsg, 'target_epsg': target_epsg,
                    'operation': selected.description, 'pipeline': selected.definition,
                    'accuracy_m': selected.accuracy,
                    'always_xy': True, 'allow_ballpark': False}


@contextlib.contextmanager
def ascii_stream(path: Path, member: str | None = None):
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as archive:
            names = [n for n in archive.namelist() if n.lower().endswith('.asc')]
            if member is None:
                if len(names) != 1:
                    raise ValueError('ZIP must contain exactly one ASC, or specify --member')
                member = names[0]
            with archive.open(member) as stream:
                yield stream, member
    else:
        if member is not None:
            raise ValueError('--member only applies to ZIP archives')
        with path.open('rb') as stream:
            yield stream, path.name


def read_header(stream):
    header = {}
    for _ in range(6):
        parts = stream.readline().decode('ascii').split()
        if len(parts) != 2:
            raise ValueError('Expected six ESRI ASCII grid header lines')
        key, raw = parts[0].lower(), parts[1]
        if key in header:
            raise ValueError('Duplicate ASCII header key')
        header[key] = float(raw)
    if not all(math.isfinite(v) for v in header.values()):
        raise ValueError('Grid header must be finite')
    for key in ('ncols', 'nrows'):
        value = header.get(key, 0)
        if value <= 0 or value != int(value):
            raise ValueError('Grid dimensions must be positive integers')
        header[key] = int(value)
    cell = header.get('cellsize', 0)
    if cell <= 0 or 'nodata_value' not in header:
        raise ValueError('Expected positive cellsize and explicit NODATA_value')
    for axis in ('x', 'y'):
        corner, center = axis + 'llcorner', axis + 'llcenter'
        if center in header:
            header[corner] = header.pop(center) - cell / 2
        if corner not in header:
            raise ValueError('Grid must specify lower-left origin')
    if len(header) != 6:
        raise ValueError('Unexpected ASCII header fields')
    return header


def cell_index(grid, easting: float, northing: float):
    if not all(math.isfinite(v) for v in (easting, northing)):
        raise ValueError('Query coordinates must be finite')
    x, y, cell = grid['xllcorner'], grid['yllcorner'], grid['cellsize']
    if not (x <= easting < x + grid['ncols'] * cell and y <= northing < y + grid['nrows'] * cell):
        raise ValueError('Point outside grid bounds')
    col = math.floor((easting - x) / cell)
    row = grid['nrows'] - 1 - math.floor((northing - y) / cell)
    return row, col


def extract_windows(path: Path, locations: list[dict], cells: int = 101,
                    member: str | None = None, crs_epsg: int = SOURCE_EPSG,
                    provenance: dict | None = None):
    """Extract square windows in one sequential read; reach EOF to verify ZIP CRC.

    Locations require unique name, easting and northing. No download occurs.
    Source is assumed north-up; data rows remain north-to-south. Heights retain
    the source vertical datum, not an ellipsoidal or game-world datum.
    """
    path = Path(path)
    if not locations or len({loc['name'] for loc in locations}) != len(locations):
        raise ValueError('Provide at least one uniquely named location')
    if cells < 1 or cells > 513 or cells % 2 != 1:
        raise ValueError('Window cells must be odd and between 1 and 513')
    windows = []
    with ascii_stream(path, member) as (stream, source_member):
        header = read_header(stream)
        half = cells // 2
        for loc in locations:
            row, col = cell_index(header, loc['easting'], loc['northing'])
            r0, c0 = row - half, col - half
            if min(r0, c0) < 0 or r0 + cells > header['nrows'] or c0 + cells > header['ncols']:
                raise ValueError('Requested window extends outside source grid; no padding is fabricated')
            windows.append({'location': dict(loc), 'r0': r0, 'c0': c0, 'data': []})
        rows_read = 0
        for row, line in enumerate(stream):
            if not line.strip():
                continue
            if row >= header['nrows']:
                raise ValueError('Source has extra rows')
            fields = line.split()
            if len(fields) != header['ncols']:
                raise ValueError(f'Source row {row} has an incorrect number of cells')
            for window in windows:
                if window['r0'] <= row < window['r0'] + cells:
                    values = [float(v) for v in fields[window['c0']:window['c0'] + cells]]
                    if not all(math.isfinite(v) for v in values):
                        raise ValueError('Non-finite sample elevations')
                    window['data'].append(values)
            rows_read += 1
        if rows_read != header['nrows']:
            raise ValueError('Source grid is truncated')
    digest = sha256(path)
    result = {}
    for window in windows:
        grid = dict(header)
        grid.update(ncols=cells, nrows=cells,
                    xllcorner=header['xllcorner'] + window['c0'] * header['cellsize'],
                    yllcorner=header['yllcorner'] + (header['nrows'] - window['r0'] - cells) * header['cellsize'],
                    row_order='north_to_south', data=window['data'])
        result[window['location']['name']] = {
            'schema': SCHEMA, 'crs': {'horizontal_epsg': crs_epsg},
            'source': {'file_name': path.name, 'member': source_member, 'sha256': digest,
                       'all_source_rows_checked': True, 'zip_crc_checked': zipfile.is_zipfile(path)},
            'selection': window['location'], 'grid': grid,
            'provenance': provenance or {'redistribution_license': 'UNSPECIFIED; do not publish without source license'},
        }
    return result


def query(window: dict, easting: float, northing: float, method: str = 'nearest'):
    if window.get('schema') != SCHEMA:
        raise ValueError('Unsupported elevation window schema')
    grid = window['grid']
    row, col = cell_index(grid, easting, northing)
    values = grid['data']
    if len(values) != grid['nrows'] or any(len(r) != grid['ncols'] for r in values):
        raise ValueError('Window dimensions do not match data')
    def sample(r, c):
        value = values[r][c]
        if not math.isfinite(value) or value == grid['nodata_value']:
            raise ValueError('Query touches NoData; no zero or invented height returned')
        return value
    if method == 'nearest':
        return sample(row, col)
    if method != 'bilinear':
        raise ValueError('Unknown query method')
    gx = (easting - grid['xllcorner']) / grid['cellsize'] - 0.5
    gy = grid['nrows'] - (northing - grid['yllcorner']) / grid['cellsize'] - 0.5
    c0, r0 = math.floor(gx), math.floor(gy)
    if r0 < 0 or c0 < 0 or r0 + 1 >= grid['nrows'] or c0 + 1 >= grid['ncols']:
        raise ValueError('Bilinear interpolation requires four in-bounds cell centers')
    tx, ty = gx - c0, gy - r0
    return ((1 - ty) * ((1 - tx) * sample(r0, c0) + tx * sample(r0, c0 + 1))
            + ty * ((1 - tx) * sample(r0 + 1, c0) + tx * sample(r0 + 1, c0 + 1)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    extract = commands.add_parser('extract')
    extract.add_argument('source', type=Path)
    extract.add_argument('--member')
    extract.add_argument('--output', type=Path, required=True)
    extract.add_argument('--name', default='sample')
    extract.add_argument('--cells', type=int, default=101)
    extract.add_argument('--provenance', type=Path, help='JSON containing original license, source and capture-date evidence')
    extract.add_argument('--epsg', type=int, default=SOURCE_EPSG)
    ask = commands.add_parser('query')
    ask.add_argument('window', type=Path)
    ask.add_argument('--method', choices=['nearest', 'bilinear'], default='nearest')
    for command in (extract, ask):
        command.add_argument('--easting', type=float)
        command.add_argument('--northing', type=float)
        command.add_argument('--longitude', type=float)
        command.add_argument('--latitude', type=float)
    args = parser.parse_args()
    window = json.loads(args.window.read_text()) if args.command == 'query' else None
    epsg = window['crs']['horizontal_epsg'] if window else args.epsg
    geographic = args.longitude is not None or args.latitude is not None
    projected = args.easting is not None or args.northing is not None
    if geographic == projected:
        parser.error('Provide either longitude/latitude or easting/northing, not both')
    conversion = None
    if geographic:
        if None in (args.longitude, args.latitude): parser.error('Both geographic coordinates are required')
        easting, northing, conversion = project_coordinates(args.longitude, args.latitude, 4326, epsg)
    else:
        if None in (args.easting, args.northing): parser.error('Both projected coordinates are required')
        easting, northing = args.easting, args.northing
    if args.command == 'query':
        print(json.dumps({'height_in_source_vertical_datum_m': query(window, easting, northing, args.method),
                          'easting': easting, 'northing': northing, 'conversion': conversion,
                          'method': args.method}, indent=2))
    else:
        location = {'name': args.name, 'easting': easting, 'northing': northing}
        if conversion: location.update(longitude=args.longitude, latitude=args.latitude, coordinate_conversion=conversion)
        provenance = json.loads(args.provenance.read_text()) if args.provenance else None
        result = extract_windows(args.source, [location], args.cells, args.member, epsg, provenance)[args.name]
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
        print(json.dumps({'output': str(args.output), 'sha256': sha256(args.output), 'cells': args.cells**2}))

if __name__ == '__main__':
    main()
