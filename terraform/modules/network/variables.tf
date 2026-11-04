# Variables du module network.

variable "network_name" {
  description = "Nom du VPC."
  type        = string
}

variable "subnet_name" {
  description = "Nom du sous-réseau."
  type        = string
}

variable "subnet_cidr" {
  description = "Plage d'adresses du sous-réseau."
  type        = string
}

variable "region" {
  description = "Région du sous-réseau."
  type        = string
}

variable "network_tag" {
  description = "Tag réseau visé par le pare-feu."
  type        = string
}

variable "ssh_source_ranges" {
  description = "Adresses autorisées en SSH."
  type        = list(string)
}

variable "http_source_ranges" {
  description = "Adresses autorisées en HTTP."
  type        = list(string)
}
