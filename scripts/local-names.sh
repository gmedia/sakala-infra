#!/usr/bin/env bash
#
# Sourced by the lifecycle scripts, never run on its own. Resolves the names of
# the runtime Caddy container, the demo container, the two networks, and the
# Railpack sandbox image tag. Each comes from the shell environment first, then
# from sakala-infra/.env, then from the default, which is the order Docker
# Compose uses for docker-compose.yml. Changing a name lets a second stack run
# beside this one; the agent must then be given the same Caddy and runtime
# network names (scripts/full-stack-env.sh agent does that).
set -euo pipefail

readonly LOCAL_NAMES_PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Prints the value of $1 from the environment, then .env, then the default $2.
local_name() {
    local key="$1" default="$2" value="${!1:-}"
    if [[ -z "${value}" && -f "${LOCAL_NAMES_PROJECT_DIR}/.env" ]]; then
        value="$(sed -n "s/^${key}=//p" "${LOCAL_NAMES_PROJECT_DIR}/.env" | tail -n 1)"
    fi
    printf '%s\n' "${value:-${default}}"
}

SAKALA_CADDY_CONTAINER="$(local_name SAKALA_CADDY_CONTAINER sakala-caddy)"
SAKALA_DEMO_CONTAINER="$(local_name SAKALA_DEMO_CONTAINER sakala-demo-static)"
SAKALA_EDGE_NETWORK="$(local_name SAKALA_EDGE_NETWORK sakala-edge)"
SAKALA_RUNTIME_NETWORK="$(local_name SAKALA_RUNTIME_NETWORK sakala-runtime)"
SAKALA_RAILPACK_SANDBOX_TAG="$(local_name SAKALA_RAILPACK_SANDBOX_TAG sakala-railpack-sandbox)"
