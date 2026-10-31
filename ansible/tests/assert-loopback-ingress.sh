#!/usr/bin/env bash
set -euo pipefail

forgejo_template="${1:-$(dirname "$0")/../roles/forgejo/templates/forgejo.container.j2}"
cloudflared_template="${2:-$(dirname "$0")/../roles/cloudflared/templates/cloudflared.container.j2}"

rg -Fx 'PublishPort=127.0.0.1:3000:3000' "$forgejo_template"
rg -Fx 'Network=host' "$cloudflared_template"
