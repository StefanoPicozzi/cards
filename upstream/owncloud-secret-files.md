---
app: ocis
project: https://github.com/owncloud/ocis
cards: [owncloud]
status: draft
found: 2026-10-28
sent:
---

# Read `IDM_ADMIN_PASSWORD` from a file

**Request.** Accept `IDM_ADMIN_PASSWORD_FILE` (paths to files holding the value) as well as `IDM_ADMIN_PASSWORD`, the way many
images do for `*_PASSWORD_FILE`.

**Why.** `IDM_ADMIN_PASSWORD`, the initial admin password, is an `env:` setting in `services/idm/pkg/config/config.go`, so it comes from the environment (or the YAML config) only. An environment variable shows up in `docker inspect`, in `/proc/<pid>/environ`, and
in anything that dumps the container's configuration. Docker and Kubernetes secrets arrive as
files, so with only the environment they have to be copied into a variable first.

**What we do now.** The [owncloud card](https://github.com/edgible-org/cards/tree/main/owncloud) makes
the secrets on first start and keeps them in files. It overrides the image's entrypoint with a
small shell script that reads the files, exports the variables, and then runs the image's own start
command. With `_FILE` variables the card could drop the override.

**Checked.** oCIS 8.2.1 (image `owncloud/ocis:8.2.1`); source read on `main` at `a065ed09`. A search of the source for `_FILE`
settings of this kind finds none.
