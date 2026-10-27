---
app: ech0
project: https://github.com/lin-snow/Ech0
status: draft
found: 2026-10-27
sent:
---

# Read `JWT_SECRET` from a file

**Request.** Accept `JWT_SECRET_FILE` (a path to a file holding the secret) as well as
`JWT_SECRET`, the way many images do for `*_PASSWORD_FILE`.

**Why.** `JWT_SECRET` is read from the environment only (`getJWTSecret()` in
`internal/config/config.go`, which tries `JWT_SECRET`, then `ECH0_JWT_SECRET`, then makes a random
one). An environment variable shows up in `docker inspect`, in `/proc/<pid>/environ`, and in
anything that dumps the container's configuration. Docker and Kubernetes secrets arrive as files,
so with only the environment they have to be copied into a variable first.

**What we do now.** The [ech0 card](https://github.com/edgible-org/cards/tree/main/ech0) makes the
secret on first start and keeps it in a file. Since the image's entrypoint is the binary, the card
overrides the entrypoint with a small shell script that reads the file, exports `JWT_SECRET`, and
then starts `/app/ech0 serve`. With `JWT_SECRET_FILE` the card could drop the override and use the
image's own start command.

**Checked.** Ech0 v5.8.0 (image `sn0wl1n/ech0:v5.8.0`); source read on `main` at `f2da207`.
Related: [#144](https://github.com/lin-snow/Ech0/issues/144) (the default secret), closed.
