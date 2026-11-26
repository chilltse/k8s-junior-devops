#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
require_cluster
OUT="${1:-$ROOT/evidence/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"
k -n "$NS" get pods,deploy,rs,svc,endpointslice -o wide > "$OUT/resources.txt"
k -n "$NS" get events --sort-by=.metadata.creationTimestamp > "$OUT/events.txt"
k -n "$NS" describe deploy lab-api > "$OUT/deployment.txt"
k -n "$NS" logs -l app=lab-api --all-containers=true --prefix=true --tail=100 > "$OUT/logs.txt" 2>&1 || true
k get nodes -o wide > "$OUT/nodes.txt"
echo "Evidence saved: $OUT (review and redact before sharing)"
