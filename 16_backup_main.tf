# ==========================================
# Recovery Services Vault 생성
# ==========================================
resource "azurerm_recovery_services_vault" "main" {
  name                = "rsv-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  
  # 소프트 삭제 설정 (실수 삭제 방지)
  soft_delete_enabled = true
  
  tags = var.common_tags
}

# ==========================================
# VM 백업 정책 설정
# ==========================================
resource "azurerm_backup_policy_vm" "daily_backup" {
  name                = "DailyVMBackup"
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name

  # 백업 스케줄 설정
  backup {
    frequency = "Daily"
    time      = "23:00"  # 오후 11시
  }

  # 보존 정책 설정
  retention_daily {
    count = 30  # 30일 보관
  }

  retention_weekly {
    count    = 12  # 12주 보관
    weekdays = ["Sunday"]
  }

  retention_monthly {
    count    = 12  # 12개월 보관
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }

  retention_yearly {
    count    = 5   # 5년 보관
    weekdays = ["Sunday"]
    weeks    = ["First"]
    months   = ["January"]
  }
}

# VM 생성 후 대기 추가
resource "time_sleep" "wait_for_vm" {
  depends_on = [azurerm_linux_virtual_machine.vm]  # 또는 azurerm_windows_virtual_machine
  create_duration = "120s"  # VM은 더 오래 걸림
}

# SQL Database 백업은 기본적으로 자동 제공되므로 별도 설정 제거
# Azure SQL Database는 자동으로 Point-in-time recovery 제공

# SQL Database는 기본적으로 자동 백업 제공 (Point-in-time recovery)
# 추가 설정이 필요하면 Azure Portal에서 구성

# ==========================================
# Blob Storage 백업 설정
# ==========================================
# Blob 백업용 별도 스토리지 계정
resource "azurerm_storage_account" "backup" {
  name                     = "backup${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"  # Geo-redundant storage

  # 버전 관리 활성화
  blob_properties {
    versioning_enabled = true
    
    # 삭제된 블롭 복구 기간
    delete_retention_policy {
      days = 30
    }
    
    # 컨테이너 삭제 복구 기간
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = var.common_tags
}

# Data Protection Backup Vault도 당분간 제거
# VM 백업은 Recovery Services Vault로 충분함

# ==========================================
# 교차 지역 복제 설정 (DR)
# ==========================================
# ==========================================
# 기존 DR 설정은 새로운 완전한 DR 구조로 대체됨
# 새로운 DR 구성은 다음 파일들에서 관리됨:
# - 24_dr_variables.tf: DR 변수
# - 25_dr_network.tf: DR 네트워크
# - 26_dr_vm.tf: DR VM
# - 27_dr_storage.tf: DR 스토리지
# - 28_dr_automation.tf: DR 자동화
# - 29_dr_monitoring.tf: DR 모니터링
# ==========================================

# Site Recovery 복제 정책
resource "azurerm_site_recovery_replication_policy" "policy" {
  name                                                 = "replication-policy"
  resource_group_name                                  = azurerm_resource_group.rg.name
  recovery_vault_name                                  = azurerm_recovery_services_vault.main.name
  recovery_point_retention_in_minutes                 = 24 * 60  # 24시간
  application_consistent_snapshot_frequency_in_minutes = 4 * 60   # 4시간
}

# ==========================================
# 백업 모니터링 및 알림
# ==========================================
# 백업 실패 알림용 Action Group
resource "azurerm_monitor_action_group" "backup_alerts" {
  name                = "backup-alerts-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "backupalert"

  email_receiver {
    name          = "admin"
    email_address = var.admin_email
  }

  sms_receiver {
    name         = "admin-sms"
    country_code = "82"  # 한국
    phone_number = var.admin_phone
  }
}

# ==========================================
# 자동화된 복구 테스트
# ==========================================
# Logic App으로 주기적 복구 테스트 실행
resource "azurerm_logic_app_workflow" "recovery_test" {
  name                = "recovery-test-automation"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
  tags = var.common_tags
}

# 복구 테스트 스케줄 (월 1회)
resource "azurerm_logic_app_trigger_recurrence" "monthly_test" {
  name         = "monthly-recovery-test"
  logic_app_id = azurerm_logic_app_workflow.recovery_test.id
  frequency    = "Month"
  interval     = 1
}

# Random string for unique naming
resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}



