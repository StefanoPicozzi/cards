#!/bin/sh
# Checks for the ci card, run on any machine with curl, after the runner has started:
#   sh etc/verify-ci.sh runner     the runner is registered and online in Gitea
#   sh etc/verify-ci.sh workflow   a one-step workflow runs on it to success
# Reads GITEA_ADMIN_PASSWORD from the environment, and the Gitea address from GITEA_URL,
# or else from HOSTNAME_GITEA, or else from ORG_LABEL.
set -eu
url=${GITEA_URL:-https://${HOSTNAME_GITEA:-gitea.$ORG_LABEL.${EDGIBLE_DOMAIN:-edgible.app}}}
api() { curl -fsS -u "gitadmin:$GITEA_ADMIN_PASSWORD" -H 'Content-Type: application/json' "$@"; }

case "${1:-}" in
  runner)
    api "$url/api/v1/admin/actions/runners" | grep -q '"status":"online"' \
      && echo "a runner is online" ;;
  workflow)
    repo=ci-check
    api -o /dev/null -X POST "$url/api/v1/user/repos" -d "{\"name\":\"$repo\",\"auto_init\":true,\"private\":true}" 2>/dev/null || true
    workflow=$(printf 'on: [push]\njobs:\n  hello:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo "ran on the self-hosted runner"\n' | base64 | tr -d '\n')
    api -o /dev/null -X POST "$url/api/v1/repos/gitadmin/$repo/contents/.gitea/workflows/check.yml" \
      -d "{\"content\":\"$workflow\",\"message\":\"Check the runner\"}" 2>/dev/null || true
    api "$url/api/v1/repos/gitadmin/$repo/actions/tasks" | grep -q '"status":"success"' \
      && echo "the workflow ran to success" ;;
  *)
    echo "usage: sh etc/verify-ci.sh runner|workflow" >&2; exit 2 ;;
esac
