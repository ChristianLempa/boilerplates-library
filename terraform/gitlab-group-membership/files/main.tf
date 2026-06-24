resource "gitlab_group_membership" "<< resource_name >>" {
  group_id    = << group_id >>
  user_id     = << user_id >>
  access_level = "<< access_level >>"
<%- if expires_at %>
  expires_at   = "<< expires_at >>"
<%- endif %>

  skip_subresources_on_destroy = << skip_subresources_on_destroy | lower >>
  unassign_issuables_on_destroy = << unassign_issuables_on_destroy | lower >>
}

