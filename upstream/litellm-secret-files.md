---
app: litellm
project: https://github.com/BerriAI/litellm
cards: [litellm]
status: draft
found: 2026-10-28
sent:
---

# Read `LITELLM_MASTER_KEY` and `LITELLM_SALT_KEY` and `DATABASE_URL` from a file

**Request.** Accept `LITELLM_MASTER_KEY_FILE` and `LITELLM_SALT_KEY_FILE` and `DATABASE_URL_FILE` (paths to files holding the value) as well as `LITELLM_MASTER_KEY` and `LITELLM_SALT_KEY` and `DATABASE_URL`, the way many
images do for `*_PASSWORD_FILE`.

**Why.** `LITELLM_MASTER_KEY` and `LITELLM_SALT_KEY` are read through `get_secret` (for example in `proxy_server.py`), which takes them from the environment or a configured secret manager, and `DATABASE_URL` from the environment; none can come from a file. `DATABASE_URL` also carries the database password. An environment variable shows up in `docker inspect`, in `/proc/<pid>/environ`, and
in anything that dumps the container's configuration. Docker and Kubernetes secrets arrive as
files, so with only the environment they have to be copied into a variable first.

If a secret-manager integration is the intended answer for file-based secrets, a short note in the proxy's production docs saying so would also help.

**What we do now.** The [litellm card](https://github.com/edgible-org/cards/tree/main/litellm) makes
the secrets on first start and keeps them in files. It overrides the image's entrypoint with a
small shell script that reads the files, exports the variables, and then runs the image's own start
command. With `_FILE` variables the card could drop the override.

**Checked.** LiteLLM v1.106.2 (image `ghcr.io/berriai/litellm:v1.106.2`); source read on `main` at `9b2fc9d`. A search of the source for `_FILE`
settings of this kind finds none.
