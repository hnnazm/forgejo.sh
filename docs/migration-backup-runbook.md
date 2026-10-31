# Docker Forgejo to Podman migration backup runbook

This runbook creates a consistent, encrypted migration backup of the current Docker-based Forgejo host before any Podman cutover. It is **not** the cutover or restore procedure.

The source deployment stores Forgejo data in `/srv/forgejo/data`, PostgreSQL data in `/srv/forgejo-db/data`, and runner registration identities in `/srv/forgejo-runners/tokens`. Its containers are `forgejo`, `forgejo-db`, `cloudflared`, and `forgejo-runner-1` through `forgejo-runner-3`.

> **Stop condition:** Do not start the destination stack, change DNS/Tunnel configuration, run `terraform apply`, or delete source data until this runbook's destination verification and a separate restore rehearsal have succeeded.

## 1. Prerequisites

Perform the source-host steps through Tailscale SSH as an account that can run passwordless or interactive `sudo`. Perform IaC-state steps from the trusted workstation/control checkout that currently manages `../forgejo-selfhost`.

Install these tools before beginning:

- Source host: `docker`, `tar`, `sha256sum`, `age`, `rsync` or `scp`.
- Control machine: `age`, `sha256sum`, `tar`, `docker` or a compatible PostgreSQL client image, and OpenTofu for the source state.
- Destination machine: enough encrypted storage for the full archive plus a temporary decrypted extraction.

Set values before copying commands. Use a Tailscale hostname or `100.x.y.z` address for `BACKUP_DESTINATION`.

```bash
export SOURCE_HOST='forgejo-current'
export BACKUP_DESTINATION='forgejo-control'
export AGE_RECIPIENT='age1REPLACE_WITH_BACKUP_RECIPIENT_PUBLIC_KEY'
export SOURCE_REPO="$HOME/forgejo-selfhost"       # source IaC checkout on control machine
export BACKUP_ID="forgejo-migration-$(date -u +%Y%m%dT%H%M%SZ)"
export SOURCE_STAGE="/root/$BACKUP_ID"             # on the Docker source host
export CONTROL_STAGE="$HOME/$BACKUP_ID"            # on this control machine
```

Confirm the source stack and available space before interrupting it:

```bash
ssh "$SOURCE_HOST" 'sudo docker ps --format "table {{.Names}}\t{{.Status}}"'
ssh "$SOURCE_HOST" 'sudo du -sh /srv/forgejo/data /srv/forgejo-db/data /srv/forgejo-runners'
ssh "$SOURCE_HOST" 'sudo mkdir -p -m 0700 '"$SOURCE_STAGE"''
mkdir -p -m 0700 "$CONTROL_STAGE"
```

Record the output in the change record. Ensure `STAGE` is on storage that can hold the PostgreSQL dump and data archive.

## 2. Capture Cloudflare and source-IaC continuity evidence

The destination Terraform configuration must **reuse** the current Cloudflare Tunnel and DNS resources. Preserve their state; a new `terraform apply` without state reconciliation can create duplicates or alter the live hostname.

Run these commands from the trusted control checkout, not from the Forgejo host:

```bash
cd "$SOURCE_REPO/terraform"
umask 077
tofu state list | tee "$CONTROL_STAGE/cloudflare-state-addresses.txt"
tofu state pull > "$CONTROL_STAGE/cloudflare-source.tfstate"
cp .terraform.lock.hcl "$CONTROL_STAGE/cloudflare-source.lock.hcl"
cp terraform.tfvars "$CONTROL_STAGE/cloudflare-source.tfvars"
```

Also preserve the source Ansible configuration and encrypted vault. Never decrypt the vault for backup:

```bash
cd "$SOURCE_REPO"
tar -C ansible -czf "$CONTROL_STAGE/source-ansible-config.tgz" \
  group_vars/all/main.yml group_vars/all/vault.yml inventory.ini requirements.yml
```

The captured `cloudflare-state-addresses.txt` is the authoritative list of resources to import or reconcile later. At minimum, expect the source addresses:

```text
cloudflare_zero_trust_tunnel_cloudflared.forgejo
cloudflare_zero_trust_tunnel_cloudflared_config.forgejo
cloudflare_dns_record.forgejo
```

Do **not** copy a state file into the new Terraform directory and run apply blindly. During the later cutover, inspect the source state for provider-specific IDs, run the appropriate Terraform imports into the selected backend, then require `terraform plan` to show no unexpected create/replace/destroy actions before any apply.

## 3. Quiesce Forgejo writes

Announce maintenance first. Running Actions jobs will be interrupted; let trusted jobs finish or cancel them deliberately.

Stop public ingress and runners first, then Forgejo. Keep PostgreSQL running until its logical dump finishes.

```bash
ssh "$SOURCE_HOST" 'sudo docker stop cloudflared forgejo-runner-1 forgejo-runner-2 forgejo-runner-3 forgejo'
ssh "$SOURCE_HOST" 'sudo docker ps --format "table {{.Names}}\t{{.Status}}"'
```

Expected result: `forgejo`, `cloudflared`, and all `forgejo-runner-*` containers are absent from the running list; `forgejo-db` remains running.

If any named runner does not exist, record it and stop the existing runner names shown by `docker ps -a`; do not proceed while Forgejo itself is still accepting writes.

## 4. Create and verify the PostgreSQL logical backup

Create a custom-format dump while only PostgreSQL is running. It is the portable restore artifact; do not use a raw PostgreSQL data-directory copy as the migration restore source.

```bash
ssh "$SOURCE_HOST" "sudo sh -c 'set -e; docker exec forgejo-db pg_dump -U forgejo -Fc -d forgejo > \"$SOURCE_STAGE/postgres-forgejo.dump\"; chmod 600 \"$SOURCE_STAGE/postgres-forgejo.dump\"'"
ssh "$SOURCE_HOST" "sudo docker run --rm -v '$SOURCE_STAGE:/backup:ro' postgres:17-alpine pg_restore --list /backup/postgres-forgejo.dump > /dev/null"
```

Expected result: `pg_restore --list` exits zero. Record the dump byte count:

```bash
ssh "$SOURCE_HOST" "sudo stat --format='%n %s bytes' '$SOURCE_STAGE/postgres-forgejo.dump'"
```

## 5. Make cold filesystem archives

Now stop PostgreSQL so all source bind mounts are cold. Archive Forgejo data separately from runner tokens. The Forgejo data archive includes repositories, LFS objects, attachments, package/container-registry blobs, generated keys, and configuration under `/data`.

```bash
ssh "$SOURCE_HOST" 'sudo docker stop forgejo-db'
ssh "$SOURCE_HOST" "sudo tar --xattrs --acls --numeric-owner -C /srv/forgejo -czf '$SOURCE_STAGE/forgejo-data.tgz' data"
ssh "$SOURCE_HOST" "sudo tar --xattrs --acls --numeric-owner -C /srv/forgejo-runners -czf '$SOURCE_STAGE/runner-tokens-rollback-only.tgz' tokens"
ssh "$SOURCE_HOST" "sudo tar --xattrs --acls --numeric-owner -C /srv/forgejo-db -czf '$SOURCE_STAGE/postgres-data-cold-rollback-only.tgz' data"
```

The PostgreSQL data-directory archive and runner-token archive are **rollback evidence only**. Do not restore them directly into the new Podman stack. Restore the logical `postgres-forgejo.dump` into the destination database, and register the destination's two runners as new runner identities.

## 6. Build an encrypted transfer bundle

Copy the source-host artifacts to the staging directory on the control machine over Tailscale, then create one encrypted archive. Do not transfer plaintext artifacts to any third party.

```bash
rsync -a --protect-args -e ssh "$SOURCE_HOST:$SOURCE_STAGE/" "$CONTROL_STAGE/source-host/"

find "$CONTROL_STAGE" -type f -printf '%P\n' | sort > "$CONTROL_STAGE/MANIFEST.txt"
tar -C "$(dirname "$CONTROL_STAGE")" -czf "${CONTROL_STAGE}.tar.gz" "$(basename "$CONTROL_STAGE")"
age -r "$AGE_RECIPIENT" -o "${CONTROL_STAGE}.tar.gz.age" "${CONTROL_STAGE}.tar.gz"
sha256sum "${CONTROL_STAGE}.tar.gz.age" > "${CONTROL_STAGE}.tar.gz.age.sha256"
```

Transfer only the encrypted bundle and checksum to the backup destination over Tailscale:

```bash
rsync -av --protect-args -e ssh \
  "${CONTROL_STAGE}.tar.gz.age" "${CONTROL_STAGE}.tar.gz.age.sha256" \
  "$BACKUP_DESTINATION:~/forgejo-migration-backups/"
```

## 7. Verify the destination copy

On the backup destination, verify the encrypted bytes before considering the backup complete. Decrypt only to a protected temporary directory, using the private identity corresponding to `AGE_RECIPIENT`.

```bash
cd ~/forgejo-migration-backups
# Replace the value with the transferred filename, excluding `.sha256`.
export BUNDLE='forgejo-migration-YYYYMMDDTHHMMSSZ.tar.gz.age'
sha256sum --check "${BUNDLE}.sha256"
mkdir -m 0700 restore-readiness
age -d -i ~/.config/age/migration-backup.key \
  -o restore-readiness/forgejo-migration.tar.gz \
  "$BUNDLE"
tar -tzf restore-readiness/forgejo-migration.tar.gz | less
```

Extract only in protected storage and validate the database dump before cutover:

```bash
tar -C restore-readiness -xzf restore-readiness/forgejo-migration.tar.gz
DUMP="$(find restore-readiness -name postgres-forgejo.dump -print -quit)"
docker run --rm -v "$(dirname "$DUMP"):/backup:ro" postgres:17-alpine \
  pg_restore --list "/backup/$(basename "$DUMP")" > /dev/null
```

Expected result: checksum verification, archive listing, and `pg_restore --list` all exit zero. Retain the encrypted bundle in at least two secure locations before cutover.

## 8. Source rollback and cleanup

Do not delete the source data after backup verification. To abandon the migration before the source is intentionally decommissioned, restart the original Docker stack:

```bash
ssh "$SOURCE_HOST" 'sudo docker start forgejo-db forgejo forgejo-runner-1 forgejo-runner-2 forgejo-runner-3 cloudflared'
ssh "$SOURCE_HOST" 'sudo docker ps --format "table {{.Names}}\t{{.Status}}"'
```

After a successful destination restore rehearsal and agreed production cutover, securely remove plaintext staging data according to the host storage policy. `rm` does not reliably sanitize SSDs or copy-on-write storage; rely on encryption and storage-provider destruction procedures where secure erasure is required.

## Completion checklist

- [ ] Maintenance window and interrupted jobs recorded.
- [ ] PostgreSQL custom dump exists and passes `pg_restore --list`.
- [ ] Cold `forgejo-data.tgz` archive exists.
- [ ] Runner-token and cold PostgreSQL archives are marked rollback-only.
- [ ] Encrypted Ansible vault and source IaC configuration captured without decryption.
- [ ] OpenTofu state, lock file, tfvars, and Cloudflare resource addresses captured.
- [ ] Encrypted bundle checksum passes on the Tailscale backup destination.
- [ ] Destination archive listing and logical database dump verification pass.
- [ ] Existing Cloudflare resources are marked for later Terraform import/reconciliation; no new Tunnel/DNS resources have been applied.
- [ ] Source Docker stack remains available for rollback until cutover acceptance.
