# Socle Web Automatisé — Fleet Info

Ce projet installe **automatiquement** un petit site web, « Fleet Info », sur plusieurs serveurs.
Une commande crée les serveurs, une commande installe le site, et si une mise à jour rate,
**on revient tout seul à l'ancienne version**.

> Pour les opérations courantes (mise à jour, mots de passe...) : [docs/RUNBOOKS.md](docs/RUNBOOKS.md).

---

## 1. Présentation

**Fleet Info** est une page qui affiche des infos sur le serveur qui l'héberge : son nom, son
adresse IP, son système, sa mémoire, la version du site et la date d'installation. Sur Google
Cloud, elle affiche aussi la zone et le type de machine.

| Adresse | Ce qu'elle affiche |
|---|---|
| `/` | La page Fleet Info |
| `/health` | « Tout va bien » + la version installée (sert à vérifier une mise à jour) |
| `/status` | Les statistiques du serveur web, **protégées par un mot de passe** |

**Ce qui est automatique :** la création des serveurs, leur installation, la mise à jour du site
et le retour en arrière en cas de problème.

**Ce qui reste manuel :** se connecter au compte Google du lab, et se transmettre le mot de passe
du coffre-fort (voir §3).

---

## 2. Architecture

Le projet fonctionne en **deux étapes** :

```
  ÉTAPE 1 : avoir des serveurs            ÉTAPE 2 : installer le site dessus

  En local  → Docker     (fausses machines sur ton PC)   ─┐
                                                           ├──▶  Ansible (même code)  ──▶  Fleet Info
  En cloud  → Terraform  (vraies machines chez Google)   ─┘
```

- **Docker** crée de fausses machines sur ton ordinateur : `node1`, `node2`, plus un
  `controller` qui contient Ansible.
- **Terraform** crée de vraies machines chez Google, avec leur réseau et leur pare-feu.
- **Ansible** se connecte aux machines (en SSH) et installe le site. **C'est le même code dans les
  deux cas** : seule la liste des machines change.

Ansible retrouve les machines Google grâce à une étiquette, `role=web`, que Terraform colle sur
chacune d'elles.

### Les dossiers

| Dossier | Contenu |
|---|---|
| `local/` | Les fausses machines (Docker) |
| `terraform/` | Les vraies machines chez Google |
| `ansible/` | Tout ce qu'on installe sur les machines (`site.yml` est le fichier principal) |
| `ansible/roles/` | Les 3 « rôles » : `common` (bases), `nginx` (serveur web), `fleetinfo` (le site) |
| `docs/` | Documentation complémentaire |

### Sur chaque serveur, après installation

```
/opt/fleetinfo/releases/1.0.0/   ← une version du site
/opt/fleetinfo/releases/1.1.0/   ← une autre version
/opt/fleetinfo/current           ← raccourci vers la version affichée
/var/log/fleetinfo/deploy.log    ← journal de chaque mise à jour
```

---

## 3. Prérequis et accès

**Pour le local, il suffit de [Docker Desktop](https://www.docker.com/products/docker-desktop/).**
Ansible est déjà dans le conteneur `controller`, rien d'autre à installer.

**Pour le cloud, il faut en plus :**
- **Terraform** (version 1.9 ou plus) : `brew install terraform` sur Mac ;
- **gcloud** (l'outil en ligne de commande de Google) ;
- un **lab Google Skills** démarré : il te prête un compte Google pour une durée limitée.


### Le mot de passe du coffre-fort (Vault)

Les mots de passe du projet sont rangés dans un fichier **chiffré** (`ansible/group_vars/all/vault.yml`).
Pour l'ouvrir, il faut une clé : le fichier `ansible/.vault_pass`.

- Cette clé n'est **jamais** mise dans Git. Demande-la à un membre de l'équipe par message privé.
- Pour la créer sur ton PC :
  ```bash
  echo 'LE_MOT_DE_PASSE_RECU' > ansible/.vault_pass
  ```
- **Envoie le projet par Git** (pas en .zip) : un .zip du dossier contiendrait ce mot de passe.

### Les contraintes du lab Google

| Contrainte | Valeur |
|---|---|
| Durée d'une session | *à noter lors du premier lab* |
| Région / zone autorisées | *à noter* (par défaut dans le code : `europe-west1-b`) |
| Types de machine autorisés | *à noter* (par défaut : `e2-small`) |
| Terraform sur le lab | Signalé comme ne fonctionnant pas encore (29/10/2026) |

---

## 4. Installer de zéro

### En local (environ 5 minutes)

Toutes les commandes se tapent dans le dossier `local/`.

```bash
cd local

# 1. Démarrer les machines (la première fois prend quelques minutes)
docker compose up -d --build

# 2. Vérifier qu'Ansible voit les 2 serveurs
docker compose exec controller ansible-inventory --graph
#    → doit afficher node1 et node2 sous « web »

# 3. Installer le site
docker compose exec controller ansible-playbook site.yml
#    → à la fin : failed=0 pour node1 et node2

# 4. Relancer : rien ne doit changer
docker compose exec controller ansible-playbook site.yml
#    → changed=0
```

Ouvre ensuite **http://localhost:8081** et **http://localhost:8082** : deux pages différentes,
une par serveur.

### Sur Google Cloud

```bash
# 1. Se connecter avec le compte DU LAB (pas ton compte perso)
gcloud auth login
gcloud auth application-default login
gcloud config set project <ID_DU_PROJET_DU_LAB>
gcloud services enable compute.googleapis.com

# 2. Créer une clé SSH (une seule fois)
ssh-keygen -t ed25519 -f ~/.ssh/fleet_gcp -N ''

# 3. Remplir les réglages
cd terraform
cp terraform.tfvars.example terraform.tfvars
curl -4 ifconfig.me          # affiche ton IP publique
#    → dans terraform.tfvars : mettre l'ID du projet et ton IP (suivie de /32)

# 4. Créer les machines
terraform init
terraform apply              # répondre « yes »
terraform plan               # → « No changes » : tout est conforme

# 5. Installer le site (même commande qu'en local, avec la liste des machines Google)
cd ../local
#    Ce 2e fichier donne au controller ta clé SSH et ton accès Google.
#    Sous Windows (PowerShell), tape d'abord : $env:HOME = $env:USERPROFILE
docker compose -f docker-compose.yml -f docker-compose.cloud.yml up -d
docker compose exec controller ansible-playbook -i inventories/cloud/fleet.gcp.yml site.yml

# 6. Voir les adresses des sites
cd ../terraform && terraform output fleetinfo_urls
```

**Avant la fin du lab :** `terraform destroy` pour tout supprimer.

---

## 5. Opérations courantes

Le détail de chaque opération est dans **[docs/RUNBOOKS.md](docs/RUNBOOKS.md)**. Voici l'essentiel :

| Je veux... | Je fais... |
|---|---|
| **Mettre une nouvelle version** | Changer `fleetinfo_version` dans `ansible/group_vars/all/vars.yml`, puis relancer `site.yml` |
| **Revenir à l'ancienne version** | Remettre l'ancien numéro dans `vars.yml`, puis relancer `site.yml` |
| **Ajouter un serveur (cloud)** | Changer `vm_count` dans `terraform.tfvars`, `terraform apply`, puis relancer `site.yml` |
| **Changer la configuration du serveur web** | Modifier `ansible/roles/nginx/`, puis `site.yml --tags nginx` |
| **Changer le mot de passe de `/status`** | `ansible-vault edit group_vars/all/vault.yml`, puis `site.yml --tags nginx` |
| **Vérifier qu'un serveur est conforme** | `site.yml --check --diff` → `changed=0` = conforme |
| **Tout supprimer** | Local : `docker compose down -v` · Cloud : `terraform destroy` |
| **Tester le retour en arrière** | `site.yml -e fleetinfo_version=1.2.0 -e fleetinfo_simulate_failure=true` |

---

## 6. Les réglages (variables)

### Ansible : les réglages importants

| Réglage | Où le changer | Valeur | À quoi il sert |
|---|---|---|---|
| `fleetinfo_version` | `ansible/group_vars/all/vars.yml` | `1.0.0` | **La version du site (le seul endroit à modifier)** |
| `nginx_status_user` | `ansible/group_vars/all/vars.yml` | `exploit` | Nom d'utilisateur de `/status` |
| `vault_nginx_status_password` | `ansible/group_vars/all/vault.yml` (chiffré) | secret | Mot de passe de `/status` |
| `fleet_env` | `ansible/inventories/local/` ou `cloud/` | `local` / `cloud` | Environnement affiché sur la page |
| `fleetinfo_simulate_failure` | en ligne de commande (`-e`) | `false` | Simule une panne pour la démo |

Les autres réglages de chaque rôle sont expliqués dans son README :
[common](ansible/roles/common/README.md) · [nginx](ansible/roles/nginx/README.md) ·
[fleetinfo](ansible/roles/fleetinfo/README.md).

### Terraform

**Outils utilisés** (versions fixées dans `terraform/versions.tf`) : Terraform 1.9 ou plus, le
provider `hashicorp/google` en version 8.9 et le provider `hashicorp/local` en version 2.5.

**Ce qui est créé chez Google :**

| Module | Ce qu'il crée |
|---|---|
| `modules/network` | Un réseau privé, un sous-réseau, et 2 règles de pare-feu : site (port 80) ouvert à tous, SSH (port 22) ouvert à ton IP seulement |
| `modules/compute` | Les machines Debian 12, avec leur étiquette `role=web` et la clé SSH |
| `inventory.tf` | Le fichier qui dit à Ansible où trouver les machines |

**Réglages** (à mettre dans `terraform.tfvars`) :

| Réglage | Obligatoire ? | Valeur par défaut | À quoi il sert |
|---|---|---|---|
| `project_id` | **oui** | — | L'ID du projet donné par le lab |
| `ssh_source_ranges` | **oui** | — | Ton IP, pour autoriser SSH (ouvrir à tout Internet est refusé) |
| `vm_count` | non | `2` | Nombre de machines |
| `region` / `zone` | non | `europe-west1` / `europe-west1-b` | Où créer les machines |
| `machine_type` | non | `e2-small` | Taille des machines |
| `image` | non | `debian-cloud/debian-12` | Système installé |
| `ssh_user` | non | `fleetadmin` | Nom de l'utilisateur SSH |
| `ssh_public_key_path` | non | `~/.ssh/fleet_gcp.pub` | Ta clé SSH publique |
| `labels` | non | `env=cloud, role=web, team=plateforme` | Étiquettes des machines |
| `network_name`, `subnet_name`, `subnet_cidr`, `network_tag`, `http_source_ranges`, `vm_name_prefix`, `ansible_inventory_path` | non | voir `variables.tf` | Noms et plages réseau |

Aucun réglage n'est secret : la clé SSH donnée à Google est la clé **publique**, qui peut être
partagée sans risque.

**Résultats affichés** par `terraform output` : noms des machines (`vm_names`), leurs IP
(`vm_public_ips`), les adresses des sites (`fleetinfo_urls`), les commandes SSH (`ssh_commands`),
le nom du réseau (`vpc_name`) et du sous-réseau (`subnet_name`).

---

## 7. Nos choix et pourquoi

| Choix | Pourquoi |
|---|---|
| **Des rôles écrits par nous** (pas de rôles tout faits de « Galaxy ») | Le besoin est simple, et on peut expliquer chaque ligne. |
| **Des conteneurs qui imitent des vraies machines** | Pour qu'Ansible les gère exactement comme les machines Google. |
| **`privileged: true` dans Docker** | Sans ça, le gestionnaire de services (systemd) ne démarre pas sous Docker Desktop. Acceptable uniquement en local. |
| **Ansible dans un conteneur** | Tout le monde a la même version, et ça marche aussi sous Windows. |
| **Les clés SSH créées au démarrage** | Aucune clé n'est jamais enregistrée dans Git. |
| **Les accès cloud dans un fichier à part** (`docker-compose.cloud.yml`) | En local, rien de personnel au PC (clés, compte Google) n'est donné au controller. |
| **La clé SSH donnée à Google via les « métadonnées »** | C'est la méthode la plus simple. En entreprise, on utiliserait plutôt « OS Login », plus sûr mais plus compliqué. |
| **L'état Terraform gardé sur le PC** | Le lab est temporaire, une seule personne déploie. En entreprise, on le partagerait dans un stockage Google. |
| **Une version = un dossier + un raccourci `current`** | Changer de version, ou revenir en arrière, revient à déplacer le raccourci : c'est instantané. |
| **nginx rechargé (reload) plutôt que redémarré** | La nouvelle configuration est appliquée sans couper les visiteurs, et elle est vérifiée avant (`nginx -t`). |
| **La date d'installation écrite une seule fois** | Sinon la page changerait à chaque passage, et relancer Ansible ne serait plus « sans effet ». |

---

## 8. En cas de problème

### Où regarder

| Quoi | Où |
|---|---|
| Historique des mises à jour | `/var/log/fleetinfo/deploy.log` sur le serveur |
| Erreurs du serveur web | `/var/log/nginx/fleetinfo.error.log` sur le serveur |
| Version affichée en ce moment | `curl http://localhost:8081/health` |

Pour ouvrir un terminal sur un serveur local : `docker exec -it fleet-node1 bash`

Pour voir le détail de ce que fait Ansible : ajouter `-vvv` à la fin de la commande.

### Problèmes connus

| Message d'erreur | Solution |
|---|---|
| `no vault secrets found` ou `vault-pass.sh returned non-zero` | Il manque le fichier `ansible/.vault_pass` (voir §3) |
| `Permission denied (publickey)` | `docker compose restart controller` |
| `/bin/sh^M: not found` au démarrage du controller | Fichier converti au format Windows : `docker compose build --no-cache controller` |
| `port is already allocated` (8081 ou 8082) | Un autre programme utilise ce port : le fermer, ou changer le port dans `local/docker-compose.yml` |
| Un conteneur `node` s'arrête tout seul | Redémarrer Docker Desktop, puis `docker compose up -d` |
| `default credentials were not found` (cloud) | Refaire `gcloud auth application-default login` |
| `Unable to parse fleet.gcp.yml` (cloud) | Lancer d'abord `terraform apply`, c'est lui qui crée ce fichier |
| Connexion SSH qui n'aboutit pas (cloud) | Ton IP a changé : la mettre à jour dans `terraform.tfvars`, puis `terraform apply` |
| `ECHEC_ROLLBACK` dans le journal | Normal si la mise à jour a raté : le site est resté sur l'ancienne version |

---

## 9. Limites connues

- **Le cloud n'a pas été testé sur de vraies machines**, car le lab ne permettait pas d'utiliser
  Terraform. Le code a seulement été vérifié avec `terraform validate`.
- **L'environnement local n'est pas sécurisé** comme une vraie production. Il sert seulement au
  développement.
- **Pas de HTTPS** : le mot de passe de `/status` circule en clair sur le réseau.
- **Les anciennes versions ne sont jamais supprimées** des serveurs.
- **Ce qu'on ferait ensuite :** ajouter le HTTPS, nettoyer les anciennes versions, partager
  l'état Terraform, et lancer les vérifications automatiquement à chaque modification du code.

### Vérifier la qualité du code

```bash
docker compose exec controller ansible-lint      # depuis local/ → 0 erreur
cd terraform && terraform validate               # → Success!
```
# projetdrecq
