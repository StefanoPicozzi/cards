#!/usr/bin/env python3
"""The mechanical part of reviewing a new card, as a comment for the pull request.

    python3 .github/scripts/card_verdict.py <card>        # from the root of the cards repo

It reads the card's files and prints Markdown: what it checked, and each thing a person should look
at, so the person reads the card for the things only a person can judge (is this the right app, does
the README make sense). It only names keys, never values, so a comment cannot leak what it finds.
It changes nothing. Needs PyYAML.

Checks: secrets written in git; well-known default passwords; ports on every interface; privileged
containers, host networking and the Docker socket; images with no pinned tag; a published app with no
healthcheck; a hostname with no login; a name from our own setup in the files.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

SECRETISH = re.compile(r"(PASSWORD|PASSWD|SECRET|TOKEN|API_?KEY|SALT|PRIVATE_?KEY)", re.I)
DEFAULTS = {"admin", "password", "changeme", "change-me", "123456", "root", "secret", "test", "postgres",
            "changeuser", "default", "example", "letmein", "pass"}
# Names that belong to our own setup, which a card for everyone must not contain.
OURS = re.compile(r"(emergile|osxdevice|cards-edgible-com|macbookair|lggram|websitedevice|stefano)", re.I)


def load(path: Path) -> dict:
    try:
        return yaml.safe_load(path.read_text()) or {}
    except (OSError, yaml.YAMLError):
        return {}


def literal(value: object) -> str:
    """A value as written, or '' when it is empty, a ${VARIABLE}, or a path to a secret file."""
    v = str(value if value is not None else "").strip().strip("\"'")
    if not v or v.startswith("${") or v.startswith("/run/") or v.startswith("$$"):
        return ""
    return v


def env_pairs(service: dict) -> dict[str, object]:
    env = service.get("environment") or {}
    if isinstance(env, list):
        return {k: v for k, _, v in (e.partition("=") for e in env if isinstance(e, str))}
    return dict(env) if isinstance(env, dict) else {}


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print(__doc__, file=sys.stderr)
        return 2
    card = Path(argv[0])
    if not (card / "card.yml").is_file():
        print(f"{card}: not a card here", file=sys.stderr)
        return 2
    warn: list[str] = []
    info: list[str] = []

    composes = sorted(p for p in card.glob("*.y*ml") if "compose" in p.name)
    services: dict[str, tuple[str, dict]] = {}
    for c in composes:
        for name, svc in (load(c).get("services") or {}).items():
            if isinstance(svc, dict):
                services[name] = (c.name, svc)

    # Secrets written in git, and default passwords: by key name only.
    written, defaults = set(), set()
    for name, (file, svc) in services.items():
        for k, v in env_pairs(svc).items():
            # CARD_SECRETS lists the commands that make secrets, not a secret.
            if SECRETISH.search(k) and not k.endswith("_FILE") and k != "CARD_SECRETS":
                lit = literal(v)
                if lit:
                    (defaults if lit.lower() in DEFAULTS else written).add(f"{k} ({file}, {name})")
    env_file = card / "card.env"
    if env_file.is_file():
        for line in env_file.read_text().splitlines():
            k, _, v = line.partition("=")
            if SECRETISH.search(k) and not k.startswith("#") and literal(v):
                (defaults if literal(v).lower() in DEFAULTS else written).add(f"{k.strip()} (card.env)")
    if written:
        warn.append("A secret has a value written in git: " + ", ".join(sorted(written))
                    + ". It should be empty in `card.env` and made on the device.")
    if defaults:
        warn.append("A well-known default password is set: " + ", ".join(sorted(defaults)) + ".")

    # Ports, privileges, images, healthchecks.
    open_ports, privileged, unpinned, no_health = [], [], [], []
    for name, (file, svc) in services.items():
        published = False
        for p in svc.get("ports") or []:
            text = str(p.get("published", "") if isinstance(p, dict) else p)
            published = True
            if isinstance(p, dict):
                host = str(p.get("host_ip", ""))
            else:
                host = text.split(":")[0] if text.count(":") >= 2 else ""
            if not host.startswith("127.") and host not in ("::1", "[::1]"):
                open_ports.append(f"{name} ({text})")
        if svc.get("privileged") is True:
            privileged.append(f"{name}: privileged")
        if str(svc.get("network_mode", "")) == "host":
            privileged.append(f"{name}: host networking")
        if any("docker.sock" in str(v) for v in svc.get("volumes") or []):
            privileged.append(f"{name}: the Docker socket")
        if any(c in ("SYS_ADMIN", "NET_ADMIN", "ALL") for c in svc.get("cap_add") or []):
            privileged.append(f"{name}: extra capabilities")
        image = re.sub(r"\$\{[A-Z0-9_]+:?-([^}]*)\}", r"\1", str(svc.get("image", "")))
        if image and "@sha256:" not in image:
            tag = image.rsplit("/", 1)[-1].partition(":")[2]
            if not tag or tag == "latest":
                unpinned.append(f"{name} ({image})")
        if published and not svc.get("healthcheck"):
            no_health.append(name)
    if open_ports:
        warn.append("A port is published on every interface, not only this machine: " + ", ".join(open_ports) + ".")
    if privileged:
        warn.append("Elevated access: " + ", ".join(privileged) + ". Check the app needs it.")
    if unpinned:
        warn.append("An image has no pinned tag: " + ", ".join(unpinned) + ".")
    if no_health:
        info.append("No healthcheck on the published service: " + ", ".join(no_health) + ".")

    # Hostnames with no login, and names from our own setup.
    meta = load(card / "card.yml")
    for app in meta.get("applications") or []:
        if isinstance(app, dict) and app.get("published") and "none" in (app.get("authModes") or []):
            warn.append(f"`{app.get('name')}` is published with no Edgible login: confirm the app has its own, "
                        "and that it is meant to be open.")
    ours = set()
    for f in card.rglob("*"):
        if f.is_file() and f.suffix in (".yml", ".yaml", ".md", ".env", ".sh", "") and f.name != "test.yml" \
                and "images" not in f.parts:
            try:
                ours.update(m.group(0).lower() for m in OURS.finditer(f.read_text()))
            except (OSError, UnicodeDecodeError):
                pass
    if ours:
        warn.append("The files name something from our own setup: " + ", ".join(sorted(ours)) + ".")

    readme = (card / "README.md").read_text() if (card / "README.md").is_file() else ""
    if not re.search(r"back\s?up", readme, re.I):
        info.append("The README does not mention backing up (the review asks where the data lives and that Tear down backs it up).")
    if not (meta.get("metadata") or {}).get("steward"):
        info.append("No steward: the card will be listed as having none until someone sets metadata.steward.")
    test = load(card / "test.yml")
    info.append(f"test.yml: {test.get('result', 'missing')}.")

    head = f"## Automated checks: {len(warn)} to look at" if warn else "## Automated checks: nothing found"
    print(head + "\n")
    print("These are the mechanical parts of the review below. They read the files only, so a person still "
          "judges the app, the README and the auth modes.\n")
    for w in warn:
        print(f"- :warning: {w}")
    for i in info:
        print(f"- :information_source: {i}")
    if not warn:
        print("- :white_check_mark: No secret or default password in git, no port on every interface, "
              "no elevated access, every image pinned, no login-less hostname.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
