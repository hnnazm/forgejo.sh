#!/usr/bin/env bash
set -euo pipefail

unit_file="${1:-$(dirname "$0")/../roles/prereqs/templates/forgejo-podman-forward.service.j2}"
rg -Fqx 'ExecStart=/bin/sh -c '\''/usr/sbin/iptables -C DOCKER-USER -i podman1 -j ACCEPT || /usr/sbin/iptables -I DOCKER-USER 1 -i podman1 -j ACCEPT'\''' "$unit_file"
rg -Fqx 'ExecStart=/bin/sh -c '\''/usr/sbin/iptables -C DOCKER-USER -o podman1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT || /usr/sbin/iptables -I DOCKER-USER 2 -o podman1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT'\''' "$unit_file"
