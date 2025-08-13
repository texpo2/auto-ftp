# ==================================================
# 28_dr_automation.tf - DR 자동화 및 페일오버 시스템
# ==================================================

# ==========================================
# Traffic Manager 프로필 (DNS 기반 페일오버)
# ==========================================

resource "azurerm_traffic_manager_profile" "ftp_service" {
  count                        = var.dr_enabled ? 1 : 0
  name                         = var.traffic_manager_profile_name
  resource_group_name          = azurerm_resource_group.rg.name
  traffic_routing_method       = var.traffic_manager_routing_method
  max_return                   = 1

  dns_config {
    relative_name = var.traffic_manager_dns_name
    ttl           = 60  # 빠른 페일오버를 위한 짧은 TTL
  }

  monitor_config {
    protocol                     = "TCP"
    port                         = 21
    # TCP 프로토콜에서는 path 불필요 (HTTP/HTTPS에서만 사용)
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = var.dr_failover_threshold
  }

  tags = local.combined_dr_tags
}

# Traffic Manager 엔드포인트 - 메인 서버 (우선순위 1)
resource "azurerm_traffic_manager_azure_endpoint" "main_endpoint" {
  count              = var.dr_enabled ? 1 : 0
  name               = "main-ftp-endpoint"
  profile_id         = azurerm_traffic_manager_profile.ftp_service[0].id
  target_resource_id = azurerm_public_ip.vm_pip.id
  priority           = 1
  weight             = 100
}

# Traffic Manager 엔드포인트 - DR 서버 (우선순위 2)
resource "azurerm_traffic_manager_azure_endpoint" "dr_endpoint" {
  count              = var.dr_enabled ? 1 : 0
  name               = "dr-ftp-endpoint"
  profile_id         = azurerm_traffic_manager_profile.ftp_service[0].id
  target_resource_id = azurerm_public_ip.dr_vm_pip[0].id
  priority           = 2
  weight             = 100
}

# ==========================================
# Azure Automation Account (DR 자동화)
# ==========================================

resource "azurerm_automation_account" "dr_automation" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-automation-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"

  tags = local.combined_dr_tags
}

# ==========================================
# DR VM 자동 시작 Runbook
# ==========================================

resource "azurerm_automation_runbook" "dr_vm_start" {
  count                   = var.dr_enabled ? 1 : 0
  name                    = "Start-DR-VM"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.dr_automation[0].name
  log_verbose             = true
  log_progress            = true
  description             = "DR VM 자동 시작 Runbook"
  runbook_type            = "PowerShell"

  content = <<CONTENT
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$VMName,
    
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId
)

# Azure 인증
$connectionName = "AzureRunAsConnection"
try {
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
    Connect-AzAccount -ServicePrincipal -Tenant $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
    Set-AzContext -SubscriptionId $SubscriptionId
} catch {
    Write-Error "Azure 인증 실패: $($_.Exception.Message)"
    exit 1
}

# DR VM 상태 확인
Write-Output "DR VM 상태 확인 중: $VMName"
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

if ($vm.Statuses | Where-Object {$_.Code -eq "PowerState/running"}) {
    Write-Output "DR VM이 이미 실행 중입니다."
} else {
    Write-Output "DR VM 시작 중..."
    Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
    Write-Output "DR VM 시작 완료: $VMName"
    
    # 시작 후 헬스 체크
    Start-Sleep -Seconds 60
    $vmStatus = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status
    if ($vmStatus.Statuses | Where-Object {$_.Code -eq "PowerState/running"}) {
        Write-Output "DR VM 헬스 체크 성공"
    } else {
        Write-Error "DR VM 시작 후 헬스 체크 실패"
    }
}
CONTENT

  tags = local.combined_dr_tags
}

# ==========================================
# DR VM 자동 중지 Runbook
# ==========================================

resource "azurerm_automation_runbook" "dr_vm_stop" {
  count                   = var.dr_enabled ? 1 : 0
  name                    = "Stop-DR-VM"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.dr_automation[0].name
  log_verbose             = true
  log_progress            = true
  description             = "DR VM 자동 중지 Runbook (메인 서버 복구 시)"
  runbook_type            = "PowerShell"

  content = <<CONTENT
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$VMName,
    
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId
)

# Azure 인증
$connectionName = "AzureRunAsConnection"
try {
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
    Connect-AzAccount -ServicePrincipal -Tenant $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
    Set-AzContext -SubscriptionId $SubscriptionId
} catch {
    Write-Error "Azure 인증 실패: $($_.Exception.Message)"
    exit 1
}

# DR VM 상태 확인 및 중지
Write-Output "DR VM 상태 확인 중: $VMName"
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status

if ($vm.Statuses | Where-Object {$_.Code -eq "PowerState/deallocated"}) {
    Write-Output "DR VM이 이미 중지되어 있습니다."
} else {
    Write-Output "DR VM 중지 중... (할당 해제)"
    Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
    Write-Output "DR VM 중지 완료: $VMName"
}
CONTENT

  tags = local.combined_dr_tags
}

# ==========================================
# 메인 서버 헬스 체크 Logic App
# ==========================================

resource "azurerm_logic_app_workflow" "main_server_health_check" {
  count               = var.dr_enabled ? 1 : 0
  name                = "main-server-health-check"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  workflow_schema   = "https://schema.management.azure.com/schemas/2016-06-01/workflowdefinition.json#"
  workflow_version  = "1.0.0.0"
  
  tags = local.combined_dr_tags
}

# 헬스 체크 Logic App 트리거 (매분 실행)
resource "azurerm_logic_app_trigger_recurrence" "health_check_trigger" {
  count        = var.dr_enabled ? 1 : 0
  name         = "health-check-trigger"
  logic_app_id = azurerm_logic_app_workflow.main_server_health_check[0].id
  frequency    = "Minute"
  interval     = 1
}

# ==========================================
# DR 데이터 동기화 Logic App
# ==========================================

resource "azurerm_logic_app_workflow" "dr_data_sync" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-data-sync"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  workflow_schema   = "https://schema.management.azure.com/schemas/2016-06-01/workflowdefinition.json#"
  workflow_version  = "1.0.0.0"
  
  tags = local.combined_dr_tags
}

# DR 데이터 동기화 트리거 (설정된 주기마다)
resource "azurerm_logic_app_trigger_recurrence" "data_sync_trigger" {
  count        = var.dr_enabled ? 1 : 0
  name         = "data-sync-trigger"
  logic_app_id = azurerm_logic_app_workflow.dr_data_sync[0].id
  frequency    = "Minute"
  interval     = var.dr_replication_frequency
}

# ==========================================
# Azure Function App (복잡한 DR 로직 처리용)
# ==========================================

resource "azurerm_service_plan" "dr_function_plan" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-function-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "Y1"  # Consumption plan (비용 효율적)

  tags = local.combined_dr_tags
}

resource "azurerm_linux_function_app" "dr_functions" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-functions-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.dr_function_plan[0].id
  storage_account_name       = azurerm_storage_account.dr_automation[0].name
  storage_account_access_key = azurerm_storage_account.dr_automation[0].primary_access_key

  site_config {
    application_stack {
      python_version = "3.9"
    }
  }

  app_settings = {
    "MAIN_VM_IP"                = azurerm_public_ip.vm_pip.ip_address
    "DR_VM_IP"                  = azurerm_public_ip.dr_vm_pip[0].ip_address
    "DR_RESOURCE_GROUP"         = azurerm_resource_group.dr[0].name
    "DR_VM_NAME"                = azurerm_linux_virtual_machine.dr_vm[0].name
    "SUBSCRIPTION_ID"           = data.azurerm_client_config.current.subscription_id
    "HEALTH_CHECK_INTERVAL"     = var.dr_health_check_interval
    "FAILOVER_THRESHOLD"        = var.dr_failover_threshold
    "AzureWebJobsFeatureFlags"  = "EnableWorkerIndexing"
  }

  tags = local.combined_dr_tags
}

# ==========================================
# EventGrid 토픽 (DR 이벤트 처리)
# ==========================================

resource "azurerm_eventgrid_topic" "dr_events" {
  count               = var.dr_enabled ? 1 : 0
  name                = "dr-events-topic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = local.combined_dr_tags
}

# DR 이벤트 구독 (VM 시작/중지 이벤트)
# Function이 먼저 배포되고 DrEventHandler 함수가 생성된 후 활성화해야 함
/*
resource "azurerm_eventgrid_event_subscription" "dr_vm_events" {
  count = var.dr_enabled ? 1 : 0
  name  = "dr-vm-events"
  scope = azurerm_resource_group.dr[0].id

  azure_function_endpoint {
    function_id = "${azurerm_linux_function_app.dr_functions[0].id}/functions/DrEventHandler"
  }

  included_event_types = [
    "Microsoft.Compute/virtualMachines/write",
    "Microsoft.Compute/virtualMachines/start/action",
    "Microsoft.Compute/virtualMachines/deallocate/action"
  ]

  depends_on = [azurerm_linux_function_app.dr_functions]
}
*/

# ==========================================
# DR 자동화 스케줄
# ==========================================

# 주기적 헬스 체크 스케줄
resource "azurerm_automation_schedule" "health_check_schedule" {
  count                   = var.dr_enabled ? 1 : 0
  name                    = "health-check-schedule"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.dr_automation[0].name
  frequency               = "Hour"
  interval                = 1  # 1시간마다
  description             = "메인 서버 헬스 체크 스케줄"
}

# 일일 DR 테스트 스케줄 (새벽 2시)
resource "azurerm_automation_schedule" "daily_dr_test" {
  count                   = var.dr_enabled ? 1 : 0
  name                    = "daily-dr-test"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.dr_automation[0].name
  frequency               = "Day"
  interval                = 1
  start_time              = timeadd(timestamp(), "10m")  # 현재 시간 + 10분
  description             = "일일 DR 시스템 테스트"
}

# ==========================================
# DR Runbook 변수
# ==========================================

resource "azurerm_automation_variable_string" "dr_resource_group" {
  count                   = var.dr_enabled ? 1 : 0
  name                    = "DR_RESOURCE_GROUP"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.dr_automation[0].name
  value                   = azurerm_resource_group.dr[0].name
  description             = "DR 리소스 그룹 이름"
}

resource "azurerm_automation_variable_string" "dr_vm_name" {
  count                   = var.dr_enabled ? 1 : 0
  name                    = "DR_VM_NAME"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.dr_automation[0].name
  value                   = azurerm_linux_virtual_machine.dr_vm[0].name
  description             = "DR VM 이름"
}

resource "azurerm_automation_variable_string" "subscription_id" {
  count                   = var.dr_enabled ? 1 : 0
  name                    = "SUBSCRIPTION_ID"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.dr_automation[0].name
  value                   = data.azurerm_client_config.current.subscription_id
  description             = "Azure 구독 ID"
}