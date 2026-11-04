# Sorties du module compute.

output "vm_names" {
  description = "Noms des VM."
  value       = google_compute_instance.vm[*].name
}

output "vm_public_ips" {
  description = "IP publique de chaque VM."
  value = {
    for vm in google_compute_instance.vm :
    vm.name => vm.network_interface[0].access_config[0].nat_ip
  }
}
