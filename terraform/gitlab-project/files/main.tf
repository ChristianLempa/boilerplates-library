resource "gitlab_project" "<< resource_name >>" {
  name = "<< project_name >>"
<%- if path %>
  path = "<< path >>"
<%- endif %>
<%- if namespace_id %>
  namespace_id = << namespace_id >>
<%- endif %>
<%- if description %>
  description = "<< description >>"
<%- endif %>
  visibility_level       = "<< visibility_level >>"
  default_branch         = "<< default_branch >>"
  initialize_with_readme = << initialize_with_readme | lower >>
  lfs_enabled            = << lfs_enabled | lower >>
  request_access_enabled = << request_access_enabled | lower >>
  shared_runners_enabled = << shared_runners_enabled | lower >>
<%- if topics %>
  topics = [
    for topic in split(",", "<< topics >>") : trimspace(topic)
    if trimspace(topic) != ""
  ]
<%- endif %>
}

