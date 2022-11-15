################################################################################
# Accelerator
################################################################################

resource "aws_globalaccelerator_accelerator" "this" {
  count = var.create ? 1 : 0

  name            = var.name
  ip_address_type = var.ip_address_type
  enabled         = var.enabled

  dynamic "attributes" {
    for_each = var.flow_logs_enabled ? [1] : []
    content {
      flow_logs_enabled   = var.flow_logs_enabled
      flow_logs_s3_bucket = var.flow_logs_s3_bucket
      flow_logs_s3_prefix = var.flow_logs_s3_prefix
    }
  }

  tags = var.tags
}

################################################################################
# Listener(s)
################################################################################

locals {
  create_listeners = var.create && var.create_listeners
}

resource "aws_globalaccelerator_listener" "this" {
  for_each = { for k, v in var.listeners : k => v if local.create_listeners }

  accelerator_arn = aws_globalaccelerator_accelerator.this[0].id
  client_affinity = try(each.value.client_affinity, null)
  protocol        = try(each.value.protocol, null)

  dynamic "port_range" {
    for_each = try(each.value.port_ranges, [])
    content {
      from_port = try(port_range.value.from_port, null)
      to_port   = try(port_range.value.to_port, null)
    }
  }

  timeouts {
    create = try(var.listeners_timeouts.create, null)
    update = try(var.listeners_timeouts.update, null)
    delete = try(var.listeners_timeouts.delete, null)
  }
}

################################################################################
# Endpoing Group(s)
################################################################################

resource "aws_globalaccelerator_endpoint_group" "this" {
  for_each = { for k, v in var.listeners : k => { for k2, v2 in try(v.endpoint_groups, {}) : k2 => v2 } if local.create_listeners }

  listener_arn = aws_globalaccelerator_listener.this[each.key].id

  endpoint_group_region         = try(each.value.endpoint_group_region, null)
  health_check_interval_seconds = try(each.value.health_check_interval_seconds, null)
  health_check_path             = try(each.value.health_check_path, null)
  health_check_port             = try(each.value.health_check_port, null)
  health_check_protocol         = try(each.value.health_check_protocol, null)
  threshold_count               = try(each.value.threshold_count, null)
  traffic_dial_percentage       = try(each.value.traffic_dial_percentage, null)

  dynamic "endpoint_configuration" {
    for_each = try(each.value.endpoint_configuration, [])
    content {
      client_ip_preservation_enabled = try(endpoint_configuration.value.client_ip_preservation_enabled, null)
      endpoint_id                    = endpoint_configuration.value.endpoint_id
      weight                         = try(endpoint_configuration.value.weight, null)
    }
  }

  dynamic "port_override" {
    for_each = try(each.value.endpoint_group.port_override, [])
    content {
      endpoint_port = port_override.value.endpoint_port
      listener_port = port_override.value.listener_port
    }
  }

  timeouts {
    create = try(var.endpoint_groups_timeouts.create, null)
    update = try(var.endpoint_groups_timeouts.update, null)
    delete = try(var.endpoint_groups_timeouts.delete, null)
  }
}
