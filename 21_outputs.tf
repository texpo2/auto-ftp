output "vm_public_ip" {
  description = "VM의 공용 IP 주소"
  value       = azurerm_public_ip.vm_pip.ip_address
}

output "vm_fqdn" {
  description = "VM의 FQDN"
  value       = azurerm_public_ip.vm_pip.fqdn
}

output "ssh_connection" {
  description = "SSH 접속 명령어"
  value       = "ssh azureuser@${azurerm_public_ip.vm_pip.ip_address}"
}

output "ftp_connection" {
  description = "FTP 접속 정보"
  value = {
    server   = azurerm_public_ip.vm_pip.ip_address
    port     = 21
    user     = "ftpuser"
    password = "SecureFTP2024!"
    protocol = "FTPS (SSL/TLS required)"
  }
}

output "storage_account_name" {
  description = "NSG Flow Logs용 스토리지 계정"
  value       = azurerm_storage_account.nsg_logs.name
}

output "log_analytics_workspace" {
  description = "Log Analytics Workspace 정보"
  value = {
    name         = azurerm_log_analytics_workspace.team2law.name
    workspace_id = azurerm_log_analytics_workspace.team2law.workspace_id
  }
}

# ==========================================
# DR (Disaster Recovery) Outputs
# ==========================================

output "dr_enabled" {
  description = "DR 기능 활성화 여부"
  value       = var.dr_enabled
}

output "dr_vm_public_ip" {
  description = "DR VM의 공용 IP 주소"
  value       = var.dr_enabled ? azurerm_public_ip.dr_vm_pip[0].ip_address : null
}

output "dr_ssh_connection" {
  description = "DR VM SSH 접속 명령어"
  value       = var.dr_enabled ? "ssh azureuser@${azurerm_public_ip.dr_vm_pip[0].ip_address}" : null
}

output "dr_ftp_connection" {
  description = "DR FTP 접속 정보 (장애 시 활성화)"
  value = var.dr_enabled ? {
    server   = azurerm_public_ip.dr_vm_pip[0].ip_address
    port     = 21
    user     = "ftpuser"
    password = "SecureFTP2024!"
    protocol = "FTPS (SSL/TLS required)"
    status   = "standby"
  } : null
}

output "traffic_manager_fqdn" {
  description = "Traffic Manager FQDN (자동 페일오버)"
  value       = var.dr_enabled ? azurerm_traffic_manager_profile.ftp_service[0].fqdn : null
}

output "dr_resource_group_name" {
  description = "DR 리소스 그룹 이름"
  value       = var.dr_enabled ? azurerm_resource_group.dr[0].name : null
}

output "dr_location" {
  description = "DR 리전"
  value       = var.dr_enabled ? var.dr_location : null
}

output "dr_dashboard_url" {
  description = "DR 모니터링 대시보드 URL (Azure Portal에서 수동 생성 필요)"
  value       = var.dr_enabled ? "https://portal.azure.com/#dashboard" : null
}

# ==========================================
# DR 상태 정보
# ==========================================

output "dr_status_summary" {
  description = "DR 시스템 상태 요약"
  value = var.dr_enabled ? {
    dr_location           = var.dr_location
    main_region          = var.location
    rto_minutes          = var.dr_rto_minutes
    rpo_minutes          = var.dr_rpo_minutes
    auto_failover_enabled = var.dr_vm_auto_start
    traffic_manager_dns   = "${var.traffic_manager_dns_name}.trafficmanager.net"
    monitoring_enabled    = var.dr_monitoring_enabled
  } : null
}