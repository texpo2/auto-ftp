# 11_RoleAssignments.tf

# VM이 Storage Account에 접근할 수 있도록 권한 부여
resource "azurerm_role_assignment" "nsg_logs_reader" {
  scope                = azurerm_storage_account.nsg_logs.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id
  
  depends_on = [azurerm_linux_virtual_machine.vm]
}

resource "azurerm_role_assignment" "nsg_logs_blob_contributor" {
  scope                = azurerm_storage_account.nsg_logs.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id
  
  depends_on = [azurerm_linux_virtual_machine.vm]
}

resource "azurerm_role_assignment" "nsg_logs_blob_queue" {
  scope                = azurerm_storage_account.nsg_logs.id
  role_definition_name = "Storage Queue Data Reader"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id
  
  depends_on = [azurerm_linux_virtual_machine.vm]
}