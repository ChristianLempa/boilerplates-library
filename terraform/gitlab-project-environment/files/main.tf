resource "gitlab_project_environment" "<< resource_name >>" {
  project             = "<< project >>"
  name                = "<< name >>"
<%- if description %>
  description         = "<< description >>"
<%- endif %>
<%- if external_url %>
  external_url        = "<< external_url >>"
<%- endif %>
  tier                = "<< tier >>"
<%- if kubernetes_namespace %>
  kubernetes_namespace = "<< kubernetes_namespace >>"
<%- endif %>
  stop_before_destroy = << stop_before_destroy | lower >>
}

