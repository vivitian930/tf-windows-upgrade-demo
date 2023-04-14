resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

module "vm1" {
  source                  = "git::https://github.com/vivitian930/tf-azurerm-win-vm-poc.git?ref=v0.1.0"
  name                    = var.vm_name
  vnet_addresses          = var.vnet_addresses
  subnet_cidr             = var.subnet_cidr
  resource_group_name     = azurerm_resource_group.rg.name
  resource_group_location = azurerm_resource_group.rg.location
  vm_size                 = var.vm_size
  os_image                = var.os_image

}


resource "null_resource" "upgrade_os" {
  provisioner "local-exec" {
    command     = ".'${path.module}\\scripts\\upgrade_os_inplace.ps1' -JsonString '${local.json}' "
    interpreter = ["pwsh", "-Command"]
  }

  depends_on = [
    module.vm1
  ]
}
