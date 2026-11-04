# Crée le fichier d'inventaire Ansible à partir du modèle.
# Le plugin GCP a besoin de l'ID du projet dans le fichier, et cet ID change à chaque lab :
# Terraform l'écrit donc pour nous. Le fichier n'est pas dans Git.
resource "local_file" "ansible_inventory" {
  filename        = var.ansible_inventory_path
  file_permission = "0644"
  content = templatefile("${path.module}/../ansible/inventories/cloud/fleet.gcp.yml.tftpl", {
    project_id = var.project_id
    zone       = var.zone
    role       = var.labels["role"]
    env        = var.labels["env"]
  })
}
