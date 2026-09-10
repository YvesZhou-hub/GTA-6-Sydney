# v0.1.2-preview.1 validation

This update was developed and checked on Apple M4 / 16 GB, macOS 26.5, Godot 4.7.2, Metal / Forward+, with Jolt physics. The released application targets Apple Silicon Mac. Intel Mac, Windows, Linux and browser builds are unverified. The historical [v0.1.1 record](TESTING_0.1.1.md) remains separate.

The **final exported application** passed [60 / 60 interaction checks](evidence/v012-app/experience-report.json), [30 / 30 native driving/save checks](evidence/v012-app/qa-report.json), and [ten native landmark/model captures](evidence/v012-app/visual-report.json). All runs reached READY, produced fresh reports and exited normally with no logged errors or warnings. Four additional UI captures were visually checked. These are bundled application validators using production buttons/controllers and input actions; OS-level input was unavailable while the Mac was locked.

The [build manifest](evidence/v012-app/build.json) records SHA-256 for all 90 game files. The [independent ZIP audit](evidence/v012-app/archive-validation.json) passed ten checks, including strict ad-hoc signature, arm64 architecture, version 0.1.2, executable permissions, PCK identity, source hashes and startup from a fresh extraction outside the repository. No editor is needed to play. The app is not notarized.

The [final exported-app airport return flight](evidence/v012-app/flight-report.json) passed: **44.406 km**, **566.133 simulated seconds**, health **100**, no recorded impacts, and a return to the runway below the completion threshold of **0.20 m/s**. All seven captured stages were visually inspected, including the [harbour pass](screenshots/v012/flight-harbour.png) and [stopped aircraft](screenshots/v012/flight-return.png). `parked_speed_mps` in the raw report describes the pre-departure wait, not the final speed.

The [recorded launch](evidence/v012-app/flight-launch.json) used `--disable-vsync --fixed-fps 60 -- --flight-qa --qa-fixed-fps=60`. The run recorded 33,968 active process/physics frames and 34,016 total native draws. Fixed simulation pacing is a route/control check, not a real-time performance benchmark. Its interval statistics and the locked-screen native QA profiles must not be quoted as normal foreground FPS. Aircraft movement after the standard airport-start action used only the production input actions; documentation camera composition did not reposition the aircraft.

## Production and component checks

The [v0.1.2 evidence index](evidence/v012/index.md) identifies each fixture, final log and whether it actually rendered. Complete-world checks assemble 20,864 damage components; local asset tests use smaller controlled scenes.

| Check | Result | What was exercised |
| --- | --- | --- |
| Free creation, immediate entry and navigation | 60 / 60 headless | Actual garage buttons, all eight free classes at zero balance, old copies, occupied state, saved waypoint, optional service charging and incident ownership |
| Economy and experiences | 40 / 40 | Generous first-time funds, repeatable rewards, no repeated migration grant, 16 services and saved stamps |
| World/life integration | 43 / 43 | Complete world, activities, modes and collision |
| Independent vehicle copies | 79 / 79 | Whole-model safe clearance, repeated copies, no wall/building spawn, retained fleet and recovery |
| Vehicle physics | 23 / 23 | All eight classes, steering and braking, stable yacht cargo and actual unrestrained car transport |
| Ground vehicle / aircraft geometry | 33 / 33 headless and native | Dimensions, contact heights, animated wheels/fans, finite geometry, bounded render budget; 11 local native views |
| Boat geometry | 41 / 41 headless; 48 / 48 native | Two hulls, waterlines, stairs, stern platforms and cargo clearance; seven local native views |
| Navigation component | 22 / 22 headless and native | Shared map geometry, clipping, heading, distant marker and no terrain redraw while moving |
| Complete-city map | 21 / 21 | Geographic coordinates, zoom/pan, named entrances and no implicit teleport |
| Legacy city migration | 38 / 38 | Only unsafe old actors move, damage-aware geometry, identifiers and source files preserved |
| Legacy vehicle / bridge migration | 21 / 21 | Safe bridge-underpass parking, airborne aircraft, old approaches and enlarged models |
| Atomic saves and recovery | 8 / 8 | State serialization, backup recovery and independent copies |
| Destruction and repair | 10 / 10 | Visible geometry and collision are removed/restored together |
| Airport | 24 / 24 | Full-size runway layout, wheel tracks, seams and saved damage |
| ICC interiors in full city | 27 / 27 | Actual player walking between street, foyer, hall, auditorium and stage |
| Opera geometry | 17 / 17 | Production model and collider checks |
| Bridge clearance | 29 / 29 | 11,345 road, rail, walkway, approach and damage queries |
| Geographic alignment | 69 / 69 | 34 mapped footprints and 22 public arrival points; same-source projection consistency |

[Bridge driving](evidence/bridge-drive-v012.json) uses the production input actions in both directions. Both runs finished at health 100 with no impacts (85.817 / 85.533 seconds). The live race crossed all eight checkpoints; its completion clock was 84.85 seconds with zero player incidents, a $232 time bonus and $2,232 total reward. The return did not award a second completion. Ambient parked-vehicle impacts no longer deduct the player's race bonus. The bridge collision skin is welded, and Jolt's internal-edge handling prevents the false surface kicks found with the previous physics configuration.

## Camera regression and test conditions

The camera samples the interpolated actor transform after physics, and the test now samples after the production camera update with one native draw per process. The earlier test incorrectly drew in addition to automatic rendering and sampled before the camera's process callback.

This session's Mac was locked. At both 1440 × 900 and 960 × 600 window sizes, the native process ran near 20 Hz and never reported focus. The two 20 Hz physics attempts could not create a meaningful render/physics mismatch; they remain recorded as inconclusive, with their failed evidence checks preserved. They do not establish normal foreground performance.

An explicit 10 Hz physics / approximately 20 Hz native draw test then collected 151 walking and 153 driving frames. Raw physics positions repeated 76 and 77 times; interpolated positions repeated zero times in both cases. Pitch-velocity jumps were 0 and 0.00002464 radians/second between samples, below the unchanged 0.01 limit. Engine draw counts matched the collected frames. The test used a 960 × 600 window and 1440 × 900 logical viewport, nine seconds per scenario including 1.5 seconds of warm-up. This is an interpolation regression, not a foreground FPS claim or an OS keyboard/mouse walkthrough.

## Modelling and geographic limits

Manufacturer photographs and dimensions informed the original procedural car, motorcycle, 787-9-sized jet, Rivamare-inspired speedboat and 90 Ocean-inspired yacht. [Vehicle references](VEHICLE_REFERENCE.md) and [boat references](BOAT_REFERENCE.md) distinguish measured dimensions from estimated panel, cabin and deck geometry. These are stylised game assets, not vendor CAD or photoreal scans.

The map uses real geographic data; ordinary facades and many heights remain inferred. The airport-to-city corridor is simplified, ground is mostly a flat datum, and roads do not implement a complete real traffic or driving-test system. Public venue interiors are partial reconstructions. The city is not a complete 1:1 replica. [Geographic evidence](GEOGRAPHIC_ALIGNMENT.md) tests correspondence to the supplied map sources, not survey accuracy.

No multi-hour soak or broad hardware matrix was completed. Native QA and fixed-step flight are automation, not a manual playthrough. Mac lock prevented final OS-level keyboard/mouse verification; no lock or security setting was changed.

## Reproduce

Install the official matching toolchain described in the README. From the project root:

```sh
./tools/runtime/godot --headless --path game --script ../source/experience_flow_test.gd
./tools/runtime/godot --headless --path game --script ../source/vehicle_spawn_test.gd
./tools/runtime/godot --headless --path game --script ../source/vehicle_model_migration_test.gd
./tools/runtime/godot --headless --path game --script ../tools/test_vehicles.gd
./tools/runtime/godot --path game --script ../source/camera_motion_test.gd -- --compact --physics-hz=10 --sample-seconds=9
./tools/build.sh
./dist/Harbourlife.app/Contents/MacOS/Harbourlife --disable-vsync -- --experience-qa
./dist/Harbourlife.app/Contents/MacOS/Harbourlife --disable-vsync -- --visual-qa --release-v012
./dist/Harbourlife.app/Contents/MacOS/Harbourlife --disable-vsync -- --qa
./dist/Harbourlife.app/Contents/MacOS/Harbourlife --disable-vsync --fixed-fps 60 -- --flight-qa --qa-fixed-fps=60
```

The export template does not support editor-only `--script`. Release checks therefore use bundled validators activated by explicit user arguments. They create isolated `qa_` worlds, retain their fixtures and do not delete player saves. Reports and captures go to the game's local user-data directory. `--interactive-qa` opens a separate test world for normal keyboard/mouse checks without loading a personal save.
