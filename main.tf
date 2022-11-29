# Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
    skip_provider_registration = true
  features {}
}

locals {
  listener_name                  = "${data.azurerm_virtual_network.demo.name}-httplstn"
  frontend_port_name             = "${data.azurerm_virtual_network.demo.name}-feport"
  frontend_ip_configuration_name = "${data.azurerm_virtual_network.demo.name}-feip"
  request_routing_rule_name      = "${data.azurerm_virtual_network.demo.name}-rqrt"

  backend_address_pool_name_app1 = "${data.azurerm_virtual_network.demo.name}-beap_app1"
  http_setting_name_app1         = "${data.azurerm_virtual_network.demo.name}-be-htst_app1"
  prob_name_app1                 = "${data.azurerm_virtual_network.demo.name}-be-probe_app1"
}

# Subnet
resource "azurerm_subnet" "demo-subnet1" {
  name                 = "${var.prefix}-subnet1"
  resource_group_name  = data.azurerm_resource_group.demo.name
  virtual_network_name = data.azurerm_virtual_network.demo.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Subnet for APP gateway
resource "azurerm_subnet" "demo-subnet2" {
  name                 = "${var.prefix}-subnet2"
  resource_group_name  = data.azurerm_resource_group.demo.name
  virtual_network_name = data.azurerm_virtual_network.demo.name
  address_prefixes     = ["10.0.2.0/24"]
}

# VMSS
resource "azurerm_linux_virtual_machine_scale_set" "demo-vmss1" {
  name                = "${var.prefix}-vmss1"
  resource_group_name = data.azurerm_resource_group.demo.name
  location            = data.azurerm_resource_group.demo.location
  sku                 = "Standard_D2s_v3"
  instances           = 2 
  admin_username      = "adminuser"

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("demo-ssh.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  custom_data = base64encode(data.template_file.install-nginx.rendered)
  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "NIC-vmss1"
    primary = true
    network_security_group_id = azurerm_network_security_group.demo-nsg-vmss1.id

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.demo-subnet1.id
      application_gateway_backend_address_pool_ids = tolist(azurerm_application_gateway.demo-app-gateway.backend_address_pool.*.id)
    }
  }
}

resource "azurerm_network_security_group" "demo-nsg-vmss1" {
  name                = "${var.prefix}-nsg-vmss1"
  location            = data.azurerm_resource_group.demo.location
  resource_group_name = data.azurerm_resource_group.demo.name

  security_rule {
    name                       = "Http"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh-access-ip
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_public_ip" "demo-pubip1" {
  name = "${var.prefix}-pubip1"
  sku = "Standard"
  location = data.azurerm_resource_group.demo.location
  resource_group_name = data.azurerm_resource_group.demo.name
  allocation_method = "Static"
  domain_name_label = "${var.prefix}-demo"
  tags = var.tags
}

resource "azurerm_application_gateway" "demo-app-gateway" {
  name                = "${var.prefix}-app-gateway"
  resource_group_name = data.azurerm_resource_group.demo.name
  location            = data.azurerm_resource_group.demo.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    # capacity = 1
  }

  autoscale_configuration {
    min_capacity = 0
    max_capacity = 10
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.demo-subnet2.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.demo-pubip1.id
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  # APP1 configs
  backend_address_pool {
    name = local.backend_address_pool_name_app1
  }

  backend_http_settings {
    name                  = local.http_setting_name_app1
    cookie_based_affinity = "Disabled"
    # path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
    probe_name = local.prob_name_app1
  }

  probe {
    name = local.prob_name_app1
    host = "127.0.0.1"
    interval = 30
    timeout = 30
    unhealthy_threshold = 3
    protocol = "Http"
    port = 80
    path = "/"
    # match //TODO: Lets see!!
  }

  request_routing_rule {
    priority = 1
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name_app1
    backend_http_settings_name = local.http_setting_name_app1
  }
  tags = var.tags
}