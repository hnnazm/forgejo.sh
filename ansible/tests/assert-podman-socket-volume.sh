#!/usr/bin/env bash
set -euo pipefail

config_template="${1:-$(dirname "$0")/../roles/forgejo_runners/templates/config.yml.j2}"
rg -Fqx '    - /run/podman/podman.sock' "$config_template"
