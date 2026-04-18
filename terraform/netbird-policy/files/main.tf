locals {
  policy_source_group_names = [
    for name in split(",", "<< source_group_names >>") : trimspace(name)
    if trimspace(name) != ""
  ]
  policy_destination_group_names = [
    for name in split(",", "<< destination_group_names >>") : trimspace(name)
    if trimspace(name) != ""
  ]
<%- if source_posture_check_names %>
  policy_source_posture_check_names = [
    for name in split(",", "<< source_posture_check_names >>") : trimspace(name)
    if trimspace(name) != ""
  ]
<%- endif %>
<%- if authorized_group_entries %>
  policy_authorized_group_entries = [
    for entry in split(";", "<< authorized_group_entries >>") : trimspace(entry)
    if trimspace(entry) != ""
  ]
  policy_authorized_group_map = {
    for entry in local.policy_authorized_group_entries :
    trimspace(split("|", entry)[0]) => [
      for username in split(",", split("|", entry)[1]) : trimspace(username)
      if trimspace(username) != ""
    ]
  }
<%- endif %>
  policy_group_names = distinct(concat(
    local.policy_source_group_names,
    local.policy_destination_group_names,
<%- if authorized_group_entries %>
    keys(local.policy_authorized_group_map),
<%- endif %>
    []
  ))
}

data "netbird_group" "policy_groups" {
  for_each = toset(local.policy_group_names)
  name     = each.value
}

<%- if source_posture_check_names %>
data "netbird_posture_check" "source_posture_checks" {
  for_each = toset(local.policy_source_posture_check_names)
  name     = each.value
}

<%- endif %>
resource "netbird_policy" "policy" {
  name = "<< policy_name >>"
<%- if policy_description %>
  description = "<< policy_description >>"
<%- endif %>
  enabled = << policy_enabled | lower >>
<%- if source_posture_check_names %>
  source_posture_checks = [for name in local.policy_source_posture_check_names : data.netbird_posture_check.source_posture_checks[name].id]
<%- endif %>

  rule {
    name          = "<< rule_name >>"
    action        = "<< rule_action >>"
    bidirectional = << rule_bidirectional | lower >>
    enabled       = << rule_enabled | lower >>
    protocol      = "<< rule_protocol >>"
    sources       = [for name in local.policy_source_group_names : data.netbird_group.policy_groups[name].id]
    destinations  = [for name in local.policy_destination_group_names : data.netbird_group.policy_groups[name].id]
<%- if rule_description %>
    description   = "<< rule_description >>"
<%- endif %>
<%- if ports %>
    ports         = [<< ports >>]
<%- endif %>
<%- if rule_protocol == "netbird-ssh" %>
<%- if authorized_group_entries %>
    authorized_groups = {
      for group_name, users in local.policy_authorized_group_map :
      data.netbird_group.policy_groups[group_name].id => users
    }
<%- endif %>
<%- endif %>
  }
}
