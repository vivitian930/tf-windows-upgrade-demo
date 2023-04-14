resource_group_name     = "rg-aue-winup-test-01"
resource_group_location = "australiaeast"

vm_name = "vmauewinuptst01"

os_image = {
  publisher = "MicrosoftWindowsServer"
  offer     = "WindowsServer"
  sku       = "2012-R2-Datacenter"
  version   = "latest"
  plan      = false
}
