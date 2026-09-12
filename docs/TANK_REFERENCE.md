# Original Harbour Bastion tracked tank

Checked 12 September 2026. This is an original fictional game vehicle, not a measured Abrams replica. All mesh geometry and materials are authored in `tank_models.gd`; no photograph, vendor CAD, GTA_SZ code, logo or third-party model is shipped. The user-requested 110 km/h handling, unlimited fuel and invulnerability are arcade settings.

## Source and actual image inspection

- Australian Army, [M1A2 Abrams equipment page](https://www.army.gov.au/equipment/vehicles-and-surveillance/m1a2-abrams-tank), consulted 12 September 2026. Its published 9.7 m length, 3.7 m width, 3.09 m height and 67-tonne mass provide a real heavy tracked vehicle scale comparison. They are not claimed as the dimensions of this original asset.
- Australian Defence International Training Centre, [2023 Parts of a Tank teaching sheet](https://ditc.defence.gov.au/sites/default/files/2024-01/20231129%20-%20MilEng%20-%20VB%20-%20Parts%20of%20a%20tank%20-%20Teachers%20Copy.pdf), page 1. The actual first page was rendered with `pdftoppm` and inspected using `view_image`, including its large three-quarter photograph and hatch/vision close-ups. The visible seven road wheels, end running gear, wide tracks, plate skirts, inclined hull/turret faces, hatch rims, protected optics, rear rack and antenna placement informed the external layout. The photograph is a visual source, not engineering or current configuration evidence. Its illustrated tank has different weapon details from the fictional game barrel.

The source PDF and rendered page are research-only ignored files under `reports/tank-reference/`, excluded from the game. Original plate proportions, colour, optical equipment arrangement, barrel collars and rectangular muzzle detail are authored approximations. No real weapon construction or ballistic data is implemented.

## Model and animation contract

`TankModels.build(body, mats, moving, factory)` uses metres, +Y up and −Z forward. It builds a sloped hull, faceted independent turret, engine grilles, protective skirt panels, 144 individual track shoes with pads, seven road wheels per side, an idler and drive sprocket per side, wheel hubs/bolts, hatch rims/handles, optics, tow fittings, lamps and separate barrel. Factory batching preserves all 23,596 triangles in 88 material meshes instead of the 824 authoring meshes.

| Moving member | Parent | Local origin | Motion |
|---|---|---|---|
| `turret` | body | `(0, 0.82, -0.10)` | local Y yaw |
| `barrel` | turret | `(0, 0.64, -1.55)` | local X pitch; positive raises the muzzle |
| `muzzle` | barrel | `(0, 0, -4.80)` | marker forward is local −Z |
| `wheels` | body | 18 separate pivots | local X rotation, `tank_side` ±1 and `tank_radius`/`radius` metadata |

Static merging must exclude every moving pivot, including nested barrel/muzzle pivots. The production factory preserves this hierarchy. Neutral rendered bounds are X ±2.0325 m, Y −0.9653 to 2.9716 m, Z −6.4095 to 3.8050 m. A grounded body origin is 0.96 m above its support; antenna height is therefore about 3.93 m. A rotated turret/barrel changes the horizontal extent and must be considered by safe-spawn clearance.

The rigid collision approximation consists of a convex hull, two long rounded track contacts, and a conservative stationary turret cylinder. Decorative barrel geometry rotates independently without a protruding physical barrel collider. The segmented track belt remains rigid while its wheels animate; there is no per-link chain physics or suspension simulation. This bounds physics cost when multiple vehicles exist.

## Driving contract and validation

`TankMotion.setup(v)` sets the fictional 58,000 kg body, inertia, low centre of mass, damping and continuous collision detection. `tick(v, delta, f, r, u, power, steer, pitch, brake)` accepts the shared motion interface; the pitch input is reserved for the combat controller. Five support rays select the local ground normal. Propulsion, differential yaw, lateral grip and slope alignment use forces/torque, not position overrides. Lateral gravity compensation prevents constant downhill creep on cross-slopes. Unsupported tanks receive no forward propulsion. Wheel animation reads `tank_track_left_speed` and `tank_track_right_speed` metadata.

`source/tank_motion_test.gd` runs 19 bounded Jolt checks: muzzle yaw/elevation, complete nondegenerate/wound meshes, running gear clearance, static merge conservation, real contact settling, forward/reverse drive, brake, pivot turn, a 25° climb/hold/descent, entering a 15° ramp from flat ground, 15° cross-slope driving and an airborne negative case. Latest measured forward speed is 107.4 km/h; stopping distance is about 16 m; the cross-slope test drifts about 0.003 m in 8 seconds. These are gameplay measurements, not real tank performance claims.

`source/combat_vehicle_state_test.gd` adds 18 production factory/HarborVehicle checks. It covers JSON and pre-ready restoration, exact tank muzzle world pose, aim bounds and legacy defaults, tank health/fuel, fighter 555 m/s restoration through actual rigid-body integration, the 620 m/s fighter guard, unchanged 240 m/s ordinary vehicle guard, and real occupied tank input dispatch plus differential wheel animation. It does not substitute for final main-world firing, destruction, UI or rendering QA.

```sh
tools/runtime/godot --headless --path game --fixed-fps 60 --script ../source/tank_motion_test.gd
tools/runtime/godot --headless --path game --fixed-fps 60 --script ../source/combat_vehicle_state_test.gd
```

Logs and hash-bound JSON evidence are `reports/tank/motion-headless.log`, `motion-checks.json`, `combat-vehicle-state-headless.log`, and `combat-vehicle-state-checks.json`. Headless geometry checks do not establish visual quality. The model fixture supports a separate root-coordinated native render:

```sh
tools/runtime/godot --path game --script ../source/tank_motion_test.gd -- --capture-only
```

It writes four 1600×1000 front, tracks, rear and aimed-turret views to `reports/tank/native/`. This capture-only path does not overwrite motion test results. Final integrated city visuals and combat verification belong to the root release validation.
