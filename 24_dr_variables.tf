# ==================================================
# 24_dr_variables.tf - DR(Disaster Recovery) 전용 변수
# ==================================================

# ==========================================
# DR 지역 설정
# ==========================================

variable "dr_location" {
  description = "DR 지역 (메인과 물리적으로 분리된 지역)"
  type        = string
  default     = "Korea South"
}

variable "dr_enabled" {
  description = "DR 기능 활성화 여부"
  type        = bool
  default     = true
}

# ==========================================
# DR 네트워크 설정
# ==========================================

variable "dr_vnet_address_space" {
  description = "DR VNet 주소 공간"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "dr_subnet_address_prefixes" {
  description = "DR 서브넷 주소 범위"
  type        = list(string)
  default     = ["10.1.1.0/24"]
}

variable "dr_bastion_subnet_address_prefixes" {
  description = "DR Bastion 서브넷 주소 범위"
  type        = list(string)
  default     = ["10.1.2.0/27"]
}

# ==========================================
# DR VM 설정
# ==========================================

variable "dr_vm_size" {
  description = "DR VM 크기 (메인과 동일 권장)"
  type        = string
  default     = "Standard_B4ms"
}

variable "dr_vm_auto_start" {
  description = "DR VM 자동 시작 여부 (장애 감지 시)"
  type        = bool
  default     = true
}

variable "dr_vm_deallocated" {
  description = "평상시 DR VM 할당 해제 상태 유지 (비용 절약)"
  type        = bool
  default     = true
}

# ==========================================
# DR 백업 및 복제 설정
# ==========================================

variable "dr_backup_frequency" {
  description = "DR 백업 주기 (시간 단위)"
  type        = number
  default     = 4  # 4시간마다
}

variable "dr_retention_days" {
  description = "DR 백업 보존 기간 (일)"
  type        = number
  default     = 30
}

variable "dr_replication_frequency" {
  description = "스토리지 복제 주기 (분 단위)"
  type        = number
  default     = 15  # 15분마다
}

# ==========================================
# DR 자동화 설정
# ==========================================

variable "dr_failover_threshold" {
  description = "자동 페일오버 임계값 (실패 횟수)"
  type        = number
  default     = 3
}

variable "dr_health_check_interval" {
  description = "헬스 체크 간격 (초)"
  type        = number
  default     = 30
}

variable "dr_rto_minutes" {
  description = "복구 목표 시간 (RTO - 분)"
  type        = number
  default     = 15
}

variable "dr_rpo_minutes" {
  description = "복구 목표 시점 (RPO - 분)"
  type        = number
  default     = 15
}

# ==========================================
# DR 모니터링 설정
# ==========================================

variable "dr_monitoring_enabled" {
  description = "DR 모니터링 활성화"
  type        = bool
  default     = true
}

variable "dr_alert_email" {
  description = "DR 알림 이메일 (메인과 별도 권장)"
  type        = string
  default     = "dr-admin@company.com"
}

variable "dr_alert_phone" {
  description = "DR 알림 전화번호"
  type        = string
  default     = "01087654321"
}

# ==========================================
# DR 태그 설정
# ==========================================

variable "dr_tags" {
  description = "DR 리소스 공통 태그"
  type        = map(string)
  default     = {
    Environment = "dr"
    Purpose     = "disaster-recovery"
    Criticality = "high"
    AutoStart   = "true"
    CostCenter  = "dr-operations"
  }
}

# ==========================================
# Traffic Manager 설정
# ==========================================

variable "traffic_manager_profile_name" {
  description = "Traffic Manager 프로필 이름"
  type        = string
  default     = "team2-ftp-tm"
}

variable "traffic_manager_dns_name" {
  description = "Traffic Manager DNS 이름"
  type        = string
  default     = "team2-ftp-service"
}

variable "traffic_manager_routing_method" {
  description = "Traffic Manager 라우팅 방법 (Priority, Performance, Geographic, Weighted)"
  type        = string
  default     = "Priority"  # 메인 우선, 장애 시 DR
}

# ==========================================
# 로컬 값 계산
# ==========================================

locals {
  # DR 리소스 이름 규칙
  dr_resource_prefix = "${var.project_name}-dr"
  dr_rg_name        = "${local.dr_resource_prefix}-rg"
  dr_vnet_name      = "${local.dr_resource_prefix}-vnet"
  dr_vm_name        = "${local.dr_resource_prefix}-vm"
  
  # DR과 메인 리소스 매핑
  main_to_dr_mapping = {
    location     = var.dr_location
    vm_size      = var.dr_vm_size
    subnet_cidr  = var.dr_subnet_address_prefixes[0]
  }
  
  # 통합 태그 (공통 태그 + DR 태그)
  combined_dr_tags = merge(var.common_tags, var.dr_tags, {
    "DR-Pair"        = "${var.project_name}-main"
    "Created-By"     = "terraform"
    "Last-Updated"   = timestamp()
  })
}