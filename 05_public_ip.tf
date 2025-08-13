resource "azurerm_public_ip" "vm_pip" {
  name                = "team2-vm-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "team2-ftp-${random_string.suffix.result}"
}

resource "azurerm_public_ip" "nat_pip" {
  name                = "team2-nat-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Bastion을 위한 공용 IP
resource "azurerm_public_ip" "bastion_pip" {
  name                = "team2-bastion-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}