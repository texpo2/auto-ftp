# 09_NetWatcherFlowLog.tf

data "azurerm_network_watcher" "existing" {
  name                = "NetworkWatcher_koreacentral"
  resource_group_name = "NetworkWatcherRG"
}

# NSG Flow Log 설정
resource "azurerm_network_watcher_flow_log" "flowlog" {
  name                 = "team2-flow-log"
  network_watcher_name = data.azurerm_network_watcher.existing.name
  resource_group_name  = data.azurerm_network_watcher.existing.resource_group_name
  target_resource_id   = azurerm_network_security_group.nsg.id
  storage_account_id   = azurerm_storage_account.nsg_logs.id # 이미 올바름
  enabled              = true

  retention_policy {
    enabled = true
    days    = 30
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.team2law.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.team2law.location
    workspace_resource_id = azurerm_log_analytics_workspace.team2law.id
    interval_in_minutes   = 10
  }

  tags = {
    Environment = "Development"
    Purpose     = "Security-Monitoring"
    Team        = "Team2"
  }

  depends_on = [
    azurerm_network_security_group.nsg,
    azurerm_storage_account.nsg_logs # Storage Account 의존성 추가
  ]
}
