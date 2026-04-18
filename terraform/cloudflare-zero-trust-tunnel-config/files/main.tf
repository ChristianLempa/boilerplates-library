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
<%- if depends_on_enabled %>
  depends_on = [<< dependencies >>]
<%- endif %>
<%- if lifecycle_enabled %>

  lifecycle {
<%- if prevent_destroy %>
    prevent_destroy = true
<%- endif %>
<%- if create_before_destroy %>
    create_before_destroy = true
<%- endif %>
<%- if ignore_changes %>
    ignore_changes = [<< ignore_changes >>]
<%- endif %>
  }
<%- endif %>
}
