# ==================================================
# 29_dr_monitoring.tf - DR 모니터링 및 알림 시스템
# ==================================================

# ==========================================
# DR 전용 Log Analytics Workspace
# ==========================================

resource "azurerm_log_analytics_workspace" "dr_law" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-law-${random_string.suffix.result}"
  location            = var.dr_location
  resource_group_name = azurerm_resource_group.dr[0].name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.combined_dr_tags
}

# ==========================================
# DR 알림 Action Group
# ==========================================

resource "azurerm_monitor_action_group" "dr_alerts" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-alerts-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "DRAlert"

  email_receiver {
    name          = "dr-admin"
    email_address = var.dr_alert_email
  }

  sms_receiver {
    name         = "dr-admin-sms"
    country_code = "82"
    phone_number = var.dr_alert_phone
  }

  # Teams 웹훅 (선택사항)
  webhook_receiver {
    name        = "teams-webhook"
    service_uri = "https://outlook.office.com/webhook/your-teams-webhook-url"
  }

  tags = local.combined_dr_tags
}

# ==========================================
# DR 시스템 상태 모니터링
# ==========================================

# DR VM 상태 모니터링
resource "azurerm_monitor_metric_alert" "dr_vm_availability" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-vm-availability"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine.dr_vm[0].id]
  description         = "DR VM 가용성 모니터링"
  severity            = 1  # Critical

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "VmAvailabilityMetric"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.dr_alerts[0].id
  }

  tags = local.combined_dr_tags
}

# 메인 서버 다운 감지 알림
resource "azurerm_monitor_metric_alert" "main_server_down" {
  count               = var.dr_enabled ? 1 : 0
  name                = "main-server-down-alert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_linux_virtual_machine.vm.id]
  description         = "메인 서버 다운 감지 시 DR 활성화 알림"
  severity            = 0  # Critical

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "VmAvailabilityMetric"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  # 연속 3번 실패 시 알림
  frequency   = "PT1M"
  window_size = "PT5M"

  action {
    action_group_id = azurerm_monitor_action_group.dr_alerts[0].id
    webhook_properties = {
      trigger_dr_failover = "true"
      main_server_ip     = azurerm_public_ip.vm_pip.ip_address
      dr_server_ip       = azurerm_public_ip.dr_vm_pip[0].ip_address
    }
  }

  tags = local.combined_dr_tags
}

# ==========================================
# DR 스토리지 동기화 모니터링
# ==========================================

# DR 스토리지 복제 지연 모니터링
resource "azurerm_monitor_metric_alert" "dr_replication_lag" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-replication-lag"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_storage_account.dr_ftp_data[0].id]
  description         = "DR 스토리지 복제 지연 모니터링"
  severity            = 2  # Warning

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "Transactions"
    aggregation      = "Total"
    operator         = "LessThan"
    threshold        = 1
  }

  # 15분 동안 복제 활동이 없으면 알림
  frequency   = "PT5M"
  window_size = "PT15M"

  action {
    action_group_id = azurerm_monitor_action_group.dr_alerts[0].id
  }

  tags = local.combined_dr_tags
}

# ==========================================
# Traffic Manager 헬스 모니터링
# ==========================================

resource "azurerm_monitor_activity_log_alert" "traffic_manager_failover" {
  count               = var.dr_enabled ? 1 : 0
  name                = "traffic-manager-failover"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "global"
  scopes              = [azurerm_resource_group.rg.id]
  description         = "Traffic Manager 페일오버 이벤트 감지"

  criteria {
    resource_id    = azurerm_traffic_manager_profile.ftp_service[0].id
    operation_name = "Microsoft.Network/trafficManagerProfiles/write"
    category       = "Administrative"
  }

  action {
    action_group_id = azurerm_monitor_action_group.dr_alerts[0].id
    webhook_properties = {
      alert_type = "traffic_manager_failover"
      timestamp  = "[alertContext.eventTimestamp]"
    }
  }

  tags = local.combined_dr_tags
}

# ==========================================
# DR 대시보드 (Azure Portal Dashboard - 수동으로 생성 권장)
# ==========================================

# Azure Dashboard는 포털에서 수동으로 생성하는 것을 권장
# DR 대시보드는 Azure Portal에서 다음과 같이 생성:
# 1. Azure Portal > Dashboard 
# 2. + New dashboard
# 3. 메인 VM, DR VM 메트릭 타일 추가
# 4. Traffic Manager 상태 타일 추가

# DR 대시보드는 Azure Portal에서 수동으로 생성 권장

# ==========================================
# DR 커스텀 로그 쿼리 (KQL)
# ==========================================

# DR 시스템 헬스 체크 쿼리
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "dr_health_check_failure" {
  count                    = var.dr_enabled ? 1 : 0
  name                     = "dr-health-check-failure"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  evaluation_frequency     = "PT5M"
  window_duration          = "PT10M"
  scopes                   = [azurerm_log_analytics_workspace.dr_law[0].id]
  severity                 = 1
  auto_mitigation_enabled  = false

  criteria {
    query = <<-QUERY
      union withsource=tt *
      | where TimeGenerated > ago(10m)
      | where tt has "Syslog" or tt has "CustomLog"
      | where Message contains "DR_HEALTH_CHECK_FAILED" or SyslogMessage contains "DR_HEALTH_CHECK_FAILED"
      | summarize count() by bin(TimeGenerated, 5m)
      | where count_ > 0
    QUERY
    
    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "GreaterThan"
  }

  action {
    action_groups = [azurerm_monitor_action_group.dr_alerts[0].id]
    custom_properties = {
      alert_type = "dr_health_check_failure"
      action_required = "investigate_dr_system"
    }
  }

  tags = local.combined_dr_tags
}

# ==========================================
# DR 성능 메트릭 수집
# ==========================================

# DR 데이터 동기화 성능 모니터링
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "dr_sync_performance" {
  count                    = var.dr_enabled ? 1 : 0
  name                     = "dr-sync-performance"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  evaluation_frequency     = "PT15M"
  window_duration          = "PT30M"
  scopes                   = [azurerm_log_analytics_workspace.dr_law[0].id]
  severity                 = 2

  criteria {
    query = <<-QUERY
      StorageBlobLogs
      | where TimeGenerated > ago(30m)
      | where OperationName == "PutBlob" or OperationName == "CopyBlob"
      | where Uri contains "dr-ftp-data"
      | summarize 
          SyncCount = count(),
          AvgDuration = avg(DurationMs),
          MaxDuration = max(DurationMs)
          by bin(TimeGenerated, 15m)
      | where SyncCount < 1  // 동기화 활동이 없는 경우
    QUERY
    
    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "GreaterThanOrEqual"
  }

  action {
    action_groups = [azurerm_monitor_action_group.dr_alerts[0].id]
  }

  tags = local.combined_dr_tags
}

# ==========================================
# DR 비용 모니터링
# ==========================================

# DR 리소스 비용 추적
# 이미 존재하는 리소스로 인해 주석처리
/*
resource "azurerm_consumption_budget_resource_group" "dr_budget" {
  count           = var.dr_enabled ? 1 : 0
  name            = "dr-monthly-budget"
  resource_group_id = azurerm_resource_group.dr[0].id

  amount     = 100  # 월 $100 예산
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", timestamp())
    end_date   = "2026-12-31T00:00:00Z"
  }

  # 80% 도달 시 알림
  notification {
    enabled   = true
    threshold = 80
    operator  = "GreaterThan"

    contact_emails = [
      var.dr_alert_email,
      var.admin_email
    ]
  }
}
*/

# ==========================================
# DR 테스트 결과 모니터링
# ==========================================

# 월간 DR 테스트 결과 추적
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "dr_test_results" {
  count                    = var.dr_enabled ? 1 : 0
  name                     = "dr-test-results"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  evaluation_frequency     = "P1D"  # 일일 평가
  window_duration          = "P1D"  # 1일 윈도우
  scopes                   = [azurerm_log_analytics_workspace.dr_law[0].id]
  severity                 = 2

  criteria {
    query = <<-QUERY
      union withsource=tt *
      | where TimeGenerated > ago(7d)
      | where tt has "CustomLog" or tt has "Syslog"
      | where Message contains "DR_TEST_" or SyslogMessage contains "DR_TEST_"
      | extend TestResult = case(
          Message contains "DR_TEST_PASSED" or SyslogMessage contains "DR_TEST_PASSED", "PASSED",
          Message contains "DR_TEST_FAILED" or SyslogMessage contains "DR_TEST_FAILED", "FAILED",
          "UNKNOWN"
      )
      | where TestResult == "FAILED"
      | summarize FailedTests = count() by bin(TimeGenerated, 1d)
      | where FailedTests > 0
    QUERY
    
    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "GreaterThanOrEqual"
  }

  action {
    action_groups = [azurerm_monitor_action_group.dr_alerts[0].id]
    custom_properties = {
      alert_type = "dr_test_failure"
      action_required = "review_dr_test_results"
    }
  }

  tags = local.combined_dr_tags
}