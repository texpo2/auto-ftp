resource "azurerm_network_interface" "nic" {
  name                = "team2-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
  # DNS 서버 명시적 설정
  dns_servers = ["168.63.129.16", "8.8.8.8"]

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_pip.id
  }
}

# NIC에 NSG 연결 (이것만 남기고 아래 중복 제거)
resource "azurerm_network_interface_security_group_association" "nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 이 부분은 이미 04_NetSecGroop.tf에서 정의되어 있으므로 삭제 필요
# resource "azurerm_subnet_network_security_group_association" "subnet_nsg_assoc" {
#   subnet_id                 = azurerm_subnet.subnet.id
#   network_security_group_id = azurerm_network_security_group.nsg.id
# }