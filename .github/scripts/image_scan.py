#!/usr/bin/env python3
"""Scan the images the cards pin for fixable HIGH and CRITICAL vulnerabilities.

Reads every <card>/docker-compose.yml, resolves ${VAR:-default} to the default, scans each
unique image once with Trivy (a container, so the runner needs only Docker), and writes
scan.json: per image, the cards that use it and its fixable findings. Nothing is deployed.

  image_scan.py [--out scan.json] [--only CARD ...] [--issues]

--issues opens or updates one issue per card with findings, and closes it when the card is
clean (needs `gh` and a token that may write issues).
"""
import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

TRIVY = "ghcr.io/aquasecurity/trivy:0.76.1"
CACHE = "trivy-cache"
LABEL = "security-scan"
IMAGE = re.compile(r"^\s*image:\s*(\S+)", re.M)
VAR = re.compile(r"\$\{[A-Za-z0-9_]+:-([^}]*)\}")


def images_by_card(root: Path, only: list[str]) -> dict[str, set[str]]:
    found: dict[str, set[str]] = defaultdict(set)
    for compose in sorted(root.glob("*/docker-compose.yml")):
        card = compose.parent.name
        if only and card not in only:
            continue
        for ref in IMAGE.findall(compose.read_text()):
            ref = VAR.sub(r"\1", ref).strip("\"'")
            if "${" not in ref:
                found[ref].add(card)
    return found


def scan(ref: str) -> dict:
    cmd = ["docker", "run", "--rm", "-v", f"{CACHE}:/root/.cache", TRIVY, "image", "--quiet",
           "--format", "json", "--severity", "HIGH,CRITICAL", "--ignore-unfixed",
           "--scanners", "vuln", ref]
    done = subprocess.run(cmd, capture_output=True, text=True)
    if done.returncode != 0:
        return {"error": done.stderr.strip().splitlines()[-1] if done.stderr.strip() else "scan failed"}
    findings = []
    for result in json.loads(done.stdout or "{}").get("Results", []):
        for v in result.get("Vulnerabilities") or []:
            findings.append({"id": v["VulnerabilityID"], "severity": v["Severity"],
                             "package": v["PkgName"], "installed": v["InstalledVersion"],
                             "fixed": v.get("FixedVersion", "")})
    return {"findings": findings}


def sync_issues(report: dict) -> None:
    by_card: dict[str, list[str]] = defaultdict(list)
    for ref, item in report.items():
        for card in item["cards"]:
            for f in item.get("findings", []):
                by_card[card].append(f"- `{ref}`: {f['id']} ({f['severity']}) {f['package']} "
                                     f"{f['installed']} -> {f['fixed']}")
    scanned = {c for item in report.values() if "error" not in item for c in item["cards"]}
    open_issues = json.loads(subprocess.run(
        ["gh", "issue", "list", "--label", LABEL, "--state", "open", "--json", "number,title",
         "--limit", "200"], capture_output=True, text=True, check=True).stdout)
    existing = {i["title"]: i["number"] for i in open_issues}
    for card, lines in by_card.items():
        title = f"Security: {card} has fixable vulnerabilities"
        body = ("The nightly image scan found fixable HIGH or CRITICAL vulnerabilities in the "
                f"images {card} pins. Bump the pin, run test-card, merge.\n\n" + "\n".join(sorted(set(lines))))
        if title in existing:
            subprocess.run(["gh", "issue", "edit", str(existing[title]), "--body", body], check=True)
        else:
            subprocess.run(["gh", "issue", "create", "--title", title, "--body", body,
                            "--label", LABEL], check=True)
    for title, number in existing.items():
        card = title.removeprefix("Security: ").removesuffix(" has fixable vulnerabilities")
        if card in scanned and card not in by_card:
            subprocess.run(["gh", "issue", "close", str(number), "--comment",
                            "The latest scan found nothing fixable."], check=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="scan.json")
    ap.add_argument("--only", nargs="*", default=[])
    ap.add_argument("--issues", action="store_true")
    args = ap.parse_args()

    images = images_by_card(Path.cwd(), args.only)
    report = {}
    for ref in sorted(images):
        print(f"scanning {ref}", file=sys.stderr)
        report[ref] = {"cards": sorted(images[ref]), **scan(ref)}
    Path(args.out).write_text(json.dumps(report, indent=2) + "\n")

    bad = {r: i for r, i in report.items() if i.get("findings")}
    broken = {r: i for r, i in report.items() if "error" in i}
    print(f"{len(report)} images: {len(bad)} with fixable findings, {len(broken)} not scanned")
    for ref, item in bad.items():
        print(f"  {ref} ({', '.join(item['cards'])}): {len(item['findings'])} findings")
    for ref, item in broken.items():
        print(f"  not scanned {ref}: {item['error']}")
    if args.issues:
        sync_issues(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
