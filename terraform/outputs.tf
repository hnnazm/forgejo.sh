output "tunnel_token" {
  description = "Connector token for cloudflared; store it in the Ansible vault."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.forgejo.token
  sensitive   = true
}

output "tunnel_id" {
  description = "Cloudflare tunnel UUID."
  value       = cloudflare_zero_trust_tunnel_cloudflared.forgejo.id
}

output "tunnel_cname" {
  description = "CNAME target for the Forgejo hostname."
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.forgejo.id}.cfargotunnel.com"
}
