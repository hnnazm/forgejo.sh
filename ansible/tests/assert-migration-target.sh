#!/usr/bin/env bash
set -euo pipefail

inventory_file="${1:-$(dirname "$0")/../inventory.ini}"
forgejo_template="${2:-$(dirname "$0")/../roles/forgejo/templates/forgejo.container.j2}"

rg -Fx 'forgejo-source ansible_user=nan' "$inventory_file"
! rg -F 'ansible_host=' "$inventory_file"
ssh -G forgejo-source 2>/dev/null | rg -q '^hostname .+$'
ssh -G forgejo-source 2>/dev/null | rg -Fx 'identitiesonly yes'
rg -Fqx 'Environment=FORGEJO__server__ROOT_URL=https://{{ vault_forgejo_external_hostname }}/' "$forgejo_template"
rg -Fqx 'Environment=FORGEJO__server__DOMAIN={{ vault_forgejo_external_hostname }}' "$forgejo_template"
rg -Fqx 'Environment=FORGEJO__server__SSH_DOMAIN={{ vault_forgejo_external_hostname }}' "$forgejo_template"
