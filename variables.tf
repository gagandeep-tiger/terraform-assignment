variable "prefix" {
  description = "Common prefixes for all resources"
  type = string
  default = "demo"
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
variable "ssh-access-ip" {
  description = "The ip address for ssh access"
  type = string
  default = "*"
}
