"""Explicit public-source allowlist shared by packaging and release checks."""
from pathlib import Path

ROOT_FILES = ('.gitignore', '.gitattributes', 'README.md', 'LICENSE', 'PLAY_PERMISSION.md', '启动 Harbourlife.command')
TOOL_FILES = ('build.py', 'build.sh', 'package_source.py', 'release_files.py', 'encode_video.py',
              'capture_trailer.py', 'edit_promo.py', 'promo_score.py', 'promo_audio_export.gd',
              'test_save.gd', 'test_integration.gd', 'test_vehicles.gd', 'import_city.py', 'city_roofs.py', 'city_fidelity.py', 'import_elevation.py', 'calibrate_summer.py', 'verify_native.py', 'verify_archive.py')
SOURCE_FILES = ('world_osm_reference.json', 'world_osm_water.json', 'world_geography.json',
                'airport-runways.json', 'airport_test.gd', 'airport_connector_test.gd', 'world_physics_probe.gd',
                'world_damage_probe.gd', 'world_road_probe.gd', 'world_winding_check.gd',
                'camera_motion_test.gd', 'bridge_drive_test.gd', 'bridge_landmark_test.gd',
                'opera_landmark_test.gd', 'opera_interior_test.gd', 'vehicle_spawn_test.gd', 'vehicle_contact_test.gd',
                'landmark_visual_check.gd', 'city_landmark_test.gd', 'bank_landmark_test.gd',
                'quay_landmark_test.gd', 'manly_landmark_test.gd', 'metro_entrance_test.gd',
                'darling_square_frontage_test.gd', 'darling_public_facilities_test.gd', 'city_map_ui_test.gd', 'map_migration_test.gd', 'structure_state_test.gd',
                'test_city_data.py', 'city_fidelity_test.py', 'mesh_composition_test.gd', 'elevation_data_test.py', 'qvb_public_test.gd', 'city_geometry_test.gd', 'cyber_landmark_test.gd',
                'icc_landmark_test.gd', 'roof_visual_check.gd', 'road_join_test.gd',
                'experience_flow_test.gd', 'landmark_alignment_test.gd', 'life_experience_test.gd',
                'navigation_map_test.gd', 'vehicle_model_test.gd', 'vehicle_model_migration_test.gd',
                'boat_model_test.gd', 'interactive_qa.gd', 'hoverboard_test.gd',
                'air_vehicle_flight_test.gd', 'vehicle_speed_test.gd', 'air_vehicle_model_test.gd',
                'precinct_detail_test.gd', 'sydney_tower_landmark_test.gd', 'manowar_detail_test.gd',
                'city_parent_base_test.gd', 'city_parent_policy_test.py', 'helipad_clearance_test.gd',
                'tank_motion_test.gd', 'fighter_flight_test.gd', 'combat_vehicle_state_test.gd',
                'combat_crush_test.gd', 'combat_crush_envelope_test.gd', 'combat_weapons_test.gd', 'combat_effects_test.gd', 'combat_spawn_test.gd',
                'runtime_diagnostics_test.gd', 'material_roles_test.gd', 'facade_night_test.gd', 'facade_stream_test.gd',
                'render_environment_test.gd', 'daylight_cycle_test.gd', 'city_clock_test.gd', 'vehicle_factory_cache_test.gd', 'public_lighting_test.gd', 'ui_font_test.gd', 'fixtures/save_store_v012.gd')

def public_files(root: Path):
    files = [root / name for name in ROOT_FILES]
    files += [root / 'tools' / name for name in TOOL_FILES]
    files += [root / 'source' / name for name in SOURCE_FILES]
    files += [p for p in (root/'source/map-data').glob('*.json') if p.is_file() and not p.is_symlink()]
    files += [p for p in (root/'source/elevation-data').glob('*.json') if p.is_file() and not p.is_symlink()]
    files += [root/'source/frontage-data/derive_frontages.py']
    files += [p for pattern in ('*.tsv', '*.json', 'derive_darling_businesses.py')
              for p in (root/'source/precinct-data').glob(pattern) if p.is_file() and not p.is_symlink()]
    files += [root / 'reports' / name for name in ('GEOGRAPHY.md', 'AIRPORT.md')]
    for folder in ('game', 'licenses', 'docs'):
        for path in (root / folder).rglob('*'):
            if not path.is_file() or path.is_symlink():
                continue
            if any(part in ('.godot', '__pycache__') for part in path.parts):
                continue
            if path.name == '.DS_Store' or path.suffix.lower() not in ('.md', '.txt', '.json', '.png', '.hdr', '.svg', '.gd', '.gdshader', '.uid', '.tscn', '.tres', '.otf', '.ttf', '.wav', '.cfg', '.godot', '.import'):
                continue
            files.append(path)
    missing = [str(path.relative_to(root)) for path in files if not path.is_file()]
    if missing:
        raise RuntimeError('Missing public source files: ' + ', '.join(missing))
    return sorted(set(files))
