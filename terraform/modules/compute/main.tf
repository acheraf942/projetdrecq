# Module compute : les VM. Leur nombre vient de la variable vm_count.

resource "google_compute_instance" "vm" {
  count = var.vm_count

  # count.index commence à 0, d'où le + 1.
  name         = "${var.vm_name_prefix}-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  # Le tag sert au pare-feu, les labels servent à Ansible pour trouver les VM.
  tags   = [var.network_tag]
  labels = var.labels

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    subnetwork = var.subnet_id
    # Bloc vide = GCP donne une IP publique.
    access_config {}
  }

  # GCP crée l'utilisateur et autorise la clé SSH.
  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }
}
