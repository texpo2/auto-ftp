# ==================================================
# 25_dr_network.tf - DR 리전 네트워크 인프라
# ==================================================

# ==========================================
# DR 리소스 그룹
# ==========================================

resource "azurerm_resource_group" "dr" {
  count    = var.dr_enabled ? 1 : 0
  name     = local.dr_rg_name
  location = var.dr_location
  
  tags = local.combined_dr_tags
}

# ==========================================
# DR 가상 네트워크
# ==========================================

resource "azurerm_virtual_network" "dr_vnet" {
  count               = var.dr_enabled ? 1 : 0
  name                = local.dr_vnet_name
  address_space       = var.dr_vnet_address_space
  location            = var.dr_location
  resource_group_name = azurerm_resource_group.dr[0].name
  
  # DNS 서버 설정 (메인과 동일)
  dns_servers = ["168.63.129.16", "8.8.8.8", "8.8.4.4"]
  
  tags = local.combined_dr_tags
}

# ==========================================
# DR 서브넷
# ==========================================

resource "azurerm_subnet" "dr_subnet" {
  count                = var.dr_enabled ? 1 : 0
  name                 = "dr-subnet"
  resource_group_name  = azurerm_resource_group.dr[0].name
  virtual_network_name = azurerm_virtual_network.dr_vnet[0].name
  address_prefixes     = var.dr_subnet_address_prefixes
}

# DR Bastion 전용 서브넷
resource "azurerm_subnet" "dr_bastion_subnet" {
  count                = var.dr_enabled ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.dr[0].name
  virtual_network_name = azurerm_virtual_network.dr_vnet[0].name
  address_prefixes     = var.dr_bastion_subnet_address_prefixes
}

# ==========================================
# VNet Peering (메인 ↔ DR)
# ==========================================

# 메인 → DR Peering
resource "azurerm_virtual_network_peering" "main_to_dr" {
  count                        = var.dr_enabled ? 1 : 0
  name                         = "main-to-dr-peering"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.dr_vnet[0].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# DR → 메인 Peering
resource "azurerm_virtual_network_peering" "dr_to_main" {
  count                        = var.dr_enabled ? 1 : 0
  name                         = "dr-to-main-peering"
  resource_group_name          = azurerm_resource_group.dr[0].name
  virtual_network_name         = azurerm_virtual_network.dr_vnet[0].name
  remote_virtual_network_id    = azurerm_virtual_network.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# ==========================================
# DR 네트워크 보안 그룹
# ==========================================

resource "azurerm_network_security_group" "dr_nsg" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-nsg"
  location            = var.dr_location
  resource_group_name = azurerm_resource_group.dr[0].name

  # SSH 접근 허용 (DR 관리용)
  security_rule {
    name                       = "AllowSSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # FTP 포트 허용 (페일오버 시)
  security_rule {
    name                       = "AllowFTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "21"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # FTP 패시브 모드 포트 허용
  security_rule {
    name                       = "AllowFTPPassive"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000-30010"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # HTTPS 허용 (관리 및 모니터링)
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # 모든 아웃바운드 허용
  security_rule {
    name                       = "AllowAllOutbound"
    priority                   = 1005
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.combined_dr_tags
}

# DR 서브넷과 NSG 연결
resource "azurerm_subnet_network_security_group_association" "dr_nsg_association" {
  count                     = var.dr_enabled ? 1 : 0
  subnet_id                 = azurerm_subnet.dr_subnet[0].id
  network_security_group_id = azurerm_network_security_group.dr_nsg[0].id
}

# ==========================================
# DR 공인 IP (페일오버 시 사용)
# ==========================================

resource "azurerm_public_ip" "dr_vm_pip" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-vm-pip"
  location            = var.dr_location
  resource_group_name = azurerm_resource_group.dr[0].name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "dr-ftp-${random_string.suffix.result}"

  tags = local.combined_dr_tags
}

# DR Bastion 공인 IP
resource "azurerm_public_ip" "dr_bastion_pip" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-bastion-pip"
  location            = var.dr_location
  resource_group_name = azurerm_resource_group.dr[0].name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.combined_dr_tags
}

# ==========================================
# DR NAT Gateway (아웃바운드 연결용)
# ==========================================

resource "azurerm_nat_gateway" "dr_natgw" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-natgw"
  location            = var.dr_location
  resource_group_name = azurerm_resource_group.dr[0].name
  sku_name            = "Standard"

  tags = local.combined_dr_tags
}

# DR NAT Gateway용 공인 IP
resource "azurerm_public_ip" "dr_nat_pip" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-nat-pip"
  location            = var.dr_location
  resource_group_name = azurerm_resource_group.dr[0].name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.combined_dr_tags
}

# NAT Gateway와 공인 IP 연결
resource "azurerm_nat_gateway_public_ip_association" "dr_nat_pip_assoc" {
  count                = var.dr_enabled ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.dr_natgw[0].id
  public_ip_address_id = azurerm_public_ip.dr_nat_pip[0].id
}

# NAT Gateway와 서브넷 연결
resource "azurerm_subnet_nat_gateway_association" "dr_nat_subnet_assoc" {
  count          = var.dr_enabled ? 1 : 0
  subnet_id      = azurerm_subnet.dr_subnet[0].id
  nat_gateway_id = azurerm_nat_gateway.dr_natgw[0].id
}

# ==========================================
# DR Bastion Host (선택적)
# ==========================================

resource "azurerm_bastion_host" "dr_bastion" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-bastion"
  location            = var.dr_location
  resource_group_name = azurerm_resource_group.dr[0].name
  sku                 = "Standard"

  copy_paste_enabled     = true
  file_copy_enabled      = true
  ip_connect_enabled     = true
  shareable_link_enabled = true
  tunneling_enabled      = true

  ip_configuration {
    name                 = "dr-bastion-ip-config"
    subnet_id            = azurerm_subnet.dr_bastion_subnet[0].id
    public_ip_address_id = azurerm_public_ip.dr_bastion_pip[0].id
  }

  tags = local.combined_dr_tags
}

# ==========================================
# Route Table (DR 네트워크 라우팅)
# ==========================================

resource "azurerm_route_table" "dr_route_table" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-route-table"
  location            = var.dr_location
  resource_group_name = azurerm_resource_group.dr[0].name

  # 메인 리전으로의 라우팅 (VNet Peering으로 자동 처리되므로 제거)
  # route {
  #   name           = "to-main-region"
  #   address_prefix = "10.0.0.0/16"
  #   next_hop_type  = "VnetLocal"
  # }

  tags = local.combined_dr_tags
}

# Route Table과 DR 서브넷 연결
resource "azurerm_subnet_route_table_association" "dr_route_assoc" {
  count          = var.dr_enabled ? 1 : 0
  subnet_id      = azurerm_subnet.dr_subnet[0].id
  route_table_id = azurerm_route_table.dr_route_table[0].id
}