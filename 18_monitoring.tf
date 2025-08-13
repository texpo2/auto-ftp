# ==================================================
# 13_monitoring_alerts.tf - 모니터링 및 알림
# ==================================================

# Action Group (알림 대상)
resource "azurerm_monitor_action_group" "monitoring_alerts" {
  name                = "team2-monitoring-alerts-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "MonAlert"

  email_receiver {
    name          = "admin"
    email_address = "323whadir@naver.com"  
  }

  depends_on = [azurerm_resource_group.rg]
}

# CPU 사용률 모니터링
resource "azurerm_monitor_metric_alert" "high_cpu" {
  name                = "team2-ftp-high-cpu"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine.vm.id]
  description         = "FTP Server High CPU Usage"
  
  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.monitoring_alerts.id
  }

  depends_on = [
    azurerm_linux_virtual_machine.vm,
    azurerm_monitor_action_group.monitoring_alerts
  ]
}

# 실패한 로그인 시도 모니터링 (Log Analytics 기반)
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "failed_login_alert" {
  name                = "team2-failed-login-alert"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
  evaluation_frequency = "PT5M"
  window_duration      = "PT10M"
  scopes               = [azurerm_log_analytics_workspace.team2law.id]
  severity             = 2
  
  criteria {
    query = <<-QUERY
      union withsource=tt *
      | where TimeGenerated > ago(10m)
      | where tt has "Syslog"
      | where SyslogMessage contains "FAIL LOGIN"
      | summarize count() by bin(TimeGenerated, 5m)
      | where count_ > 5
    QUERY
    
    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "GreaterThan"
  }

  action {
    action_groups = [azurerm_monitor_action_group.monitoring_alerts.id]
  }

  depends_on = [
    azurerm_log_analytics_workspace.team2law,
    azurerm_monitor_action_group.monitoring_alerts
  ]
}