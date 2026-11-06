#!/usr/bin/env bash
#
# Writes the local .env files docs/FULL_STACK_LOCAL.md needs, from each app
# repository's own .env.example. Secrets are generated on this machine and never
# printed. Safe to run again: generated values and any other keys stay as they are.
#
# Usage:
#   scripts/full-stack-env.sh         API, Console, and this repository
#   scripts/full-stack-env.sh agent   provisions one node and writes the agent env
#   scripts/full-stack-env.sh railpack-sandbox   builds the sandbox image and prints its pin
#
# Environment:
#   SAKALA_APPS_DIR         folder holding the sakala-* clones (default: parent of this repository)
#   SAKALA_LOCAL_DB_PORT    host port for PostgreSQL (default: 15432)
#   SAKALA_LOCAL_VALKEY_PORT host port for Valkey (default: 16379)
#   SAKALA_LOCAL_REVERB_PORT host port for Reverb (default: 8081)
#   SAKALA_HTTP_PORT        edge port of the runtime Caddy (default: value in .env, then 8080)
#   SAKALA_CADDY_CONTAINER, SAKALA_RUNTIME_NETWORK, SAKALA_CADDY_SITES_DIR,
#   SAKALA_RUNTIME_WORKSPACE, SAKALA_NODE_NAME   agent settings, with local defaults
#   SAKALA_RAILPACK_IMAGE   sandbox image pinned by sha256 (default: built from sakala-agent)
set -euo pipefail

readonly SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly APPS_DIR="${SAKALA_APPS_DIR:-$(CDPATH= cd -- "${PROJECT_DIR}/.." && pwd)}"
readonly API_DIR="${APPS_DIR}/sakala-api"
readonly CONSOLE_DIR="${APPS_DIR}/sakala-console"
readonly AGENT_DIR="${APPS_DIR}/sakala-agent"

readonly DB_PORT="${SAKALA_LOCAL_DB_PORT:-15432}"
readonly VALKEY_PORT="${SAKALA_LOCAL_VALKEY_PORT:-16379}"
readonly REVERB_PORT="${SAKALA_LOCAL_REVERB_PORT:-8081}"

umask 077

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

get_env() {
    sed -n "s/^$2=//p" "$1" | tail -n 1
}

# Replaces the key's line, or appends it. The value never passes through a regex
# or the command line of another process.
set_env() {
    local file="$1" key="$2" value="$3" temporary
    temporary="$(mktemp "${file}.XXXXXX")"
    KEY="${key}" VALUE="${value}" awk '
        BEGIN { key = ENVIRON["KEY"]; value = ENVIRON["VALUE"]; prefix = key "="; found = 0 }
        index($0, prefix) == 1 { print prefix value; found = 1; next }
        { print }
        END { if (!found) print prefix value }
    ' "${file}" >"${temporary}"
    mv -- "${temporary}" "${file}"
}

# Fills the key only while it still holds the example value, so a second run keeps it.
generate_once() {
    local file="$1" key="$2" example="$3" bytes="$4"
    if [[ "$(get_env "${file}" "${key}")" == "${example}" ]]; then
        set_env "${file}" "${key}" "$(openssl rand -hex "${bytes}")"
    fi
}

prepare_env_file() {
    local dir="$1"
    [[ -f "${dir}/.env.example" ]] || fail "${dir}/.env.example not found. Clone the repository next to sakala-infra or set SAKALA_APPS_DIR."
    if [[ -f "${dir}/.env" ]]; then
        [[ -f "${dir}/.env.backup" ]] || cp -- "${dir}/.env" "${dir}/.env.backup"
    else
        cp -- "${dir}/.env.example" "${dir}/.env"
    fi
    chmod 600 "${dir}/.env"
}

write_infra_env() {
    [[ -f "${PROJECT_DIR}/.env" ]] || cp -- "${PROJECT_DIR}/.env.example" "${PROJECT_DIR}/.env"
    EDGE_PORT="${SAKALA_HTTP_PORT:-$(get_env "${PROJECT_DIR}/.env" SAKALA_HTTP_PORT)}"
    EDGE_PORT="${EDGE_PORT:-8080}"
    [[ "${EDGE_PORT}" != "${REVERB_PORT}" ]] || fail "the edge port and Reverb port must differ, both are ${EDGE_PORT}"
}

write_api_env() {
    local file="${API_DIR}/.env"
    prepare_env_file "${API_DIR}"

    # PHP and the agent run on the host, so they reach these services over published ports.
    set_env "${file}" DB_HOST 127.0.0.1
    set_env "${file}" DB_PORT "${DB_PORT}"
    # Compose publishes these on every interface unless the value names one.
    set_env "${file}" FORWARD_DB_PORT "127.0.0.1:${DB_PORT}"
    set_env "${file}" REDIS_HOST 127.0.0.1
    set_env "${file}" REDIS_PORT "${VALKEY_PORT}"
    set_env "${file}" FORWARD_VALKEY_PORT "127.0.0.1:${VALKEY_PORT}"
    generate_once "${file}" DB_PASSWORD password 24

    set_env "${file}" MAIL_MAILER log
    # The log mailer delivers nothing, so the API needs this explicit opt-in to offer email flows locally.
    set_env "${file}" SAKALA_EMAIL_DELIVERY_ENABLED true

    set_env "${file}" SAKALA_PROJECT_DEFAULT_DOMAIN run.sakala.localhost
    set_env "${file}" SAKALA_PROJECT_URL_SCHEME http
    set_env "${file}" SAKALA_PROJECT_URL_PORT "${EDGE_PORT}"

    set_env "${file}" SAKALA_AVATAR_STORAGE local

    set_env "${file}" BROADCAST_CONNECTION reverb
    set_env "${file}" REVERB_ALLOWED_ORIGINS app.sakala.localhost,localhost
    set_env "${file}" REVERB_HOST 127.0.0.1
    set_env "${file}" REVERB_PORT "${REVERB_PORT}"
    set_env "${file}" REVERB_SCHEME http
    set_env "${file}" REVERB_SERVER_HOST 127.0.0.1
    set_env "${file}" REVERB_SERVER_PORT "${REVERB_PORT}"
    if [[ -z "$(get_env "${file}" REVERB_APP_ID)" ]]; then
        set_env "${file}" REVERB_APP_ID sakala-local
    fi
    generate_once "${file}" REVERB_APP_KEY '' 16
    generate_once "${file}" REVERB_APP_SECRET '' 24
}

write_console_env() {
    local file="${CONSOLE_DIR}/.env"
    prepare_env_file "${CONSOLE_DIR}"
    set_env "${file}" PUBLIC_REVERB_HOST localhost
    set_env "${file}" PUBLIC_REVERB_PORT "${REVERB_PORT}"
    set_env "${file}" PUBLIC_REVERB_SCHEME http
    # Public connection metadata. REVERB_APP_SECRET must never reach this file.
    set_env "${file}" PUBLIC_REVERB_KEY "$(get_env "${API_DIR}/.env" REVERB_APP_KEY)"
}

# Railpack only ever runs inside this image, and the agent's docker driver refuses
# to start without it. Build output goes to stderr, so stdout is only the image ID.
build_railpack_sandbox() {
    local recipe="${AGENT_DIR}/docker/railpack-sandbox"
    local image="sakala-railpack-sandbox"

    [[ -f "${recipe}/Dockerfile" ]] || fail "${recipe} not found. Clone sakala-agent next to sakala-infra or set SAKALA_APPS_DIR."
    # Without --provenance=false, every build on the containerd image store gets a new ID and
    # drops the previous one, which would break a pin that an agent env already holds.
    docker build --provenance=false --tag "${image}" "${recipe}" >&2 || fail "Building the Railpack sandbox image failed."
    docker image inspect --format '{{.Id}}' "${image}"
}

resolve_railpack_image() {
    local pinned="${SAKALA_RAILPACK_IMAGE:-}"

    [[ -n "${pinned}" ]] || pinned="$(build_railpack_sandbox)"
    [[ "${pinned}" == sha256:* || "${pinned}" == *@sha256:* ]] ||
        fail "SAKALA_RAILPACK_IMAGE must be pinned by sha256, and a tag is rejected: ${pinned}"
    printf '%s\n' "${pinned}"
}

write_agent_env() {
    local file="${AGENT_DIR}/.env"
    local sites_dir="${SAKALA_CADDY_SITES_DIR:-${PROJECT_DIR}/caddy/sites}"
    local workspace="${SAKALA_RUNTIME_WORKSPACE:-${HOME}/.local/share/sakala/builds}"
    local credentials railpack_image

    [[ -d "${AGENT_DIR}" ]] || fail "${AGENT_DIR} not found. Clone sakala-agent next to sakala-infra or set SAKALA_APPS_DIR."
    railpack_image="$(resolve_railpack_image)"
    if [[ -f "${file}" ]] && grep -q '^SAKALA_AGENT_TOKEN=' "${file}"; then
        printf '%s already holds a node token, so no new node was provisioned.\n' "${file}"
    else
        credentials="$(cd "${API_DIR}" && php artisan agent:provision "${SAKALA_NODE_NAME:-local-node}" --description "local full stack" --no-interaction)" ||
            fail "agent:provision failed. Is PostgreSQL running and has 'composer setup' finished?"
        printf '%s\n' "${credentials}" >"${file}"
        printf 'Provisioned one node. Its token exists only in %s.\n' "${file}"
    fi
    chmod 600 "${file}"

    # The agent preflight runs df on the workspace before it creates the folder.
    mkdir -p "${workspace}"

    set_env "${file}" SAKALA_AGENT_MODE connected
    set_env "${file}" SAKALA_API_URL http://127.0.0.1:8000
    set_env "${file}" SAKALA_RUNTIME_DRIVER docker
    set_env "${file}" SAKALA_RAILPACK_IMAGE "${railpack_image}"
    set_env "${file}" SAKALA_RUNTIME_NETWORK "${SAKALA_RUNTIME_NETWORK:-sakala-runtime}"
    set_env "${file}" SAKALA_CADDY_CONTAINER "${SAKALA_CADDY_CONTAINER:-sakala-caddy}"
    set_env "${file}" SAKALA_CADDY_SITES_DIR "${sites_dir}"
    set_env "${file}" SAKALA_RUNTIME_WORKSPACE "${workspace}"
}

case "${1:-}" in
"")
    command -v openssl >/dev/null || fail "openssl is required"
    write_infra_env
    write_api_env
    write_console_env
    printf 'Wrote .env files in sakala-infra, sakala-api, and sakala-console. Project URLs use port %s, Reverb uses %s.\n' "${EDGE_PORT}" "${REVERB_PORT}"
    ;;
agent)
    write_agent_env
    ;;
railpack-sandbox)
    printf 'SAKALA_RAILPACK_IMAGE=%s\n' "$(resolve_railpack_image)"
    ;;
*)
    fail "unknown argument '$1'. Use no argument, 'agent', or 'railpack-sandbox'."
    ;;
esac
