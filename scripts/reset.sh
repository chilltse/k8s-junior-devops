#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_cluster
k -n "$NS" delete hpa lab-api --ignore-not-found
k -n "$NS" delete pod loadgen fault-crash fault-oom fault-pending fault-image pull-failure --ignore-not-found
k -n "$NS" delete networkpolicy restrict-api-ingress --ignore-not-found
k apply -k "$ROOT/k8s/base"
k -n "$NS" scale deploy/lab-api --replicas=2
k -n "$NS" rollout restart deploy/lab-api
k -n "$NS" rollout status deploy/lab-api --timeout=180s
