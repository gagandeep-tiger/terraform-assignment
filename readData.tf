data "azurerm_resource_group" "demo" {
  name  = "mle-cloud-training"
}

data "azurerm_virtual_network" "demo" {
  name = "mlecloudtraining-vnet"
  resource_group_name = data.azurerm_resource_group.demo.name
}