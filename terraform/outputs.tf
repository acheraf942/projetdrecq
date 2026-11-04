# Infos affichées après « terraform apply » (ou avec « terraform output »).

output "vm_names" {
  description = "Noms des VM."
  value       = module.compute.vm_names
}

output "vm_public_ips" {
  description = "IP publique de chaque VM."
  value       = module.compute.vm_public_ips
}

output "fleetinfo_urls" {
  description = "Adresse du site sur chaque VM."
  value       = { for name, ip in module.compute.vm_public_ips : name => "http://${ip}/" }
}

output "ssh_commands" {
  description = "Commande pour se connecter en SSH à chaque VM."
  value       = { for name, ip in module.compute.vm_public_ips : name => "ssh -i ~/.ssh/fleet_gcp ${var.ssh_user}@${ip}" }
}

output "vpc_name" {
  description = "Nom du VPC."
  value       = module.network.network_name
}

output "subnet_name" {
  description = "Nom du sous-réseau."
  value       = module.network.subnet_name
}
