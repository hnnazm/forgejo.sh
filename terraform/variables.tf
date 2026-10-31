variable "cloudflare_api_token" {
  description = "Cloudflare API token with account Tunnel edit and zone DNS edit permissions."
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID that owns the tunnel."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID that owns forgejo_hostname."
  type        = string
}

variable "tunnel_name" {
  description = "Name shown for the tunnel in Cloudflare Zero Trust."
  type        = string
  default     = "forgejo"
}

variable "forgejo_hostname" {
  description = "Public Forgejo FQDN; must match Ansible's forgejo_external_hostname."
  type        = string
}

variable "forgejo_service_url" {
  description = "Cloudflared origin on the host loopback listener; it is never publicly exposed."
  type        = string
  default     = "http://127.0.0.1:3000"
}
