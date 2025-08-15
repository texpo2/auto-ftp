# Sentinel 온보딩
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  workspace_id                 = azurerm_log_analytics_workspace.team2law.id
  customer_managed_key_enabled = false
  
  depends_on = [
    azurerm_log_analytics_workspace.team2law,
    azurerm_linux_virtual_machine.vm
  ]
}

/*
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "main" {
  workspace_id                 = azurerm_log_analytics_workspace.soc_workspace.id
  customer_managed_key_enabled = false
}
*/

# 경고 규칙은 온보딩 후에
# Commented out due to import conflict - resource already exists
# resource "azurerm_sentinel_alert_rule_scheduled" "failed_login" {
#   name                       = "Multiple-Failed-Logins-${random_string.suffix.result}"
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.team2law.id
#   display_name               = "Multiple Failed Logins (Team2-${random_string.suffix.result})"
#   severity                   = "High"
#   query                      = <<KQL
# Syslog
# | where TimeGenerated > ago(10m)
# | where Facility == "authpriv" and SeverityLevel == "err"
# | where SyslogMessage contains "authentication failure" or SyslogMessage contains "Failed password"
# | summarize Count=count() by Computer, bin(TimeGenerated, 5m)
# | where Count >= 5
# KQL
#   query_frequency            = "PT5M"
#   query_period               = "PT15M"
#   trigger_operator           = "GreaterThan"
#   trigger_threshold          = 0
#   enabled                    = true

#   depends_on = [
#     azurerm_sentinel_log_analytics_workspace_onboarding.this,
#     azurerm_linux_virtual_machine.vm
#   ]
# }
