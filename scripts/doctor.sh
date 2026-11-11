#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/local-names.sh
. "${SCRIPT_DIR}/local-names.sh"
readonly NETWORKS=("${SAKALA_EDGE_NETWORK}" "${SAKALA_RUNTIME_NETWORK}")
readonly CADDY="${SAKALA_CADDY_CONTAINER}"

printf 'Checking Docker CLI... '
docker --version >/dev/null
printf 'ok\n'

printf 'Checking Docker daemon... '
docker info >/dev/null
printf 'ok\n'

printf 'Checking Docker Compose... '
docker compose version >/dev/null
printf 'ok\n'

for network in "${NETWORKS[@]}"; do
    printf 'Checking network %s... ' "${network}"
    docker network inspect "${network}" >/dev/null
    printf 'ok\n'
done

printf 'Checking container %s... ' "${CADDY}"
container_status="$(docker inspect --format '{{.State.Status}}' "${CADDY}" 2>/dev/null || true)"
if [ "${container_status}" != 'running' ]; then
    printf '%s\n' "${container_status:-not found}" >&2
    printf 'Run "make up" before checking the active local runtime.\n' >&2
    exit 1
fi
printf 'running\n'

printf 'Checking wget in %s... ' "${CADDY}"
if ! docker exec "${CADDY}" wget --help >/dev/null 2>&1; then
    printf 'missing\n' >&2
    printf 'sakala-agent runs its readiness probe with wget inside this container. Use a caddy:*-alpine image.\n' >&2
    exit 1
fi
printf 'ok\n'

docker compose --project-directory "${PROJECT_DIR}" -f "${PROJECT_DIR}/docker-compose.yml" ps
