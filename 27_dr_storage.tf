# ==================================================
# 27_dr_storage.tf - DR 스토리지 및 백업 구성
# ==================================================

# ==========================================
# DR 진단 스토리지 계정
# ==========================================

resource "azurerm_storage_account" "dr_diagnostics" {
  count                    = var.dr_enabled ? 1 : 0
  name                     = "drdiag${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.dr[0].name
  location                 = var.dr_location
  account_tier             = "Standard"
  account_replication_type = "LRS"  # DR 리전에서는 LRS 충분

  tags = local.combined_dr_tags
}

# ==========================================
# DR FTP 데이터 스토리지 (복제용)
# ==========================================

resource "azurerm_storage_account" "dr_ftp_data" {
  count                    = var.dr_enabled ? 1 : 0
  name                     = "drftp${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.dr[0].name
  location                 = var.dr_location
  account_tier             = "Standard"
  account_replication_type = "GRS"  # 지역 간 복제로 이중 보호
  
  # 메인 리전 데이터와 동기화를 위한 설정
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = var.dr_retention_days
    }
    
    container_delete_retention_policy {
      days = var.dr_retention_days
    }
  }

  tags = local.combined_dr_tags
}

# DR FTP 데이터 컨테이너
resource "azurerm_storage_container" "dr_ftp_data_container" {
  count                 = var.dr_enabled ? 1 : 0
  name                  = "ftp-data"
  storage_account_id    = azurerm_storage_account.dr_ftp_data[0].id
  container_access_type = "private"
  
  depends_on = [azurerm_storage_account.dr_ftp_data]
}

# ==========================================
# DR 로그 스토리지
# ==========================================

resource "azurerm_storage_account" "dr_logs" {
  count                    = var.dr_enabled ? 1 : 0
  name                     = "drlogs${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.dr[0].name
  location                 = var.dr_location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = local.combined_dr_tags
}

# DR 로그 컨테이너
resource "azurerm_storage_container" "dr_logs_container" {
  count                 = var.dr_enabled ? 1 : 0
  name                  = "dr-logs"
  storage_account_id    = azurerm_storage_account.dr_logs[0].id
  container_access_type = "private"
  
  depends_on = [azurerm_storage_account.dr_logs]
}

# ==========================================
# DR Recovery Services Vault
# ==========================================

resource "azurerm_recovery_services_vault" "dr_vault" {
  count               = var.dr_enabled ? 1 : 0
  name                = "rsv-dr-${var.environment}-${random_string.suffix.result}"
  location            = var.dr_location
  resource_group_name = azurerm_resource_group.dr[0].name
  sku                 = "Standard"
  
  # 소프트 삭제 비활성화로 충돌 방지 (개발 환경)
  soft_delete_enabled = false
  
  # 교차 지역 복원 비활성화 (비용 절약)
  cross_region_restore_enabled = false

  tags = local.combined_dr_tags
}

# ==========================================
# DR VM 백업 정책
# ==========================================

resource "azurerm_backup_policy_vm" "dr_backup_policy" {
  count               = var.dr_enabled ? 1 : 0
  name                = "DR-VM-Backup-Policy"
  resource_group_name = azurerm_resource_group.dr[0].name
  recovery_vault_name = azurerm_recovery_services_vault.dr_vault[0].name

  backup {
    frequency = "Daily"
    time      = "03:00"  # 오전 3시 (메인과 시간차)
  }

  retention_daily {
    count = var.dr_retention_days
  }

  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }

  retention_monthly {
    count    = 12
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }

  depends_on = [azurerm_recovery_services_vault.dr_vault]
}

# ==========================================
# 메인-DR 간 스토리지 동기화 (스크립트 기반)
# ==========================================

# Azure File Sync는 Terraform에서 제한적 지원
# 대신 Azure Automation Runbook으로 동기화 처리

# ==========================================
# DR 데이터 복제 자동화 스크립트 스토리지
# ==========================================

resource "azurerm_storage_account" "dr_automation" {
  count                    = var.dr_enabled ? 1 : 0
  name                     = "drauto${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.dr[0].name
  location                 = var.dr_location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.combined_dr_tags
}

# DR 자동화 스크립트 컨테이너
resource "azurerm_storage_container" "dr_automation_scripts" {
  count                 = var.dr_enabled ? 1 : 0
  name                  = "automation-scripts"
  storage_account_id    = azurerm_storage_account.dr_automation[0].id
  container_access_type = "private"
  
  depends_on = [azurerm_storage_account.dr_automation]
}

# ==========================================
# DR 데이터 동기화 스크립트 업로드
# ==========================================

# DR 동기화 스크립트는 Azure Automation Runbook으로 처리
# (28_dr_automation.tf 파일에서 관리)

# ==========================================
# DR 스토리지 네트워크 규칙
# ==========================================

# 스토리지 계정 네트워크 규칙 설정
resource "azurerm_storage_account_network_rules" "dr_ftp_data_rules" {
  count                      = var.dr_enabled ? 1 : 0
  storage_account_id         = azurerm_storage_account.dr_ftp_data[0].id
  default_action             = "Allow"  # 초기 설정 후 필요시 Deny로 변경
  bypass                     = ["AzureServices"]
  
  depends_on = [azurerm_storage_account.dr_ftp_data]
}

resource "azurerm_storage_account_network_rules" "dr_logs_rules" {
  count                      = var.dr_enabled ? 1 : 0
  storage_account_id         = azurerm_storage_account.dr_logs[0].id
  default_action             = "Allow"  # 초기 설정 후 필요시 Deny로 변경
  bypass                     = ["AzureServices"]
  
  depends_on = [azurerm_storage_account.dr_logs]
}

# ==========================================
# DR 스토리지 생명주기 관리
# ==========================================

resource "azurerm_storage_management_policy" "dr_ftp_data_policy" {
  count              = var.dr_enabled ? 1 : 0
  storage_account_id = azurerm_storage_account.dr_ftp_data[0].id

  rule {
    name    = "drDataRetentionPolicy"
    enabled = true
    
    filters {
      prefix_match = ["ftp-data/"]
      blob_types   = ["blockBlob"]
    }
    
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 7
        tier_to_archive_after_days_since_modification_greater_than = 30
        delete_after_days_since_modification_greater_than          = var.dr_retention_days
      }
    }
  }
  
  depends_on = [azurerm_storage_account.dr_ftp_data]
}

resource "azurerm_storage_management_policy" "dr_logs_policy" {
  count              = var.dr_enabled ? 1 : 0
  storage_account_id = azurerm_storage_account.dr_logs[0].id

  rule {
    name    = "drLogsRetentionPolicy"
    enabled = true
    
    filters {
      prefix_match = ["dr-logs/"]
      blob_types   = ["blockBlob"]
    }
    
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 3
        tier_to_archive_after_days_since_modification_greater_than = 14
        delete_after_days_since_modification_greater_than          = var.dr_retention_days
      }
    }
  }
  
  depends_on = [azurerm_storage_account.dr_logs]
}

# ==========================================
# DR 스토리지 모니터링
# ==========================================

# DR 스토리지 계정에 대한 진단 설정 (29_dr_monitoring.tf에서 관리)
# 스토리지 진단 설정은 Log Analytics Workspace 연결이 필요하므로
# 모니터링 파일에서 통합 관리합니다.