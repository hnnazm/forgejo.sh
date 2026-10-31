#!/usr/bin/env bash
set -euo pipefail

workflow_file="${1:-$(dirname "$0")/../../.forgejo/workflows/ci.yml}"
base_image_file="${2:-$(dirname "$0")/../roles/ci_images/files/base.Containerfile}"
role_tasks="${3:-$(dirname "$0")/../roles/ci_images/tasks/main.yml}"
variables_file="${4:-$(dirname "$0")/../group_vars/all/main.yml}"

! rg -Fq 'container:' "$workflow_file"
rg -Fq 'Install Terraform' "$workflow_file"
rg -Fq 'terraform_version=1.11.4' "$workflow_file"
rg -Fq 'apt-get install -y --no-install-recommends unzip' "$workflow_file"
rg -Fq 'Install Ansible tooling' "$workflow_file"
rg -Fq 'ansible-core==2.18.2' "$workflow_file"
rg -Fqx 'default_ci_image: localhost/forgejo-ci-base:1' "$variables_file"
rg -Fq 'apt-get install -y --no-install-recommends git curl ca-certificates' "$base_image_file"
rg -Fq 'localhost/forgejo-ci-base:1' "$role_tasks"
! rg -Fq 'forgejo-ci-terraform' "$role_tasks"
! rg -Fq 'forgejo-ci-ansible' "$role_tasks"
