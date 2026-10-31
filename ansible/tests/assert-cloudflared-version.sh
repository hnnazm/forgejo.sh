#!/usr/bin/env bash
set -euo pipefail

variables_file="${1:-$(dirname "$0")/../group_vars/all/main.yml}"
rg -Fx 'cloudflared_version: "2026.7.1"' "$variables_file"
