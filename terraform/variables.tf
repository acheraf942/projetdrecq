# Variables du projet. Les valeurs sont dans terraform.tfvars (voir terraform.tfvars.example).

variable "project_id" {
  description = "ID du projet GCP donné par le lab."
  type        = string
}

variable "region" {
  description = "Région GCP."
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "Zone GCP des VM."
  type        = string
  default     = "europe-west1-b"
}

variable "network_name" {
  description = "Nom du réseau VPC."
  type        = string
  default     = "fleet-vpc"
}

variable "subnet_name" {
  description = "Nom du sous-réseau."
  type        = string
  default     = "fleet-subnet"
}

variable "subnet_cidr" {
  description = "Plage d'adresses du sous-réseau."
  type        = string
  default     = "10.10.0.0/24"
}

variable "network_tag" {
  description = "Tag réseau mis sur les VM, utilisé par le pare-feu."
  type        = string
  default     = "fleet-web"
}

variable "ssh_source_ranges" {
  description = "Adresses autorisées en SSH (votre IP en /32)."
  type        = list(string)

  validation {
    condition     = !contains(var.ssh_source_ranges, "0.0.0.0/0")
    error_message = "Ne pas ouvrir SSH à tout Internet : mettez votre IP en /32."
  }
}

variable "http_source_ranges" {
  description = "Adresses autorisées en HTTP."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vm_count" {
  description = "Nombre de VM."
  type        = number
  default     = 2
}

variable "vm_name_prefix" {
  description = "Début du nom des VM (fleet-web-1, fleet-web-2...)."
  type        = string
  default     = "fleet-web"
}

variable "machine_type" {
  description = "Type de machine."
  type        = string
  default     = "e2-small"
}

variable "image" {
  description = "Image du système."
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "ssh_user" {
  description = "Utilisateur SSH créé sur les VM."
  type        = string
  default     = "fleetadmin"
}

variable "ssh_public_key_path" {
  description = "Chemin de la clé SSH publique."
  type        = string
  default     = "~/.ssh/fleet_gcp.pub"
}

variable "labels" {
  description = "Labels des VM. Ansible utilise role=web pour les trouver."
  type        = map(string)
  default = {
    env  = "cloud"
    role = "web"
    team = "plateforme"
  }
}

variable "ansible_inventory_path" {
  description = "Fichier d'inventaire Ansible créé par Terraform."
  type        = string
  default     = "../ansible/inventories/cloud/fleet.gcp.yml"
}
