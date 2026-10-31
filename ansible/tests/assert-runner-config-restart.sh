#!/usr/bin/env bash
set -euo pipefail

role_file="${1:-$(dirname "$0")/../roles/forgejo_runners/tasks/runner.yml}"
python3 - "$role_file" <<'PY'
import sys

text = open(sys.argv[1], encoding="utf-8").read()
start = text.index("- name: Render runner configuration for runner {{ runner_index }}")
end = text.index("- name: Render runner Quadlet for runner {{ runner_index }}", start)
assert "notify: Reload runner Quadlets" in text[start:end]
PY
