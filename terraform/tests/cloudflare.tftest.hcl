mock_provider "cloudflare" {
  mock_data "cloudflare_zero_trust_tunnel_cloudflared_token" {
    defaults = {
      token = "test-connector-token"
    }
  }
}

mock_provider "random" {
  mock_resource "random_bytes" {
    defaults = {
      base64 = "test-tunnel-secret"
    }
  }
}

variables {
  cloudflare_api_token  = "test-token"
  cloudflare_account_id = "account-id"
  cloudflare_zone_id    = "zone-id"
  forgejo_hostname      = "forgejo.example.test"
  forgejo_service_url   = "http://127.0.0.1:3000"
}

run "routes_the_forgejo_hostname_to_the_internal_origin" {
  command = apply

  assert {
    condition     = cloudflare_zero_trust_tunnel_cloudflared_config.forgejo.config.ingress[0].hostname == "forgejo.example.test"
    error_message = "The tunnel must route the public Forgejo hostname."
  }

  assert {
    condition     = cloudflare_zero_trust_tunnel_cloudflared_config.forgejo.config.ingress[0].service == "http://127.0.0.1:3000"
    error_message = "The tunnel must use Forgejo's loopback-only host listener."
  }

  assert {
    condition     = cloudflare_dns_record.forgejo.proxied && cloudflare_dns_record.forgejo.ttl == 1
    error_message = "The Forgejo CNAME must be proxied with automatic TTL."
  }

  assert {
    condition     = output.tunnel_token != null
    error_message = "The cloudflared connector token must be exposed for Ansible."
  }
}
