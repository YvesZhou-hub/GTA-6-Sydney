#!/usr/bin/env python3
"""Export a Windows x86_64 supplement without changing the released game sources.

Requires official Godot 4.7.2 and its installed Windows export templates.
This creates a package, not a claim of GPU or Windows runtime validation.
"""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import struct
import subprocess
import tempfile
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ENGINE_VERSION = '4.7.2.stable.official.ed1daf0bf'


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def game_hashes():
    return {p.relative_to(ROOT).as_posix(): digest(p)
            for p in sorted((ROOT / 'game').rglob('*'))
            if p.is_file() and '.godot' not in p.parts}


def project_version():
    text = (ROOT / 'game/project.godot').read_text(encoding='utf-8')
    matches = re.findall(r'^config/version="([0-9]+\.[0-9]+\.[0-9]+)"\s*$', text, re.M)
    if len(matches) != 1 or any(int(part) > 65535 for part in matches[0].split('.')):
        raise RuntimeError('Expected one numeric major.minor.patch project version')
    return matches[0]


def windows_preset(templates, game_version):
    def quoted(path):
        return json.dumps(path.as_posix(), ensure_ascii=False)
    return f'''[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
include_filter="assets/*.json"
exclude_filter="*.md,*.log,export_presets.cfg"
export_path=""
script_export_mode=2

[preset.0.options]
custom_template/debug={quoted(templates / 'windows_debug_x86_64.exe')}
custom_template/release={quoted(templates / 'windows_release_x86_64.exe')}
binary_format/architecture="x86_64"
binary_format/embed_pck=false
debug/export_console_wrapper=0
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
shader_baker/enabled=false
codesign/enable=false
application/modify_resources=true
application/icon="res://assets/icon.svg"
application/file_version="{game_version}.0"
application/product_version="{game_version}.0"
application/product_name="Harbourlife"
application/file_description="Harbourlife Sydney"
application/copyright="Harbourlife contributors, 2026"
application/export_d3d12=2
application/export_angle=0
'''


def run_logged(engine, args, log):
    with log.open('w', encoding='utf-8') as output:
        subprocess.run([str(engine), *map(str, args)], stdout=output,
                       stderr=subprocess.STDOUT, check=True, timeout=1200)
    text = log.read_text(encoding='utf-8', errors='replace')
    errors = [line for line in text.splitlines()
              if re.search(r'(?:SCRIPT ERROR|SHADER ERROR|ERROR):', line)]
    if errors:
        raise RuntimeError(f'{log.name}: ' + '\n'.join(errors[-15:]))


def verify_pe(exe):
    data = exe.read_bytes()
    if len(data) < 64 or data[:2] != b'MZ':
        raise RuntimeError('Export did not produce a Windows executable')
    offset = struct.unpack_from('<I', data, 0x3c)[0]
    if offset + 26 > len(data) or data[offset:offset + 4] != b'PE\0\0':
        raise RuntimeError('Invalid Windows PE header')
    if (struct.unpack_from('<H', data, offset + 4)[0] != 0x8664
            or struct.unpack_from('<H', data, offset + 24)[0] != 0x20b):
        raise RuntimeError('Expected AMD64 PE32+ executable')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', type=pathlib.Path, required=True)
    parser.add_argument('--templates', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, default=ROOT / 'dist/windows')
    parser.add_argument('--report', type=pathlib.Path, default=ROOT / 'reports/windows-build.json')
    args = parser.parse_args()
    engine, templates = args.engine.resolve(), args.templates.resolve()
    output, report_path = args.output.resolve(), args.report.resolve()
    if not engine.is_file():
        raise SystemExit('Missing Godot executable')
    for name in ('windows_debug_x86_64.exe', 'windows_release_x86_64.exe'):
        if not (templates / name).is_file():
            raise SystemExit('Missing official template: ' + name)
    version = subprocess.check_output([str(engine), '--headless', '--version'], text=True).strip()
    if version != ENGINE_VERSION:
        raise SystemExit(f'Expected {ENGINE_VERSION}, got {version}')
    game_version = project_version()
    game_release = f'v{game_version}-preview.1'
    source_reference = f'docs/evidence/v{game_version.replace(".", "")}-app/build.json'
    reference_path = ROOT / source_reference
    sources = game_hashes()
    reference = json.loads(reference_path.read_text(encoding='utf-8'))
    if sources != reference['source_sha256']:
        raise SystemExit(f'Game files differ from the {game_release} macOS build evidence. Refusing mismatched platform packages.')
    if reference['engine'] != version:
        raise SystemExit('Windows and macOS build evidence must use the same official Godot version')
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    # An existing output is never silently destroyed; choose another output folder.
    if output.exists() and any(output.iterdir()):
        raise SystemExit('Output must be empty: ' + str(output))
    output.mkdir(parents=True, exist_ok=True)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    logs = report_path.parent / 'windows-export-logs'
    logs.mkdir(parents=True, exist_ok=True)
    preset = windows_preset(templates, game_version)
    with tempfile.TemporaryDirectory(prefix='harbourlife-windows-') as temp:
        project = pathlib.Path(temp) / 'game'
        shutil.copytree(ROOT / 'game', project,
                        ignore=shutil.ignore_patterns('.godot', '.DS_Store'))
        (project / 'export_presets.cfg').write_text(preset, encoding='utf-8')
        run_logged(engine, ['--headless', '--path', project, '--editor', '--import', '--quit'], logs / 'import.log')
        package = output / 'Harbourlife'
        package.mkdir()
        exe, pck = package / 'Harbourlife.exe', package / 'Harbourlife.pck'
        run_logged(engine, ['--headless', '--path', project, '--export-release', 'Windows Desktop', exe], logs / 'export.log')
        verify_pe(exe)
        with pck.open('rb') as stream:
            if stream.read(4) != b'GDPC':
                raise RuntimeError('Missing or invalid external Godot PCK')
        shutil.copytree(ROOT / 'licenses', package / 'licenses')
        for name in ('LICENSE', 'PLAY_PERMISSION.md'):
            shutil.copy2(ROOT / name, package / name)
        (package / 'START-HERE.txt').write_text(
            f'HARBOURLIFE / 悉尼海港 — Windows x86_64 {game_version}\n\n'
            '请先全部解压，再运行 Harbourlife.exe。无需安装 Godot。\n'
            '保留旁边的 PCK 和 licenses；移动时移动整个文件夹。\n'
            '使用 Vulkan 渲染，需要支持 Vulkan 的显卡与驱动。\n'
            'WASD 移动，鼠标观察，Tab 免费新增载具并立即驾驶，M 地图，Esc 菜单。\n'
            '跑车/摩托车用 Ctrl + A/D 漂移，Space 急刹，Shift 三倍增压。\n'
            'T 调整日夜，F3 诊断，F5 保存；坦克/战斗机用 X 或左键开火。\n\n'
            'Unzip everything, then run Harbourlife.exe. Keep all accompanying files.\n'
            'Uses Vulkan rendering. A Vulkan-capable GPU and driver are required.\n'
            'This preview is unsigned. Verification scope and download checksums:\n'
            f'https://github.com/YvesZhou-hub/harbourlife/releases/tag/{game_release}\n'
            'Windows instructions: https://github.com/YvesZhou-hub/harbourlife/blob/main/docs/WINDOWS.md\n',
            encoding='utf-8-sig')
        if game_hashes() != sources:
            raise RuntimeError('Original game sources changed during export')
        archive = output / 'Harbourlife-Windows-x86_64.zip'
        manifest = {p.relative_to(output).as_posix(): {'sha256': digest(p), 'bytes': p.stat().st_size}
                    for p in sorted(package.rglob('*')) if p.is_file()}
        with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
            for relative in manifest:
                bundle.write(output / relative, relative)
        with zipfile.ZipFile(archive) as bundle:
            if bundle.testzip() is not None or set(bundle.namelist()) != set(manifest):
                raise RuntimeError('ZIP integrity failure')
            for relative, entry in manifest.items():
                if hashlib.sha256(bundle.read(relative)).hexdigest() != entry['sha256']:
                    raise RuntimeError('ZIP entry changed: ' + relative)
        if game_hashes() != sources:
            raise RuntimeError('Original game sources changed during packaging')
        report = {
            'engine': version, 'architecture': 'x86_64', 'source_commit': commit,
            'game_version': game_version, 'game_release': game_release, 'source_sha256': sources,
            'source_reference': source_reference, 'source_reference_sha256': digest(reference_path),
            'source_file_count': len(sources),
            'source_frozen_from': f'Matches {source_reference} before staging; checked after export and ZIP packaging',
            'windows_preset': preset, 'archive_sha256': digest(archive),
            'archive_bytes': archive.stat().st_size,
            'uncompressed_bytes': sum(entry['bytes'] for entry in manifest.values()),
            'app_identity': {'executable_sha256': digest(exe), 'pck_sha256': digest(pck)},
            'package_files': manifest, 'signature': 'Unsigned preview; no signing certificate configured',
            'rendering': {'default': 'Vulkan Forward+',
                          'gpu_tested_by_build': False},
            'runtime_tested_by_build': False,
        }
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        print(f'BUILT {archive} ({archive.stat().st_size} bytes)')
        print('SHA256 ' + report['archive_sha256'])


if __name__ == '__main__':
    main()
