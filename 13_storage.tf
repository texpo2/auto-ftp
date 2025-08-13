# -------------------------------------------
# 08_StorageAccount.tf
# Storage Account for NSG Flow Logs
# -------------------------------------------

# Storage Account for NSG Flow Logs
resource "azurerm_storage_account" "nsg_logs" {
  name                          = "nsglog${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  account_kind                  = "StorageV2"
  min_tls_version               = "TLS1_2"
  https_traffic_only_enabled    = true  # Azure Provider 4.x 문법
  public_network_access_enabled = true   # NSG Flow Logs 접근을 위해 필요
  
  # 보안 설정
  allow_nested_items_to_be_public = false
  shared_access_key_enabled        = true
  
  # Blob 속성 설정
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }
  
  tags = {
    Environment = "Development"
    Purpose     = "NSG-Flow-Logs"
    Team        = "Team2"
  }
  
  depends_on = [azurerm_resource_group.rg]
}

# NSG Flow Logs를 위한 Storage Container
resource "azurerm_storage_container" "nsglogs" {
  name                  = "insights-logs-networksecuritygroupflowevent"
  storage_account_id    = azurerm_storage_account.nsg_logs.id  # storage_account_id 사용
  container_access_type = "private"
}

# Storage Account Network Rules (선택사항)
resource "azurerm_storage_account_network_rules" "nsg_logs_rules" {
  storage_account_id = azurerm_storage_account.nsg_logs.id
  
  default_action             = "Allow"
  bypass                     = ["AzureServices", "Logging", "Metrics"]
  ip_rules                   = []  # 필요시 특정 IP 추가
  virtual_network_subnet_ids = []  # 필요시 서브넷 ID 추가
}

# Storage Management Policy (로그 수명 주기 관리)
# 이미 존재하는 리소스로 인해 주석처리
/*
resource "azurerm_storage_management_policy" "nsglogs_policy" {
  storage_account_id = azurerm_storage_account.nsg_logs.id

  rule {
    name    = "log_lifecycle"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["insights-logs-networksecuritygroupflowevent/"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 365
      }
    }
  }
}
*/