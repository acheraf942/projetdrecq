# Connexion à Google Cloud. Les identifiants viennent de « gcloud auth application-default login ».
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
