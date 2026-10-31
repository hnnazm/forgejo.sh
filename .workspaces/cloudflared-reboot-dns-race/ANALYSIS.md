## Context

A controlled reboot of `forgejo-source` was run as the Podman-stack persistence acceptance test. Expected behavior was for the temporary Forgejo endpoint to recover automatically. Actual behavior: `cloudflared.service` failed, and `https://forgejo-migrate.example.com/api/healthz` returned Cloudflare HTTP 530. Forgejo, PostgreSQL, both runners, Podman bridge forwarding, and a fresh Podman-network HTTP egress probe recovered.

Cloudflared `2026.7.1` repeatedly failed DNS edge discovery with `lookup _v2-origintunneld._tcp.argotunnel.com on [::1]:53: connection refused`, then hit systemd's restart-start limit.

## Investigation

| # | Mechanism hypothesis | Would be false if | Cheapest discriminating experiment | Result / eliminated space |
|---|---|---|---|---|
| 1 | The Quadlet starts before DNS is usable after reboot. | Cloudflared's failure time is at or after usable resolver configuration. | Compare boot timestamps in cloudflared and tailscaled journals. | Confirmed ordering: cloudflared started/fails at `22:01:08`; Tailscale first applied DNS configuration at `22:01:15`. |
| 2 | `network-online.target` guarantees usable DNS on this host. | That target is inactive before cloudflared starts or DNS is ready when it is active. | Inspect generated unit dependencies, target state, and logs. | Refuted: cloudflared has `Wants=`/`After=network-online.target`, which was active, but it still inherited an unusable loopback resolver. |
| 3 | The failure is a Podman bridge/NAT issue. | The same failure happens without host networking, or independent host-network traffic is broken. | Inspect Quadlet networking and execute a fresh bridge egress probe. | Refuted: cloudflared uses `Network=host`; an independent fresh `forgejo-net` BusyBox request to Debian succeeded after reboot. |

## Evidence state

- Observability: captured systemd and container logs.
- Repeatability: observed once during the controlled reboot; startup race is expected to recur because no dependency waits for resolver readiness.
- Reduction: original reboot case.
- Automation: scripted acceptance probe that failed on cloudflared status and public health.
- Provenance: bounded to the cloudflared startup ordering after reboot.

## Confirmed cause

- Defect: `ansible/roles/cloudflared/templates/cloudflared.container.j2` — its only explicit ordering is `After=forgejo.service`; the generated Quadlet additionally orders after `network-online.target`, but the template supplies neither a DNS-readiness gate nor delayed retries.
- Chain: `network-online.target` becomes active before a usable resolver exists → cloudflared receives transient `nameserver ::1` configuration → Cloudflare edge SRV lookup is refused → the connector exits in under one second → `Restart=always` retries immediately five times → systemd start-limit failure prevents the retry that would occur after DNS becomes usable → HTTP 530.
- Counterfactual: added `After=... tailscaled.service`, `Wants=tailscaled.service`, `RestartSec=15`, and `StartLimitIntervalSec=0` to the Podman Quadlet, then rebooted. The initial DNS race still produced one restart, but the delayed retry occurred after DNS became usable; cloudflared became active and public health passed. This directly removes the failure mode.
- Exact shape: boot chronology shows `network-online.target` at `22:01:04`, cloudflared launches from `22:01:06` through `22:01:12`, and Tailscale configures DNS at `22:01:15`. `systemd-analyze critical-chain` shows cloudflared is ordered through Forgejo and `network-online`, not DNS availability. Other Podman workloads were healthy because they use the Podman network and do not require Cloudflare SRV discovery.

The immediate-restart/start-limit combination is the actionable defect. Adding `After=tailscaled.service` alone would not be sufficient: Tailscale's Type=notify activation occurred at `22:01:05`, but its DNS configuration did not occur until `22:01:15`.

## Fix & verification

- Level: fix at the service-recovery boundary. DNS readiness cannot be represented reliably by `network-online.target` on this host, so the connector now survives transient DNS absence rather than permanently failing during boot.
- Change: `ansible/roles/cloudflared/templates/cloudflared.container.j2` — orders after/wants Tailscale, waits 15 seconds between restarts, and disables systemd's short start-rate limit.
- Regression test: `ansible/tests/assert-cloudflared-retry-readiness.sh` failed before the configuration change and passed afterward.
- Checks: template assertion, `ansible-lint`, and Ansible syntax check passed; deployment restored public `/api/healthz`; a second controlled reboot recovered cloudflared after one delayed retry, all expected services became active, public health passed, fresh Podman bridge egress passed, and a following Ansible run had `changed=0`.

## Open items

- Rotate the Cloudflare Tunnel token: an unredacted generated-unit inspection in this operational session exposed it. Do not copy the token into this record or any future logs.
