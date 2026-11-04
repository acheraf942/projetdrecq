# Module network : le réseau, le sous-réseau et le pare-feu.

resource "google_compute_network" "vpc" {
  name = var.network_name
  # On crée notre propre sous-réseau au lieu d'en avoir un automatique par région.
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Port 80 ouvert pour le site. La règle ne vise que les VM avec notre tag.
resource "google_compute_firewall" "allow_http" {
  name    = "${var.network_name}-allow-http"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = var.http_source_ranges
  target_tags   = [var.network_tag]
}

# Port 22 ouvert seulement depuis notre IP (pour Ansible).
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.network_name}-allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = [var.network_tag]
}
