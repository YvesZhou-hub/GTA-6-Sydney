"""Compile the workflow and challenge its real aggregate gate with synthetic evidence.

No download, build, game launch, GitHub operation or existing player data access.
Passing synthetic input tests only gate logic, never Windows game compatibility.
"""
from __future__ import annotations

import ast
import contextlib
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch

import yaml

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/windows-package-check.yml"
checks = []


def check(name, passed, detail=None):
    checks.append({"name": name, "passed": bool(passed), "detail": detail or {}})
    print(("PASS " if passed else "FAIL ") + name)


workflow = yaml.safe_load(WORKFLOW.read_text())
steps = workflow["jobs"]["build-check-windows"]["steps"]
python_steps = [step for step in steps if step.get("shell") == "python"]
for step in python_steps:
    compile(step["run"], step["name"], "exec")
check("YAML parses and every embedded Python step compiles", len(python_steps) == 8)

dispatch = workflow.get("on", workflow.get(True))["workflow_dispatch"]
check("manual release defaults to v0.2.2-preview.1", dispatch["inputs"]["release_tag"]["default"] == "v0.2.2-preview.1")
runner = next(step["run"] for step in python_steps if step["name"].startswith("Run natural encounter"))
check("encounter EXE runner has isolated user directories, fresh evidence and 300-second timeout",
      all(part in runner for part in ("encounter-user/roaming", "encounter-user/local", "exist_ok=False", "--encounter-qa", "timeout=300", "started_ns", "report_fresh", "encounter_reports()", "encounter-engine.log", "encounter-stdout.log", "encounter-stderr.log")))
arsenal_runner = next(step["run"] for step in python_steps if step["name"].startswith("Run aerial arsenal"))
check("arsenal runner executes the exported EXE with isolated data and fresh bounded evidence",
      all(part in arsenal_runner for part in ("package/Harbourlife", "Harbourlife.exe", "arsenal-user/roaming", "arsenal-user/local", "exist_ok=False", "--arsenal-qa", "timeout=300", "started_ns", "report_fresh", "arsenal_reports()", "arsenal-engine.log", "arsenal-stdout.log", "arsenal-stderr.log", "arsenal-report.json")))
gate = next(step["run"] for step in python_steps if step["name"].startswith("Require world readiness"))
required = {}
for node in ast.walk(ast.parse(gate)):
    if isinstance(node, ast.Assign):
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id.startswith("required_"):
                required[target.id] = ast.literal_eval(node.value)
check("gate requires driving, survival, natural encounter and aerial arsenal behaviors", set(required) == {"required_driving_checks", "required_survival_checks", "required_encounter_checks", "required_arsenal_checks"})
arsenal_source = (ROOT / "game/scripts/arsenal_validation.gd").read_text()
source_names = json.loads(next(line.removeprefix("const REQUIRED := ") for line in arsenal_source.splitlines() if line.startswith("const REQUIRED := ")))
check("arsenal workflow names match every production required scenario", required["required_arsenal_checks"] == set(source_names) and len(source_names) == 15)


def passing_report(names, **metadata):
    names = sorted(names)
    return {"passed": True, "count": len(names), "checks": [{"name": name, "passed": True} for name in names], **metadata}


driving = passing_report(required["required_driving_checks"], failures=0, backend="Jolt Physics", physics_hz=60, user_saves_touched=False, save_written=False)
survival = passing_report(required["required_survival_checks"], world_ready=True, native=False, display_driver="headless", user_saves_touched=False, save_written=False)
encounter = passing_report(required["required_encounter_checks"], world_ready=True, native=False, display_driver="headless", physics_hz=60, qa_running=True, user_saves_touched=False, save_written=False, direct_enemy_spawn_calls=0, forced_damage_calls=0, auto_spawn_enabled=True)
arsenal = passing_report(required["required_arsenal_checks"], world_ready=True, native=False, display_driver="headless", physics_hz=60, qa_running=True, user_saves_touched=False, save_written=False)
process = {"passed": True, "exit_code": 0, "timed_out": False, "report_fresh": True}
baseline = {"package.json": {"passed": True, "archive_sha256": "synthetic-test-only"}, "process.json": dict(process),
            "driving-process.json": dict(process), "driving-report.json": driving,
            "survival-process.json": dict(process), "survival-report.json": survival,
            "encounter-process.json": dict(process), "encounter-report.json": encounter,
            "arsenal-process.json": dict(process), "arsenal-report.json": arsenal}
log_baseline = {
    "engine.log": "HARBOR_WORLD_READY buildings=15097 structure_components=21697\nINTERACTIVE_QA_READY world=qa_interactive_123 components=21697\n",
    "stdout.log": "", "stderr.log": "",
    "driving-engine.log": f"DRIVING_QA_COMPLETE {driving['count']} passed=true\n", "driving-stdout.log": "", "driving-stderr.log": "",
    "survival-engine.log": f"SURVIVAL_QA_COMPLETE {survival['count']} passed=true report=synthetic\n", "survival-stdout.log": "", "survival-stderr.log": "",
    "encounter-engine.log": f"HARBOR_WORLD_READY buildings=15097 structure_components=21697\nENCOUNTER_QA_COMPLETE checks={encounter['count']} passed=true\n", "encounter-stdout.log": "", "encounter-stderr.log": "",
    "arsenal-engine.log": f"HARBOR_WORLD_READY buildings=15097 structure_components=21697\nARSENAL_QA_COMPLETE checks={arsenal['count']} passed=true\n", "arsenal-stdout.log": "", "arsenal-stderr.log": "",
}


def run_case(name, mutate=None, expected=True):
    records, logs = copy.deepcopy(baseline), dict(log_baseline)
    if mutate:
        mutate(records, logs)
    with tempfile.TemporaryDirectory(prefix="harbour-ci-gate-") as folder:
        base = Path(folder)
        evidence, package = base / "evidence", base / "package/Harbourlife"
        evidence.mkdir(); package.mkdir(parents=True)
        identities = {}
        for field, filename in (("executable_sha256", "Harbourlife.exe"), ("pck_sha256", "Harbourlife.pck")):
            data = ("synthetic gate fixture: " + filename).encode()
            (package / filename).write_bytes(data)
            identities[field] = hashlib.sha256(data).hexdigest()
        records["package.json"]["app_identity"] = identities
        for filename, value in records.items():
            (evidence / filename).write_text(json.dumps(value))
        for filename, value in logs.items():
            (evidence / filename).write_text(value)
        path = base / "aggregate_gate.py"
        path.write_text(gate)
        environment = dict(os.environ, QA_ROOT=str(base), GITHUB_STEP_SUMMARY=str(base / "summary.md"))
        result = subprocess.run([sys.executable, str(path)], cwd=base, env=environment, capture_output=True, text=True, timeout=20)
        report_path = evidence / "report.json"
        report = json.loads(report_path.read_text()) if report_path.is_file() else {}
        accepted = result.returncode == 0 and report.get("passed") is True
        failed_gates = [key for key, value in report.get("checks", {}).items() if value is not True]
        check(name, accepted == expected and bool(report), {"expected_accept": expected, "exit_code": result.returncode, "failed_gates": failed_gates, "gate_count": report.get("check_count"), "stderr": result.stderr[-1200:]})
        return report


accepted_report = run_case("complete synthetic evidence is accepted")
check("aggregate binds full arsenal process, report and all runtime logs by identity",
      accepted_report.get("arsenal") == arsenal and accepted_report.get("arsenal_process") == process
      and accepted_report.get("arsenal_report_sha256") == hashlib.sha256(json.dumps(arsenal).encode()).hexdigest()
      and all(accepted_report.get("log_sha256", {}).get(name) == hashlib.sha256(log_baseline[name].encode()).hexdigest()
              for name in ("arsenal-engine.log", "arsenal-stdout.log", "arsenal-stderr.log")))
run_case("missing encounter report is rejected", lambda records, _logs: records.pop("encounter-report.json"), False)
run_case("failed encounter report is rejected", lambda records, _logs: records["encounter-report.json"].update(passed=False), False)


def remove_required(records, logs):
    data = records["encounter-report.json"]
    data["checks"].pop(0)
    data["count"] = len(data["checks"])
    logs["encounter-engine.log"] = log_baseline["encounter-engine.log"].replace(f"checks={encounter['count']}", f"checks={data['count']}")


run_case("missing required encounter behavior is rejected even with a consistent count", remove_required, False)
run_case("failed individual encounter check is rejected", lambda records, _logs: records["encounter-report.json"]["checks"][0].update(passed=False), False)


def duplicate(records, logs):
    data = records["encounter-report.json"]
    data["checks"].append(dict(data["checks"][0]))
    data["count"] = len(data["checks"])
    logs["encounter-engine.log"] = log_baseline["encounter-engine.log"].replace(f"checks={encounter['count']}", f"checks={data['count']}")


run_case("duplicate passing encounter check names are rejected", duplicate, False)
run_case("incorrect encounter check count is rejected", lambda records, _logs: records["encounter-report.json"].update(count=1), False)
run_case("native report cannot impersonate Windows headless evidence", lambda records, _logs: records["encounter-report.json"].update(native=True), False)
run_case("missing production world readiness is rejected", lambda records, _logs: records["encounter-report.json"].update(world_ready=False), False)
run_case("disabled save guard is rejected", lambda records, _logs: records["encounter-report.json"].update(qa_running=False), False)
run_case("player-save access is rejected", lambda records, _logs: records["encounter-report.json"].update(user_saves_touched=True), False)
run_case("disabled production autospawn is rejected", lambda records, _logs: records["encounter-report.json"].update(auto_spawn_enabled=False), False)
run_case("manually spawned enemy evidence is rejected", lambda records, _logs: records["encounter-report.json"].update(direct_enemy_spawn_calls=1), False)
run_case("stale encounter report is rejected", lambda records, _logs: records["encounter-process.json"].update(report_fresh=False), False)
run_case("timed-out encounter process is rejected", lambda records, _logs: records["encounter-process.json"].update(timed_out=True), False)
run_case("missing encounter completion marker is rejected", lambda _records, logs: logs.update({"encounter-engine.log": "HARBOR_WORLD_READY buildings=15097 structure_components=21697\n"}), False)
run_case("runtime warning from encounter phase is rejected", lambda _records, logs: logs.update({"encounter-stderr.log": "WARNING: synthetic fixture warning\n"}), False)


def update_arsenal_count(records, logs):
    data = records["arsenal-report.json"]
    data["count"] = len(data["checks"])
    logs["arsenal-engine.log"] = log_baseline["arsenal-engine.log"].replace(f"checks={arsenal['count']}", f"checks={data['count']}")


def remove_arsenal_required(records, logs):
    records["arsenal-report.json"]["checks"].pop(0)
    update_arsenal_count(records, logs)


def duplicate_arsenal_check(records, logs):
    rows = records["arsenal-report.json"]["checks"]
    rows.append(dict(rows[0]))
    update_arsenal_count(records, logs)


run_case("missing arsenal report is rejected", lambda records, _logs: records.pop("arsenal-report.json"), False)
run_case("failed arsenal report is rejected", lambda records, _logs: records["arsenal-report.json"].update(passed=False), False)
run_case("missing required arsenal scenario is rejected despite matching count and marker", remove_arsenal_required, False)
run_case("failed individual arsenal check is rejected", lambda records, _logs: records["arsenal-report.json"]["checks"][0].update(passed=False), False)
run_case("duplicate passing arsenal names are rejected", duplicate_arsenal_check, False)
run_case("incorrect arsenal count is rejected", lambda records, _logs: records["arsenal-report.json"].update(count=1), False)
run_case("malformed arsenal checks are rejected", lambda records, _logs: records["arsenal-report.json"].update(checks=["not a check"]), False)
run_case("arsenal native evidence cannot impersonate headless Windows", lambda records, _logs: records["arsenal-report.json"].update(native=True), False)
run_case("arsenal wrong display driver is rejected", lambda records, _logs: records["arsenal-report.json"].update(display_driver="windows"), False)
run_case("arsenal wrong physics rate is rejected", lambda records, _logs: records["arsenal-report.json"].update(physics_hz=30), False)
run_case("arsenal missing world-ready state is rejected", lambda records, _logs: records["arsenal-report.json"].update(world_ready=False), False)
run_case("arsenal missing save-isolation mode is rejected", lambda records, _logs: records["arsenal-report.json"].update(qa_running=False), False)
run_case("arsenal player-save reads are rejected", lambda records, _logs: records["arsenal-report.json"].update(user_saves_touched=True), False)
run_case("arsenal player-save writes are rejected", lambda records, _logs: records["arsenal-report.json"].update(save_written=True), False)
run_case("arsenal stale report is rejected", lambda records, _logs: records["arsenal-process.json"].update(report_fresh=False), False)
run_case("arsenal timeout is rejected", lambda records, _logs: records["arsenal-process.json"].update(timed_out=True), False)
run_case("arsenal nonzero process exit is rejected", lambda records, _logs: records["arsenal-process.json"].update(exit_code=1), False)
run_case("arsenal completion cannot be borrowed from encounter logs", lambda _records, logs: logs.update({"encounter-stdout.log": log_baseline["arsenal-engine.log"], "arsenal-engine.log": "HARBOR_WORLD_READY buildings=15097 structure_components=21697\n"}), False)
run_case("arsenal mismatched completion count is rejected", lambda _records, logs: logs.update({"arsenal-engine.log": log_baseline["arsenal-engine.log"].replace(f"checks={arsenal['count']}", "checks=1")}), False)
run_case("arsenal full-city marker cannot be borrowed from earlier stages", lambda _records, logs: logs.update({"arsenal-engine.log": f"ARSENAL_QA_COMPLETE checks={arsenal['count']} passed=true\n"}), False)
run_case("arsenal partial world is rejected", lambda _records, logs: logs.update({"arsenal-engine.log": log_baseline["arsenal-engine.log"].replace("buildings=15097", "buildings=20")}), False)
run_case("missing arsenal stderr file is rejected", lambda _records, logs: logs.pop("arsenal-stderr.log"), False)
run_case("arsenal warning is rejected even after all scenarios passed", lambda _records, logs: logs.update({"arsenal-stderr.log": "WARNING: synthetic fixture warning\n"}), False)
run_case("arsenal runtime error is rejected even after all scenarios passed", lambda _records, logs: logs.update({"arsenal-stdout.log": "SCRIPT ERROR: synthetic fixture failure\n"}), False)
run_case("arsenal controlled scenarios are not subject to natural-encounter-only counters", lambda records, _logs: records["arsenal-report.json"].update(direct_enemy_spawn_calls=8, forced_damage_calls=2, auto_spawn_enabled=False))

# Execute the actual final step with all external commands intercepted. This
# challenges tag/commit and asset preflight logic without touching GitHub.
upload = next(step["run"] for step in python_steps if step["name"].startswith("Upload only verified"))
fixture_commit = "a" * 40
fixture_tag = "v0.2.2-preview.1"
fixture_repo = "fixture-only/harbourlife"


def run_upload_case(name, mutate=None, expected=True, expect_upload=True):
    fixture = {
        "release": {"tagName": fixture_tag, "targetCommitish": fixture_commit, "isDraft": True, "assets": []},
        "refs": [], "tag_objects": {}, "different_asset": False,
        "package": {"build": {"source_commit": fixture_commit}, "release_tag": fixture_tag, "repository": fixture_repo},
    }
    if mutate:
        mutate(fixture)
    commands = []
    error = ""
    with tempfile.TemporaryDirectory(prefix="harbour-release-gate-") as folder:
        base = Path(folder)
        evidence, output = base / "evidence", base / "dist/windows"
        evidence.mkdir(); output.mkdir(parents=True)
        archive = output / "Harbourlife-Windows-x86_64.zip"
        archive.write_bytes(b"synthetic release fixture only")
        fixture["package"]["archive_sha256"] = hashlib.sha256(archive.read_bytes()).hexdigest()
        (evidence / "report.json").write_text(json.dumps({"passed": True, "package": fixture["package"]}))

        def fake_output(command, **_kwargs):
            commands.append(command)
            if command[:3] == ["gh", "release", "view"]:
                return json.dumps(fixture["release"])
            if command[:2] == ["gh", "api"] and "/git/matching-refs/" in command[2]:
                return json.dumps(fixture["refs"])
            if command[:2] == ["gh", "api"] and "/git/tags/" in command[2]:
                return json.dumps({"object": fixture["tag_objects"][command[2].rsplit("/", 1)[1]]})
            raise AssertionError("Unexpected read command: " + repr(command))

        def fake_run(command, **_kwargs):
            commands.append(command)
            if command[:3] == ["gh", "release", "download"]:
                filename = command[command.index("--pattern") + 1]
                directory = Path(command[command.index("--dir") + 1])
                data = b"different existing asset" if fixture["different_asset"] else (output / filename).read_bytes()
                (directory / filename).write_bytes(data)
            elif command[:3] != ["gh", "release", "upload"]:
                raise AssertionError("Unexpected mutation command: " + repr(command))
            return subprocess.CompletedProcess(command, 0)

        original_cwd = Path.cwd()
        environment = {"QA_ROOT": str(base), "GITHUB_SHA": fixture_commit, "RELEASE_TAG": fixture_tag, "GITHUB_REPOSITORY": fixture_repo}
        try:
            os.chdir(base)
            with patch.dict(os.environ, environment), patch.object(subprocess, "check_output", fake_output), patch.object(subprocess, "run", fake_run), contextlib.redirect_stdout(io.StringIO()):
                exec(compile(upload, "workflow-release-upload", "exec"), {"__name__": "__main__"})
        except Exception as exc:
            error = f"{type(exc).__name__}: {exc}"
        finally:
            os.chdir(original_cwd)
    uploaded = any(command[:3] == ["gh", "release", "upload"] for command in commands)
    changes_status = any(command[:3] in (["gh", "release", "edit"], ["gh", "release", "create"]) for command in commands)
    clobbers = any("--clobber" in command for command in commands)
    check(name, (not error) == expected and uploaded == (expected and expect_upload) and not changes_status and not clobbers,
          {"expected_accept": expected, "uploaded": uploaded, "release_status_changed": changes_status, "error": error})


def with_commit_ref(fixture, commit=fixture_commit):
    fixture["refs"] = [{"ref": "refs/tags/" + fixture_tag, "object": {"type": "commit", "sha": commit}}]


run_upload_case("exact-commit draft accepts verified assets before its Git tag exists")
run_upload_case("matching existing lightweight tag accepts verified assets", with_commit_ref)


def annotated_ref(fixture):
    fixture["refs"] = [{"ref": "refs/tags/" + fixture_tag, "object": {"type": "tag", "sha": "b" * 40}}]
    fixture["tag_objects"]["b" * 40] = {"type": "commit", "sha": fixture_commit}


run_upload_case("annotated tag is resolved to the validated commit", annotated_ref)


def published_release(fixture):
    with_commit_ref(fixture)
    fixture["release"]["isDraft"] = False


run_upload_case("exact-commit published release accepts verified assets without status mutation", published_release)
run_upload_case("floating release target main is rejected before upload", lambda f: f["release"].update(targetCommitish="main"), False)
run_upload_case("wrong full release target commit is rejected before upload", lambda f: f["release"].update(targetCommitish="c" * 40), False)
run_upload_case("wrong release tag is rejected before upload", lambda f: f["release"].update(tagName="v0.2.0-preview.1"), False)
run_upload_case("package source commit mismatch is rejected before upload", lambda f: f["package"]["build"].update(source_commit="c" * 40), False)
run_upload_case("package repository mismatch is rejected before upload", lambda f: f["package"].update(repository="other/project"), False)
run_upload_case("existing tag on another commit is rejected before upload", lambda f: with_commit_ref(f, "c" * 40), False)
run_upload_case("published release without an exact Git tag is rejected", lambda f: f["release"].update(isDraft=False), False)


def same_assets(fixture):
    fixture["release"]["assets"] = [{"name": name} for name in ("Harbourlife-Windows-x86_64.zip", "windows-validation.json", "Windows-SHA256SUMS.txt")]


run_upload_case("identical existing assets are retained without upload or clobber", same_assets, expect_upload=False)


def different_asset(fixture):
    # Other assets are missing; the existing mismatch must prevent all uploads.
    fixture["release"]["assets"] = [{"name": "windows-validation.json"}]
    fixture["different_asset"] = True


run_upload_case("different same-name asset rejects the whole upload during preflight", different_asset, False)

output = ROOT / "reports/windows-ci-gate"
output.mkdir(parents=True, exist_ok=True)
report = {"passed": all(item["passed"] for item in checks), "count": len(checks), "checks": checks,
          "embedded_python_steps_compiled": len(python_steps), "required_name_counts": {key: len(value) for key, value in required.items()},
          "workflow_sha256": hashlib.sha256(WORKFLOW.read_bytes()).hexdigest(),
          "scope": "Local YAML/Python compilation, adversarial synthetic inputs to the real aggregate Windows CI gate, and mocked exact-commit release upload/preflight. No Windows EXE execution, build, actual GitHub operation or user save access."}
(output / "checks.json").write_text(json.dumps(report, indent=2) + "\n")
print("WINDOWS_GATE_FIXTURE", json.dumps({"passed": report["passed"], "count": len(checks), "required_name_counts": report["required_name_counts"]}))
sys.exit(0 if report["passed"] else 1)
