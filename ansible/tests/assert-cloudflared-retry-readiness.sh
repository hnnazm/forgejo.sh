#!/usr/bin/env bash
set -euo pipefail

unit_template="${1:-$(dirname "$0")/../roles/cloudflared/templates/cloudflared.container.j2}"
rg -Fqx 'After=forgejo.service tailscaled.service' "$unit_template"
rg -Fqx 'Wants=tailscaled.service' "$unit_template"
rg -Fqx 'StartLimitIntervalSec=0' "$unit_template"
rg -Fqx 'RestartSec=15' "$unit_template"
