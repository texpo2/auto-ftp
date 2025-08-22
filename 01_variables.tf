# 기본 시스템 변수
variable "prodid" {
  type    = string
  default = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

variable "admin_password" {
  type    = string
  default = "It12345!"
}

# ==========================================
# 기본 환경 변수
# ==========================================

variable "environment" {
  description = "환경 구분 (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure 리전"
  type        = string
  default     = "Korea Central"
}

# ==========================================
# 네트워크 변수
# ==========================================

variable "vnet_address_space" {
  description = "VNet 주소 공간"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefixes" {
  description = "서브넷 주소 접두사"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

# ==========================================
# VM 관련 변수
# ==========================================

variable "vm_admin_username" {
  description = "VM 관리자 사용자명"
  type        = string
  default     = "azureuser"
}

variable "vm_admin_password" {
  description = "VM 관리자 비밀번호"
  type        = string
  sensitive   = true
  default     = null
}

# ==========================================
# 보안팀 연락처
# ==========================================

variable "security_admin_email" {
  description = "보안 관리자 이메일"
  type        = string
  default     = "security-admin@company.com"
}

variable "security_analyst_email" {
  description = "보안 분석가 이메일"
  type        = string
  default     = "security-analyst@company.com"
}

variable "security_oncall_phone" {
  description = "보안팀 긴급 연락처 (SMS)"
  type        = string
  default     = "01012345678"
}

# IT 운영팀 연락처
variable "it_admin_email" {
  description = "IT 관리자 이메일"
  type        = string
  default     = "it-admin@company.com"
}

# ==========================================
# 모니터링 및 알림 설정
# ==========================================

variable "slack_webhook_url" {
  description = "Slack 웹훅 URL (선택사항)"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "로그 보존 기간 (일)"
  type        = number
  default     = 90
}

variable "monitoring_level" {
  description = "모니터링 수준 (basic, standard, premium)"
  type        = string
  default     = "standard"
}

variable "enable_email_alerts" {
  description = "이메일 알림 활성화"
  type        = bool
  default     = true
}

variable "enable_sms_alerts" {
  description = "SMS 알림 활성화"
  type        = bool
  default     = true
}

variable "enable_webhook_alerts" {
  description = "웹훅 알림 활성화"
  type        = bool
  default     = false
}

# ==========================================
# 컴플라이언스
# ==========================================

variable "compliance_standards" {
  description = "적용할 컴플라이언스 표준"
  type        = list(string)
  default     = ["ISO27001", "KISA"]
}

# ==========================================
# 백업 및 프로젝트 관련 변수
# ==========================================

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "03-test"
}

variable "admin_email" {
  description = "관리자 이메일"
  type        = string
  default     = "323whadir@naver.com"
}

variable "admin_phone" {
  description = "관리자 전화번호"
  type        = string
  default     = "01012345678"
}

variable "common_tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {
    Environment = "dev"
    Project     = "03-test"
    Team        = "Team2"
  }
}
