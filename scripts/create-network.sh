#!/usr/bin/env bash
set -euo pipefail

# Without arguments this prepares the local runtime contract networks. The
# integration test passes the names of its own networks as arguments.
if (($# > 0)); then
    networks=("$@")
else
    networks=(sakala-edge sakala-runtime)
fi

for network in "${networks[@]}"; do
    if docker network inspect "${network}" >/dev/null 2>&1; then
        printf 'Network %s already exists.\n' "${network}"
        continue
    fi

    docker network create "${network}" >/dev/null
    printf 'Created network %s.\n' "${network}"
done
