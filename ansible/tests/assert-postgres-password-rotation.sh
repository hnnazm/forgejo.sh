#!/usr/bin/env bash
set -euo pipefail

role_file="${1:-$(dirname "$0")/../roles/postgres/tasks/main.yml}"
variables_file="${2:-$(dirname "$0")/../group_vars/all/main.yml}"
! rg -F 'forgejo_db_password_rotation_id:' "$variables_file"
rg -Fq 'Calculate the PostgreSQL password fingerprint' "$role_file"
rg -Fq "vault_forgejo_db_password | hash('sha256')" "$role_file"
rg -Fq 'ALTER ROLE' "$role_file"
rg -Fq 'Write the PostgreSQL password fingerprint' "$role_file"
