#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this verification as root so it exercises the rootful Podman service." >&2
  exit 1
fi

if [[ "$(podman info --format '{{ .Host.Security.Rootless }}')" != "false" ]]; then
  echo "Podman must be rootful for the trusted DinD runner host." >&2
  exit 1
fi

container_name="forgejo-dind-smoke-$$"
cleanup() {
  podman rm --force "$container_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

podman run --detach --privileged --name "$container_name" docker:27-dind >/dev/null

for _ in $(seq 1 30); do
  if podman exec "$container_name" docker info >/dev/null 2>&1; then
    echo "DinD smoke test passed: inner Docker daemon is ready."
    exit 0
  fi
  sleep 2
done

echo "Inner Docker daemon did not become ready." >&2
podman logs "$container_name" >&2 || true
exit 1
