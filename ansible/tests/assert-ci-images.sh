#!/usr/bin/env bash
set -euo pipefail

workflow_file="${1:-$(dirname "$0")/../../.forgejo/workflows/ci.yml}"
terraform_image_file="${2:-$(dirname "$0")/../roles/ci_images/files/terraform.Containerfile}"
ansible_image_file="${3:-$(dirname "$0")/../roles/ci_images/files/ansible.Containerfile}"
role_tasks="${4:-$(dirname "$0")/../roles/ci_images/tasks/main.yml}"

rg -Fqx '      image: localhost/forgejo-ci-terraform:1' "$workflow_file"
rg -Fqx '      image: localhost/forgejo-ci-ansible:1' "$workflow_file"
! rg -Fq 'pip install ansible-core ansible-lint' "$workflow_file"
rg -Fq 'apk add --no-cache nodejs git' "$terraform_image_file"
rg -Fq 'apt-get install -y --no-install-recommends nodejs git' "$ansible_image_file"
rg -Fq 'containers.podman.podman_image:' "$role_tasks"
