# Shared material roles

Reviewed 12 September 2026. `material_roles.gd` groups existing `StandardMaterial3D` resources and two explicitly supported facade ShaderMaterial families by surface purpose. Changing one role updates every registered resource in place; meshes keep the same resource references. Different buildings retain their authored colours, alpha, textures, UV coordinates, emission colour and feature flags. Registering a material alone does not change its numeric appearance.

## API and integration

Create one registry per world, not one per mesh or a process-wide singleton:

```gdscript
var material_roles = preload("res://scripts/material_roles.gd").new()

# At material creation, after local colour/roughness/metallic are assigned:
material_roles.register_key(existing_material, key, true)

# Or use explicit semantic ownership for a new/unclassified key:
material_roles.register_material(existing_material, "metal")

# One deliberate adjustment affects all registered stone resources:
material_roles.set_role("stone", {"roughness":0.88, "metallic":0.0})
material_roles.set_role("light", {"energy":0.8})
```

`register_material(material, role, initialize_features=false)` and `register_key(material, key, initialize_features=false)` return `bool`. Unsupported shaders, unknown roles and conflicting StandardMaterial3D ownership return false. A supported facade ShaderMaterial can belong to both glass and stone because those roles update distinct uniforms. Duplicate registration under the same role does not duplicate membership. `classify_key(key)` returns a reviewed role or the empty string; it does not guess from arbitrary substring matches. `unregister_material(material)` detaches all its memberships without changing the material.

The explicit creation flag may enable emission once for the `light` role. It never supplies or replaces emission colour: the creator must author that colour as usual. Existing resources registered with the default flag retain their existing emission feature. Repeated registration, even after a registry reset, cannot re-enable emission on a previously registered material. All other texture and shader feature configuration remains at the original creation site.

Register the completed `world.materials` dictionary again after building to discover materials assigned directly by modules. The legacy world facade factory uses `_material_cache` instead of `materials`, so register its values too, or register each resource in `_facade_material()` as it is created. Apply role tuning after this build step when it must override locally assigned numeric values. Registering later materials automatically applies active role overrides. Existing material replacement remains visible through its existing users; this registry does not retarget mesh references or merge independently coloured resources.

`set_role(role, tuning)` accepts only numeric `roughness`, `metallic`, and—for lights—`energy` / `emission_energy_multiplier`. Unit properties clamp to 0–1; energy clamps to the project's 0–16 multiplier range. Booleans, strings, infinity, NaN, colours, texture assignments and feature flags are rejected. The result exposes `ok`, `updated`, `ignored`, `clamped` and accepted `values`. Missing properties retain their current value. Identical repeated tuning performs no material writes. Empty profiles intentionally preserve the current appearance until an explicit tuning choice is made.

`stats()` returns `{resources, roles, covered_shader_count, current_overrides}`. `roles` maps each role to its actual live material count; `current_overrides` is an independent dictionary snapshot. `resources` and `covered_shader_count` count unique Material resources, not shader programs, meshes, buildings or draw calls. A facade contributes once to resources and once to each of glass/stone memberships, so role counts can sum to more than resources. The registry holds weak references, so it does not keep an old world’s materials alive. `clear()` drops registration and override state without undoing material changes.

## Exact preview restoration

```gdscript
var original = material_roles.snapshot_role("glass")
material_roles.set_role("glass", {"roughness":0.45, "metallic":0.1})
# When leaving this preview:
var result = material_roles.restore_role("glass", original)
```

The snapshot captures each registered material's own numeric values plus the previous role override profile. Restoring therefore recovers differently authored roughness values individually instead of imposing one approximate reset value. The result reports `ok`, `restored`, `skipped` and `late_members`; restored counts actual changed resources. A resource created during the preview returns to its registration baseline plus the profile that preceded the preview. Freed or unregistered captured resources are skipped.

Snapshots are ephemeral dictionaries bound to one registry instance and its current generation, not save-file data. They contain IDs and numeric values, never strong material references. Wrong-role, foreign-registry, pre-clear and malformed snapshots are rejected before mutation. Restore only touches this role's allowed numeric fields; another role's changes and colours remain intact.

For shader uniforms, snapshots retain the raw override, including null. Null is restored with `set_shader_parameter(name, null)`, which removes that override and uses the shader's declared default again. An explicit value equal to the default remains explicit. This follows Godot 4.7's ShaderMaterial parameter-cache getter/setter behaviour. [Godot 4.7 material implementation](https://github.com/godotengine/godot/blob/4.7-stable/scene/resources/material.cpp)

## Source audit and classification

The audit searched all `game/scripts/*.gd` for material creation and properties, then read the world, City, Quay, Bank, Opera, QVB, ICC, Sydney Tower, Manly, bridge, metro, Darling and airport material definitions and their use. Colour names alone are not reliable substance labels. Explicit exceptions classify QVB amber/green as stained glass, its cream/red/trim as stone, Quay green as planting, and bridge/tower edge pieces as metal.

| Role | Intended existing resources |
|---|---|
| `glass` | Ordinary and transparent glazing, stained glass, glass roof panes |
| `stone` | Sandstone, granite, masonry trim, stone paving and brick |
| `concrete` | Concrete slabs, piers, tower shaft and concrete soffits |
| `metal` | Steel, copper, bronze, metal frames, vertical fins, tower cladding |
| `trim` | Existing generic painted trim, signage and mixed decorative palette |
| `light` | Authored lamps, downlights, signals and luminous panels |
| `wood` | Timber, wood panels, bark and authored timber variants |
| `asphalt` | Road and taxi surface materials |
| `vegetation` | Grass, leaves, hedges, palms and tree crowns |
| `roof` | Roof materials with unconfirmed substance; OSM roof-colour variants |
| `cloth` | Seats, carpet, fabric and theatre upholstery |
| `rubber` | Rubber safety surfaces and marine fenders |
| `soil` | Sand, mulch, scrub and ground substrate |

`fins`, `vertical_fins` and `steel` alias `metal`; `timber` aliases `wood`. These aliases do not introduce extra resources or shader variants. Generic historical palette resources can serve several objects; registering a single such resource cannot distinguish different uses without changing the underlying material assignment. Source-specific colours are therefore preserved, and no universal physical accuracy is claimed for the generic `trim` bucket.

## Supported facade shaders and coverage limits

`register_key` recognizes these exact shader resource paths and automatically registers each matching material under both glass and stone. It does not copy the shader or material, create window meshes, or alter shader code during tuning:

| Shader resource path | Declared defaults preserved from previous constant values |
|---|---|
| `res://shaders/city_facade.gdshader` | `glass_roughness=0.24`, `glass_metallic=0.28`, `wall_roughness=0.84` |
| `res://assets/world_facade.gdshader` | `glass_roughness=0.20`, `glass_metallic=0.36`, `wall_roughness=0.86` |

Glass roughness/metallic role values map to the first two uniforms; stone roughness maps to wall roughness. Wall metallic remains the shader's existing fixed behaviour: setting stone metallic still affects registered StandardMaterial3D stone, but adds no new uniform to these facades. Role tuning retains local colour parameters, facade bay sizes, roof logic and emission settings. The subsequent day/night extension below adds fixed window occupancy and numeric global exposure independently of material-role tuning. No runtime shader feature flags are changed.

Other custom ShaderMaterials remain unsupported and unchanged, even if their keys contain “glass.” The remaining coverage gaps at the time of this audit include:

| Current shader family | Unmanaged numeric material code |
|---|---|
| City / Quay / Cyber glazing | Mixed roughness 0.23/0.72 and metallic 0.38/0.12 |
| Bank glazing | Mixed roughness 0.19/0.61 and metallic 0.39/0.62 |
| ICC perforated facade | Roughness 0.62 and metallic 0.45 |
| QVB/ICC paving, Opera tile/wood, landcover and water | Dedicated material or surface-pattern logic |

A future explicit adapter could expose numeric uniforms for these remaining shader families while preserving their material resources, patterns and local colours. This module does not rewrite shader code at runtime, replace water, or claim that all landmark glazing is unified. Vehicle, character and independent airport material factories also require explicit integration before their resources appear in world registry counts.

## Godot evidence and tests

Godot documents materials as resources and explains that one loaded resource can be shared by users; modifying it changes those users. The implementation follows that resource model and never calls `duplicate()` on a material. [Godot Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html)

The material guide distinguishes metallic and roughness numeric surface properties from emission behaviour. The API reference identifies emission enablement as a feature while its energy multiplier is a numeric setting. The role API keeps that distinction. [Standard material guide](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html), [BaseMaterial3D](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html)

Godot’s renderer documentation explains that enabled material features determine generated shader code and can increase shader variants and compilation work. This motivates numeric-only runtime changes; no headless test is presented as a measurement of GPU compilation or frame rate. [Internal rendering architecture](https://docs.godotengine.org/en/stable/engine_details/architecture/internal_rendering_architecture.html#core-shaders)

`source/material_roles_test.gd` performs 41 bounded headless checks with actual StandardMaterial3D and supported ShaderMaterial resources: shared identity, appearance preservation, current/future role members, clamping, initialization-only emission, semantic exceptions, unsupported shader exclusion, weak-reference lifetime, unregistration/reset, diagnostic snapshots, mixed per-material originals, null/default shader restoration, two-role independence and invalid-snapshot rejection. Shader files are included in report hashes. Run:

```sh
tools/runtime/godot --headless --path game --script ../source/material_roles_test.gd
```

Evidence: `reports/material-roles/headless.log` and hash-bound `reports/material-roles/checks.json`. The root integration owns final world counts and native visual/performance verification.

## Stable day/night window emission

Both supported facade shaders now declare `global uniform float city_night_amount`, a project setting with a daylight default of zero. The city clock/lighting integration owns its 0–1 value. Updating it through `RenderingServer.global_shader_parameter_set` changes all existing facade materials without traversing materials, changing shader code, creating window nodes, or allocating new resources. This module does not set dates, the summer sun position, time acceleration or the sky. Godot documents project-defined global uniforms and the low-cost setter separately from adding/removing parameters. [Global uniforms](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html#global-uniforms)

Ordinary OSM extrusions use the root integration's immutable UV2 contract: `x = posmod(String(item.id).hash(), 10000) / 10000.0`, `y = 0` office, `1` residential, `2` other. The shader reads these through a flat varying and combines the ID seed with facade direction, floor and window index. Stable unsigned integer arithmetic selects occupied windows, warm/cool tint and a small intensity variation. The pattern contains no frame time, camera position, draw/instance ID or fresh random values. Batched geometry must preserve UV2 and world normals; the root geometry fixture owns that check. Godot documents UV2 and model normals in the spatial shader interface. [Spatial shader inputs](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)

The legacy `world_facade` boxes have no per-building OSM UV2. Their seed derives from existing masonry colour and module counts, so identical legacy materials can repeat a pattern. This remains stable when meshes are combined or rebuilt; it is not a claim of unique or surveyed lighting for each legacy building. No facade colour or building coordinate is generated by the occupancy seed.

The following are authored visual parameters, not surveyed Sydney occupancy rates or measured lamp temperatures:

| Usage code | Mean occupied-window fraction | Fraction of lit windows using the warmer tint |
|---|---:|---:|
| Office `0` | 0.38 | 0.35 |
| Residential `1` | 0.64 | 0.85 |
| Other `2` | 0.24 | 0.60 |

A fixed per-floor offset of at most ±0.08 creates floor-to-floor variation. Warm RGB `(1.0, 0.72, 0.43)` and cool RGB `(0.74, 0.84, 1.0)` receive a 0.82–1.18 intensity multiplier and 0.42 exposure. At full night, a resolved pane's largest component is at most 0.4956. This is scene-linear emission, not a real-world photometric calibration. Legacy `lit_windows` remains a compatible exposure trim: its existing default 0.05 is neutral; zero disables emission and values above 0.05 clamp to the neutral multiplier of one, so the legacy parameter cannot amplify the glass. Legacy defaults previously emitted dimly during daylight; added night emission now becomes exactly zero at `city_night_amount=0`.

A full-city native diagnostic capture (`04-time-night.png`, 22:00) showed the initial 1.9 multiplier clipping most resolved panes toward white and obscuring the warm/cool distinction. The revised 0.42 multiplier reduces emission by about 2.18 stops, while the legacy trim cap falls from four to one. The prior theoretical maximum including intensity and trim was 8.968; the revised maximum is 0.4956. The initial image and source/report hashes are retained locally under `reports/facade-night/exposure-before`. This is a source-level correction after actually viewing that native image; the revised appearance still needs root-owned native recapture.

The day/night value multiplies only `EMISSION`. City close-range `ALBEDO` is unchanged. Legacy close-range masonry, glass, brick and frame expressions are also retained, with derivative filtering newly averaging those fine details at distance. Both shaders blend subpixel window emission to the expected occupied pane area and mean tint, rather than leaving random single-pixel highlights or making the entire wall glow with pane intensity. The transition uses `fwidth` in window-grid coordinates, fades across 0.08–0.45 cells per fragment footprint, and suppresses roof emission. Brightness changes continuously through twilight without switching a different set of windows on each frame. Native camera movement remains necessary to judge perceptual shimmer and night exposure.

`source/facade_night_test.gd` runs 29 bounded checks. It loads both real Shader resources, verifies the global/UV2/filter contracts, then extracts their identical pure GLSL night functions verbatim and compiles those bodies with local Clang as CPU C++ using small GLSL vector/builtin adapters. This tests the actual hash and emission arithmetic rather than a separately reimplemented formula. Fixed integer vectors, 16,384-window density samples, seed stability, day-zero output, warm/cool variation, twilight continuity, input bounds and filtered mean energy are checked. The sampled occupied fractions are 0.378723 / 0.634094 / 0.234680; filtered energy differs from the corresponding sample means by under 3%.

```sh
tools/runtime/godot --headless --path game --script ../source/facade_night_test.gd
tools/runtime/godot --headless --path game --script ../source/material_roles_test.gd
```

Evidence: `reports/facade-night/checks.json`, `headless.log`, `cpu-compile.log`, and `cpu-results.json`; the role regression remains 41 checks. Reports bind the current shader and test hashes. CPU compilation and headless resource loading do **not** establish Metal/Vulkan shader compilation, sky accuracy, GPU performance or visual acceptance. Those remain root-owned native integration checks.
