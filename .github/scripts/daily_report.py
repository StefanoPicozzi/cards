#!/usr/bin/env python3
"""Write the daily report: what last night's jobs did, and what needs a person.

    GH_TOKEN=... python3 .github/scripts/daily_report.py > report.md
    GH_TOKEN=... python3 .github/scripts/daily_report.py --json ops.json   (the same night, for the ops page)

It reads GitHub only (runs, issues, pull requests, main's history, the test-status branch), through the gh
CLI, so every number in it is exact. It covers the last 24 hours, and starts with the
actions for a person, each with its link. The workflow adds a short summary and posts it.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from datetime import datetime, timedelta, timezone

REPO = os.environ.get("GITHUB_REPOSITORY", "edgible-org/cards")
KIT = "edgible-org/card-kit"
SITE = os.environ.get("SITE_URL") or "https://cards.edgible.org"
NOW = datetime.now(timezone.utc)
SINCE = NOW - timedelta(hours=24)
JOBS = {"regression": "Cards regression", "skill-evals": "Skill evals", "grow": "Grow"}
# The ops page lists these, in the order the night runs them.
NIGHT = {"image-scan": "Image scan", "skill-evals": "Skill evals", "grow": "Grow",
         "regression": "Cards regression", "site": "Site build"}
ROOT = Path(os.environ.get("CARDS_DIR", "."))


def gh(*args: str) -> object:
    out = subprocess.run(["gh", *args], capture_output=True, text=True)
    if out.returncode != 0:
        print(f"gh {' '.join(args)}: {out.stderr.strip()}", file=sys.stderr)
        return []
    return json.loads(out.stdout or "null")


def when(stamp: str) -> datetime:
    return datetime.fromisoformat(stamp.replace("Z", "+00:00"))


def runs(workflow: str) -> list[dict]:
    found = gh("run", "list", "--repo", REPO, "--workflow", f"{workflow}.yml", "--limit", "10",
               "--json", "databaseId,conclusion,status,createdAt,updatedAt,event,url") or []
    return [r for r in found if when(r["createdAt"]) >= SINCE]


def issues(*args: str) -> list[dict]:
    return gh("issue", "list", "--repo", REPO, "--limit", "100", "--json",
              "number,title,url,createdAt,labels", *args) or []


def prs(repo: str, *args: str) -> list[dict]:
    return gh("pr", "list", "--repo", repo, "--limit", "100", "--json",
              "number,title,url,createdAt,headRefName", *args) or []


def status() -> dict:
    out = subprocess.run(["gh", "api", f"repos/{REPO}/contents/status.json?ref=test-status",
                          "--jq", ".content"], capture_output=True, text=True)
    if out.returncode != 0:
        return {}
    import base64
    return json.loads(base64.b64decode(out.stdout.strip() or "e30="))


def card_changes() -> tuple[list[str], list[str], list[str]]:
    """The cards added, changed, and removed on main in the last 24 hours, by card name."""
    since = SINCE.strftime("%Y-%m-%dT%H:%M:%SZ")
    before = gh("api", f"repos/{REPO}/commits?sha=main&until={since}&per_page=1") or []
    head = gh("api", f"repos/{REPO}/commits/main") or {}
    if not before or not head or before[0]["sha"] == head["sha"]:
        return [], [], []
    files = (gh("api", f"repos/{REPO}/compare/{before[0]['sha']}...{head['sha']}") or {}).get("files") or []
    tree = gh("api", f"repos/{REPO}/git/trees/{head['sha']}?recursive=1") or {}
    cards = {t["path"].split("/")[0] for t in tree.get("tree") or []
             if t["path"].count("/") == 1 and t["path"].endswith("/card.yml")}
    added = sorted(f["filename"].split("/")[0] for f in files
                   if f["filename"].count("/") == 1 and f["filename"].endswith("/card.yml") and f["status"] == "added")
    removed = sorted(f["filename"].split("/")[0] for f in files
                     if f["filename"].count("/") == 1 and f["filename"].endswith("/card.yml") and f["status"] == "removed")
    changed = sorted({f["filename"].split("/")[0] for f in files if "/" in f["filename"]} & cards - set(added))
    return added, changed, removed


def file_json(branch: str, path: str) -> dict:
    out = subprocess.run(["gh", "api", f"repos/{REPO}/contents/{path}?ref={branch}", "--jq", ".content"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        return {}
    import base64
    try:
        return json.loads(base64.b64decode(out.stdout.strip() or "e30="))
    except ValueError:
        return {}


def pr_state(p: dict, agent: bool) -> tuple[str, str]:
    """ready | hold | review, and why, for the ops page. Ready means everything that can be checked
    by a machine has been: a person can merge it on sight."""
    heads = [c["messageHeadline"] for c in p.get("commits") or []]
    tested = any(h.startswith("test.yml for the image bump") for h in heads)
    conflict = p.get("mergeable") == "CONFLICTING"
    if p.get("isDraft"):
        return "hold", "draft"
    if conflict:
        return "hold", "has a merge conflict; for a bump, tick its rebase box"
    if agent:
        return "review", "its test passed on a device (see the PR); read the card, then merge or close"
    if p["headRefName"].startswith("renovate/"):
        if tested:
            return "ready", "image bump; its test passed and the result is in the PR"
        return "hold", "image bump; the test has not finished or did not pass"
    return "review", "needs a person"


def ops_data() -> dict:
    """The night as data, for the ops page: what ran, what failed, what waits for a person."""
    st = status()
    day = NOW.date()
    names = sorted(p.parent.name for p in ROOT.glob("*/card.yml"))
    failing = sorted(k for k, v in st.items() if v.get("result") == "fail")
    ages = {k: (day - datetime.fromisoformat(v["tested"]).date()).days for k, v in st.items() if v.get("tested")}
    jobs = []
    for wf, label in NIGHT.items():
        found = runs(wf)
        state = "none"
        if found:
            latest = found[0]
            state = "running" if latest["status"] in ("queued", "in_progress") else \
                    ("ok" if latest["conclusion"] in ("success", "skipped") else "fail")
        jobs.append({"workflow": wf, "name": label, "state": state, "count": len(found),
                     "failed": sum(1 for r in found if r["conclusion"] == "failure"),
                     "latest": found[0]["url"] if found else "",
                     "at": found[0]["createdAt"] if found else ""})
    scan = file_json("scan-status", "scan.json")
    per_card: dict[str, set] = {}
    for img in scan.values():
        for c in img.get("cards", []):
            per_card.setdefault(c, set()).update(f["id"] for f in img.get("findings", []))
    dirty = sorted(((len(v), k) for k, v in per_card.items() if v), reverse=True)
    queue = []
    open_prs = gh("pr", "list", "--repo", REPO, "--state", "open", "--limit", "50",
                  "--json", "number,title,url,headRefName,mergeable,isDraft,labels") or []
    for p in open_prs:
        agent = any(l["name"] == "agent-card" for l in p.get("labels", []))
        if p["headRefName"].startswith("renovate/") and not p.get("isDraft"):
            # The commits one PR at a time: asking for them across fifty is more than GitHub allows.
            p["commits"] = (gh("pr", "view", str(p["number"]), "--repo", REPO, "--json", "commits") or {}).get("commits", [])
        state, why = pr_state(p, agent)
        queue.append({"number": p["number"], "title": p["title"], "url": p["url"],
                      "kind": "new card" if agent else ("image bump" if p["headRefName"].startswith("renovate/") else "change"),
                      "state": state, "why": why})
    kit = [{"number": p["number"], "title": p["title"], "url": p["url"]} for p in prs(KIT, "--state", "open")]
    made = [{"title": p["title"], "url": p["url"]} for p in prs(REPO, "--label", "agent-card", "--state", "all")
            if when(p["createdAt"]) >= SINCE]
    unmade = [{"title": i["title"], "url": i["url"]} for i in issues("--label", "agent-card", "--state", "all")
              if when(i["createdAt"]) >= SINCE]
    upstream = {}
    for f in sorted((ROOT / "upstream").glob("*.md")):
        if f.name == "README.md":
            continue
        for line in f.read_text().splitlines()[:12]:
            if line.startswith("status:"):
                k = line.split(":", 1)[1].strip()
                upstream[k] = upstream.get(k, 0) + 1
    regress = [{"number": i["number"], "title": i["title"], "url": i["url"],
                "days": (NOW - when(i["createdAt"])).days} for i in issues("--state", "open")
               if i["title"].startswith("Regression:")]
    evals = next(iter(issues("--state", "open", "--search", "\"Skill eval report\" in:title")), None)
    return {
        "generated": NOW.isoformat(timespec="seconds"), "repo": REPO, "site": SITE,
        "jobs": jobs,
        "cards": {"total": len(names), "with_status": len(st), "passing": len(st) - len(failing), "failing": failing,
                  "tested_24h": sum(1 for a in ages.values() if a <= 1),
                  "oldest": max(((a, k) for k, a in ages.items()), default=(0, ""))[::-1],
                  "no_test_yet": [n for n in names if n not in st]},
        "regression_issues": regress,
        "images": {"cards_with_fixable": len(dirty), "worst": [{"card": k, "count": n} for n, k in dirty[:5]],
                   "scanned": len(scan)},
        "queue": queue, "card_kit_prs": kit,
        "grow": {"made": made, "could_not_make": unmade,
                 "agent_prs_open": sum(1 for q in queue if q["kind"] == "new card")},
        "upstream": upstream,
        "skill_evals_report": evals["url"] if evals else "",
    }


def main() -> int:
    if "--json" in sys.argv:
        Path(sys.argv[sys.argv.index("--json") + 1]).write_text(json.dumps(ops_data(), indent=1) + "\n")
        return 0
    actions: list[str] = []
    body: list[str] = []

    # Cards that landed on main, made by a person or merged from grow
    added, changed, removed = card_changes()
    body += ["## Cards", ""]
    for c in added:
        body.append(f"- Added: [{c}]({SITE}/{c}/) ([source](https://github.com/{REPO}/tree/main/{c}))")
    if changed:
        body.append(f"- Changed: {', '.join(changed)}. The regression retests them on its next run.")
    if removed:
        body.append(f"- Removed: {', '.join(removed)}.")
    if not (added or changed or removed):
        body.append("- No card added, changed, or removed.")
    body.append("")

    # Cards regression
    reg = runs("regression")
    st = status()
    tested = {k: v for k, v in st.items() if v.get("tested", "") >= SINCE.date().isoformat()}
    failing = sorted(k for k, v in st.items() if v.get("result") == "fail")
    reg_issues = [i for i in issues("--state", "open", "--search", "\"Regression:\" in:title")
                  if i["title"].startswith("Regression:")]
    body += ["## Cards regression", ""]
    if not reg:
        body.append("- Did not run in the last 24 hours.")
        actions.append("The cards regression did not run last night: check that the fleet machines were on and awake.")
    for r in reg:
        body.append(f"- [{r['event']} run]({r['url']}): {r['conclusion'] or r['status']}")
    if tested:
        # Each card with the fleet machine that tested it, when the status records one.
        on = lambda k: f"{k} ({tested[k]['device']})" if tested[k].get("device") else k
        passed = sorted(on(k) for k, v in tested.items() if v["result"] == "pass")
        failed = sorted(on(k) for k, v in tested.items() if v["result"] == "fail")
        body.append(f"- Tested: {len(tested)} card(s). Passed: {', '.join(passed) or 'none'}. "
                    f"Failed: {', '.join(failed) or 'none'}.")
    body.append(f"- Every card: {len(st) - len(failing)} of {len(st)} passing at their latest test"
                + (f"; failing: {', '.join(failing)}." if failing else "."))
    for i in reg_issues:
        age = (NOW - when(i["createdAt"])).days
        card = i["title"].removeprefix("Regression: ").removesuffix(" fails")
        if age >= 2:
            actions.append(f"`{card}` has failed for {age} days: [#{i['number']}]({i['url']}) needs a fix.")
        else:
            actions.append(f"`{card}` failed: [#{i['number']}]({i['url']}). If it passes tonight, the issue closes itself.")
    body.append("")

    # Skill evals
    ev = runs("skill-evals")
    report = next(iter(issues("--state", "open", "--search", "\"Skill eval report\" in:title")), None)
    body += ["## Skill evals", ""]
    if not ev:
        body.append("- Did not run in the last 24 hours.")
    for r in ev:
        body.append(f"- [Run]({r['url']}): {r['conclusion'] or r['status']}")
        if r["conclusion"] == "failure":
            actions.append(f"The skill evals stopped early ([run]({r['url']})): usage limit or sign-in. "
                           "If it repeats, check the runner's Claude token.")
    if report:
        text = gh("issue", "view", str(report["number"]), "--repo", REPO, "--json", "body") or {}
        score = next((l for l in (text.get("body") or "").splitlines() if l.startswith("**")), "")
        body.append(f"- This week: {score} [Full report]({report['url']})")
    body.append("")

    # Grow
    gr = runs("grow")
    new_prs = [p for p in prs(REPO, "--label", "agent-card", "--state", "all") if when(p["createdAt"]) >= SINCE]
    new_issues = [i for i in issues("--label", "agent-card", "--state", "all") if when(i["createdAt"]) >= SINCE]
    queue = prs(REPO, "--label", "agent-card", "--state", "open")
    body += ["## Grow", ""]
    if not gr:
        body.append("- Did not run in the last 24 hours.")
    for r in gr:
        body.append(f"- [Run]({r['url']}): {r['conclusion'] or r['status']}")
    for p in new_prs:
        body.append(f"- New card: [{p['title']}]({p['url']})")
    for i in new_issues:
        body.append(f"- Could not make a card: [{i['title']}]({i['url']})")
    if gr and not new_prs and not new_issues:
        body.append("- No new card: skipped (review queue full, or the evals stopped early), or nothing left to pick.")
    for p in queue:
        actions.append(f"Review the new card [{p['title']}]({p['url']}): merge it, or close it with a note.")
    for i in new_issues:
        actions.append(f"The grow job could not make [{i['title']}]({i['url']}): pick it up, or close it.")
    kit = [p for p in prs(KIT, "--state", "open") if p["headRefName"].startswith("needs-map/")]
    for p in kit:
        actions.append(f"Merge the needs-map update [{p['title']}]({p['url']}), so grow moves on to the next gap.")
    body.append("")

    # Health
    late = []
    for name, label in JOBS.items():
        for r in runs(name):
            if r["status"] in ("queued", "in_progress") and NOW - when(r["createdAt"]) > timedelta(hours=6):
                late.append(f"{label} has been {r['status'].replace('_', ' ')} for over 6 hours ([run]({r['url']}))")
    body += ["## Health", ""]
    body += [f"- {l}" for l in late] or ["- All jobs finished."]
    actions += [f"{l}: the runner may be stuck." for l in late]
    body.append("")

    date = NOW.date().isoformat()
    head = [f"# Daily report, {date}", ""]
    if actions:
        head += [f"## Actions for you ({len(actions)})", ""] + [f"- [ ] {a}" for a in actions] + [""]
    else:
        head += ["## Actions for you", "", "Nothing to do today.", ""]
    print("\n".join(head + body))
    return 0


if __name__ == "__main__":
    sys.exit(main())
