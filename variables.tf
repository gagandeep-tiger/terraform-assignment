variable "prefix" {
  description = "Common prefixes for all resources"
  type = string
  default = "demo"
}

variable "rg-location" {
  description = "Location where resource will be created"
  type = string
  default = "eastus"
}

variable "tags" {
  description = "tags for resources created"
  type = map(string)
  default = {
    "created_by" = "gagandeep.prasad@tigeranalytics.com"
    "created_for" = "terraform-practices"
  }    
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type = string
  default = "8080"
}
