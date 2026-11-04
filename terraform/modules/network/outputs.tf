# Sorties du module network.

output "network_name" {
  description = "Nom du VPC."
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "Nom du sous-réseau."
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_id" {
  description = "ID du sous-réseau (utilisé par le module compute)."
  value       = google_compute_subnetwork.subnet.id
}

output "network_tag" {
  description = "Tag réseau à mettre sur les VM."
  value       = var.network_tag
}
