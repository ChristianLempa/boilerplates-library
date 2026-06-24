resource "gitlab_project_hook" "<< resource_name >>" {
  project                 = "<< project >>"
  url                     = "<< url >>"
<%- if name %>
  name                    = "<< name >>"
<%- endif %>
<%- if description %>
  description             = "<< description >>"
<%- endif %>
<%- if token %>
  token                   = "<< token >>"
<%- endif %>
  enable_ssl_verification = << enable_ssl_verification | lower >>
<%- if push_events_branch_filter %>
  push_events_branch_filter = "<< push_events_branch_filter >>"
<%- endif %>

  push_events           = << push_events | lower >>
  merge_requests_events = << merge_requests_events | lower >>
  pipeline_events       = << pipeline_events | lower >>
  job_events            = << job_events | lower >>
  tag_push_events       = << tag_push_events | lower >>
  releases_events       = << releases_events | lower >>
  deployment_events     = << deployment_events | lower >>
  issues_events         = << issues_events | lower >>
  note_events           = << note_events | lower >>
  wiki_page_events      = << wiki_page_events | lower >>
}

