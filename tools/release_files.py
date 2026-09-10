"""Explicit public-source allowlist shared by packaging and release checks."""
from pathlib import Path

ROOT_FILES = ('.gitignore', '.gitattributes', 'README.md', 'PLAY_PERMISSION.md', '启动 Harbourlife.command')
TOOL_FILES = ('build.py', 'build.sh', 'package_source.py', 'release_files.py', 'encode_video.py',
              'test_save.gd', 'test_integration.gd', 'test_vehicles.gd', 'import_city.py', 'city_roofs.py')
SOURCE_FILES = ('world_osm_reference.json', 'world_osm_water.json', 'world_geography.json',
                'airport-runways.json', 'airport_test.gd', 'world_physics_probe.gd',
                'world_damage_probe.gd', 'world_road_probe.gd', 'world_winding_check.gd',
                'camera_motion_test.gd', 'bridge_drive_test.gd', 'bridge_landmark_test.gd',
                'opera_landmark_test.gd', 'vehicle_spawn_test.gd', 'vehicle_contact_test.gd',
                'landmark_visual_check.gd', 'city_landmark_test.gd', 'bank_landmark_test.gd',
                'quay_landmark_test.gd', 'manly_landmark_test.gd', 'metro_entrance_test.gd',
                'darling_square_frontage_test.gd', 'city_map_ui_test.gd', 'map_migration_test.gd',
                'test_city_data.py', 'city_geometry_test.gd', 'cyber_landmark_test.gd',
                'icc_landmark_test.gd', 'roof_visual_check.gd', 'road_join_test.gd')

def public_files(root: Path):
    files = [root / name for name in ROOT_FILES]
    files += [root / 'tools' / name for name in TOOL_FILES]
    files += [root / 'source' / name for name in SOURCE_FILES]
    files += [p for p in (root/'source/map-data').glob('*.json') if p.is_file() and not p.is_symlink()]
    files += [root/'source/frontage-data/derive_frontages.py']
    files += [root / 'reports' / name for name in ('GEOGRAPHY.md', 'AIRPORT.md')]
    for folder in ('game', 'licenses', 'docs'):
        for path in (root / folder).rglob('*'):
            if not path.is_file() or path.is_symlink():
                continue
            if any(part in ('.godot', '__pycache__') for part in path.parts):
                continue
            if path.name == '.DS_Store' or path.suffix.lower() not in ('.md', '.txt', '.json', '.png', '.svg', '.gd', '.gdshader', '.uid', '.tscn', '.cfg', '.godot', '.import'):
                continue
            files.append(path)
    missing = [str(path.relative_to(root)) for path in files if not path.is_file()]
    if missing:
        raise RuntimeError('Missing public source files: ' + ', '.join(missing))
    return sorted(set(files))
