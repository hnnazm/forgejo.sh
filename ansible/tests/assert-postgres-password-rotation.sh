#!/usr/bin/env bash
set -euo pipefail

role_file="${1:-$(dirname "$0")/../roles/postgres/tasks/main.yml}"
rotation_playbook="${2:-$(dirname "$0")/../rotate-postgres-password.yml}"
! rg -F 'password-fingerprint' "$role_file"
rg -Fq 'vars_prompt:' "$rotation_playbook"
rg -Fq 'pg_new_password == vault_forgejo_db_password' "$rotation_playbook"
rg -Fq 'ALTER ROLE' "$rotation_playbook"
rg -Fq 'name: postgres' "$rotation_playbook"
rg -Fq 'name: forgejo' "$rotation_playbook"
