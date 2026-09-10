"""Run bundled validators in the exported macOS application, retaining fresh evidence."""
import argparse
import datetime
import json
from pathlib import Path
import shutil
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("experience", "visual", "qa", "flight", "mobility", "air-vehicle"))
    parser.add_argument("--app", type=Path, default=Path("dist/Harbourlife.app"))
    parser.add_argument("--output", type=Path, default=Path("reports/release-v013-native"))
    args = parser.parse_args()
    app = args.app.resolve() / "Contents/MacOS/Harbourlife"
    user_data = Path.home() / "Library/Application Support/Godot/app_userdata/Harbourlife · 悉尼海港"
    cases = {
        "experience": (["--experience-qa"], "experience-flow-report.json", "experience-qa"),
        "visual": (["--visual-qa", "--release-v013"], "update-v013-views/capture-evidence.json", "update-v013-views"),
        "qa": (["--qa"], "qa-report.json", "qa-screenshots"),
        "flight": (["--flight-qa", "--qa-fixed-fps=60"], "flight-qa/flight-report.json", "flight-qa"),
        "mobility": (["--mobility-qa"], "mobility-qa/report.json", "mobility-qa"),
        "air-vehicle": (["--air-vehicle-qa"], "air-vehicle-qa/report.json", "air-vehicle-qa"),
    }
    flags, report_name, images_name = cases[args.mode]
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    log = out / (args.mode + "-runtime.log")
    command = [str(app), "--disable-vsync", "--log-file", str(log)]
    if args.mode in ("flight", "mobility", "air-vehicle"):
        command += ["--fixed-fps", "60"]
    command += ["--"] + flags
    started = time.time()
    print("START", args.mode, flush=True)
    with (out / (args.mode + "-console.log")).open("w") as console:
        result = subprocess.run(command, stdout=console, stderr=subprocess.STDOUT, timeout=2400)
    report = user_data / report_name
    record = {
        "mode": args.mode,
        "launch_flags": ["--disable-vsync"] + (["--fixed-fps", "60"] if "--fixed-fps" in command else []) + ["--"] + flags,
        "started_utc": datetime.datetime.fromtimestamp(started, datetime.timezone.utc).isoformat(),
        "wall_seconds": round(time.time() - started, 3),
        "exit_code": result.returncode,
        "report_fresh": report.is_file() and report.stat().st_mtime >= started,
    }
    if record["report_fresh"]:
        shutil.copy2(report, out / (args.mode + "-report.json"))
        data = json.loads(report.read_text())
        if isinstance(data, list):
            record["checks"] = len(data)
            record["passed"] = bool(data) and all(x.get("saved") and x.get("ready") for x in data)
        elif "checks" in data:
            record["checks"] = len(data["checks"])
            record["passed"] = bool(data["checks"]) and all(x.get("passed", x.get("pass", False)) for x in data["checks"])
        else:
            record["passed"] = data.get("passed", False)
        copied = []
        for image in (user_data / images_name).glob("*.png"):
            if image.stat().st_mtime < started:
                continue
            destination = out / (args.mode + "-screenshots")
            destination.mkdir(exist_ok=True)
            shutil.copy2(image, destination / image.name)
            copied.append(image.name)
        record["screenshots"] = copied
    logged = log.read_text() if log.exists() else "Missing runtime log"
    record["runtime_errors"] = [line for line in logged.splitlines() if "ERROR:" in line or "WARNING:" in line]
    record["passed"] = bool(record.get("passed")) and result.returncode == 0 and not record["runtime_errors"]
    (out / (args.mode + "-launch.json")).write_text(json.dumps(record, ensure_ascii=False, indent=2))
    print(json.dumps(record, ensure_ascii=False), flush=True)
    return 0 if record["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
