# -------------------------------------------
# Terraform: FTP 접속 탐지 & Sentinel 기반 구성
# -------------------------------------------

# 01_RandomString.tf
resource "random_string" "suffix" {
  length  = 6  # 길이를 8에서 6으로 단축하여 이름 충돌 방지
  special = false
  upper   = false
  numeric = true
}