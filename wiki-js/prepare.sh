#!/bin/sh
# Prepare for the wiki-js card: finish the setup and make the admin before the setup page is public.
# Run it after Start and before Publish, from the directory that holds wiki-js/:
#   sh wiki-js/prepare.sh
set -eu
cd "$(dirname "$0")"
set -a; . ./card.env; set +a
COMPOSE=${COMPOSE:-docker compose --env-file card.env -f docker-compose.yml}

# The admin's password is the human secret wiki-js-secrets made on this machine.
WIKI_JS_ADMIN_PASSWORD=$($COMPOSE run --rm --no-deps wiki-js-secrets show WIKI_JS_ADMIN_PASSWORD)
WIKI_JS_SITE_URL=${WIKI_JS_URL:-https://wiki-js.${ORG_LABEL:?set ORG_LABEL in card.env}.${EDGIBLE_DOMAIN:-edgible.app}}

# Wiki.js shows a setup wizard to the first visitor; this finishes it, then waits for the wiki to restart.
$COMPOSE exec -T -e WIKI_JS_ADMIN_PASSWORD="$WIKI_JS_ADMIN_PASSWORD" \
  -e WIKI_JS_ADMIN_EMAIL="$WIKI_JS_ADMIN_EMAIL" -e WIKI_JS_SITE_URL="$WIKI_JS_SITE_URL" wiki-js node -e '
const B = "http://127.0.0.1:3000";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
(async () => {
  const r = await fetch(B + "/finalize", {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      adminEmail: process.env.WIKI_JS_ADMIN_EMAIL,
      adminPassword: process.env.WIKI_JS_ADMIN_PASSWORD,
      adminPasswordConfirm: process.env.WIKI_JS_ADMIN_PASSWORD,
      siteUrl: process.env.WIKI_JS_SITE_URL,
      telemetry: false,
    }),
  });
  const body = await r.text();
  if (!r.ok || body.includes("\"ok\":false")) { console.error("setup answered " + r.status + ": " + body); process.exit(1); }
  for (let i = 0; i < 60; i++) {
    await sleep(2000);
    try {
      const h = await fetch(B + "/healthz");
      if (h.ok && !(await h.text()).trimStart().startsWith("<")) return;
    } catch (e) {}
  }
  console.error("the wiki did not come back after setup");
  process.exit(1);
})();
'
echo "the setup is finished; the admin signs in with WIKI_JS_ADMIN_EMAIL and WIKI_JS_ADMIN_PASSWORD"
