# A check for test-card, run after Verify with card.env exported and HOSTNAME_<APP> set.
# OpenClaw's set-up gave it Edgible: the edgible MCP server in its config and the edgible-cards
# skill in its workspace, and edgible-mcp answers on the project's network. Read through
# OpenClaw's own commands in the Gateway's container, which this test's Compose project names,
# through the card's loader, which gives them the Gateway token as the Gateway has it.
set -eu
c=$(docker ps --filter "label=com.docker.compose.service=openclaw" --filter "publish=$OPENCLAW_PORT" -q | head -1)
[ -n "$c" ] || { echo "no openclaw container publishing $OPENCLAW_PORT"; exit 1; }
docker exec "$c" sh /run/card-secrets/.load node dist/index.js mcp show edgible 2>/dev/null | grep -q '"url": "http://edgible-mcp:8000/mcp"' \
  || { echo "OpenClaw has no edgible MCP server"; exit 1; }
docker exec "$c" sh /run/card-secrets/.load node dist/index.js skills list 2>/dev/null | grep -q 'edgible-cards' \
  || { echo "OpenClaw has no edgible-cards skill"; exit 1; }
docker exec "$c" node -e 'fetch("http://edgible-mcp:8000/healthz").then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))' \
  || { echo "edgible-mcp does not answer on the project network"; exit 1; }
echo "OpenClaw has Edgible's MCP tools and the edgible-cards skill; edgible-mcp answers"
