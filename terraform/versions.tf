# Versions de Terraform et des providers (déclarées uniquement ici).
terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.9"
    }
    # Pour écrire le fichier d'inventaire Ansible.
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }

  # Le state reste en local (terraform.tfstate, pas dans Git) car le lab est temporaire.
  # En entreprise on le mettrait dans un bucket GCS pour le partager.
}
