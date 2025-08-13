/*
resource "azurerm_management_group_policy_assignment" "iso27001" {
  name                 = "iso27001-assignment"
  
  # 1. 실제 관리 그룹 ID로 변경
  management_group_id  = "/providers/Microsoft.Management/managementGroups/Contoso-MG" 
  
  # 2. 실제 정책 이니셔티브의 리소스 ID로 변경
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-4589-4e44-9042-8ad9616710e8"
  
  # 정책에 필요한 파라미터가 있다면 여기에 정의합니다.
  parameters = jsonencode({
    # 예: "logAnalytics" = "/subscriptions/..."
  })
}
*/
