resource "azurerm_logic_app_workflow" "security_response" {
  name                = "security-incident-response"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_monitor_action_group" "security_alerts" {
  name                = "security-alerts-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "secalerts"
}