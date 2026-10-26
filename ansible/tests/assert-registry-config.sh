#!/usr/bin/env bash
set -euo pipefail

config_file="${1:-$(dirname "$0")/../group_vars/all/main.yml}"
template_file="${2:-$(dirname "$0")/../roles/forgejo/templates/forgejo.container.j2}"

rg -qx 'forgejo_packages_enabled: true' "$config_file"
rg -Fqx 'Environment=FORGEJO__packages__ENABLED={{ forgejo_packages_enabled | string | lower }}' "$template_file"
