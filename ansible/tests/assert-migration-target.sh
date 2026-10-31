#!/usr/bin/env bash
set -euo pipefail

inventory_file="${1:-$(dirname "$0")/../inventory.ini}"
variables_file="${2:-$(dirname "$0")/../group_vars/all/main.yml}"

rg -Fx 'forgejo-source ansible_host=100.87.98.97 ansible_user=nan' "$inventory_file"
rg -Fx 'forgejo_external_hostname: forgejo-migrate.example.com' "$variables_file"
