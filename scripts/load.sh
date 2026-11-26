#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_cluster
k -n "$NS" delete pod loadgen --ignore-not-found --wait=true
k -n "$NS" run loadgen --restart=Never --image=busybox:1.36 --command -- sh -c 'for i in 1 2 3 4; do (while true; do wget -qO /dev/null "http://lab-api/burn?ms=200" || sleep 1; done) & done; wait'
echo 'Stop with: kubectl --context kind-junior-devops -n devops-lab delete pod loadgen'
