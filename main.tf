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
  backend_address_pool_name      = "${data.azurerm_virtual_network.demo.name}-beap"
  frontend_port_name             = "${data.azurerm_virtual_network.demo.name}-feport"
  frontend_ip_configuration_name = "${data.azurerm_virtual_network.demo.name}-feip"
  http_setting_name              = "${data.azurerm_virtual_network.demo.name}-be-htst"
  listener_name                  = "${data.azurerm_virtual_network.demo.name}-httplstn"
  request_routing_rule_name      = "${data.azurerm_virtual_network.demo.name}-rqrt"
  redirect_configuration_name    = "${data.azurerm_virtual_network.demo.name}-rdrcfg"
}

# Subnet
resource "azurerm_subnet" "demo-subnet1" {
  name                 = "${var.prefix}-subnet1"
  resource_group_name  = data.azurerm_resource_group.demo.name
  virtual_network_name = data.azurerm_virtual_network.demo.name
  address_prefixes     = ["10.0.0.0/24"]
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
  sku                 = "Standard_F2"
  instances           = 1
  admin_username      = "adminuser"

  # automatic rolling upgrade
  
  upgrade_mode = "Rolling"

  automatic_os_upgrade_policy {
    enable_automatic_os_upgrade = true
    disable_automatic_rollback = false
  }
  rolling_upgrade_policy {
    max_batch_instance_percent = 20
    max_unhealthy_instance_percent = 20
    max_unhealthy_upgraded_instance_percent = 5
    pause_time_between_batches = "PT0S"
  }
  

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
      load_balancer_backend_address_pool_ids = tolist(azurerm_application_gateway.demo-app-gateway.backend_address_pool.*.id)
    }
  }
}

# AutoScaleGroup
resource "azurerm_monitor_autoscale_setting" "demo" {
  name                = "${var.prefix}-scaleSetting-vmss1"
  resource_group_name = data.azurerm_resource_group.demo.name
  location            = data.azurerm_resource_group.demo.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.demo-vmss1.id

  profile {
    name = "default-working"

    capacity {
      default = 1
      minimum = 1
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.demo-vmss1.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        dimensions {
          name     = "AppName"
          operator = "Equals"
          values   = ["App1"]
        }
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.demo-vmss1.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

#   notification {
#     email {
#       send_to_subscription_administrator    = true
#       send_to_subscription_co_administrator = true
#       custom_emails                         = ["admin@contoso.com"]
#     }
#   }
}

resource "azurerm_network_security_group" "demo-nsg-vmss1" {
  name                = "${var.prefix}-demo-nsg-vmss1"
  location            = data.azurerm_resource_group.demo.location
  resource_group_name = data.azurerm_resource_group.demo.name

  security_rule {
    name                       = "Http"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
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
  location = data.azurerm_resource_group.demo.location
  resource_group_name = data.azurerm_resource_group.demo.name
  allocation_method = "Static"
  domain_name_label = "${var.prefix}-demo"
  tags = var.tags
}

resource "azurerm_application_gateway" "demo-app-gateway" {
  name                = "${var.prefix}-demo-app-gateway"
  resource_group_name = data.azurerm_resource_group.demo.name
  location            = data.azurerm_resource_group.demo.location

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
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

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 8080
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
  tags = var.tags
}
