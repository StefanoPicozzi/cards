---
app: docmost
project: https://github.com/docmost/docmost
cards: [docmost]
status: draft
found: 2026-10-28
sent:
---

# Read `APP_SECRET` and `DATABASE_URL` from files

**Request.** Accept `APP_SECRET_FILE` and `DATABASE_URL_FILE` (paths to files holding the value) as
well as `APP_SECRET` and `DATABASE_URL`, the way many images do for `*_PASSWORD_FILE`.

**Why.** Both are read from the environment only (`getAppSecret()` and `getDatabaseURL()` in
`apps/server/src/integrations/environment/environment.service.ts`). An environment variable shows
up in `docker inspect`, in `/proc/<pid>/environ`, and in anything that dumps the container's
configuration. `DATABASE_URL` also carries the database password. Docker and Kubernetes secrets
arrive as files, so with only the environment they have to be copied into a variable first.

**What we do now.** The [docmost card](https://github.com/edgible-org/cards/tree/main/docmost)
makes the secrets on first start and keeps them in files. It overrides the image's entrypoint with
a small shell script that reads the files, exports the two variables, and then runs `pnpm start`.
With `_FILE` variables the card could drop the override and use the image's own start command.

**Checked.** Docmost v0.97.0 (image `docmost/docmost:0.97.0`); source read at `6d117f8`, which is
the v0.97.0 tag. A search of the repository for `_FILE` finds nothing in the server.
