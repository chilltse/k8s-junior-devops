#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_cluster
docker build -t lab-api:v1 "$ROOT/app"
kind load docker-image lab-api:v1 --name "$CLUSTER"
k apply -f "$ROOT/k8s/base/namespace.yaml"
k apply -k "$ROOT/k8s/base"
k -n "$NS" rollout status deployment/lab-api --timeout=180s
