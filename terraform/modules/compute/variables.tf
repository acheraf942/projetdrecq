# Variables du module compute.

variable "vm_count" {
  description = "Nombre de VM."
  type        = number
}

variable "vm_name_prefix" {
  description = "Début du nom des VM."
  type        = string
}

variable "machine_type" {
  description = "Type de machine."
  type        = string
}

variable "zone" {
  description = "Zone des VM."
  type        = string
}

variable "image" {
  description = "Image du système."
  type        = string
}

variable "subnet_id" {
  description = "ID du sous-réseau (donné par le module network)."
  type        = string
}

variable "network_tag" {
  description = "Tag réseau des VM."
  type        = string
}

variable "labels" {
  description = "Labels des VM."
  type        = map(string)
}

variable "ssh_user" {
  description = "Utilisateur SSH."
  type        = string
}

variable "ssh_public_key" {
  description = "Contenu de la clé SSH publique."
  type        = string
}
