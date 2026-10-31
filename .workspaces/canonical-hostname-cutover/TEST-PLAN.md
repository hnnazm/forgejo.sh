# Test Plan: Canonical hostname cutover

- Under test: Podman Forgejo deployment after commit `76575a6`
- Criteria source: post-cutover checks requested for the canonical Forgejo hostname.

## Strategy

Use the canonical HTTPS hostname for authenticated Forgejo API access, Git clone/push, registry authentication/pull, and triggering/polling the existing privileged DinD smoke workflow. These are external acceptance checks rather than internal host-health probes.

## Results by acceptance criterion

| # | Criterion | Test | Result |
|---|---|---|---|
| 1 | Canonical public Forgejo endpoint is healthy and authenticates an administrator. | Public `/api/healthz` passed; authenticated `GET /api/v1/user` through the canonical hostname returned user `forgejo`. | PASS |
| 2 | Git clients can clone and push through the canonical hostname. | Cloned `hnnazm/test` over canonical HTTPS, pushed disposable branch `canonical-smoke-20261031155324`, then deleted it. | PASS |
| 3 | The container registry authenticates and serves an image through the canonical hostname. | Authenticated rootful Podman login, removed the local canonical tag, then pulled `forgejo.example.com/forgejo/registry-smoke:<tag>`. | PASS |
| 4 | Forgejo Actions accepts and completes the existing Podman socket/DinD smoke workflow after canonical-hostname cutover. | Updated the workflow through the canonical API at commit `e1ff449fca4e5637c5b3b41f602026d8fc3ba723`; run ID `10` completed `success`. | PASS |

## Edge cases probed

- The Git push uses a disposable branch that is deleted afterward, avoiding persistent repository content drift.
- The registry pull removes the canonical-tagged local image first, ensuring the request reaches the registry.

## Bugs

N/A.

## Regression test

- The existing `hnnazm/test` DinD workflow is the regression test for Actions scheduling, Podman socket access, nested Docker, and Podman bridge egress.

## Criteria that could not be tested

N/A.

VERDICT: PASS — 4/4 post-cutover checks passed through the canonical hostname.
