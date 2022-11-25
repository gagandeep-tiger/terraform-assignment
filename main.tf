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
  name     = "demo-resources"
  location = "West Europe"
  tags = {
    "created_by" = "gagandeep.prasad@tigeranalytics.com"
    "created_for" = "terraform-assignments"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "demo" {
  name                = "demo-VNet1"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  tags = {
    "created_by" = "gagandeep.prasad@tigeranalytics.com"
    "created_for" = "terraform-assignments"
  }
}

# Subnet
resource "azurerm_subnet" "demo-subnet1" {
  name                 = "demo-subnet1"
  resource_group_name  = azurerm_resource_group.demo.name
  virtual_network_name = azurerm_virtual_network.demo.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Public IP
resource "azurerm_public_ip" "demo-pubip1" {
  name = "demo-pubip1"
  resource_group_name = azurerm_resource_group.demo.name
  location = azurerm_resource_group.demo.location
  allocation_method = "Static"
  domain_name_label = "demo-site"
  tags = {
    "created_by" = "gagandeep.prasad@tigeranalytics.com"
    "created_for" = "terraform-assignments"
  }
}

# NIC
resource "azurerm_network_interface" "demo-nic1" {
  name                = "demo-nic1"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.demo-subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = {
    "created_by" = "gagandeep.prasad@tigeranalytics.com"
    "created_for" = "terraform-assignments"
  }
}

# Linux VM
resource "azurerm_linux_virtual_machine" "demo-machine1" {
  name                = "demo-machine1"
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
              nohup busybox httpd -f -p 8080 &
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
  tags = {
    "created_by" = "gagandeep.prasad@tigeranalytics.com"
    "created_for" = "terraform-assignments"
  }
}

# NSG
resource "azurerm_network_security_group" "demo-NSG1" {
  name                = "demo-NSG1"
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name

  security_rule {
    name                       = "Http"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "8080"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    "created_by" = "gagandeep.prasad@tigeranalytics.com"
    "created_for" = "terraform-assignments"
  }
}

resource "azurerm_network_interface_security_group_association" "demo-nic-nsg-assoc" {
  network_interface_id      = azurerm_network_interface.demo-nic1.id
  network_security_group_id = azurerm_network_security_group.demo-NSG1.id
}