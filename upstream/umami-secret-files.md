---
app: umami
project: https://github.com/umami-software/umami
cards: [umami]
status: draft
found: 2026-10-28
sent:
---

# Read `APP_SECRET` and `TWO_FACTOR_ENCRYPTION_KEY` and `DATABASE_URL` from a file

**Request.** Accept `APP_SECRET_FILE` and `TWO_FACTOR_ENCRYPTION_KEY_FILE` and `DATABASE_URL_FILE` (paths to files holding the value) as well as `APP_SECRET` and `TWO_FACTOR_ENCRYPTION_KEY` and `DATABASE_URL`, the way many
images do for `*_PASSWORD_FILE`.

**Why.** `APP_SECRET`, `TWO_FACTOR_ENCRYPTION_KEY` and `DATABASE_URL` are read from the environment only. `DATABASE_URL` also carries the database password. An environment variable shows up in `docker inspect`, in `/proc/<pid>/environ`, and
in anything that dumps the container's configuration. Docker and Kubernetes secrets arrive as
files, so with only the environment they have to be copied into a variable first.

This was asked for before in [#3761](https://github.com/umami-software/umami/issues/3761), which the stale bot closed in January 2026 without a reply. This is a fresh request, not a claim that the earlier one was wrong.

**What we do now.** The [umami card](https://github.com/edgible-org/cards/tree/main/umami) makes
the secrets on first start and keeps them in files. It overrides the image's entrypoint with a
small shell script that reads the files, exports the variables, and then runs the image's own start
command. With `_FILE` variables the card could drop the override.

**Checked.** Umami 3.4.0 (image `ghcr.io/umami-software/umami:3.4.0`); source read on `main` at `559e3c6`. A search of the source for `_FILE`
settings of this kind finds none.
