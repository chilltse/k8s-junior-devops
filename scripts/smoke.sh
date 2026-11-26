#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_cluster
k -n "$NS" rollout status deploy/lab-api --timeout=120s
# Each execution creates a distinct pod, which kubectl cleans up on completion.
k -n "$NS" run "smoke-$(date +%s)-$$" --rm -i --restart=Never --image=busybox:1.36 --command -- sh -ec 'wget -qO- http://lab-api/healthz; echo; wget -qO- http://lab-api/readyz; echo; wget -qO- http://lab-api/; echo'
