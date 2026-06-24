resource "gitlab_project_milestone" "<< resource_name >>" {
  project = "<< project >>"
  title   = "<< title >>"
<%- if description %>
  description = "<< description >>"
<%- endif %>
<%- if start_date %>
  start_date = "<< start_date >>"
<%- endif %>
<%- if due_date %>
  due_date = "<< due_date >>"
<%- endif %>
  state = "<< state >>"
}

