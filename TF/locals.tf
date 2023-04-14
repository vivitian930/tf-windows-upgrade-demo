locals {
  assets_config = {
    for vm_yaml_file in try(fileset(path.module, "./assets/target_vm.yaml"), {}) :
    trimsuffix(basename(vm_yaml_file), ".yaml") => yamldecode(file(vm_yaml_file))
  }

  target_asset = local.assets_config.target_vm.poc

  vms = flatten([
    for key, value in local.target_asset : [
      for vm in value.virtual_machines : {
        virtual_machine_name = vm
        resource_group       = value.resource_group
        subscription_id      = value.subscription_id
      }
    ]
  ])

  json = jsonencode(local.vms)
}
