# Registers each app's key with the gateway, beside LiteLLM in its container (see docker-compose.yml).
#
# An app that uses this gateway has its own key, made on the device by its card like any other
# secret: a file LITELLM_KEY_<APP> in this card's secrets volume (in a pattern, the pattern's
# card-secrets service makes it there, or in /run/app-keys). This registers each one as a LiteLLM key named after the
# app, with LITELLM_APP_BUDGET dollars per LITELLM_APP_BUDGET_PERIOD, so the admin shows who spent
# what. A key already registered is left as it is. Keys for apps on other machines are made in the
# admin instead.
import glob
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = "http://127.0.0.1:4000"
MASTER = os.environ["LITELLM_MASTER_KEY"]


def call(method, path, body=None):
    req = urllib.request.Request(BASE + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Authorization": f"Bearer {MASTER}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read() or b"{}")


for _ in range(120):
    try:
        urllib.request.urlopen(BASE + "/health/liveliness", timeout=3)
        break
    except Exception:
        time.sleep(5)
else:
    print("register-keys: the gateway did not start, so no app keys were registered", flush=True)
    raise SystemExit(1)

budget = float(os.environ.get("LITELLM_APP_BUDGET") or 5)
period = os.environ.get("LITELLM_APP_BUDGET_PERIOD") or "30d"
# The card's own secrets, and /run/app-keys: an app's secrets volume mounted read-only, as the
# edgible-agent pattern does, so the app never sees the gateway's.
for path in sorted(glob.glob("/run/card-secrets/LITELLM_KEY_*") + glob.glob("/run/app-keys/LITELLM_KEY_*")):
    app = os.path.basename(path)[len("LITELLM_KEY_"):].lower().replace("_", "-")
    key = open(path).read().strip()
    # Registered already, or not (404)? Any other answer means the gateway is still starting (its
    # database), so ask again rather than take it for a key to register.
    found = None
    for _ in range(30):
        try:
            call("GET", "/key/info?key=" + urllib.parse.quote(key))
            found = True
        except urllib.error.HTTPError as err:
            found = False if err.code == 404 else None
        except Exception:
            found = None
        if found is not None:
            break
        time.sleep(5)
    if found is None:
        print(f"register-keys: {app}: the gateway did not say whether its key exists, so it was left alone", flush=True)
        continue
    if found:
        print(f"register-keys: {app} already has its key", flush=True)
        continue
    try:
        call("POST", "/key/generate", {"key": key, "key_alias": app, "max_budget": budget,
                                       "budget_duration": period, "metadata": {"made_by": "litellm card"}})
        print(f"register-keys: {app}: key registered, ${budget:g} per {period}", flush=True)
    except urllib.error.HTTPError as err:
        print(f"register-keys: {app}: not registered ({err.code}): {err.read()[:200]!r}", flush=True)
