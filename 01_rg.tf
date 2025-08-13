# Resource Group X
resource "azurerm_resource_group" "rg" {
  name     = "03-team2-rg"
  location = var.location

  tags = var.common_tags
}
