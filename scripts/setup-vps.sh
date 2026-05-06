#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

prompt() {
    local label="$1"
    local default="${2:-}"
    local value

    if [[ -n "$default" ]]; then
        read -r -p "$label [$default]: " value
        printf '%s' "${value:-$default}"
    else
        read -r -p "$label: " value
        printf '%s' "$value"
    fi
}

prompt_secret() {
    local label="$1"
    local value

    read -r -s -p "$label: " value
    printf '\n' >&2
    printf '%s' "$value"
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$command_name" >&2
        exit 1
    fi
}

derive_origin() {
    local url="$1"

    url="${url%/mcp}"
    url="${url%/}"
    printf '%s' "$url"
}

derive_host() {
    local origin="$1"
    local without_scheme

    without_scheme="${origin#http://}"
    without_scheme="${without_scheme#https://}"
    printf '%s' "${without_scheme%%/*}"
}

require_command docker
require_command curl

if ! docker compose version >/dev/null 2>&1; then
    printf 'Docker Compose v2 is required. Install the docker compose plugin first.\n' >&2
    exit 1
fi

printf 'Taiga MCP VPS setup\n'
printf 'Repository: %s\n\n' "$ROOT_DIR"

taiga_api_url="$(prompt 'Taiga API URL' 'https://api.taiga.io')"
taiga_username="$(prompt 'Taiga username/email')"
taiga_password="$(prompt_secret 'Taiga password')"
public_url="$(prompt 'Public MCP URL' 'https://taiga-mcp.example.com/mcp')"

if [[ -z "$taiga_username" || -z "$taiga_password" || -z "$public_url" ]]; then
    printf 'Taiga username, password, and public MCP URL are required.\n' >&2
    exit 1
fi

mcp_public_origin="$(derive_origin "$public_url")"
mcp_public_host="$(derive_host "$mcp_public_origin")"

if [[ "$mcp_public_origin" != http://* && "$mcp_public_origin" != https://* ]]; then
    printf 'Public MCP URL must start with http:// or https://.\n' >&2
    exit 1
fi

if [[ -f "$ENV_FILE" ]]; then
    backup_file="$ENV_FILE.backup.$(date +%Y%m%d%H%M%S)"
    cp "$ENV_FILE" "$backup_file"
    chmod 600 "$backup_file"
    printf 'Existing .env backed up to %s\n' "$backup_file"
fi

umask 077
cat >"$ENV_FILE" <<EOF
TAIGA_API_URL=$taiga_api_url
TAIGA_USERNAME=$taiga_username
TAIGA_PASSWORD=$taiga_password

MCP_PUBLIC_HOST=$mcp_public_host
MCP_PUBLIC_ORIGIN=$mcp_public_origin
EOF
chmod 600 "$ENV_FILE"

printf '\nWritten %s with:\n' "$ENV_FILE"
grep -E '^(TAIGA_API_URL|TAIGA_USERNAME|MCP_PUBLIC_HOST|MCP_PUBLIC_ORIGIN)=' "$ENV_FILE"
printf 'TAIGA_PASSWORD=<redacted>\n\n'

cd "$ROOT_DIR"

printf 'Building Docker image...\n'
docker compose build

printf 'Starting taiga-mcp container...\n'
docker compose up -d --force-recreate

printf 'Waiting for local MCP endpoint...\n'
for attempt in {1..20}; do
    if curl -fsS -o /tmp/taiga-mcp-setup-check.out \
        -X POST http://127.0.0.1:8087/mcp \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json, text/event-stream' \
        -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"setup-vps","version":"1.0.0"}}}' >/dev/null 2>&1; then
        printf 'Local MCP endpoint responded successfully.\n'
        break
    fi

    if [[ "$attempt" == 20 ]]; then
        printf 'MCP endpoint did not respond successfully. Recent logs:\n' >&2
        docker logs --tail 80 taiga-mcp >&2 || true
        exit 1
    fi

    sleep 2
done

printf '\nRecent auth logs:\n'
docker logs --tail 80 taiga-mcp 2>&1 | grep -E 'Login successful|Auto-authentication successful|Auto-authentication failed|Auto-authentication error|No environment credentials' || true

printf '\nSetup complete.\n'
printf 'Public MCP endpoint: %s/mcp\n' "$mcp_public_origin"
