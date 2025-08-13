resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = azurerm_key_vault.ftp_kv.id  
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id 
  depends_on = [
    azurerm_key_vault.ftp_kv,
    azurerm_linux_virtual_machine.vm
  ]
}

resource "azurerm_role_assignment" "kv_certificate_user" {
  scope                = azurerm_key_vault.ftp_kv.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id
  
  depends_on = [
    azurerm_key_vault.ftp_kv,
    azurerm_linux_virtual_machine.vm
  ]
}