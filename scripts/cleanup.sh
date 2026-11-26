#!/usr/bin/env bash
source "$(dirname "$0")/common.sh"
[[ "${1:-}" == '--yes' ]] || { echo 'This deletes the entire local kind-junior-devops cluster including PVC data. Pass --yes to proceed.'; exit 1; }
kind delete cluster --name "$CLUSTER"
