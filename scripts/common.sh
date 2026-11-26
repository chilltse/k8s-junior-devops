#!/usr/bin/env bash
if [[ $- != *i* ]]; then set -euo pipefail; fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER=junior-devops
CTX="kind-$CLUSTER"
NS=devops-lab
k() { kubectl --context "$CTX" "$@"; }
require_cluster() { k get namespace kube-system >/dev/null; }
