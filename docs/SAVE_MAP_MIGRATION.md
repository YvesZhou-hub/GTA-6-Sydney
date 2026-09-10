# Map revision migration

The city expansion marks saves with `map_revision: 1`. Save format version remains 3 and still accepts format 1/2 input. Only saves older than map revision 1 run the relocation pass. A current revision save is restored exactly rather than repeatedly moving or respawning its fleet.

`map_migration.gd` checks the full stored vehicle envelope and the player's capsule-sized bounds against live mapped building solids. Polygon intersection and courtyard subtraction preserve concave outlines and holes. Building-part base heights preserve public ground under elevated structures. Destroyed storey components are excluded. Custom city, bank, Quay, Manly, metro and frontage structures use their real collision shapes; closed trimesh containment catches an object entirely inside a shell. Open meshes are not automatically considered solid interiors.

If displacement is necessary, each existing vehicle searches near its own saved location using the ordinary full-footprint spawn planner. Its ID, health, fuel, ownership and other persistent fields survive. Movement velocities are reset at a safe replacement pose. The originally occupied copy and the last summoned copy's waypoint are restored after migration. The player receives the existing “移出建筑” notice. Loading itself does not rewrite the source file; a subsequent normal save records the map revision.

The same custom-solid containment check is used by vehicle summoning so that an airborne waiting wing cannot be created wholly inside a custom tower. The checks are cached from the final world geometry and still consult live destruction state.

## Verification

Run `tools/runtime/godot --headless --path game --script ../source/map_migration_test.gd` from the repository root. This uses the real main load/save methods, vehicle models, physics server, imported-building extrusion code and custom prism construction inside a small isolated scene. It never calls the save-slot menu or reads non-QA world IDs. Temporary files have a unique `qa_map_migration_` prefix and only those files are cleaned up.

The regression fixtures cover a very tall hollow collider, a courtyard, a courtyard with a masonry notch, raised building parts, a closed custom tower, a solid metro column, a destroyed imported building, nearby full-width aircraft relocation, on-foot recovery, remote fleet copies, occupied vehicle restoration, unchanged safe copies, revision gating and source-file preservation. Baseline evidence is kept in `reports/map-migration-baseline.log` and `reports/map-migration-spawn-baseline.log`; final assertions are in `reports/map-migration.json`.

Geometry and facade reconstruction limitations are documented in the individual landmark reference files. Migration prevents occupied solid volumes; it does not turn unmapped interiors into playable rooms.
