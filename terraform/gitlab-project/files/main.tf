<%- if namespace_group_full_path and not namespace_id %>
data "gitlab_group" "project_namespace" {
  full_path = "<< namespace_group_full_path >>"
}

<%- endif %>
<%- if namespace_user_username and not namespace_id and not namespace_group_full_path %>
data "gitlab_user" "project_namespace" {
  username = "<< namespace_user_username >>"
}

<%- endif %>
resource "gitlab_project" "<< resource_name >>" {
  name = "<< project_name >>"
<%- if path %>
  path = "<< path >>"
<%- endif %>
<%- if namespace_id %>
  namespace_id = << namespace_id >>
<%- elif namespace_group_full_path %>
  namespace_id = data.gitlab_group.project_namespace.id
<%- elif namespace_user_username %>
  namespace_id = data.gitlab_user.project_namespace.namespace_id
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

