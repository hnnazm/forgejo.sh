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

## Validation

```bash
cd terraform
terraform fmt -check -diff
terraform init -backend=false
terraform validate
terraform test
```
