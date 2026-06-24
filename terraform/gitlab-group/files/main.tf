resource "gitlab_group" "<< resource_name >>" {
  name        = "<< group_name >>"
  path        = "<< path >>"
<%- if parent_id %>
  parent_id   = << parent_id >>
<%- endif %>
<%- if description %>
  description = "<< description >>"
<%- endif %>

  visibility_level                   = "<< visibility_level >>"
  project_creation_level             = "<< project_creation_level >>"
  subgroup_creation_level            = "<< subgroup_creation_level >>"
  request_access_enabled             = << request_access_enabled | lower >>
  lfs_enabled                        = << lfs_enabled | lower >>
  require_two_factor_authentication  = << require_two_factor_authentication | lower >>
  two_factor_grace_period            = << two_factor_grace_period >>
  permanently_remove_on_delete       = << permanently_remove_on_delete | lower >>
}

