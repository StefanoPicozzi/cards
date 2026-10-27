---
app: docmost
project: https://github.com/docmost/docmost
cards: [docmost]
status: draft
found: 2026-10-28
sent:
---

# Add a `HEALTHCHECK` to the image

**Request.** A `HEALTHCHECK` in the `Dockerfile`, on `/api/health`, which the server already
answers (`HealthController` in `apps/server/src/integrations/health/`; the global prefix is `api`).

**Why.** Without one, `docker ps` shows the container as running as soon as the process starts,
and anything that waits for "healthy" (`docker compose up --wait`, an orchestrator, a monitor) has
no signal until each user writes a check of their own. The image is `node:26-slim`, which has no
`curl` or `wget`, but Node's built-in `fetch` can make the request, for example:

```
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=6 \
  CMD node -e "fetch('http://127.0.0.1:3000/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
```

**What we do now.** The [docmost card](https://github.com/edgible-org/cards/tree/main/docmost)
declares that check in its Compose file, and its regression waits on it.

**Checked.** Docmost v0.97.0; the `Dockerfile` at `6d117f8` (the v0.97.0 tag) has no `HEALTHCHECK`.
