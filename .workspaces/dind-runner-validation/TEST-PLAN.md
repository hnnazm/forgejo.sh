# DinD runner validation

## Contract

Validate the migrated Forgejo Actions capacity using repository `hnnazm/test` through the temporary validation hostname:

1. Forgejo exposes exactly two active Podman-backed runner services.
2. A workflow scheduled with `runs-on: docker` is accepted and executes.
3. The job can use the runner-mounted Docker-compatible Podman socket.
4. The job can create a privileged nested Docker daemon and run `docker info` from inside it.
5. The workflow reports success through Forgejo Actions.

## Existing evidence

- Both runner systemd services and containers were active after migration.
- The final validation workflow run completed successfully after the runner socket allowlist and Podman bridge forwarding fixes.

## Test procedure

1. Verify both runner units/containers are active on the host.
2. Commit a one-shot `workflow_dispatch` workflow to `hnnazm/test`; it installs Docker CLI in the Node job image, runs host-socket `docker info`, starts a privileged `docker:dind` container, waits for its inner daemon, and runs inner `docker info`.
3. Trigger the workflow through Forgejo’s API and poll the run result.
4. Record pass/fail evidence. Do not delete the workflow automatically; it is useful regression coverage.

## Result

| Criterion | Result | Evidence |
|---|---|---|
| Two runner services are active | PASS | `forgejo-runner-1.service` and `forgejo-runner-2.service` were both `active` after the final runner restart. |
| Docker-labelled workflow is scheduled | PASS | Final run ID `9`, job ID `9`, and task ID `15` were accepted and completed successfully. |
| Outbound IPv4 from a Podman job network | PASS | The job completed `apt-get update` and installed `docker.io`; an independent fresh `forgejo-net` BusyBox container also downloaded Debian's Bookworm `InRelease` over IPv4. |
| Socket-backed Docker-compatible Podman API | PASS | The final workflow mounted `/run/podman/podman.sock` at `/var/run/podman.sock`, set `DOCKER_HOST=unix:///var/run/podman.sock`, then completed `docker version` and `docker info`. |
| Privileged nested Docker daemon | PASS | The same workflow created `docker:27-dind` with `--privileged`, started `dockerd`, selected its inner Unix socket, and completed inner `docker info`. |
| Workflow reports success | PASS | Forgejo API reports run ID `9` and its `nested-docker` job as `success`. |

### Failure evidence and repairs

The initial task log at `/srv/forgejo/data/gitea/actions_log/hnnazm/test/07/7.log.zst` identified two independent failures:

1. `/run/podman/podman.sock` was not in `container.valid_volumes`.
2. Podman bridge traffic was dropped by Docker's `FORWARD` policy before Netavark forwarding rules could accept it.

Repairs:

- Added `/run/podman/podman.sock` to the runner volume allowlist and ensured configuration changes restart the runner units.
- Added the rootful `forgejo-podman-forward.service`, which installs the least-privilege `DOCKER-USER` rules needed for outbound `podman1` traffic and established replies.
- The runner also auto-mounts host Docker at `/var/run/docker.sock`; mounting Podman's socket there produced a duplicate destination. The final workflow instead mounts it at `/var/run/podman.sock` and explicitly selects it with `DOCKER_HOST`.

### Reproduction

Open the `hnnazm/test` Actions run ID `9` through the configured Forgejo hostname while logged in. The passing workflow is `.forgejo/workflows/dind-smoke.yml` at test-repository commit `5a130b9fa87c6b9f145b2200697f3a53ddda0df1`.

### Verdict

**PASS — both privileged runners support outbound CI networking, Docker-compatible rootful Podman socket access, and privileged nested Docker/DinD.**
