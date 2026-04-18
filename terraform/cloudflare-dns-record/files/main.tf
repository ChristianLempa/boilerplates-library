data "cloudflare_zone" "zone" {
  zone_id = "<< cloudflare_zone_id >>"
}

resource "cloudflare_dns_record" "<< resource_name >>" {
  zone_id = data.cloudflare_zone.zone.zone_id
  name    = "<< name >>"
  type    = "<< record_type >>"
<%- if record_type == "A" %>
  content = "<< ipv4_address >>"
  proxied = << proxied | lower >>
<%- endif %>
<%- if record_type == "AAAA" %>
  content = "<< ipv6_address >>"
  proxied = << proxied | lower >>
<%- endif %>
<%- if record_type == "CNAME" %>
  content = "<< target_hostname >>"
  proxied = << proxied | lower >>
<%- endif %>
<%- if record_type == "TXT" %>
  content = "<< text_value >>"
<%- endif %>
<%- if record_type == "MX" %>
  content  = "<< mail_server >>"
  priority = << priority >>
<%- endif %>
  ttl     = << ttl >>
}
