variable "resource_group_name" {
  type = string
}

variable "resource_group_location" {
  type        = string
  description = "location of the resource group"
}

variable "vm_name" {
  type        = string
  description = "VM name"
}

variable "vm_size" {
  type        = string
  description = "size of the VM"
  default     = "Standard_D2s_v5"
}

variable "os_image" {
  description = "Details of the Image to be used to provison the Virtual Machine."
  type        = map(any)
  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
    plan      = false
  }
}

variable "vnet_addresses" {
  type        = list(string)
  description = "New Vnet Address space"
  default     = ["10.0.0.0/16"]
}

variable "subnet_cidr" {
  type        = list(string)
  description = "subnet cidr"
  default     = ["10.0.2.0/24"]
}
