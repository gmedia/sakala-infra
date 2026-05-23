#!/usr/bin/env bash
set -euo pipefail

readonly NETWORKS=(sakala-edge sakala-runtime)

for network in "${NETWORKS[@]}"; do
    if docker network inspect "${network}" >/dev/null 2>&1; then
        printf 'Network %s already exists.\n' "${network}"
        continue
    fi

    docker network create "${network}" >/dev/null
    printf 'Created network %s.\n' "${network}"
done
