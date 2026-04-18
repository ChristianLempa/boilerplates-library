resource "cloudflare_zero_trust_access_application" "<< resource_name >>" {
  zone_id          = data.cloudflare_zone.main.zone_id
  name             = "<< app_name >>"
  domain           = "<< domain >>"
  type             = "self_hosted"
  session_duration = "<< session_duration >>"
  policies         = [
<%- if service_token_enabled %>
    {
      id = cloudflare_zero_trust_access_policy.<< resource_name >>_service_token.id
    }
<%- if ip_policy_enabled %>
    ,
<%- endif %>
<%- endif %>
<%- if ip_policy_enabled %>
    {
      id = cloudflare_zero_trust_access_policy.<< resource_name >>_ip.id
    }
<%- endif %>
  ]
<%- if depends_on_enabled and dependencies %>
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
