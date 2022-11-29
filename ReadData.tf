data "azurerm_resource_group" "demo" {
  name  = "mle-cloud-training"
}

data "azurerm_virtual_network" "demo" {
  name = "mlecloudtraining-vnet"
  resource_group_name = data.azurerm_resource_group.demo.name
}

data "template_file" "install-nginx" {
  template = file("commands.sh")
}

data "template_file" "install-apache" {
  template = file("commands-apa.sh")
}