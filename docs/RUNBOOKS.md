# Runbooks

Les opérations courantes. Les commandes se lancent depuis le dossier `local/`.

En local :
```bash
docker compose exec controller ansible-playbook site.yml
```
Sur le cloud, on ajoute l'inventaire GCP (et le controller doit avoir été démarré avec
`docker compose -f docker-compose.yml -f docker-compose.cloud.yml up -d`) :
```bash
docker compose exec controller ansible-playbook -i inventories/cloud/fleet.gcp.yml site.yml
```

Dans la suite, on écrit seulement la version locale.

---

## 1. Déployer une nouvelle version

1. Dans `ansible/group_vars/all/vars.yml`, changer `fleetinfo_version` (ex. `"1.1.0"`).
2. Lancer :
   ```bash
   docker compose exec controller ansible-playbook site.yml --tags fleetinfo
   ```

**Vérifier :** `curl http://localhost:8081/health` affiche la nouvelle version.

Si le déploiement échoue, l'ancienne version est remise automatiquement et le play s'arrête avec
le message « Le déploiement de la version X a échoué. Retour à la version Y. »

**Tester le rollback :**
```bash
docker compose exec controller ansible-playbook site.yml -e fleetinfo_version=1.2.0 -e fleetinfo_simulate_failure=true
curl http://localhost:8081/health                         # toujours l'ancienne version
docker exec fleet-node1 tail -1 /var/log/fleetinfo/deploy.log   # resultat=ECHEC_ROLLBACK
```
Il faut demander une version différente de celle qui est en ligne.

---

## 2. Revenir à une version précédente

1. Remettre l'ancien numéro dans `ansible/group_vars/all/vars.yml`.
2. Lancer `site.yml --tags fleetinfo`.

**Vérifier :** `/health` affiche l'ancienne version.

En urgence, directement sur le serveur :
```bash
sudo ln -sfn /opt/fleetinfo/releases/1.0.0 /opt/fleetinfo/current
```
Penser ensuite à remettre `vars.yml` à jour.

---

## 3. Ajouter ou retirer un serveur

**Cloud :**
1. Dans `terraform/terraform.tfvars`, changer `vm_count` (ex. `3`).
2. `terraform apply`
3. Lancer `site.yml` avec l'inventaire cloud. Rien à changer dans Ansible.

**Vérifier :** `docker compose exec controller ansible-inventory -i inventories/cloud/fleet.gcp.yml --graph`
affiche la nouvelle VM.

Pour retirer un serveur, on baisse `vm_count` : c'est la VM avec le plus grand numéro qui est supprimée.

**Local :**
1. Dans `local/docker-compose.yml`, copier le bloc `node2` en `node3` (port `8083:80`).
2. Dans `ansible/inventories/local/hosts.yml`, ajouter `node3`.
3. `docker compose up -d`, puis `site.yml`.

---

## 4. Modifier la configuration du serveur web

1. Changer une variable dans `ansible/roles/nginx/defaults/main.yml`, ou le fichier
   `ansible/roles/nginx/templates/fleetinfo.conf.j2`.
2. Voir ce qui va changer sans rien appliquer :
   ```bash
   docker compose exec controller ansible-playbook site.yml --tags nginx --check --diff
   ```
3. Appliquer : la même commande sans `--check --diff`.

**Vérifier :** les handlers « Vérifier la configuration nginx » puis « Recharger nginx » s'exécutent.
Si la config est fausse, `nginx -t` échoue et nginx n'est pas rechargé.

Attention : si on change le port, il faut aussi changer les ports dans `docker-compose.yml`
(local) ou le pare-feu dans `terraform/modules/network` (cloud).

---

## 5. Changer les mots de passe

**Mot de passe de `/status` :**
```bash
docker compose exec controller ansible-vault edit group_vars/all/vault.yml
docker compose exec controller ansible-playbook site.yml --tags nginx
```
**Vérifier :** http://localhost:8081/status accepte le nouveau mot de passe (utilisateur `exploit`).

**Mot de passe du Vault :**
```bash
docker compose exec controller ansible-vault rekey group_vars/all/vault.yml   # demande le nouveau mot de passe
echo 'NOUVEAU_MOT_DE_PASSE' > ../ansible/.vault_pass
```
Puis envoyer le nouveau mot de passe à l'équipe par message privé.

**Vérifier :** `docker compose exec controller ansible-vault view group_vars/all/vault.yml` marche.

---

## 6. Vérifier qu'un serveur est conforme

```bash
docker compose exec controller ansible-playbook site.yml --check --diff
```
- `changed=0` : le serveur est conforme.
- sinon : le `--diff` montre ce qui est différent. Relancer `site.yml` pour corriger.

Voir le journal des déploiements :
```bash
docker exec fleet-node1 cat /var/log/fleetinfo/deploy.log
```

---

## 7. Tout supprimer

**Cloud :**
```bash
cd terraform
terraform destroy
```
**Vérifier :** `gcloud compute instances list` ne montre plus de VM.

**Local :**
```bash
docker compose down -v
```
**Vérifier :** `docker ps -a | grep fleet` ne renvoie rien.
