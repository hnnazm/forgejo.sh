#!/usr/bin/env bash
set -euo pipefail

role_file="${1:-$(dirname "$0")/../roles/forgejo/tasks/main.yml}"
rg -U -F -q -- $'- name: Create the initial Forgejo administrator\n  containers.podman.podman_container_exec:\n    name: forgejo\n    user: "1000:1000"' "$role_file"
