resource "azurerm_virtual_network" "vnet" {
  name                = "team2-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
  # DNS 서버 명시적 설정 (중요!)
  dns_servers = ["168.63.129.16", "8.8.8.8", "8.8.4.4"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "team2-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Bastion 전용 서브넷 (이름이 반드시 AzureBastionSubnet이어야 함)
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/27"]  # Bastion은 최소 /27 필요
}