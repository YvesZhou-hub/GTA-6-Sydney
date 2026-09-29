#!/usr/bin/env python3
"""Stage Harbourlife, export an iOS Xcode project, and optionally build a device app.

The default build is unsigned and cannot be installed on an iPhone. Nothing is
uploaded, installed, or provisioned. All Godot configuration changes are staged.
"""
import argparse
import hashlib
import json
import os
import pathlib
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ENGINE_VERSION = '4.7.2.stable.official.ed1daf0bf'
RELEASE_TAG = '4.7.2-stable'
ARCHIVE_NAME = 'Godot_v4.7.2-stable_export_templates.tpz'
RELEASE_API = 'https://api.github.com/repos/godotengine/godot-builds/releases/tags/' + RELEASE_TAG
# Published by the official release, checked 2026-09-29. Both hashes cover the
# complete TPZ; a range download of ios.zip cannot establish this provenance.
ARCHIVE_SHA256 = 'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011'
ARCHIVE_SHA512 = 'ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079'
UNSIGNED_TEAM = '0000000000'
SIGNING_BLOCKED_XATTRS = ('com.apple.FinderInfo', 'com.apple.ResourceFork')


def digest(path, algorithm='sha256'):
    result = hashlib.new(algorithm)
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def file_hashes(folder):
    return {p.relative_to(folder).as_posix(): digest(p)
            for p in sorted(folder.rglob('*'))
            if p.is_file() and '.godot' not in p.parts and p.name != '.DS_Store'}


def json_write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


def clean_generated_xattrs(folder):
    """Remove only code-signing blockers, never source or other metadata.

    File Provider may add FinderInfo to new .app/storyboardc directories inside
    Documents, even if source files were copied without their metadata.
    """
    folder = pathlib.Path(folder).resolve()
    for protected in (ROOT / 'game', ROOT / 'licenses'):
        if folder == protected or protected in folder.parents or folder in protected.parents:
            raise RuntimeError('Refusing to clean extended attributes on original sources.')
    # -s operates on symlinks themselves, preventing traversal into source data.
    for attribute in SIGNING_BLOCKED_XATTRS:
        subprocess.run(['xattr', '-r', '-s', '-d', attribute, str(folder)],
                       check=True, capture_output=True, text=True, timeout=60)
    # File Provider can immediately recreate FinderInfo in synced Documents.
    # Record that fact rather than claiming deletion necessarily stayed deleted.
    listing = subprocess.check_output(['xattr', '-r', '-s', '-l', str(folder)],
                                      text=True, errors='replace', timeout=60)
    remaining = []
    for line in listing.splitlines():
        for attribute in SIGNING_BLOCKED_XATTRS:
            marker = ': ' + attribute + ':'
            if marker in line:
                remaining.append({'path': line.split(marker, 1)[0], 'attribute': attribute})
    return {'path': str(folder), 'cleanup_attributes': list(SIGNING_BLOCKED_XATTRS),
            'remaining_blocked_entries': remaining, 'other_attributes_preserved': True}


def read_url(url, accept='application/vnd.github+json'):
    request = urllib.request.Request(url, headers={
        'User-Agent': 'Harbourlife-iOS-build', 'Accept': accept,
        'X-GitHub-Api-Version': '2022-11-28'})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()


def ensure_template(template, fetch=False, archive=None, download_timeout=600):
    receipt_path = template.with_name('ios-template.json')
    if archive is None and template.is_file() and receipt_path.is_file():
        receipt = json.loads(receipt_path.read_text(encoding='utf-8'))
        if (receipt.get('archive_sha256') == ARCHIVE_SHA256
                and receipt.get('archive_sha512') == ARCHIVE_SHA512
                and receipt.get('ios_sha256') == digest(template)):
            return receipt
        raise RuntimeError('iOS template receipt does not match the file; fetch it again into a new template directory.')
    if archive is None and not fetch:
        raise RuntimeError('Missing verified iOS template. Run with --fetch-templates (official download is about 1.28 GB).')
    template.parent.mkdir(parents=True, exist_ok=True)
    if archive is None:
        release = json.loads(read_url(RELEASE_API))
        asset = next(a for a in release['assets'] if a['name'] == ARCHIVE_NAME)
        sums_asset = next(a for a in release['assets'] if a['name'] == 'SHA512-SUMS.txt')
        if asset.get('digest') != 'sha256:' + ARCHIVE_SHA256:
            raise RuntimeError('Official release metadata differs from the pinned SHA-256; investigate before downloading.')
        # A unique query prevents proxies from reusing the JSON response for an
        # octet-stream asset request to the same API URL.
        suffix = '?harbourlife=' + str(time.time_ns())
        sums = read_url(sums_asset['url'] + suffix, 'application/octet-stream').decode('utf-8')
        if not any(line.split() == [ARCHIVE_SHA512, ARCHIVE_NAME] for line in sums.splitlines()):
            raise RuntimeError('Official SHA512-SUMS.txt differs from the pinned export template digest.')
        cache = template.parent / 'downloads'
        cache.mkdir(exist_ok=True)
        archive = cache / ARCHIVE_NAME
        if not archive.is_file():
            partial = archive.with_suffix('.tpz.part')
            print('Downloading the official export templates (bounded timeout, then checksum verification).', flush=True)
            command = ['curl', '--fail', '--location', '--silent', '--show-error',
                       '--connect-timeout', '20', '--max-time', str(download_timeout),
                       '--speed-limit', '131072', '--speed-time', '40',
                       '--header', 'Accept: application/octet-stream',
                       '--header', 'X-GitHub-Api-Version: 2022-11-28',
                       '--header', 'User-Agent: Harbourlife-iOS-build',
                       '--output', str(partial), asset['url'] + suffix]
            subprocess.run(command, check=True, timeout=download_timeout + 10)
            partial.replace(archive)
        json_write(cache / 'official-release.json', release)
        (cache / 'SHA512-SUMS.txt').write_text(sums, encoding='utf-8')
    if digest(archive) != ARCHIVE_SHA256 or digest(archive, 'sha512') != ARCHIVE_SHA512:
        raise RuntimeError('Export archive checksum mismatch. No template was extracted.')
    with zipfile.ZipFile(archive) as bundle:
        members = [m for m in bundle.infolist() if m.filename == 'templates/ios.zip']
        if len(members) != 1:
            raise RuntimeError('Official archive must contain exactly one templates/ios.zip.')
        # Copy just this known member; never extract arbitrary archive paths.
        temporary = template.with_suffix('.zip.part')
        with bundle.open(members[0]) as source, temporary.open('wb') as target:
            shutil.copyfileobj(source, target)
        with zipfile.ZipFile(temporary) as ios:
            if ios.testzip() is not None:
                raise RuntimeError('iOS template ZIP integrity check failed.')
        temporary.replace(template)
    receipt = {'engine': ENGINE_VERSION, 'release_api': RELEASE_API,
               'archive_name': ARCHIVE_NAME, 'archive_sha256': ARCHIVE_SHA256,
               'archive_sha512': ARCHIVE_SHA512, 'ios_sha256': digest(template),
               'ios_bytes': template.stat().st_size, 'extracted_member': 'templates/ios.zip'}
    json_write(receipt_path, receipt)
    return receipt


def ios_preset(template, team, bundle_id, version, minimum_ios):
    quote = lambda value: json.dumps(str(value), ensure_ascii=False)
    return f'''[preset.0]
name="iOS"
platform="iOS"
runnable=true
export_filter="all_resources"
include_filter="assets/*.json,licenses/*"
exclude_filter="*.log,export_presets.cfg"
export_path=""
script_export_mode=2

[preset.0.options]
custom_template/debug={quote(template)}
custom_template/release={quote(template)}
architectures/arm64=true
application/app_store_team_id={quote(team)}
application/bundle_identifier={quote(bundle_id)}
application/export_project_only=true
application/export_method_debug=1
application/export_method_release=1
application/code_sign_identity_debug="Apple Development"
application/code_sign_identity_release="Apple Development"
application/short_version={quote(version)}
application/version={quote(version)}
application/targeted_device_family=2
application/min_ios_version={quote(minimum_ios)}
shader_baker/enabled=false
'''


def clear_placeholder_team(exported):
    project = exported / 'Harbourlife.xcodeproj/project.pbxproj'
    text = project.read_text(encoding='utf-8')
    text = re.sub(r'DEVELOPMENT_TEAM = "?' + UNSIGNED_TEAM + r'"?;', 'DEVELOPMENT_TEAM = "";', text)
    project.write_text(text, encoding='utf-8')
    for path in exported.rglob('*.plist'):
        with path.open('rb') as stream:
            value = plistlib.load(stream)
        if isinstance(value, dict) and value.get('teamID') == UNSIGNED_TEAM:
            value.pop('teamID')
            with path.open('wb') as stream:
                plistlib.dump(value, stream)
    if UNSIGNED_TEAM in project.read_text(encoding='utf-8'):
        raise RuntimeError('Could not remove the staging-only team placeholder from the Xcode project.')


def run_logged(command, log, timeout=1200, godot=False):
    with log.open('w', encoding='utf-8') as stream:
        subprocess.run(list(map(str, command)), stdout=stream, stderr=subprocess.STDOUT,
                       check=True, timeout=timeout, env={**os.environ, 'COPYFILE_DISABLE': '1'})
    text = log.read_text(encoding='utf-8', errors='replace')
    if godot:
        errors = [line for line in text.splitlines() if re.search(r'(?:SCRIPT ERROR|SHADER ERROR|ERROR):', line)]
        if errors:
            raise RuntimeError(log.name + ': ' + '\n'.join(errors[-15:]))
    return text


def xcode_command(project, derived, args):
    command = ['xcodebuild', '-project', project, '-scheme', 'Harbourlife',
               '-configuration', args.configuration, '-sdk', 'iphoneos',
               '-destination', 'generic/platform=iOS', '-derivedDataPath', derived,
               'build', 'ARCHS=arm64', 'ONLY_ACTIVE_ARCH=NO']
    if args.sign:
        command += ['CODE_SIGNING_ALLOWED=YES', 'DEVELOPMENT_TEAM=' + args.team,
                    'CODE_SIGN_IDENTITY=' + args.identity]
        if args.provisioning_profile:
            command += ['CODE_SIGN_STYLE=Manual', 'PROVISIONING_PROFILE_SPECIFIER=' + args.provisioning_profile]
    else:
        command += ['CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO',
                    'CODE_SIGN_IDENTITY=', 'DEVELOPMENT_TEAM=']
    return command


def capture(command):
    result = subprocess.run(command, capture_output=True, text=True, timeout=45)
    return {'returncode': result.returncode, 'output': (result.stdout + result.stderr).strip()}


def verify_pack_licenses(engine, stage, pck, license_folder, log):
    """Read the exported pack in an isolated script, without launching the game."""
    expected = {'res://licenses/' + name: value for name, value in file_hashes(license_folder).items()}
    source = '''extends SceneTree
func _initialize() -> void:
    if not ProjectSettings.load_resource_pack(PACK):
        push_error("Could not open exported PCK")
        quit(1)
        return
    var expected: Dictionary = EXPECTED
    for path in expected:
        if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != expected[path]:
            push_error("Missing or changed license: " + path)
            quit(1)
            return
    print("IOS_LICENSES_VERIFIED ", expected.size())
    quit(0)
'''.replace('PACK', json.dumps(str(pck))).replace('EXPECTED', json.dumps(expected))
    script = stage / 'verify_pack.gd'
    script.write_text(source, encoding='utf-8')
    text = run_logged([engine, '--headless', '--path', stage, '--script', script], log, godot=True)
    if 'IOS_LICENSES_VERIFIED' not in text:
        raise RuntimeError('Exported PCK license verification did not complete.')
    return expected


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=pathlib.Path, default=ROOT / 'tools/runtime/godot')
    parser.add_argument('--template', type=pathlib.Path, default=ROOT / 'tools/runtime/templates/ios.zip')
    parser.add_argument('--fetch-templates', action='store_true', help='download and verify the official 1.28 GB template archive if needed')
    parser.add_argument('--templates-archive', type=pathlib.Path, help='verify and extract ios.zip from an already downloaded official TPZ')
    parser.add_argument('--download-timeout', type=int, default=600)
    parser.add_argument('--prepare-only', action='store_true', help='verify/install templates and stop before export')
    parser.add_argument('--output', type=pathlib.Path, default=ROOT / 'dist/ios-Xcode')
    parser.add_argument('--app-output', type=pathlib.Path,
                        help='app bundle destination; signed builds default to non-synced Library/Application Support')
    parser.add_argument('--report', type=pathlib.Path, default=ROOT / 'reports/ios-build.json')
    parser.add_argument('--project-only', action='store_true', help='generate the Xcode project without compiling it')
    parser.add_argument('--configuration', choices=['Debug', 'Release'], default='Release')
    parser.add_argument('--team', help='real Apple team ID (ten alphanumeric characters); optional for unsigned export')
    parser.add_argument('--bundle-id', default='local.yveszhou.harbourlife')
    parser.add_argument('--minimum-ios', default='16.0')
    parser.add_argument('--sign', action='store_true', help='opt in to local development signing using existing credentials; requires --team')
    parser.add_argument('--identity', default='Apple Development')
    parser.add_argument('--provisioning-profile', help='existing local development profile name for manual signing')
    args = parser.parse_args(argv)
    if args.sign and not args.team:
        parser.error('--sign requires an explicit --team')
    if args.team and (not re.fullmatch(r'[A-Z0-9]{10}', args.team) or args.team == UNSIGNED_TEAM):
        parser.error('--team must be a real ten-character Apple team ID')
    if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', args.bundle_id):
        parser.error('--bundle-id must be a reverse-DNS identifier')
    if not re.fullmatch(r'\d+\.\d+(?:\.\d+)?', args.minimum_ios):
        parser.error('--minimum-ios must be a numeric OS version')
    if args.download_timeout < 30 or args.download_timeout > 1800:
        parser.error('--download-timeout must be between 30 and 1800 seconds')
    report_path, output = args.report.resolve(), args.output.resolve()
    app_output = (args.app_output.resolve() if args.app_output else
                  pathlib.Path.home() / 'Library/Application Support/Harbourlife/ios-builds' / output.name / 'Harbourlife.app'
                  if args.sign else output / 'build/Harbourlife.app')
    logs = report_path.parent / (report_path.stem + '-logs')
    logs.mkdir(parents=True, exist_ok=True)
    report = {'status': 'STARTED', 'stages': {}, 'runtime_tested': False,
              'device_installation_tested': False, 'simulator_tested': False,
              'signing_requested': args.sign, 'provisioning_updates_requested': False,
              'installable_claim': False, 'output': str(output)}
    phase = 'preflight'
    try:
        if sys.platform != 'darwin':
            raise RuntimeError('iOS export requires macOS and Xcode.')
        engine = args.engine.resolve()
        actual_version = subprocess.check_output([str(engine), '--headless', '--version'], text=True, timeout=30).strip()
        if actual_version != ENGINE_VERSION:
            raise RuntimeError(f'Expected {ENGINE_VERSION}, got {actual_version}')
        report['engine'] = actual_version
        report['engine_sha256'] = digest(engine)
        report['xcode'] = capture(['xcodebuild', '-version'])
        report['iphoneos_sdk'] = capture(['xcrun', '--sdk', 'iphoneos', '--show-sdk-version'])
        report['available_signing_identities'] = capture(['security', 'find-identity', '-v', '-p', 'codesigning'])
        if report['xcode']['returncode'] or report['iphoneos_sdk']['returncode']:
            raise RuntimeError('Xcode or the iPhoneOS SDK is unavailable. See report.')
        report['stages'][phase] = 'PASS'
        phase = 'template'
        report['template'] = ensure_template(args.template.resolve(), args.fetch_templates,
                                             args.templates_archive, args.download_timeout)
        report['stages'][phase] = 'PASS'
        if args.prepare_only:
            report['status'] = 'TEMPLATE_READY'
            return 0
        phase = 'staging'
        if output.exists() and any(output.iterdir()):
            raise RuntimeError('Output must be empty; choose a new --output directory: ' + str(output))
        if not args.project_only and app_output.exists():
            raise RuntimeError('App destination must not exist; choose a new --app-output: ' + str(app_output))
        if ROOT / 'game' == output or ROOT / 'game' in output.parents:
            raise RuntimeError('Output must not be inside the source game directory.')
        source_hashes = file_hashes(ROOT / 'game')
        license_hashes = file_hashes(ROOT / 'licenses')
        report['source_sha256'] = source_hashes
        report['license_sha256'] = license_hashes
        report['source_commit'] = capture(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'])['output']
        with tempfile.TemporaryDirectory(prefix='harbourlife-ios-') as temp:
            stage = pathlib.Path(temp)
            game, exported = stage / 'game', stage / 'export'
            shutil.copytree(ROOT / 'game', game, copy_function=shutil.copy,
                            ignore=shutil.ignore_patterns('.godot', '.DS_Store'))
            if file_hashes(game) != source_hashes:
                raise RuntimeError('Game sources changed while staging; retry after edits finish.')
            shutil.copytree(ROOT / 'licenses', game / 'licenses', copy_function=shutil.copy)
            shutil.copyfile(ROOT / 'LICENSE', game / 'licenses/PROJECT_LICENSE.txt')
            shutil.copyfile(ROOT / 'PLAY_PERMISSION.md', game / 'licenses/PLAY_PERMISSION.md')
            clean_generated_xattrs(game)
            version_match = re.search(r'^config/version="([0-9]+\.[0-9]+\.[0-9]+)"',
                                      (game / 'project.godot').read_text(encoding='utf-8'), re.M)
            if not version_match:
                raise RuntimeError('Expected a numeric major.minor.patch game version.')
            report['game_version'] = version_match[1]
            preset = ios_preset(args.template.resolve(), args.team or UNSIGNED_TEAM,
                                args.bundle_id, version_match[1], args.minimum_ios)
            (game / 'export_presets.cfg').write_text(preset, encoding='utf-8')
            report['staged_preset'] = preset
            report['stages'][phase] = 'PASS'
            phase = 'import'
            run_logged([engine, '--headless', '--path', game, '--editor', '--import', '--quit'], logs / 'import.log', godot=True)
            report['stages'][phase] = 'PASS'
            phase = 'xcode_project_generation'
            exported.mkdir()
            export_flag = '--export-debug' if args.configuration == 'Debug' else '--export-release'
            run_logged([engine, '--headless', '--path', game, export_flag, 'iOS', exported / 'Harbourlife.zip'], logs / 'export.log', godot=True)
            project = exported / 'Harbourlife.xcodeproj'
            if not (project / 'project.pbxproj').is_file():
                raise RuntimeError('Godot did not generate a complete Xcode project.')
            pcks = list(exported.rglob('Harbourlife.pck'))
            if len(pcks) != 1:
                raise RuntimeError('Godot did not generate exactly one valid game PCK.')
            with pcks[0].open('rb') as stream:
                if stream.read(4) != b'GDPC':
                    raise RuntimeError('Invalid Godot PCK header.')
            report['pack_license_sha256'] = verify_pack_licenses(engine, stage, pcks[0], game / 'licenses', logs / 'licenses.log')
            if not args.team:
                clear_placeholder_team(exported)
            shutil.copytree(ROOT / 'licenses', exported / 'licenses', copy_function=shutil.copy)
            for name in ('LICENSE', 'PLAY_PERMISSION.md'):
                shutil.copyfile(ROOT / name, exported / name)
            clean_generated_xattrs(exported)
            report['pck_sha256'] = digest(pcks[0])
            report['stages'][phase] = 'PASS'
            # Save the generated project even if compilation fails later.
            shutil.copytree(exported, output, dirs_exist_ok=True, copy_function=shutil.copy)
            report['generated_metadata_cleanup'] = [clean_generated_xattrs(output)]
            report['xcode_project'] = str(output / project.name)
            report['xcode_project_sha256'] = digest(project / 'project.pbxproj')
            report['status'] = 'XCODE_PROJECT_READY'
            if not args.project_only:
                phase = 'device_build'
                derived = stage / 'DerivedData'
                run_logged(xcode_command(project, derived, args), logs / 'xcodebuild.log', timeout=1800)
                app = derived / 'Build/Products' / (args.configuration + '-iphoneos') / 'Harbourlife.app'
                if not app.is_dir():
                    raise RuntimeError('xcodebuild succeeded but the expected device .app is missing.')
                clean_generated_xattrs(app)
                with (app / 'Info.plist').open('rb') as stream:
                    info = plistlib.load(stream)
                executable = app / info['CFBundleExecutable']
                archs = capture(['lipo', '-archs', str(executable)])
                if archs['returncode'] or archs['output'] != 'arm64':
                    raise RuntimeError('Expected an arm64 device executable: ' + archs['output'])
                signature = capture(['codesign', '-dv', '--verbose=2', str(app)])
                if args.sign:
                    run_logged(['codesign', '--verify', '--deep', '--strict', str(app)], logs / 'codesign-verify.log')
                # File Provider recreates FinderInfo in Documents after deletion.
                # Keep installable signed bundles outside that synced hierarchy;
                # the reusable Xcode project still lives in the chosen --output.
                destination = app_output
                destination.parent.mkdir(parents=True, exist_ok=True)
                # copy keeps executable modes, but not copy2's extended metadata.
                shutil.copytree(app, destination, copy_function=shutil.copy)
                report['generated_metadata_cleanup'].append(clean_generated_xattrs(destination))
                if args.sign:
                    run_logged(['codesign', '--verify', '--deep', '--strict', str(destination)], logs / 'copied-codesign-verify.log')
                report['app'] = {'path': str(destination), 'executable_sha256': digest(executable),
                                 'bundle_identifier': info['CFBundleIdentifier'],
                                 'minimum_ios': info.get('MinimumOSVersion'),
                                 'architectures': archs['output'], 'signature': signature,
                                 'embedded_profile': (app / 'embedded.mobileprovision').is_file(),
                                 'bytes': sum(p.stat().st_size for p in app.rglob('*') if p.is_file())}
                report['stages'][phase] = 'PASS'
                report['status'] = 'SIGNED_DEVICE_BUILD_READY' if args.sign else 'UNSIGNED_DEVICE_BUILD_READY'
            phase = 'source_preservation'
            if file_hashes(ROOT / 'game') != source_hashes or file_hashes(ROOT / 'licenses') != license_hashes:
                raise RuntimeError('Original sources changed during the build; report identifies the staged snapshot only.')
            report['stages'][phase] = 'PASS'
        print(report['status'] + ': ' + str(output))
        if 'app' in report:
            print('App: ' + report['app']['path'])
        if not args.sign:
            print('Unsigned output cannot be installed on an iPhone. Open the Xcode project and configure development signing.')
        return 0
    except Exception as error:
        report['stages'][phase] = 'FAIL'
        report['status'] = 'FAILED'
        report['failed_stage'] = phase
        report['error'] = str(error)
        print(f'FAILED [{phase}]: {error}', file=sys.stderr)
        return 1
    finally:
        json_write(report_path, report)
        print('Report: ' + str(report_path))


if __name__ == '__main__':
    raise SystemExit(main())
