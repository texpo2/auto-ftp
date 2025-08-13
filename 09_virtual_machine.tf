# 10_VM.tf에서 identity 블록 추가 (Role Assignment를 위해 필요)

# Marketplace 이미지 약관 동의 (이미 존재함 - 주석 처리)
# resource "azurerm_marketplace_agreement" "rockylinux" {
#   publisher = "resf"
#   offer     = "rockylinux-x86_64"
#   plan      = "9-lvm"
# }

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "team2-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = "Standard_B4ms"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.nic.id]

  disable_password_authentication = false
  admin_password                  = var.admin_password

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-lvm"
    version   = "latest"
  }

  plan {
    publisher = "resf"
    product   = "rockylinux-x86_64"
    name      = "9-lvm"
  }

  custom_data = base64encode(file("${path.module}/ftp_cloud_config.yml"))

  # Managed Identity 추가 (중요!)
  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    azurerm_network_interface.nic
  ]

  tags = {
    Environment = "Development"
    Purpose     = "FTP-Server"
  }
}