# Preview validation

Tested 10 September 2026 on Apple M4, 16 GB, macOS 26.5, Godot 4.7.2, Metal / Forward+, 1440 × 900. This is a playable experimental preview, not a commercial-readiness certificate. No Intel Mac, Windows, Linux or browser player build is claimed.

| Check | Passed | Evidence |
| --- | ---: | --- |
| Native game QA | 28 / 28 | [JSON](evidence/delivery-qa.json) |
| World/life integration | 43 / 43 | [results](evidence/integration.txt) |
| Airport geometry, seams and saved damage | 24 / 24 | [results](evidence/airport.txt) |
| Vehicle physics | 18 / 18 | [JSON](evidence/vehicle-physics.json) |
| Save files and recovery | 8 / 8 | [results](evidence/save.txt) |
| Building mesh/collision damage consistency | 10 / 10 | [results](evidence/building_damage.txt) |

The native QA sets controlled starting positions and drives normal input actions. Integration tests move the character to checkpoints to validate activity conditions; they do not replace manually walking every route. Real-time gameplay needs further user testing.

## Airport flight

The complete native flight passed: start parked on Sydney Airport runway 34L, take off, fly past the Opera House and Harbour Bridge, return to the same runway and stop below 0.2 m/s. Simulated duration 565.65 s, travelled distance 44.37 km, minimum aircraft health 100/100, no recorded impacts. Closest horizontal distances: Opera House 484.49 m, bridge central reference 870.60 m. See [flight telemetry](evidence/flight-report.json).

After the normal airport-start operation, the automation uses production flight inputs; it does not set the aircraft position during the route. The documentation camera changes its angle around the aircraft to show landmarks. The movie uses fixed 24 FPS capture with an explicit render each process frame. Its simulation-to-video time ratio is approximately 0.99997; it is not a real-time performance benchmark. The published highlight video is an edited 67.91-second selection, retaining capture speed within each shot. Full captured flight: 567.16 seconds including start/end padding. Screenshots on the README are actual game frames.

## Performance limitation

Short native samples explicitly render each process iteration to avoid counting skipped occluded draws. Normal vehicle scenarios reported approximately 107–114 FPS in the engine monitor. The visible Opera House destruction sample (11 components, 33 debris bodies) included a **518 ms process-frame stall**, despite a monitor average of 94.3 FPS. Averages do not establish stable 60 FPS. The detailed JSON includes median, P95, worst process intervals and explicit render counts.

There has been no multi-hour soak test, comprehensive accessibility audit, general hardware matrix or fully manual takeoff/landing acceptance. Four repeated life/sandbox resets and save round trips do not establish indefinite stability. Simplified visuals, limited life content, occasional stalls and unresolved commercial landmark-image clearance remain documented limitations.

## Reproduce selected checks

Install the fixed toolchain as described in the README, then run from the repository root:

```sh
./tools/runtime/godot --headless --path game --script ../tools/test_save.gd
./tools/runtime/godot --headless --path game --script ../tools/test_integration.gd
./tools/runtime/godot --headless --path game --script ../tools/test_vehicles.gd
./tools/runtime/godot --headless --path game --script ../source/airport_test.gd
./tools/build.sh
./dist/Harbourlife.app/Contents/MacOS/Harbourlife --disable-vsync -- --qa
./dist/Harbourlife.app/Contents/MacOS/Harbourlife -- --flight-qa
```

Release packaging checks and gameplay-source identity are recorded in [release-build.json](evidence/release-build.json). The public release changes packaging, permission notices and build portability; the prior flight and gameplay evidence is tied to unchanged gameplay scripts/assets, rather than presented as a new manual flight.
