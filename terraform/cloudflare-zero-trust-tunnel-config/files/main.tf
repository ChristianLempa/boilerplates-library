resource "cloudflare_zero_trust_tunnel_cloudflared_config" "<< resource_name >>" {
  account_id = "<< account_id_value >>"
  tunnel_id  = "<< tunnel_id >>"

  config = {
    ingress = [
      {
        hostname = "<< ingress_hostname >>"
        service  = "<< ingress_service >>"
      },
      {
        service = "<< fallback_service >>"
      }
    ]
  }

}
