variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID used to authenticate the provider"
}

variable "admin_password" {
  type        = string
  description = "Admin password for the virtual machine"
  sensitive   = true
}
