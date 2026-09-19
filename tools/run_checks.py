#!/usr/bin/env python3
"""Run the regression checks listed in tools/checks.json.

The same script runs on every pull request (.github/workflows/pr-checks.yml)
and locally:

    python3 tools/run_checks.py                 # everything
    python3 tools/run_checks.py --group qa      # only the in-game QA modes
    python3 tools/run_checks.py --only attack_delivery_test street

A check passes when Godot exits 0, prints no ERROR, WARNING or FAIL line, and
shows that it actually ran (a PASS or COMPLETE line; the interactive start
must reach INTERACTIVE_QA_READY). Checks can be split into
shards that take about the same time, so CI runs them side by side.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "tools" / "checks.json"
PROBLEM = re.compile(r"(?:SCRIPT ERROR|SHADER ERROR|FATAL ERROR|ERROR|WARNING):")
FAILED = re.compile(r"(^|\s)FAIL(\s|:|$)|passed=false|failures=[1-9]")


def plan(manifest, group):
    """Every check as (name, kind, expected seconds, command arguments, proof it ran)."""
    checks = []
    if group in ("all", "source"):
        for name, seconds in manifest["source"].items():
            checks.append((name, "source", seconds, ["--script", f"../source/{name}.gd"], "PASS|COMPLETE"))
    if group in ("all", "qa"):
        extra = manifest.get("qa_args", {})
        markers = manifest.get("qa_marker", {})
        for name, seconds in manifest["qa"].items():
            # A fixed frame step keeps game time independent of how fast the machine is.
            checks.append((name, "qa", seconds, ["--fixed-fps", "60", *extra.get(name, []), "--", f"--{name}-qa"],
                           markers.get(name, "COMPLETE")))
    return checks


def shard(checks, index, count):
    """Longest first into the emptiest shard, so shards finish close together."""
    bins = [[0, []] for _ in range(count)]
    for check in sorted(checks, key=lambda c: (-c[2], c[0])):
        target = min(bins, key=lambda b: b[0])
        target[0] += check[2]
        target[1].append(check)
    return bins[index - 1][1]


def run(godot, check, logs):
    name, kind, seconds, arguments, marker = check
    log = logs / f"{name}.log"
    command = [godot, "--headless", "--path", "game", *arguments]
    # CI machines are slower than the one that measured the times.
    limit = max(180, seconds * 5)
    started = time.monotonic()
    with log.open("w", encoding="utf-8", errors="replace") as output:
        try:
            code = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=limit).returncode
        except subprocess.TimeoutExpired:
            code = "timeout"
    elapsed = time.monotonic() - started
    text = log.read_text(encoding="utf-8", errors="replace")
    problems = [line.strip() for line in text.splitlines() if PROBLEM.search(line)]
    failures = [line.strip() for line in text.splitlines() if FAILED.search(line)]
    passed = code == 0 and not problems and not failures and bool(re.search(marker, text))
    return {"name": name, "kind": kind, "passed": passed, "exit": code, "seconds": round(elapsed, 1),
            "problems": problems[:10], "failures": failures[:10], "log": str(log)}


def markdown(results, title):
    failed = [r for r in results if not r["passed"]]
    lines = [f"### {title}: {len(results) - len(failed)}/{len(results)} passed", ""]
    if failed:
        lines += ["| Check | Exit | What went wrong |", "| --- | --- | --- |"]
        for r in failed:
            reason = (r["failures"] or r["problems"] or ["never reported that it ran"])[0].replace("|", "\\|")[:180]
            lines.append(f"| {r['name']} | {r['exit']} | {reason} |")
        lines.append("")
    slowest = sorted(results, key=lambda r: -r["seconds"])[:5]
    lines.append("Slowest: " + ", ".join(f"{r['name']} {r['seconds']:.0f}s" for r in slowest))
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", default=os.environ.get("GODOT", str(ROOT / "tools/runtime/godot")))
    parser.add_argument("--group", choices=["all", "source", "qa"], default="all")
    parser.add_argument("--shard", default="1/1", help="K/N: run the K-th of N balanced shards")
    parser.add_argument("--only", nargs="*", help="run just these checks by name")
    parser.add_argument("--summary", help="append a markdown summary here (for GITHUB_STEP_SUMMARY)")
    parser.add_argument("--output", default=str(ROOT / "reports" / "checks"))
    args = parser.parse_args()

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    checks = plan(manifest, args.group)
    if args.only:
        checks = [c for c in checks if c[0] in args.only]
        missing = set(args.only) - {c[0] for c in checks}
        if missing:
            sys.exit("Unknown checks: " + ", ".join(sorted(missing)))
    index, count = (int(part) for part in args.shard.split("/"))
    checks = shard(checks, index, count)

    output = Path(args.output)
    logs = output / "logs"
    logs.mkdir(parents=True, exist_ok=True)
    results = []
    for check in checks:
        result = run(args.godot, check, logs)
        results.append(result)
        mark = "PASS" if result["passed"] else "FAIL"
        print(f"{mark} {result['name']} ({result['kind']}) exit={result['exit']} {result['seconds']:.0f}s", flush=True)
        for line in (result["failures"] + result["problems"])[:3]:
            print("     " + line[:200], flush=True)

    title = f"{args.group} checks, shard {index}/{count}"
    (output / f"{args.group}-{index}-of-{count}.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    if args.summary:
        with open(args.summary, "a", encoding="utf-8") as summary:
            summary.write(markdown(results, title))
    failed = [r["name"] for r in results if not r["passed"]]
    print(f"{title}: {len(results) - len(failed)}/{len(results)} passed" + (f"; failed: {', '.join(failed)}" if failed else ""))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
