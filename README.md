# Self-hosted Forgejo on Podman

Infrastructure as code for a dedicated Debian 12 Forgejo host running rootful Podman system Quadlets, PostgreSQL, Cloudflare Tunnel, and exactly two trusted DinD-capable Forgejo Actions runners.

> The runners are privileged and receive a Docker-compatible Podman socket. A workflow can therefore control the dedicated CI host. Do not run untrusted repositories or workflows on it, and do not co-locate unrelated self-hosted services there.

## Provisioning layers

1. `terraform/` manages Cloudflare Tunnel, DNS, and public ingress.
2. `ansible/` (added in the next phase) provisions the Debian host and services.

Terraform manages no host resources. Cloudflared will forward the public hostname to the internal Podman-network origin `http://forgejo:3000`.

## Cloudflare Tunnel

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Fill in the account ID, zone ID, hostname, and scoped API token.
terraform init
terraform apply
terraform output -raw tunnel_token
```

Store the resulting token in the encrypted Ansible vault when the host layer is configured. Terraform state contains tunnel credentials; use an encrypted, access-controlled remote backend before applying outside a disposable environment.

## Deploy on the dedicated Debian 12 host

Install Ansible on the host, clone this repository, then configure the encrypted vault:

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
# Set the admin password, PostgreSQL password, and `terraform output -raw tunnel_token`.
ansible-vault encrypt group_vars/all/vault.yml
ansible-playbook -i inventory.ini site.yml --ask-vault-pass
sudo ../scripts/verify-dind.sh
```

The default inventory intentionally targets `localhost`. After validating the dedicated VM, replace it with your Tailscale lab host, for example:

```ini
[forgejo_host]
forgejo-lab ansible_host=100.x.y.z ansible_user=<your-admin-user>
```

Then invoke `ansible-playbook -i inventory.ini site.yml --ask-vault-pass`; the role logic does not contain host addresses or Tailscale policy. Configure Tailscale, SSH credentials, and ACLs outside this repository.

## Verify

```bash
sudo podman ps
# Expected: forgejo-db, forgejo, cloudflared, forgejo-runner-1, forgejo-runner-2
```

Open `https://<forgejo_hostname>/api/healthz`, then use **Site Administration → Actions → Runners** to confirm exactly two online `docker` runners. Run `examples/demo-dind.yml` as a Forgejo workflow; its `docker info` and image build must succeed.

## Validation

```bash
cd terraform
terraform fmt -check -diff
terraform init -backend=false
terraform validate
terraform test

cd ../ansible
ansible-lint .
ansible-playbook --syntax-check -i inventory.ini site.yml
```
