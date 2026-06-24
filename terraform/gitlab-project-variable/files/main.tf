resource "gitlab_project_variable" "<< resource_name >>" {
  project           = "<< project >>"
  key               = "<< key >>"
  value             = "<< value >>"
<%- if description %>
  description       = "<< description >>"
<%- endif %>
  environment_scope = "<< environment_scope >>"
  variable_type     = "<< variable_type >>"
  protected         = << protected | lower >>
  masked            = << masked | lower >>
  hidden            = << hidden | lower >>
  raw               = << raw | lower >>
}

