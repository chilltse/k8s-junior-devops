#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
for cmd in docker kind kubectl; do command -v "$cmd" >/dev/null || { echo "missing: $cmd"; exit 1; }; done
docker info >/dev/null
if ! kind get clusters | grep -Fxq "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --config "$ROOT/kind.yaml" --wait 180s
fi
require_cluster
k get nodes -o wide
