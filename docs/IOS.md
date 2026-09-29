# iPhone / iPad development

Native Godot 4.7.2, arm64, iOS 16+, landscape. A successful export is not a
real-device performance or touch validation. Do not install or launch on a
connected device without authorization for the current session.

## Controls and settings

Left stick moves/steers; drag the right side to look. The contextual controls
use the existing jump, brake, boost, drift, elevation and weapon actions.
Rise/raise is above descend/lower. Menus pause combat and release held actions.
The map supports touch selection and panning. Notifications use a compact
maximum-two-line banner; destination labels avoid the touch controls.

Mobile and `--mobile-preview` use `user://settings_mobile.json`. Desktop keeps
`user://settings.json`; the mobile renderer's frame limit, resolution and window
settings cannot overwrite desktop preferences. Existing world saves are shared.
Backgrounding saves an active non-QA world once and pauses combat.

Phone defaults target 30 FPS at 67% render resolution; tablet uses 75%.
These are budgets, not promises of measured performance. Nearby facade detail
is bounded; base city geometry and collision remain resident. Mobile construction
releases consumed map records and duplicate hidden GPU meshes, retaining
losslessly compressed source geometry for destruction and repair. Unchanged
structures are not rebuilt when starting a new world. The initial parked fleet
is one car; every vehicle remains available through the normal creation flow.

## Quiet Mac preview and related checks

```sh
# A window on the Mac; silent and not a device performance measurement.
tools/runtime/godot --path game --audio-driver Dummy --rendering-method mobile -- --mobile-preview
# Add --mobile-tablet for the tablet layout.

# Run only checks related to the change; PR CI runs the complete suite.
python3 tools/run_checks.py --only mobile_controls_test mobile_profile_test mobile_ui_test
```

`--mobile-qa` uses an isolated unsaved world with engine-injected touches.
`--mobile-visual-qa` adds orbit/walk/sprint/fire screenshots. Review the images:
input assertions alone do not prove visual correctness. The hand-weapon
regression checks actual imported bones across nine animations; held props
follow bone position/rotation without inheriting its approximately 97× scale.

QA reports and images go to `user://qa/mobile-integration/`. `--mobile-qa-keep-open`
leaves a deliberately unsaveable world. Relaunch without QA flags for normal play.
The QA guards hash both settings files and existing saves before/after the run.

## Build and install later

On a Mac with Xcode and the official engine at `tools/runtime/godot`:

```sh
python3 tools/build_ios.py --fetch-templates
# With an existing valid development signing identity/profile:
python3 tools/build_ios.py --team YOURTEAMID --sign --configuration Release \
  --output dist/ios-next --report reports/ios-next.json
```

The first command obtains the pinned official template archive, verifies SHA-256
and SHA-512 and caches the iOS template. Subsequent builds use the verified cache.
`--prepare-only` checks tooling; `--project-only` generates an Xcode project.
Outputs must be empty: use a new output/report path for each build.

The build stages a copy of the game and licensing notices, leaving source presets
and files unchanged. Unsigned output cannot run on a device. Signing uses existing
credentials and never requests provisioning automatically. Signed bundles live
outside synced Documents by default, under
`~/Library/Application Support/Harbourlife/ios-builds/`, to avoid Finder metadata
invalidating signatures; use the exact `app.path` returned in the build report.
The script does not install, publish, upload to App Store Connect or export an IPA.

For an authorized installation, open the generated Xcode project, select your
team and connected device, enable Developer Mode/trust as required by iOS, and run.
Update-install the same bundle identifier to retain app data; do not uninstall
as a routine troubleshooting step. Keep team IDs, device IDs and account details
out of public reports. See [Godot's iOS export guide](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html).

## Real-device checklist

- Actual finger movement, simultaneous fire/aim, menus, map, entering/leaving vehicles.
- Foreground/background, lock/unlock, interruption and save/resume; no stuck actions.
- Screenshots on foot, in car, tank, helicopter and map, including safe-area edges.
- Ordinary title-menu idle and loaded-game idle, not only the scripted QA route.
- Sustained frame times, heat, audio and peak physical memory on the intended device.

`--mobile-stress-qa --mobile-stress-seconds=50` drives the production six-location
route for at least five minutes; do not use fixed FPS or a debugger during timing.
`--mobile-stress-keep-open` leaves the completed temporary world paused for a
separate native-memory measurement. Require a successful `task_info` return and
record physical footprint, lifetime peak and remaining limit separately from
Godot's allocation counters. Target at least 500 MB below the device limit.
A SIG9 alone is not evidence of a memory crash: installation, explicit termination
and system reclamation must be distinguished using logs and matching processes.

These changes still require hardware acceptance. Earlier 2026-09-29 testing of
`ios-mobile-final-20260929` recorded 29.91 effective FPS over 300.10 seconds and a
3.162 GB lifetime physical peak; that older run is not validation of later UI or
control changes, nor iPad hardware. Raw local evidence remains under ignored
`reports/ios-final-stress/`. iOS can emit an engine startup mouse diagnostic;
distinguish it from new or repeated script/runtime errors instead of hiding logs.
