#!/usr/bin/env bash
#
# Integration test for the local runtime contract between Caddy, the runtime
# network, and a container the agent would manage:
#
#   networks -> Caddy -> disposable app -> generated route -> validate + reload
#   -> domain response -> remove route and app -> fallback edge
#
# Every resource belongs to this run: it has a unique sakala-it-* name, a free
# loopback port, and a temporary route folder. A running `make up` stack and
# unrelated containers are never touched, and the EXIT trap removes everything
# this run created, including when it fails or is interrupted.
#
# Environment:
#   SAKALA_TEST_HTTP_PORT   host port for the edge, default 0 (a free port)
#   SAKALA_TEST_HTTPS_PORT  host port for HTTPS, default 0 (a free port)
#   SAKALA_TEST_FAIL_AFTER  fail on purpose after the named step to prove cleanup
set -euo pipefail

readonly SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"
readonly OVERRIDE_FILE="${PROJECT_DIR}/tests/docker-compose.integration.yml"
readonly ROUTE_TEMPLATE="${PROJECT_DIR}/templates/caddy-app-route.Caddyfile"
readonly PLACEHOLDER_ROUTE="${PROJECT_DIR}/caddy/sites/00-placeholder.Caddyfile"

readonly RUN_ID="$$-${RANDOM}"
readonly PREFIX="sakala-it-${RUN_ID}"
readonly CADDY_CONTAINER="${PREFIX}-caddy"
readonly APP_CONTAINER="${PREFIX}-app"
readonly EDGE_NETWORK="${PREFIX}-edge"
readonly RUNTIME_NETWORK="${PREFIX}-runtime"

readonly APP_IMAGE="busybox:1.37"
readonly APP_PORT=3000
readonly APP_TOKEN="sakala-it-response-${RUN_ID}"
readonly APP_HOST="it-${RUN_ID}.run.sakala.localhost"
readonly PROJECT_ID="11111111-1111-4111-8111-111111111111"
readonly ROUTE_SUFFIX=".run.sakala.localhost"
readonly FALLBACK_BODY="Sakala Edge is running"
readonly CADDY_CONFIG=(--config /etc/caddy/Caddyfile --adapter caddyfile)

readonly STEPS=(contract networks caddy boundaries app route-validation route-active probe bad-route route-removed app-removed)
readonly FAIL_AFTER="${SAKALA_TEST_FAIL_AFTER:-}"
readonly HTTP_PORT_REQUEST="${SAKALA_TEST_HTTP_PORT:-0}"
readonly HTTPS_PORT_REQUEST="${SAKALA_TEST_HTTPS_PORT:-0}"

RUN_DIR=""
SITES_DIR=""
ROUTE_FILE=""
EDGE_PORT=""

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

# Marks a step as passed. SAKALA_TEST_FAIL_AFTER turns it into a failure.
checkpoint() {
    printf 'ok: %s\n' "$1"
    if [[ "${FAIL_AFTER}" == "$1" ]]; then
        fail "stopped after step ${1} because SAKALA_TEST_FAIL_AFTER asked for it"
    fi
}

compose() {
    docker compose \
        --env-file /dev/null \
        --project-name "${PREFIX}" \
        --project-directory "${PROJECT_DIR}" \
        -f "${COMPOSE_FILE}" \
        -f "${OVERRIDE_FILE}" \
        "$@"
}

caddy_exec() {
    docker exec "${CADDY_CONTAINER}" caddy "$@" "${CADDY_CONFIG[@]}"
}

list_leftovers() {
    docker ps -a --filter "name=^/${PREFIX}-" --format 'container {{.Names}}'
    docker ps -a --filter "label=com.docker.compose.project=${PREFIX}" --format 'container {{.Names}}'
    docker network ls --filter "name=^${PREFIX}-" --format 'network {{.Name}}'
    docker volume ls --filter "label=com.docker.compose.project=${PREFIX}" --format 'volume {{.Name}}'
    if [[ -n "${RUN_DIR}" && -e "${RUN_DIR}" ]]; then
        printf 'directory %s\n' "${RUN_DIR}"
    fi
}

on_exit() {
    local status=$?
    trap '' INT TERM
    set +e

    if ((status != 0)) && [[ -n "$(docker ps -aq --filter "name=^/${CADDY_CONTAINER}\$")" ]]; then
        printf -- '--- last Caddy log lines ---\n' >&2
        docker logs --tail 15 "${CADDY_CONTAINER}" >&2 2>&1
    fi

    docker rm -f -v "${APP_CONTAINER}" >/dev/null 2>&1
    if [[ -n "${SITES_DIR}" ]]; then
        compose down --volumes --remove-orphans --timeout 5 >/dev/null 2>&1
    fi
    docker network rm "${EDGE_NETWORK}" "${RUNTIME_NETWORK}" >/dev/null 2>&1
    if [[ -n "${RUN_DIR}" ]]; then
        rm -rf -- "${RUN_DIR}"
    fi

    local leftovers
    leftovers="$(list_leftovers)"
    if [[ -n "${leftovers}" ]]; then
        printf 'FAIL: cleanup left these resources behind:\n%s\n' "${leftovers}" >&2
        status=1
    else
        printf 'Cleanup complete: no %s-* resources remain.\n' "${PREFIX}"
    fi

    if ((status == 0)); then
        printf 'Runtime route integration test passed.\n'
    else
        printf 'Runtime route integration test failed (exit %d).\n' "${status}" >&2
    fi
    trap - EXIT
    exit "${status}"
}

check_prerequisites() {
    local tool
    for tool in docker curl; do
        command -v "${tool}" >/dev/null || fail "${tool} is required"
    done
    docker info >/dev/null 2>&1 || fail "the Docker daemon is not reachable"
    docker compose version >/dev/null 2>&1 || fail "the Docker Compose plugin is required"

    local port
    for port in "${HTTP_PORT_REQUEST}" "${HTTPS_PORT_REQUEST}"; do
        if ! [[ "${port}" =~ ^[0-9]{1,5}$ ]] || ((10#${port} > 65535)); then
            fail "SAKALA_TEST_HTTP_PORT and SAKALA_TEST_HTTPS_PORT must be 0 to 65535, received ${port}"
        fi
    done

    if [[ -n "${FAIL_AFTER}" && " ${STEPS[*]} " != *" ${FAIL_AFTER} "* ]]; then
        fail "SAKALA_TEST_FAIL_AFTER must be one of: ${STEPS[*]}"
    fi
}

# Renders docker-compose.yml without .env and without the name variables a
# developer may have exported, plus any assignments given as arguments.
render_default_config() {
    env -u SAKALA_CADDY_CONTAINER -u SAKALA_DEMO_CONTAINER -u SAKALA_EDGE_NETWORK -u SAKALA_RUNTIME_NETWORK "$@" \
        docker compose --env-file /dev/null --project-directory "${PROJECT_DIR}" -f "${COMPOSE_FILE}" config
}

# The test swaps names to stay isolated, so the names the agent relies on are
# checked here on the configuration `make up` renders, without any override.
check_default_contract() {
    local rendered
    rendered="$(render_default_config)"

    local expected
    for expected in 'container_name: sakala-caddy' 'name: sakala-edge' 'name: sakala-runtime' 'target: /etc/caddy/sites'; do
        grep -qF -- "${expected}" <<<"${rendered}" || fail "default Compose config lost: ${expected}"
    done
    grep -A1 -F -- 'target: /etc/caddy/sites' <<<"${rendered}" | grep -qF -- 'read_only: true' ||
        fail "default Compose config must mount the route folder read-only"
    if grep -qF -- 'docker.sock' <<<"${rendered}"; then
        fail "default Compose config mounts the Docker socket"
    fi
    if grep -qE -- 'target: 2019|published: "?2019"?' <<<"${rendered}"; then
        fail "default Compose config publishes the Caddy Admin API port"
    fi

    # The names stay configurable, so a second stack can run beside this one.
    rendered="$(render_default_config SAKALA_CADDY_CONTAINER=other-caddy SAKALA_DEMO_CONTAINER=other-demo \
        SAKALA_EDGE_NETWORK=other-edge SAKALA_RUNTIME_NETWORK=other-runtime)"
    for expected in 'container_name: other-caddy' 'container_name: other-demo' 'name: other-edge' 'name: other-runtime'; do
        grep -qF -- "${expected}" <<<"${rendered}" || fail "Compose config ignores a configured name: ${expected}"
    done
}

check_networks() {
    "${SCRIPT_DIR}/create-network.sh" "${EDGE_NETWORK}" "${RUNTIME_NETWORK}" >/dev/null

    local first second
    first="$(docker network inspect --format '{{.Id}}' "${EDGE_NETWORK}" "${RUNTIME_NETWORK}")"
    "${SCRIPT_DIR}/create-network.sh" "${EDGE_NETWORK}" "${RUNTIME_NETWORK}" >/dev/null
    second="$(docker network inspect --format '{{.Id}}' "${EDGE_NETWORK}" "${RUNTIME_NETWORK}")"
    [[ "${first}" == "${second}" ]] || fail "create-network.sh replaced a network that already existed"
}

start_caddy() {
    if ! compose up --detach --no-build caddy; then
        fail "Caddy did not start. If the cause is an occupied port, unset SAKALA_TEST_HTTP_PORT and SAKALA_TEST_HTTPS_PORT to use free ports (requested ${HTTP_PORT_REQUEST} and ${HTTPS_PORT_REQUEST})"
    fi
    local published
    published="$(compose port caddy 80)"
    EDGE_PORT="${published##*:}"
    [[ "${EDGE_PORT}" =~ ^[0-9]+$ ]] || fail "could not read the published edge port from '${published}'"
    printf 'Edge port: %s\n' "${EDGE_PORT}"
}

request_body() {
    curl --silent --show-error --fail --max-time 5 \
        --resolve "${1}:${EDGE_PORT}:127.0.0.1" \
        "http://${1}:${EDGE_PORT}/"
}

# Polls because a reload and a container start finish after the command returns.
wait_for_body() {
    local host="$1" expected="$2" body="" _attempt
    for _attempt in {1..40}; do
        body="$(request_body "${host}" 2>&1 || true)"
        if [[ "${body}" == *"${expected}"* ]]; then
            return 0
        fi
        sleep 0.25
    done
    fail "expected '${expected}' from ${host}, last response: ${body}"
}

check_caddy_boundaries() {
    local mounts bindings
    mounts="$(docker inspect --format '{{range .Mounts}}{{.Source}} {{.Destination}} rw={{.RW}}{{"\n"}}{{end}}' "${CADDY_CONTAINER}")"
    if grep -qF -- 'docker.sock' <<<"${mounts}"; then
        fail "Caddy received the Docker socket: ${mounts}"
    fi
    grep -qE -- ' /etc/caddy/sites rw=false$' <<<"${mounts}" || fail "the route folder is not read-only in Caddy: ${mounts}"

    bindings="$(docker inspect --format '{{json .HostConfig.PortBindings}}' "${CADDY_CONTAINER}")"
    if grep -qF -- '2019' <<<"${bindings}"; then
        fail "the Caddy Admin API is published on the host: ${bindings}"
    fi
    if [[ "${bindings}" != *'"80/tcp"'* ]]; then
        fail "the edge port is not published: ${bindings}"
    fi

    docker exec "${CADDY_CONTAINER}" wget --help >/dev/null 2>&1 ||
        fail "the Caddy image has no wget, which the sakala-agent readiness probe needs. Use a caddy:*-alpine image"

    docker exec "${CADDY_CONTAINER}" wget -q -O /dev/null http://127.0.0.1:2019/config/ ||
        fail "the Admin API does not answer on loopback inside Caddy, so 'caddy reload' cannot work"
}

start_app() {
    # Same restrictions the agent applies. The token proves which container answered.
    docker run --detach --name "${APP_CONTAINER}" \
        --network "${RUNTIME_NETWORK}" \
        --restart no \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        --memory 32m \
        --pids-limit 32 \
        --env "PORT=${APP_PORT}" \
        --env "APP_TOKEN=${APP_TOKEN}" \
        "${APP_IMAGE}" \
        sh -c 'mkdir -p /www && printf "%s\n" "${APP_TOKEN}" >/www/index.html && exec httpd -f -p "0.0.0.0:${PORT}" -h /www' \
        >/dev/null

    local networks bindings
    networks="$(docker inspect --format '{{range $name, $_ := .NetworkSettings.Networks}}{{$name}} {{end}}' "${APP_CONTAINER}")"
    [[ "${networks}" == "${RUNTIME_NETWORK} " ]] || fail "the app must join only ${RUNTIME_NETWORK}, it joined: ${networks}"

    bindings="$(docker inspect --format '{{json .HostConfig.PortBindings}}' "${APP_CONTAINER}")"
    [[ "${bindings}" == '{}' ]] || fail "the app must not publish host ports: ${bindings}"

    # The name must resolve and the port must refuse, otherwise this proves nothing.
    local admin_output
    admin_output="$(docker exec "${APP_CONTAINER}" wget -T 2 -O /dev/null "http://${CADDY_CONTAINER}:2019/config/" 2>&1 || true)"
    grep -qF -- "can't connect" <<<"${admin_output}" ||
        fail "the Caddy Admin API must refuse connections from the app network: ${admin_output}"
}

valid_route_host() {
    local host="$1"
    ((${#host} <= 253)) && [[ "${host}" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+run\.sakala\.localhost$ ]]
}

valid_route_upstream() {
    local upstream="$1" name port
    [[ "${upstream}" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?):([0-9]{1,5})$ ]] || return 1
    name="${BASH_REMATCH[1]}"
    port="${BASH_REMATCH[3]}"
    ((${#name} <= 63 && 10#${port} >= 1 && 10#${port} <= 65535))
}

# Renders the repository template into one file per project, using the
# temporary-file-then-rename sequence the agent uses, so Caddy never sees a
# half-written route.
write_route() {
    local project_id="$1" host="$2" upstream="$3"
    valid_route_host "${host}" || return 1
    valid_route_upstream "${upstream}" || return 1

    local slug="${host%"${ROUTE_SUFFIX}"}"
    local target="${SITES_DIR}/${project_id}.Caddyfile"
    local temporary="${SITES_DIR}/.${project_id}.Caddyfile.tmp"
    {
        printf '# Generated by scripts/test-runtime-route.sh for project %s.\n' "${project_id}"
        sed -e '/^#/d' -e "s/APP_SLUG/${slug}/" -e "s/APP_UPSTREAM/${upstream}/" "${ROUTE_TEMPLATE}"
    } >"${temporary}"
    mv -- "${temporary}" "${target}"
    ROUTE_FILE="${target}"
}

check_route_validation() {
    local value
    local bad_hosts=(
        "evil.example.com"
        "app.run.sakala.dev"
        "UPPER.run.sakala.localhost"
        "-dash.run.sakala.localhost"
        ".run.sakala.localhost"
        $'app.run.sakala.localhost {\n}\nother.run.sakala.localhost'
    )
    for value in "${bad_hosts[@]}"; do
        if write_route "${PROJECT_ID}" "${value}" "${APP_CONTAINER}:${APP_PORT}"; then
            fail "the route generator accepted hostname: ${value}"
        fi
    done

    local bad_upstreams=(
        "${APP_CONTAINER}"
        "${APP_CONTAINER}:0"
        "${APP_CONTAINER}:70000"
        "http://${APP_CONTAINER}:${APP_PORT}"
        "app;reboot:${APP_PORT}"
        $'app:3000\n}'
    )
    for value in "${bad_upstreams[@]}"; do
        if write_route "${PROJECT_ID}" "${APP_HOST}" "${value}"; then
            fail "the route generator accepted upstream: ${value}"
        fi
    done

    [[ ! -e "${SITES_DIR}/${PROJECT_ID}.Caddyfile" ]] || fail "a refused route still wrote a file"
}

activate_route() {
    write_route "${PROJECT_ID}" "${APP_HOST}" "${APP_CONTAINER}:${APP_PORT}" ||
        fail "the route generator refused ${APP_HOST} -> ${APP_CONTAINER}:${APP_PORT}"
    [[ ! -e "${SITES_DIR}/.${PROJECT_ID}.Caddyfile.tmp" ]] || fail "the temporary route file was left behind"

    caddy_exec validate >/dev/null 2>&1 || fail "caddy validate refused the generated route: $(cat "${ROUTE_FILE}")"
    caddy_exec reload >/dev/null 2>&1 || fail "caddy reload failed"
    wait_for_body "${APP_HOST}" "${APP_TOKEN}"
}

# Runs the exact readiness probe of sakala-agent and prints wget's stderr.
agent_probe() {
    local upstream="$1"
    docker exec --env "http_proxy=http://${upstream}" "${CADDY_CONTAINER}" \
        wget -Y on --server-response --spider -T 2 "http://${upstream}/" 2>&1 || true
}

check_agent_probe() {
    local output status
    output="$(agent_probe "${APP_CONTAINER}:${APP_PORT}")"
    status="$(grep -m1 -E '^  HTTP/' <<<"${output}" | awk '{print $2}' || true)"
    [[ "${status}" =~ ^[1-4][0-9][0-9]$ ]] || fail "the agent readiness probe saw no healthy status: ${output}"

    # The agent reports runtime_app_not_listening when it reads this wording.
    output="$(agent_probe "${APP_CONTAINER}:9")"
    grep -qF -- "wget: can't connect" <<<"${output}" || fail "a closed port did not produce the wget error the agent classifies: ${output}"

    # The agent reports runtime_dependency_failed when it reads this wording.
    output="$(agent_probe "${PREFIX}-missing:${APP_PORT}")"
    grep -qF -- "wget: bad address" <<<"${output}" || fail "an unknown name did not produce the wget error the agent classifies: ${output}"
}

# A route Caddy refuses must never replace the configuration that is serving.
check_bad_route_is_refused() {
    local bad_route="${SITES_DIR}/22222222-2222-4222-8222-222222222222.Caddyfile"
    printf 'broken.run.sakala.localhost:80 {\n\treverse_proxy\n' >"${bad_route}"
    if caddy_exec validate >/dev/null 2>&1; then
        fail "caddy validate accepted a malformed route"
    fi
    rm -f -- "${bad_route}"
    wait_for_body "${APP_HOST}" "${APP_TOKEN}"
}

remove_route() {
    rm -f -- "${ROUTE_FILE}"
    caddy_exec validate >/dev/null 2>&1 || fail "caddy validate failed after the route was removed"
    caddy_exec reload >/dev/null 2>&1 || fail "caddy reload failed after the route was removed"
    wait_for_body "${APP_HOST}" "${FALLBACK_BODY}"
}

remove_app() {
    docker rm -f -v "${APP_CONTAINER}" >/dev/null
    if docker inspect "${APP_CONTAINER}" >/dev/null 2>&1; then
        fail "the app container still exists after removal"
    fi
    local body
    body="$(request_body "${APP_HOST}")"
    [[ "${body}" == *"${FALLBACK_BODY}"* ]] || fail "expected the fallback edge after cleanup, received: ${body}"
    [[ "${body}" != *"${APP_TOKEN}"* ]] || fail "the removed app still answered"
}

main() {
    check_default_contract
    checkpoint contract

    RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sakala-it.XXXXXX")"
    SITES_DIR="${RUN_DIR}/sites"
    mkdir -p "${SITES_DIR}"
    cp "${PLACEHOLDER_ROUTE}" "${SITES_DIR}/"

    export SAKALA_TEST_CADDY_CONTAINER="${CADDY_CONTAINER}"
    export SAKALA_TEST_EDGE_NETWORK="${EDGE_NETWORK}"
    export SAKALA_TEST_RUNTIME_NETWORK="${RUNTIME_NETWORK}"
    export SAKALA_TEST_SITES_DIR="${SITES_DIR}"
    export SAKALA_HTTP_PORT="127.0.0.1:${HTTP_PORT_REQUEST}"
    export SAKALA_HTTPS_PORT="127.0.0.1:${HTTPS_PORT_REQUEST}"

    check_networks
    checkpoint networks

    start_caddy
    wait_for_body "${APP_HOST}" "${FALLBACK_BODY}"
    checkpoint caddy

    check_caddy_boundaries
    checkpoint boundaries

    start_app
    checkpoint app

    check_route_validation
    checkpoint route-validation

    activate_route
    checkpoint route-active

    check_agent_probe
    checkpoint probe

    check_bad_route_is_refused
    checkpoint bad-route

    remove_route
    checkpoint route-removed

    remove_app
    checkpoint app-removed
}

check_prerequisites
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
main
