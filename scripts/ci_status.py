#!/usr/bin/env python3
"""Статус GitHub Actions для коммита (по умолчанию — HEAD) + ошибки/предупреждения сборки.

    python3 scripts/ci_status.py            # текущее состояние
    python3 scripts/ci_status.py --wait     # ждать завершения прогона
    python3 scripts/ci_status.py --sha <sha>

Репозиторий публичный, поэтому токен не нужен (лимит API без токена — 60 запросов/час).
"""
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request

REPO = "KiryaChainik/backlog-gaming"
API = f"https://api.github.com/repos/{REPO}"


def get(url):
    req = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "backlog-gaming-ci-status",
    })
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def main():
    args = sys.argv[1:]
    sha = args[args.index("--sha") + 1] if "--sha" in args else \
        subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    wait = "--wait" in args
    deadline = time.time() + 40 * 60

    run = None
    while True:
        runs = get(f"{API}/actions/runs?head_sha={sha}&per_page=5")["workflow_runs"]
        run = runs[0] if runs else None
        if run is None:
            print(f"{sha[:7]}: прогонов пока нет (коммит не запушен или CI ещё не стартовал)")
        else:
            print(f"{sha[:7]}: {run['name']} — {run['status']}"
                  + (f" / {run['conclusion']}" if run["conclusion"] else "")
                  + f"\n  {run['html_url']}")
        if not wait or (run and run["status"] == "completed") or time.time() > deadline:
            break
        time.sleep(30)

    if not run:
        return 2
    for job in get(run["jobs_url"])["jobs"]:
        print(f"\n[{job['conclusion'] or job['status']}] {job['name']}")
        for step in job.get("steps", []):
            if step.get("conclusion") not in (None, "success", "skipped"):
                print(f"  ✗ шаг: {step['name']} ({step['conclusion']})")
        try:
            annotations = get(job["check_run_url"] + "/annotations")
        except urllib.error.HTTPError:
            annotations = []
        for a in annotations:
            where = f"{a['path']}:{a['start_line']}" if a.get("path") and a["path"] != ".github" else ""
            print(f"  {a['annotation_level']}: {where} {a['message']}".rstrip())
    return 0 if run["conclusion"] == "success" else 1


if __name__ == "__main__":
    sys.exit(main())
