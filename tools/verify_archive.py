#!/usr/bin/env python3
"""Independent release audit. Writes reports and fresh /tmp extraction only.

Prepare: python3 tools/verify_archive.py --prepare-only
Final:   python3 tools/verify_archive.py --manifest REPORT/build.json
         --archive dist/Harbourlife-macOS-arm64.zip
         [--source-archive dist/Harbourlife-source-public.zip]
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import zipfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
RESOURCES = [
    "res://scripts/main.gd", "res://scripts/navigation_input_validation.gd",
    "res://scripts/harbor_map.gd", "res://scripts/harbor_minimap.gd",
    "res://scripts/opera_landmark.gd", "res://scripts/opera_interiors.gd",
    "res://scripts/opera_access_validation.gd", "res://scripts/precinct_validation.gd", "res://scripts/darling_public_facilities.gd",
    "res://scripts/darling_precinct_businesses.gd", "res://assets/darling_precinct_directory.json",
    "res://assets/darling_public_facilities.json", "res://assets/darling_precinct_frontages.json",
    "res://scripts/save_store.gd", "res://scripts/hoverboard_motion.gd",
    "res://scripts/hoverboard_models.gd", "res://scripts/mobility_validation.gd",
    "res://scripts/air_vehicle_validation.gd", "res://scripts/experience_validation.gd",
    "res://scripts/flight_validation.gd", "res://scripts/landmark_validation.gd",
    "res://scripts/sydney_tower_landmark.gd", "res://scripts/circular_quay_detail.gd",
    "res://scripts/darling_square_detail.gd", "res://scripts/map_migration.gd",
    "res://scripts/vehicle_model_migration.gd", "res://assets/city_map.json",
    "res://assets/icc_geometry.json", "res://assets/bridge_north_approach.json",
    "res://scripts/manowar_detail.gd", "res://assets/manowar_piers.json",
    "res://scripts/city_landmarks.gd", "res://scripts/icc_landmarks.gd",
    "res://scripts/bank_landmarks.gd", "res://scripts/quay_landmarks.gd",
]


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def game_hashes():
    return {str(p.relative_to(ROOT)): digest(p) for p in sorted((ROOT / "game").rglob("*"))
            if p.is_file() and ".godot" not in p.parts}


def difference(actual, expected):
    return {"file_count": len(actual), "expected_count": len(expected),
            "missing": sorted(expected.keys() - actual.keys()),
            "extra": sorted(actual.keys() - expected.keys()),
            "mismatched": sorted(k for k in actual.keys() & expected.keys() if actual[k] != expected[k])}


def public_source_audit():
    spec = importlib.util.spec_from_file_location("release_files_audit", ROOT / "tools/release_files.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    files = module.public_files(ROOT)
    forbidden_parts = {"runtime", "map-runtime", "media-venv", ".godot", ".git", "__pycache__",
                       "worlds", "saves", "photos", "private", "secrets", "tmp", "dist"}
    forbidden_suffixes = {".pem", ".key", ".p12", ".pfx", ".bak", ".avi", ".mp4"}
    path_failures = []
    content_failures = []
    # High-confidence credential formats only; never print matching values.
    secret_patterns = [rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
                       rb"\bAKIA[0-9A-Z]{16}\b", rb"\bghp_[A-Za-z0-9]{36}\b",
                       rb"\bsk-(?:proj-)?[A-Za-z0-9_-]{48,}\b"]
    for path in files:
        relative = path.relative_to(ROOT)
        if (any(x.lower() in forbidden_parts for x in relative.parts) or
                path.name.startswith(".env") or path.name == "USER_REQUEST.txt" or
                path.suffix.lower() in forbidden_suffixes or path.is_symlink()):
            path_failures.append(str(relative))
        if path.suffix.lower() in {".md", ".txt", ".json", ".gd", ".py", ".cfg", ".godot", ".command"}:
            content = path.read_bytes()
            if any(re.search(pattern, content) for pattern in secret_patterns):
                content_failures.append(str(relative))
    return files, {"file_count": len(files), "forbidden_paths": path_failures,
                   "credential_pattern_paths": content_failures,
                   "scope": "Explicit source allowlist and high-confidence credential scan; no matching values printed; no user-data or ignored private files opened.",
                   "passed": not path_failures and not content_failures}


def command(args, cwd=Path("/tmp"), timeout=240):
    result = subprocess.run([str(x) for x in args], cwd=cwd, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    return result.returncode, result.stdout


def errors(text):
    return [line for line in text.splitlines() if "SCRIPT ERROR:" in line or "ERROR:" in line]


def safe_extract(archive, target):
    with zipfile.ZipFile(archive) as package:
        corrupt = package.testzip()
        if corrupt:
            raise RuntimeError("ZIP CRC failed: " + corrupt)
        names = []
        modes = {}
        for entry in package.infolist():
            name = PurePosixPath(entry.filename)
            mode = entry.external_attr >> 16
            if (name.is_absolute() or ".." in name.parts or not name.parts or
                    name.parts[0] != "Harbourlife.app" or stat.S_ISLNK(mode) or
                    "\\" in entry.filename):
                raise RuntimeError("Unexpected or unsafe ZIP member path")
            if entry.filename in names:
                raise RuntimeError("Duplicate ZIP member")
            names.append(entry.filename)
            destination = target.joinpath(*name.parts)
            if entry.is_dir():
                destination.mkdir(parents=True, exist_ok=True)
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                with package.open(entry) as source, destination.open("wb") as output:
                    shutil.copyfileobj(source, output)
                os.chmod(destination, mode & 0o777)
                modes[entry.filename] = mode & 0o777
        return names, modes


def audit_source_zip(archive, files):
    expected = {str(p.relative_to(ROOT)): digest(p) for p in files}
    with zipfile.ZipFile(archive) as package:
        corrupt = package.testzip()
        manifest = json.loads(package.read("harbourlife/SOURCE_MANIFEST.json"))
        expected_names = {"harbourlife/" + p for p in expected} | {"harbourlife/SOURCE_MANIFEST.json"}
        actual_names = package.namelist()
        hashed = {k: hashlib.sha256(package.read("harbourlife/" + k)).hexdigest()
                  for k in expected if "harbourlife/" + k in actual_names}
    detail = difference(hashed, expected)
    return {"passed": corrupt is None and len(actual_names) == len(set(actual_names)) and
            set(actual_names) == expected_names and manifest == expected and hashed == expected,
            "file_count": len(hashed), "hash_comparison": detail, "sha256": digest(archive),
            "manifest_matches_working_tree": manifest == expected,
            "only_allowlisted_entries": set(actual_names) == expected_names}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--archive", type=Path, default=ROOT / "dist/Harbourlife-macOS-arm64.zip")
    parser.add_argument("--source-archive", type=Path)
    parser.add_argument("--version", default="0.1.6")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    output = args.output.resolve() if args.output else ROOT / "reports" / ("archive-audit-preparation.json" if args.prepare_only else "archive-validation.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    record = {"checked_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "mode": "preparation_only" if args.prepare_only else "final_archive_audit", "checks": {}}
    try:
        files, public = public_source_audit()
        record["public_source_allowlist"] = public
        record["checks"]["public_allowlist_excludes_runtime_saves_private_credentials"] = public["passed"]
        if args.prepare_only:
            record["pending"] = ["Receive final build manifest and app ZIP", "Verify archive SHA and CRC",
                                 "Extract to fresh /tmp preserving archive modes", "arm64-only, version, strict codesign",
                                 "PCK/resource loader and complete game source hash matching",
                                 "Headless full-world READY from /tmp; no normal save/settings reads",
                                 "Optional final public source ZIP exact allowlist/hash comparison"]
        else:
            if args.manifest is None:
                raise RuntimeError("Final audit requires --manifest")
            manifest = json.loads(args.manifest.read_text())
            archive = args.archive.resolve()
            record["archive_sha256"] = digest(archive)
            record["checks"]["archive_matches_final_build_manifest"] = record["archive_sha256"] == manifest["archive_sha256"]
            expected = manifest["source_sha256"]
            actual = game_hashes()
            record["source_hashes"] = difference(actual, expected)
            record["checks"]["all_game_hashes_match_final_build"] = actual == expected
            extracted = Path(tempfile.mkdtemp(prefix="harbourlife-zip-audit-", dir="/tmp"))
            record["extraction_directory"] = str(extracted)
            entries, modes = safe_extract(archive, extracted)
            record["checks"]["zip_crc_and_safe_entries"] = True
            record["archive_entries"] = len(entries)
            app = extracted / "Harbourlife.app"
            executable = app / "Contents/MacOS/Harbourlife"
            binary_name = "Harbourlife.app/Contents/MacOS/Harbourlife"
            record["executable_mode"] = oct(executable.stat().st_mode & 0o777)
            record["checks"]["executable_permissions_preserved"] = (executable.stat().st_mode & 0o777) == modes[binary_name] and modes[binary_name] & 0o111 == 0o111
            info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
            record["plist"] = {k: info.get(k) for k in ("CFBundleExecutable", "CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion")}
            record["checks"]["plist_version_and_executable"] = info.get("CFBundleExecutable") == "Harbourlife" and info.get("CFBundleShortVersionString") == args.version and info.get("CFBundleVersion") == args.version
            code, architecture = command(["lipo", "-archs", executable])
            record["architecture"] = architecture.strip()
            record["checks"]["arm64_only"] = code == 0 and architecture.strip() == "arm64"
            code, signed = command(["codesign", "--verify", "--deep", "--strict", "--verbose=2", app])
            record["codesign"] = {"returncode": code, "output": signed, "notarization": "Not tested; project distributes an ad-hoc signed local preview."}
            record["checks"]["strict_codesign"] = code == 0
            resources = app / "Contents/Resources"
            record["resources"] = sorted(str(p.relative_to(resources)) for p in resources.rglob("*") if p.is_file())
            required = ["Harbourlife.pck", "LICENSE", "PLAY_PERMISSION.md", "licenses/GODOT_LICENSE.txt", "licenses/ASSET_REGISTER.md"]
            record["checks"]["pck_and_resources_present"] = all((resources / name).is_file() for name in required) and (resources / "Harbourlife.pck").stat().st_size > 1024
            pck_hash = digest(resources / "Harbourlife.pck")
            record["pck_sha256"] = pck_hash
            record["checks"]["extracted_pck_matches_built_app"] = pck_hash == digest(Path(manifest["app"]) / "Contents/Resources/Harbourlife.pck")
            script = extracted / "resource_probe.gd"
            script.write_text('extends SceneTree\nfunc _initialize():\n\tvar failed:=false\n\tfor path in ' + json.dumps(RESOURCES) + ':\n\t\tvar okay:bool=(ResourceLoader.exists(path) and load(path)!=null) if str(path).ends_with(".gd") else FileAccess.file_exists(path)\n\t\tprint("ARCHIVE_RESOURCE ",path," ",okay)\n\t\tif not okay:failed=true\n\tvar packed_store=load("res://scripts/save_store.gd")\n\tprint("ARCHIVE_SAVE_FORMAT ",packed_store.VERSION)\n\tif packed_store.VERSION!=5:failed=true\n\tquit(1 if failed else 0)\n')
            # Release templates do not support the tools-only --script flag.
            # The matching official toolchain loads this exact extracted PCK;
            # the App itself is tested separately through its bundled QA flag.
            engine = ROOT / "tools/runtime/godot"
            version_code, version_text = command([engine, "--version"])
            resource_command = [engine, "--headless", "--path", extracted, "--main-pack", resources / "Harbourlife.pck", "--script", script, "--quit-after", "60", "--", "--interactive-qa"]
            code, text = command(resource_command)
            (ROOT / "reports/archive-resources.log").write_text(text)
            format_match = re.search(r"^ARCHIVE_SAVE_FORMAT (\d+)$", text, re.MULTILINE)
            packed_format = int(format_match.group(1)) if format_match else None
            record["resource_probe"] = {"returncode": code, "resources": len(RESOURCES), "packed_save_format": packed_format, "expected_save_format": 5, "errors": errors(text), "engine": version_text.strip(), "method": "Matching official Godot version independently loads scripts and JSON from this extracted PCK and reads its actual save-store VERSION; not a claim that the release template accepts external --script."}
            record["checks"]["bundled_models_and_qa_resources_loadable"] = version_code == 0 and version_text.strip() == manifest["engine"] and code == 0 and text.count("ARCHIVE_RESOURCE ") == len(RESOURCES) and not errors(text) and " false" not in text and packed_format == 5
            smoke_command = [executable, "--headless", "--quit-after", "15", "--log-file", extracted / "isolated-engine.log", "--", "--interactive-qa"]
            started = time.monotonic()
            code, smoke = command(smoke_command)
            (ROOT / "reports/archive-smoke.log").write_text(smoke)
            engine_log = (extracted / "isolated-engine.log").read_text() if (extracted / "isolated-engine.log").exists() else ""
            ready = [line for line in smoke.splitlines() if "HARBOR_WORLD_READY" in line]
            qa_ready = [line for line in smoke.splitlines() if "INTERACTIVE_QA_READY" in line]
            record["smoke"] = {"returncode": code, "elapsed_seconds": round(time.monotonic() - started, 3), "cwd": "/tmp", "command": [str(p) for p in smoke_command],
                               "world_ready_lines": ready, "qa_ready_lines": qa_ready,
                               "errors": sorted(set(errors(smoke) + errors(engine_log))),
                               "save_isolation": "Built-in --interactive-qa skips normal slot/settings reads; no existing user saves read or deleted. Headless only; no native GPU validation in this audit."}
            record["checks"]["fresh_extracted_app_full_world_ready_without_errors"] = code == 0 and bool(ready) and bool(qa_ready) and bool(engine_log) and not record["smoke"]["errors"]
            record["checks"]["game_hashes_still_match_after_smoke"] = game_hashes() == expected
            if args.source_archive:
                record["public_source_zip"] = audit_source_zip(args.source_archive.resolve(), files)
                record["checks"]["public_source_zip_exact_allowlist_and_hashes"] = record["public_source_zip"]["passed"]
            else:
                record["public_source_zip"] = {"status": "Not supplied; source allowlist checked, source ZIP not verified in this run."}
    except Exception as error:
        record["failure"] = {"type": type(error).__name__, "message": str(error)}
        record["checks"]["audit_completed"] = False
    record["passed"] = bool(record["checks"]) and all(record["checks"].values())
    output.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"mode": record["mode"], "passed": record["passed"], "checks": len(record["checks"]),
                      "failed": [k for k, v in record["checks"].items() if not v], "report": str(output)}, ensure_ascii=False))
    return 0 if record["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
