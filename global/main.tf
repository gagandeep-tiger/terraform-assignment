# provider
terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = ">=3.0.0"
    }
  }
  backend "azurerm" {
    key = "global/storage/terraform.tfstate"
    resource_group_name = "mle-cloud-training"
    storage_account_name = "demowu89f"
    container_name = "demo-tfstate"
  }
}

provider "azurerm" {
    skip_provider_registration = true
    features {}
}

resource "random_string" "ran_gen" {
  length  = 5
  special = false
  upper   = false
}


resource "azurerm_storage_account" "demo-storage" {
  name                     = "${var.prefix}${random_string.ran_gen.result}"
  resource_group_name      = data.azurerm_resource_group.demo.name
  location                 = data.azurerm_resource_group.demo.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags
}

resource "azurerm_storage_container" "demo-container" {
  name                  = "${var.prefix}-tfstate"
  storage_account_name  = azurerm_storage_account.demo-storage.name
  container_access_type = "blob"
}

# resource "azurerm_storage_blob_inventory_policy" "example" {
#   storage_account_id = azurerm_storage_account.demo-storage.id
#   rules {
#     name                   = "rule1"
  
#     storage_container_name = azurerm_storage_container.demo-container.name
#     format                 = "Csv"
#     schedule               = "Daily"
#     scope                  = "Blob"
#     schema_fields = [
#       "Name",
#       "Creation-Time",
#       "Last-Modified",
#       "IsCurrentVersion",
#       "VersionId"
#     ]
#     filter {
#       blob_types = [ "blockBlob" ]
#       include_blob_versions = true
#     }
#   }
# }