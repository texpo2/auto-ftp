# ==================================================
# 26_dr_vm.tf - DR VM 및 관련 리소스
# ==================================================

# ==========================================
# DR 네트워크 인터페이스
# ==========================================

resource "azurerm_network_interface" "dr_nic" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-nic"
  location            = var.dr_location
  resource_group_name = azurerm_resource_group.dr[0].name

  ip_configuration {
    name                          = "dr-ip-config"
    subnet_id                     = azurerm_subnet.dr_subnet[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dr_vm_pip[0].id
  }

  tags = local.combined_dr_tags
}

# DR NIC와 NSG 연결
resource "azurerm_network_interface_security_group_association" "dr_nic_nsg_assoc" {
  count                     = var.dr_enabled ? 1 : 0
  network_interface_id      = azurerm_network_interface.dr_nic[0].id
  network_security_group_id = azurerm_network_security_group.dr_nsg[0].id
}

# ==========================================
# DR Key Vault (DR 리전 전용)
# ==========================================

resource "azurerm_key_vault" "dr_kv" {
  count                       = var.dr_enabled ? 1 : 0
  name                        = "dr-ftp-kv-${random_string.suffix.result}"
  location                    = var.dr_location
  resource_group_name         = azurerm_resource_group.dr[0].name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true
  sku_name                    = "standard"
  enable_rbac_authorization   = true

  tags = local.combined_dr_tags

  depends_on = [
    azurerm_resource_group.dr,
    random_string.suffix
  ]
}

# DR Key Vault RBAC 할당
resource "azurerm_role_assignment" "dr_kv_admin" {
  count                = var.dr_enabled ? 1 : 0
  scope                = azurerm_key_vault.dr_kv[0].id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# DR Key Vault 인증서 (메인과 동일)
resource "azurerm_key_vault_certificate" "dr_ftps_cert" {
  count        = var.dr_enabled ? 1 : 0
  name         = "ftps-ssl-cert"
  key_vault_id = azurerm_key_vault.dr_kv[0].id

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
      key_usage = [
        "digitalSignature",
        "keyEncipherment",
      ]

      subject            = "CN=dr-ftps.local"
      validity_in_months = 12

      subject_alternative_names {
        dns_names = [
          "dr-ftpserver.local",
          "dr-ftps.local",
        ]
      }

      extended_key_usage = [
        "1.3.6.1.5.5.7.3.1",  # Server Authentication
      ]
    }
  }

  depends_on = [azurerm_role_assignment.dr_kv_admin]

  tags = local.combined_dr_tags
}

# DR VM 관리자 비밀번호 저장
resource "azurerm_key_vault_secret" "dr_vm_admin_password" {
  count        = var.dr_enabled ? 1 : 0
  name         = "dr-vm-admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.dr_kv[0].id

  depends_on = [azurerm_role_assignment.dr_kv_admin]

  tags = local.combined_dr_tags
}

# ==========================================
# DR VM 생성 (할당 해제 상태)
# ==========================================

resource "azurerm_linux_virtual_machine" "dr_vm" {
  count               = var.dr_enabled ? 1 : 0
  name                = local.dr_vm_name
  location            = var.dr_location
  resource_group_name = azurerm_resource_group.dr[0].name
  size                = var.dr_vm_size
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.dr_nic[0].id,
  ]

  # SSH와 패스워드 인증 모두 허용
  disable_password_authentication = false
  admin_password                  = var.admin_password

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"  # DR은 더 빠른 스토리지 사용
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-lvm"
    version   = "latest"
  }

  # Marketplace 이미지 사용을 위한 plan 정보
  plan {
    publisher = "resf"
    product   = "rockylinux-x86_64"
    name      = "9-lvm"
  }

  # DR VM은 평상시 할당 해제 상태
  # 장애 시에만 자동으로 시작됨
  
  # Managed Identity 설정 (Key Vault 접근용)
  identity {
    type = "SystemAssigned"
  }

  # 부팅 진단 활성화
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.dr_diagnostics[0].primary_blob_endpoint
  }

  # DR 전용 cloud-init 설정
  custom_data = base64encode(templatefile("${path.module}/dr_cloud_config.yml", {
    primary_ftp_server = azurerm_public_ip.vm_pip.ip_address
    dr_mode            = "standby"
    main_region        = var.location
    dr_region          = var.dr_location
  }))

  tags = local.combined_dr_tags

  depends_on = [
    azurerm_network_interface.dr_nic,
    azurerm_storage_account.dr_diagnostics
  ]
}

# ==========================================
# DR VM 자동 시작/중지 설정
# ==========================================

# DR VM 자동 종료 (비용 절약)
resource "azurerm_dev_test_global_vm_shutdown_schedule" "dr_vm_shutdown" {
  count              = var.dr_enabled && var.dr_vm_deallocated ? 1 : 0
  virtual_machine_id = azurerm_linux_virtual_machine.dr_vm[0].id
  location           = var.dr_location
  enabled            = true

  daily_recurrence_time = "2000"  # 오후 8시에 자동 종료
  timezone              = "Korea Standard Time"

  notification_settings {
    enabled = false
  }

  tags = local.combined_dr_tags
}

# ==========================================
# DR VM 스냅샷 생성 (즉시 복구용)
# 참고: 실제 스냅샷은 VM 생성 후 별도 스크립트로 처리
# ==========================================

# VM 스냅샷은 Azure Automation을 통해 주기적으로 생성됨

# ==========================================
# DR VM에서 메인 VM으로의 데이터 동기화 설정
# ==========================================

# Data 디스크 추가 (FTP 데이터 전용)
resource "azurerm_managed_disk" "dr_data_disk" {
  count                = var.dr_enabled ? 1 : 0
  name                 = "dr-data-disk"
  location             = var.dr_location
  resource_group_name  = azurerm_resource_group.dr[0].name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128

  tags = local.combined_dr_tags
}

# Data 디스크를 DR VM에 연결
resource "azurerm_virtual_machine_data_disk_attachment" "dr_data_disk_attachment" {
  count              = var.dr_enabled ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.dr_data_disk[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.dr_vm[0].id
  lun                = "1"
  caching            = "ReadWrite"
}

# ==========================================
# DR VM Role Assignments
# ==========================================

# DR Key Vault 접근 권한
resource "azurerm_role_assignment" "dr_vm_kv_secrets_user" {
  count                = var.dr_enabled ? 1 : 0
  scope                = azurerm_key_vault.dr_kv[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.dr_vm[0].identity[0].principal_id

  depends_on = [azurerm_linux_virtual_machine.dr_vm]
}

resource "azurerm_role_assignment" "dr_vm_kv_certificate_user" {
  count                = var.dr_enabled ? 1 : 0
  scope                = azurerm_key_vault.dr_kv[0].id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_linux_virtual_machine.dr_vm[0].identity[0].principal_id

  depends_on = [azurerm_linux_virtual_machine.dr_vm]
}