
resource "azurerm_bastion_host" "bastion" {
  name                = "team2-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  # Bastion 고급 기능 활성화
  copy_paste_enabled     = true
  file_copy_enabled      = true
  ip_connect_enabled     = true
  shareable_link_enabled = true
  tunneling_enabled      = true

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }

  depends_on = [
    azurerm_subnet.bastion_subnet,
    azurerm_public_ip.bastion_pip
  ]
}
