# ==================================================
# 06_key_vault.tf - Key Vault 및 보안 (파트 3 기반)
# ==================================================

# 현재 클라이언트 정보 가져오기
data "azurerm_client_config" "current" {}


# Key Vault 생성
resource "azurerm_key_vault" "ftp_kv" {
  name                        = "team2-ftp-kv-${random_string.suffix.result}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true
  sku_name                    = "standard"
  enable_rbac_authorization   = true

  depends_on = [
    azurerm_resource_group.rg,
    random_string.suffix
  ]
}

# Key Vault 관리자 권한 부여
resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.ftp_kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id

  depends_on = [azurerm_key_vault.ftp_kv]
}

# FTPS용 SSL 인증서 생성
resource "azurerm_key_vault_certificate" "ftps_cert" {
  name         = "ftps-ssl-cert"
  key_vault_id = azurerm_key_vault.ftp_kv.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }
    
    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }
    
    secret_properties {
      content_type = "application/x-pkcs12"
    }
    
    x509_certificate_properties {
      subject            = "CN=team2-ftps.local"
      validity_in_months = 12
      key_usage = [
        "keyEncipherment",
        "digitalSignature"
      ]
      extended_key_usage = [
        "1.3.6.1.5.5.7.3.1"  # Server Authentication
      ]
      
      subject_alternative_names {
        dns_names = [
          "team2-ftps.local",
          "ftpserver.local"
        ]
      }
    }
  }

  depends_on = [azurerm_role_assignment.kv_admin]
}

# VM 관리자 비밀번호 저장
resource "azurerm_key_vault_secret" "vm_admin_password" {
  name         = "vm-admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.ftp_kv.id

  depends_on = [azurerm_role_assignment.kv_admin]
}