output "rg-name" {
  value = data.azurerm_resource_group.demo.name
}
output "rg-location" {
  value = data.azurerm_resource_group.demo.location
}

output "rg-id" {
  value = data.azurerm_resource_group.demo.id
}