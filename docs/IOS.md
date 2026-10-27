# iPhone / iPad development

Native Godot 4.7.2, arm64, iOS 17+, landscape; builds currently target iPhone
only. A successful export is not a
real-device performance or touch validation. Do not install or launch on a
connected device without authorization for the current session.

## Controls and settings

Left stick moves/steers; drag the right side or the held right fire button to
look. Optional left fire leaves the right thumb free. The floating stick follows
the initial touch; push forward beyond its ring briefly and release to lock
running, then touch the stick again to cancel. Menus, backgrounding and vehicle
changes clear all held controls. The contextual controls use the existing jump,
brake, boost, drift, elevation and weapon actions; combat values are unchanged.
Rise/raise is above descend/lower. Menus pause combat and release held actions.
The map supports touch selection and panning. Notifications use a compact
maximum-two-line banner; destination labels avoid the touch controls.

Mobile and `--mobile-preview` use `user://settings_mobile.json`. Desktop keeps
`user://settings.json`; the mobile renderer's frame limit, resolution and window
settings cannot overwrite desktop preferences. Existing world saves are shared.
Backgrounding saves an active non-QA world once and pauses combat.

Settings → Touch controls has four independent sensitivities (look, held fire,
vehicle camera and gyroscope), fixed/floating stick, run lock, left fire and
joystick/button driving. Button driving separates throttle, reverse and brake;
enter/exit stays in the same place. Gyroscope modes are off, while firing and
always. Optional short haptics confirm successful firing, hits and damage;
neither haptics nor real sensor performance can be checked in the Mac preview.

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
and files unchanged. Unsigned output cannot run on a device. `--sign` uses existing
credentials and never requests provisioning; only `--archive`/`--upload` (see
TestFlight below) do. Signed bundles live
outside synced Documents by default, under
`~/Library/Application Support/Harbourlife/ios-builds/`, to avoid Finder metadata
invalidating signatures; use the exact `app.path` returned in the build report.
The script never installs; only `--upload` sends a build to App Store Connect.

For an authorized installation, open the generated Xcode project, select your
team and connected device, enable Developer Mode/trust as required by iOS, and run.
Update-install the same bundle identifier to retain app data; do not uninstall
as a routine troubleshooting step. Keep team IDs, device IDs and account details
out of public reports. See [Godot's iOS export guide](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html).

## TestFlight 公测

```sh
# 归档并导出本地 .ipa 自查，不上传：
python3 tools/build_ios.py --archive --team YOURTEAMID --build-number 2 \
  --output "$HOME/Library/Application Support/Harbourlife/ios-projects/testflight-2" \
  --report reports/ios-testflight-2.json
# 归档并上传到 App Store Connect：
python3 tools/build_ios.py --upload --team YOURTEAMID --build-number 2 \
  --output "$HOME/Library/Application Support/Harbourlife/ios-projects/testflight-2-upload" \
  --report reports/ios-testflight-2-upload.json
```

- 第一次上传前，要先在 App Store Connect 建好 bundle id 为
  `com.yveszhou.harbourlife` 的 App 记录。
- 显示的版本号就是游戏的 `config/version`；`--build-number` 是 CFBundleVersion，
  每次上传都要比上一次大。
- `--archive` 用自动签名，会向 Apple 请求更新证书和描述文件。归档默认放在
  `~/Library/Developer/Xcode/Archives/`，中间文件在
  `~/Library/Application Support/Harbourlife/ios-derived/`，都不放进同步的 Documents。
  上传前脚本会检查归档里的版本号、隐私说明、设备要求、图标有没有透明通道和内存权限，
  有一项不过就停下，不上传。
- bundle id 从 `local.yveszhou.harbourlife` 改成了 `com.yveszhou.harbourlife`：
  以前装的开发版算另一个 App，里面的存档不会带过来。
- 只能装在 iPhone 15 Pro 及更新的机型上（`iphone-performance-gaming-tier`，需要
  iOS 17），这一轮也只支持 iPhone，不支持 iPad。
- 打开了 increased memory limit 权限（`com.apple.developer.kernel.increased-memory-limit`），
  让系统给游戏更高的内存上限。

## Real-device checklist

- Actual finger movement, simultaneous fire/aim, menus, map, entering/leaving vehicles.
- Both fire buttons together; floating stick/run lock; both driving modes and reverse.
- Gyroscope in both landscape orientations and different holding angles; all four
  sensitivities, firing-only mode and haptics on/off, including cooldown refusals.
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
