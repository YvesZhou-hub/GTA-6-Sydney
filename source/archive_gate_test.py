"""Challenge the release archive auditor with real temporary ZIPs and bytes.

The aggregate auditor runs too, with only native command execution substituted.
No game launch, signing action, user data access, package build or GitHub request.
"""
from __future__ import annotations

import contextlib
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import stat
import sys
import tempfile
from unittest.mock import patch
import warnings
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("archive_auditor", ROOT / "tools/verify_archive.py")
auditor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auditor)
checks = []


def check(name, passed, detail=None):
    checks.append({"name": name, "passed": bool(passed), "detail": detail or {}})
    print(("PASS " if passed else "FAIL ") + name)


def write_zip(path, members):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)  # zipfile reports deliberate duplicate fixture names.
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as archive:
            for name, data, mode in members:
                info = zipfile.ZipInfo(name)
                info.create_system = 3
                info.external_attr = mode << 16
                archive.writestr(info, data)


file_mode = stat.S_IFREG | 0o644
exe_mode = stat.S_IFREG | 0o755
dir_mode = stat.S_IFDIR | 0o755


def extraction_case(name, members, expected=False, corrupt=False, dirty=False):
    with tempfile.TemporaryDirectory(prefix="harbour-archive-gate-") as folder:
        base = Path(folder)
        archive, target = base / "fixture.zip", base / "extracted"
        target.mkdir()
        write_zip(archive, members)
        if corrupt:
            data = archive.read_bytes()
            archive.write_bytes(data.replace(b"unique-fixture-payload", b"broken-fixture-payload", 1))
        if dirty:
            (target / "existing.txt").write_bytes(b"keep")
        error = ""
        try:
            auditor.safe_extract(archive, target)
        except Exception as exc:
            error = str(exc)
        untouched = list(target.iterdir()) == ([target / "existing.txt"] if dirty else [])
        check(name, bool(not error) == expected and (expected or untouched),
              {"accepted": not error, "untouched_after_rejection": untouched, "error": error})


extraction_case("valid app archive preserves executable mode and directory structure", [
    ("Harbourlife.app/", b"", dir_mode),
    ("Harbourlife.app/Contents/MacOS/Harbourlife", b"executable fixture", exe_mode),
    ("Harbourlife.app/Contents/Resources/Harbourlife.pck", b"PCK fixture", file_mode),
], True)
with tempfile.TemporaryDirectory(prefix="harbour-archive-modes-") as folder:
    base = Path(folder); target = base / "out"; target.mkdir()
    archive = base / "good.zip"
    write_zip(archive, [("Harbourlife.app/Contents/MacOS/Harbourlife", b"exe", exe_mode)])
    _names, modes = auditor.safe_extract(archive, target)
    executable = target / "Harbourlife.app/Contents/MacOS/Harbourlife"
    check("actual extracted executable retains 0755 archive permissions", executable.stat().st_mode & 0o777 == 0o755 and modes["Harbourlife.app/Contents/MacOS/Harbourlife"] == 0o755)

for label, path in [
    ("parent traversal", "Harbourlife.app/Contents/../../outside"),
    ("absolute path", "/Harbourlife.app/Contents/file"),
    ("foreign root", "Other.app/Contents/file"),
    ("backslash path", "Harbourlife.app/Contents\\outside"),
    ("dot normalization alias", "Harbourlife.app/Contents/./a"),
    ("empty path component", "Harbourlife.app/Contents//a"),
    ("drive or stream component", "Harbourlife.app/Contents/a:stream"),
    ("trailing-space component", "Harbourlife.app/Contents /a"),
    ("trailing-dot component", "Harbourlife.app/Contents./a"),
]:
    extraction_case("rejects " + label + " before extracting any entry", [
        ("Harbourlife.app/Contents/safe-first", b"safe", file_mode),
        (path, b"bad", file_mode),
    ])

for label, first, second in [
    ("raw duplicate", "a", "a"),
    ("casefold duplicate", "A", "a"),
    ("Unicode normalized duplicate", "café", "cafe\u0301"),
]:
    extraction_case("rejects " + label + " destinations", [
        ("Harbourlife.app/Contents/" + first, b"first", file_mode),
        ("Harbourlife.app/Contents/" + second, b"second", file_mode),
    ])
for label, kind in [("symlink", stat.S_IFLNK), ("FIFO", stat.S_IFIFO), ("device", stat.S_IFCHR)]:
    extraction_case("rejects " + label + " ZIP entries", [("Harbourlife.app/Contents/unsafe", b"/outside", kind | 0o777)])
extraction_case("rejects file versus casefolded parent-directory conflicts", [
    ("Harbourlife.app/Contents/ASSET", b"file", file_mode),
    ("Harbourlife.app/Contents/asset/child", b"child", file_mode),
])
extraction_case("rejects parent-directory conflicts regardless of entry order", [
    ("Harbourlife.app/Contents/asset/child", b"child", file_mode),
    ("Harbourlife.app/Contents/asset", b"file", file_mode),
])
extraction_case("rejects CRC-corrupted bytes before extraction", [("Harbourlife.app/Contents/a", b"unique-fixture-payload", file_mode)], corrupt=True)
extraction_case("refuses to overwrite a nonempty extraction destination", [("Harbourlife.app/Contents/a", b"safe", file_mode)], dirty=True)

for kind in ("WARNING", "ERROR", "SCRIPT ERROR", "SHADER ERROR", "FATAL ERROR"):
    text = f"ordinary progress\n\x1b[33m{kind}: deliberate validation fixture\x1b[0m\nfinished"
    found = auditor.errors(text)
    check(kind + " is a fatal audit diagnostic including ANSI color", len(found) == 1 and found[0].startswith(kind + ":"))
check("ordinary status messages do not trigger diagnostic rejection", auditor.errors("HARBOR_WORLD_READY buildings=15097 structure_components=21697\nARCHIVE_RESOURCE res://scripts/main.gd true\n") == [])


def aggregate_case(name, fault=None, expected=False):
    """Execute main and its real file checks; mock only external tool execution."""
    with tempfile.TemporaryDirectory(prefix="harbour-archive-aggregate-") as folder:
        base = Path(folder); (base / "reports").mkdir()
        app_bytes = {
            "Contents/MacOS/Harbourlife": b"synthetic arm64 executable identity",
            "Contents/Resources/Harbourlife.pck": b"synthetic packed data" * 100,
            "Contents/Info.plist": plistlib.dumps({"CFBundleExecutable": "Harbourlife", "CFBundleIdentifier": "test.fixture", "CFBundleShortVersionString": "0.2.2", "CFBundleVersion": "0.2.2"}),
            **{path: b"fixture license" for path in ("Contents/Resources/LICENSE", "Contents/Resources/PLAY_PERMISSION.md", "Contents/Resources/licenses/GODOT_LICENSE.txt", "Contents/Resources/licenses/ASSET_REGISTER.md")},
        }
        archive = base / "fixture.zip"
        write_zip(archive, [("Harbourlife.app/" + path, data, exe_mode if path.endswith("MacOS/Harbourlife") else file_mode) for path, data in app_bytes.items()])
        identity = {"executable_sha256": hashlib.sha256(app_bytes["Contents/MacOS/Harbourlife"]).hexdigest(),
                    "pck_sha256": hashlib.sha256(app_bytes["Contents/Resources/Harbourlife.pck"]).hexdigest()}
        manifest = {"archive_sha256": auditor.digest(archive), "source_sha256": {"game/fixture": "fixture-only"},
                    "engine": "4.7.2.stable.official.fixture", "app_identity": identity,
                    "app": str(base / "absent-original-build.app")}
        resource_warning = ""; smoke_warning = ""; packed_format = 7
        if fault == "exe": manifest["app_identity"]["executable_sha256"] = "0" * 64
        elif fault == "pck": manifest["app_identity"]["pck_sha256"] = "0" * 64
        elif fault == "missing_identity": manifest.pop("app_identity")
        elif fault == "missing_exe_identity": manifest["app_identity"].pop("executable_sha256")
        elif fault == "warning_resource": resource_warning = "WARNING: fixture leaked resource\n"
        elif fault == "warning_smoke": smoke_warning = "WARNING: fixture ObjectDB leak\n"
        elif fault == "old_save": packed_format = 6
        elif fault == "archive_hash": manifest["archive_sha256"] = "0" * 64
        manifest_path = base / "build.json"; manifest_path.write_text(json.dumps(manifest))
        output = base / "report.json"
        extraction = base / "fresh-extraction"

        def fake_mkdtemp(**_kwargs):
            extraction.mkdir()
            return str(extraction)

        def fake_command(args, **_kwargs):
            args = list(map(str, args))
            if args[0] == "lipo": return 0, "arm64\n"
            if args[0] == "codesign": return 0, "fixture signature validation substituted\n"
            if "--version" in args: return 0, manifest["engine"] + "\n"
            if "--main-pack" in args:
                probe = Path(args[args.index("--script") + 1]).read_text()
                if "packed_store.VERSION!=7" not in probe:
                    raise AssertionError("Actual generated probe did not bind default save format 7")
                return 0, "".join("ARCHIVE_RESOURCE " + path + " true\n" for path in auditor.RESOURCES) + f"ARCHIVE_SAVE_FORMAT {packed_format}\n" + resource_warning
            if "--interactive-qa" in args:
                log = Path(args[args.index("--log-file") + 1])
                text = "HARBOR_WORLD_READY buildings=15097 structure_components=21697\nINTERACTIVE_QA_READY world=qa_interactive_123 components=21697\n" + smoke_warning
                log.write_text(text)
                return 0, text
            raise AssertionError("Unexpected native command: " + repr(args))

        argv = ["verify_archive.py", "--manifest", str(manifest_path), "--archive", str(archive), "--output", str(output)]
        with patch.object(auditor, "ROOT", base), patch.object(auditor, "public_source_audit", return_value=([], {"passed": True})), patch.object(auditor, "game_hashes", return_value={"game/fixture": "fixture-only"}), patch.object(auditor, "command", fake_command), patch.object(auditor.tempfile, "mkdtemp", fake_mkdtemp), patch.object(sys, "argv", argv), contextlib.redirect_stdout(io.StringIO()):
            code = auditor.main()
        report = json.loads(output.read_text())
        passed = code == 0 and report.get("passed") is True
        check(name, passed == expected, {"accepted": passed, "failed_gates": [key for key, value in report.get("checks", {}).items() if not value], "failure": report.get("failure")})
        return report


valid = aggregate_case("complete actual aggregate gate accepts matching ZIP identities without original build path", expected=True)
check("aggregate records both extracted SHA256 values directly against manifest", valid["checks"].get("extracted_executable_and_pck_match_final_build") is True and valid["app_identity"]["actual"] == valid["app_identity"]["expected"])
aggregate_case("wrong executable identity fails even when ZIP hash is correct", "exe")
aggregate_case("wrong PCK identity fails even when ZIP hash is correct", "pck")
aggregate_case("missing manifest identities cannot pass aggregate validation", "missing_identity")
aggregate_case("partial manifest identity cannot pass aggregate validation", "missing_exe_identity")
aggregate_case("resource-load warnings fail the actual aggregate gate", "warning_resource")
aggregate_case("smoke-run ObjectDB warnings fail the actual aggregate gate", "warning_smoke")
aggregate_case("old packed save format fails despite zero probe process exit", "old_save")
aggregate_case("archive SHA mismatch still fails aggregate validation", "archive_hash")

out = ROOT / "reports/archive-gate"
out.mkdir(parents=True, exist_ok=True)
report = {"passed": all(row["passed"] for row in checks), "count": len(checks), "checks": checks,
          "tool_sha256": hashlib.sha256((ROOT / "tools/verify_archive.py").read_bytes()).hexdigest(),
          "scope": "Real temporary ZIP extraction/CRC/mode checks, diagnostic rejection and real aggregate auditor execution over synthetic app bytes. Only lipo, codesign and Godot execution are substituted; no real game, signing, release package or user data touched."}
(out / "checks.json").write_text(json.dumps(report, indent=2) + "\n")
print("ARCHIVE_GATE_FIXTURE", json.dumps({"passed": report["passed"], "count": report["count"]}))
sys.exit(0 if report["passed"] else 1)
