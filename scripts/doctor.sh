#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly NETWORKS=(sakala-edge sakala-runtime)

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

printf 'Checking container sakala-caddy... '
container_status="$(docker inspect --format '{{.State.Status}}' sakala-caddy 2>/dev/null || true)"
if [ "${container_status}" != 'running' ]; then
    printf '%s\n' "${container_status:-not found}" >&2
    printf 'Run "make up" before checking the active local runtime.\n' >&2
    exit 1
fi
printf 'running\n'

docker compose --project-directory "${PROJECT_DIR}" -f "${PROJECT_DIR}/docker-compose.yml" ps
