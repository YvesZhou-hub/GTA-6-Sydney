# v0.1.1-preview.1 validation

This record covers the expanded city update on Apple M4, 16 GB, macOS 26.5, Godot 4.7.2, Metal / Forward+, 1440 × 900. The application is an experimental Apple Silicon Mac preview. Intel Mac, Windows, Linux and browser player builds have not been verified.

**The final exported application passed native QA, the airport return flight and standalone ZIP extraction checks.** [Build identity and source hashes](evidence/release-build.json) bind these results to the downloadable application. Older v0.1.0 flight footage and performance numbers are not evidence for this update.

| Check | Result | Scope |
| --- | --- | --- |
| World/life integration | [43 / 43](evidence/integration.txt) | Complete city reached READY; four life/sandbox resets, activities, state and world collision |
| World damage | [10 / 10](evidence/building_damage.txt) | Visible geometry and collision disappear, survive save restoration, and repair together |
| Bridge clearance | [29 / 29](evidence/bridge.txt) | 11,111 queries including road, rail, footway, approaches and damaged deck |
| Airport subsystem | [24 / 24](evidence/airport.txt) | Three full-size runway pairs, wheel-lane seams and saved damage |
| Vehicle physics | [18 / 18](evidence/vehicle-physics.json) | Ground, boat, helicopter and fixed-wing scenarios |
| Save/recovery | [8 / 8](evidence/save.txt) | Atomic storage and recovery |
| Map source geometry | [21 / 21](evidence/city-data.json) | Footprint/courtyard area, heights, pitched-roof rise, land/water and Metro holes |
| CPU city geometry/damage | [9 / 9](evidence/city-geometry.txt) | Outward winding, matching roof collision, damage and exact repair |
| Current-world vehicle copies | [75 / 75](evidence/vehicle-spawn.json) | Independent repeated copies, full-envelope clearance, save/reload and old-copy preservation |
| Current-world navigation | [21 / 21](evidence/city-map-ui.json) | Pan/zoom, locations, public entrances and no implicit teleport |
| Legacy map migration | [38 / 38](evidence/map-migration.json) | Existing actors displaced only if new geometry conflicts; roof and wall damage handled separately |
| ICC complete-world interiors | [27 / 27](evidence/icc-interiors.txt) | Actual player walks from street to interior and returns |
| Exported application native QA | [28 / 28](evidence/delivery-qa.json) | Normal input actions and controlled fixtures; actual rendering |
| Exported application airport return flight | [Passed](evidence/flight-report.json) | 44.373 km, 565.65 simulated seconds; health 100%; returned to the runway and stopped |

Component references contain the photographed scope and model-specific checks: [bridge](BRIDGE_REFERENCE.md), [Opera](OPERA_REFERENCE.md), [city landmarks](CITY_REFERENCE.md), [banks](BANK_REFERENCE.md), [Quay towers](QUAY_REFERENCE.md), [cybersecurity offices](CYBER_REFERENCE.md), [Manly](MANLY_REFERENCE.md), [Metro](METRO_REFERENCE.md), [Darling Square](DARLING_SQUARE_REFERENCE.md), and [ICC](ICC_REFERENCE.md). Individual model checks are not a claim that every city street or private interior has been manually surveyed.

## Camera and road regressions

The original camera problem was reproduced by forcing 20 Hz physics with a higher render rate. Before interpolation, the walk sample had 270 unchanged render positions out of 341 and the car sample 347/418. After the fix, the corresponding samples had 0/419 and 0/420 unchanged interpolated positions. These before/after recordings use the original controlled route; the later city check uses the airport runway and is identified separately.

The city check recorded 245 render samples per walk/car run: 174 raw physics positions repeated, but zero interpolated positions repeated. Walking pitch steps stayed below 0.0000036 radians; the car sample recorded zero pitch steps. This tests the physics/render timing mismatch, not every possible frame hitch or camera collision. [Original before](evidence/camera-before.json), [original after](evidence/camera-after.json), [expanded-city check](evidence/camera-city.json).

A separate roof review found and fixed hipped roofs that had valid footprint area but missing ridge vertices. All 524 supported tagged roof records retain a raised profile; 523 are constructed, with one inside the bridge reserve intentionally omitted. Seventeen actual native views were visually inspected; [capture and collider evidence](evidence/roof-review.json). Only seven records contain an explicit roof-rise tag; the remaining 517 rises are estimates.

Road bends and material overlap passed [17 geometry checks](evidence/road-joins.json), including 316 former gap samples, zero road/paving overlap and zero intrusion into the two Metro openings. The exact native street cameras also showed the old black/white fragments were gone. The small Fairy Bower turning island was retained after a satellite image confirmed a triangular planted divider; its precise boundary remains inferred from mapped road width.

## Performance and flight interpretation

The final source scene's stationary city view recorded median 10.939 ms, P95 12.373 ms and worst 13.299 ms across 120 intervals at 1440 × 900. The final five-view capture and sampling evidence is [here](evidence/final-native-captures.json). These figures are not displayed frame rates. Exported-application real-time QA and flight telemetry are recorded separately below. Static samples use a stationary production camera, 24 warm-up frames and 120 measured intervals with `force_draw(false)` plus `process_frame`. They include CPU scheduling and drawing but do not swap the display buffer; they are not displayed FPS, isolated GPU timings or a moving-gameplay benchmark.

The exported app passed 28/28 native QA checks with no logged errors or warnings. It assembled 20,798 damage components and took 38.766 seconds to initialize this city on the test machine. Native QA uses explicit rendering and normal real-time scheduling. The local destruction sample removed 23 components, created 69 debris bodies, and recorded a worst process interval of 49.445 ms (median 8.331 ms, P95 8.768 ms). The short samples do not establish sustained performance. The automated flight uses production control inputs after the standard airport-start action; validation camera changes do not reposition the aircraft.

The complete exported-app flight covered 44.373 km in 565.65 simulated seconds, passed both harbour landmarks, returned to the runway and stopped at 0.080 m/s with health 100 and no recorded impacts. It ran with `--disable-vsync --fixed-fps 60 -- --flight-qa`; this is a native rendered fixed-step route check, not a manual flight or real-time performance benchmark. The engine consumed the recognized fixed-FPS flag before the in-game argument detector could see it. The public report corrects the capture metadata from the [recorded launch arguments](evidence/flight-launch.json), retains the original detector fields, and leaves measured simulation data unchanged. [Runtime log](evidence/flight-runtime.txt), [harbour image](screenshots/flight-harbour.png), [stopped on runway](screenshots/flight-return.png).

There has been no multi-hour soak test, complete manual route audit or broad hardware matrix. The map's flat ground datum, inferred ordinary facades, partial public interiors and simplified airport corridor remain limitations. Source and modelling confidence are documented in [CITY_DATA](CITY_DATA.md).

## Reproduce

Install the fixed official Godot toolchain using the README, then run from the repository root:

```sh
./tools/runtime/godot --headless --path game --script ../tools/test_integration.gd
./tools/runtime/godot --headless --path game --script ../source/world_damage_probe.gd
./tools/runtime/godot --headless --path game --script ../source/bridge_landmark_test.gd
./tools/runtime/godot --headless --path game --script ../source/vehicle_spawn_test.gd
./tools/runtime/godot --headless --path game --script ../source/map_migration_test.gd
./tools/runtime/godot --headless --fixed-fps 60 --path game --script ../source/icc_landmark_test.gd -- --full-world
./tools/runtime/godot --headless --path game --script ../source/road_join_test.gd
./tools/build.sh
./dist/Harbourlife.app/Contents/MacOS/Harbourlife --disable-vsync -- --qa
./dist/Harbourlife.app/Contents/MacOS/Harbourlife --fixed-fps 60 -- --flight-qa
```

The isolated migration fixture reports eight AudioStreamPlaybackWAV objects at engine teardown; this warning was preserved rather than counted as an in-game stability pass. Final application exit is checked separately.

QA scripts use isolated test save identifiers; they do not delete or migrate the player's saved worlds. [Release-build evidence](evidence/release-build.json) records the final ZIP hash, 74 production source hashes, strict ad-hoc signature verification and clean standalone extraction/startup. A fresh extracted copy launched from outside the project, assembled all 20,798 components and exited without logged errors or warnings. The Mac app is not notarized.
