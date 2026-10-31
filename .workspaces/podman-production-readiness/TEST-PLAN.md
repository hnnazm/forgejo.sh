# Test Plan: Podman production readiness

- Under test: deployed Podman Quadlet Forgejo stack on `forgejo-source`
- Criteria source: user request to run the registry smoke test, reboot-persistence test, and post-reboot Ansible idempotency test before promoting `forgejo.example.com`.

## Strategy

Run authenticated container-registry push/pull using the temporary public hostname, reboot the host and probe expected system services, public health, and fresh Podman bridge egress, then run the complete Ansible site playbook and inspect its convergence result.

## Results by acceptance criterion

| # | Criterion | Test | Result |
|---|---|---|---|
| 1 | An authenticated user can push and pull a container image through the temporary Forgejo registry hostname. | Logged in as `forgejo`, pushed a newly tagged BusyBox image, removed its local tag, then pulled it from `forgejo-migrate.example.com`. | PASS |
| 2 | After a host reboot, Forgejo, PostgreSQL, cloudflared, both runners, and Podman bridge egress recover without manual intervention. | After the cloudflared retry repair, SSH recovered on the fifth 5-second probe; all six required services were `active`; cloudflared recovered after one delayed retry; public health passed; and a fresh `forgejo-net` BusyBox request reached Debian. | PASS |
| 3 | The full Ansible deployment converges after reboot without unexpected changes. | Complete `ansible/site.yml` run after the repaired reboot reported `ok=32 changed=0 unreachable=0 failed=0`. | PASS |

## Edge cases probed

- Docker firewall reconstruction caused by service restart was previously validated; the reboot repeats this at the host lifecycle boundary.
- Registry test removes the locally cached test image before the pull, ensuring the pull reaches the registry.

## Bugs

N/A. B1, the cloudflared reboot DNS race, was repaired and verified by the second reboot. Investigation: `.workspaces/cloudflared-reboot-dns-race/ANALYSIS.md`.

## Regression test

- Podman bridge egress: a fresh `forgejo-net` container downloads Debian metadata after the reboot. This is the regression probe for the Docker `FORWARD`-policy interaction.

## Criteria that could not be tested

N/A.

VERDICT: PASS — 3/3 readiness criteria passed. The temporary Podman deployment is ready for the credential rotation and controlled `forgejo.example.com` cutover steps.
