# Security Center 설정을 주석 처리 (이미 subscription 레벨에서 설정됨)
# resource "azurerm_security_center_subscription_pricing" "vm" {
#   tier          = "Standard"
#   resource_type = "VirtualMachines"
#   
#   # 기존 Security Center 설정과의 충돌 방지
#   lifecycle {
#     ignore_changes = [tier]
#   }
# }

/*
resource "azurerm_security_center_setting" "main" {
  setting_name   = "MCAS"
  enabled        = true
}
*/
