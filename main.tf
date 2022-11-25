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

# Resource Group
resource "azurerm_resource_group" "demo" {
  name     = "${var.prefix}-resources"
  location = var.rg-location
  tags = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "demo" {
  name                = "${var.prefix}-VNet1"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  tags = var.tags
}

# Subnet
resource "azurerm_subnet" "demo-subnet1" {
  name                 = "${var.prefix}-subnet1"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Public IP
resource "azurerm_public_ip" "demo-pubip1" {
  name = "${var.prefix}-pubip1"
  resource_group_name = azurerm_resource_group.demo.name
  location = azurerm_resource_group.demo.location
  allocation_method = "Static"
  domain_name_label = "demo-site"
  tags = var.tags
}

# NIC
resource "azurerm_network_interface" "demo-nic1" {
  name                = "${var.prefix}-nic1"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo-subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = var.tags
}

# Linux VM
resource "azurerm_linux_virtual_machine" "demo-machine1" {
  name                = "${var.prefix}-machine1"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.demo-nic1.id,
  ]
  
  custom_data = base64encode(<<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
  )
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("demo-ssh.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  tags = var.tags
}

# NSG
resource "azurerm_network_security_group" "demo-NSG1" {
  name                = "${var.prefix}-NSG1"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  security_rule {
    name                       = "Http"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = var.server_port
    destination_port_range     = var.server_port
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "demo-nic-nsg-assoc" {
  network_interface_id      = azurerm_network_interface.demo-nic1.id
  network_security_group_id = azurerm_network_security_group.demo-NSG1.id
}