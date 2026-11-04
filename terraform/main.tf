# Appelle les deux modules. Le module compute reçoit le sous-réseau créé par le module network.

module "network" {
  source = "./modules/network"

  network_name       = var.network_name
  subnet_name        = var.subnet_name
  subnet_cidr        = var.subnet_cidr
  region             = var.region
  network_tag        = var.network_tag
  ssh_source_ranges  = var.ssh_source_ranges
  http_source_ranges = var.http_source_ranges
}

module "compute" {
  source = "./modules/compute"

  vm_count       = var.vm_count
  vm_name_prefix = var.vm_name_prefix
  machine_type   = var.machine_type
  zone           = var.zone
  image          = var.image
  subnet_id      = module.network.subnet_id
  network_tag    = module.network.network_tag
  labels         = var.labels
  ssh_user       = var.ssh_user
  # trimspace enlève le retour à la ligne de fin, sinon « plan » verrait une différence.
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}
