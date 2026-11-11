#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Without arguments this prepares the local runtime contract networks, named by
# SAKALA_EDGE_NETWORK and SAKALA_RUNTIME_NETWORK. The integration test passes
# the names of its own networks as arguments.
if (($# > 0)); then
    networks=("$@")
else
    # shellcheck source=scripts/local-names.sh
    . "${SCRIPT_DIR}/local-names.sh"
    networks=("${SAKALA_EDGE_NETWORK}" "${SAKALA_RUNTIME_NETWORK}")
fi

for network in "${networks[@]}"; do
    if docker network inspect "${network}" >/dev/null 2>&1; then
        printf 'Network %s already exists.\n' "${network}"
        continue
    fi

    docker network create "${network}" >/dev/null
    printf 'Created network %s.\n' "${network}"
done
