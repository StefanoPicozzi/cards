---
app: rallly
project: https://github.com/lukevella/rallly
cards: [rallly]
status: draft
found: 2026-10-28
sent:
---

# Read `SECRET_PASSWORD` and `DATABASE_URL` from a file

**Request.** Accept `SECRET_PASSWORD_FILE` and `DATABASE_URL_FILE` (paths to files holding the value) as well as `SECRET_PASSWORD` and `DATABASE_URL`, the way many
images do for `*_PASSWORD_FILE`.

**Why.** `SECRET_PASSWORD` (the key that signs sessions) and `DATABASE_URL` are read from the environment only, as the sample `.env` and the self-hosting docs show. `DATABASE_URL` also carries the database password. An environment variable shows up in `docker inspect`, in `/proc/<pid>/environ`, and
in anything that dumps the container's configuration. Docker and Kubernetes secrets arrive as
files, so with only the environment they have to be copied into a variable first.

**What we do now.** The [rallly card](https://github.com/edgible-org/cards/tree/main/rallly) makes
the secrets on first start and keeps them in files. It overrides the image's entrypoint with a
small shell script that reads the files, exports the variables, and then runs the image's own start
command. With `_FILE` variables the card could drop the override.

**Checked.** Rallly 4.7.0 (image `lukevella/rallly:4.7.0`); source read on `main` at `ddca504`. A search of the source for `_FILE`
settings of this kind finds none.
