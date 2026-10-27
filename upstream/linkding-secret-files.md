---
app: linkding
project: https://github.com/sissbruecker/linkding
cards: [linkding]
status: draft
found: 2026-10-28
sent:
---

# Read `LD_SUPERUSER_PASSWORD` from a file

**Request.** Accept `LD_SUPERUSER_PASSWORD_FILE` (paths to files holding the value) as well as `LD_SUPERUSER_PASSWORD`, the way many
images do for `*_PASSWORD_FILE`.

**Why.** `LD_SUPERUSER_PASSWORD` is read from the environment only (`create_initial_superuser.py`, `os.getenv`). An environment variable shows up in `docker inspect`, in `/proc/<pid>/environ`, and
in anything that dumps the container's configuration. Docker and Kubernetes secrets arrive as
files, so with only the environment they have to be copied into a variable first.

**What we do now.** The [linkding card](https://github.com/edgible-org/cards/tree/main/linkding) makes
the secrets on first start and keeps them in files. It overrides the image's entrypoint with a
small shell script that reads the files, exports the variables, and then runs the image's own start
command. With `_FILE` variables the card could drop the override.

**Checked.** linkding 1.47.0 (image `ghcr.io/sissbruecker/linkding:1.47.0`); source read on `main` at `27b7303`. A search of the source for `_FILE`
settings of this kind finds none.
