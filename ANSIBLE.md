# 1. Exigences Ansible

Chaque mécanisme ci-dessous est **obligatoire**. Pour chacun : ce qui est attendu, et comment
l'examinateur le vérifiera.

## 1.1 Playbooks — idempotents, simples, commentés, structurés

**Attendu :**

- un playbook d'entrée `site.yml` qui orchestre l'ensemble en appelant des rôles
- des playbooks **courts** : la logique est dans les rôles, pas dans les playbooks ;
- chaque play et chaque tâche porte un `name` explicite ; les choix non évidents sont commentés ;
- modules en nom complet (FQCN : `ansible.builtin.template`, `ansible.builtin.apt`…) ;
- module `command` / `shell` à éviter sauf absence de module dédié, et dans ce cas rendus idempotents
  (`changed_when`) avec un commentaire justifiant leur usage ;
- `ansible-lint` sans erreur.

**Vérification :**

- `ansible-playbook site.yml --check --diff` s'exécute sans erreur ;
- **un deuxième passage de `site.yml` affiche `changed=0`** sur tous les hôtes, en local comme
  sur le cloud.

## 1.2 Rôles — idempotents et documentés

**Attendu :** au minimum trois rôles aux responsabilités distinctes, par exemple :

| Rôle | Responsabilité |
|---|---|
| `common` | Socle de tout serveur : paquets de base, fuseau horaire, utilisateur d'exploitation, bannière de connexion… |
| `nginx` (ou `webserver`) | Installation et configuration du serveur web, site applicatif, page `/status` protégée. |
| `fleetinfo` | Déploiement versionné de l'application, contrôle de santé, retour arrière. |

Pour **chaque** rôle :

- une arborescence standard (`tasks/`, `handlers/`, `templates/`, `defaults/`, `vars/`, `meta/`) ;
- un `README.md` : objectif, variables (nom, défaut, description), dépendances, exemple
  d'utilisation ;
- un `meta/main.yml` renseigné (bonus : `meta/argument_specs.yml` pour valider les variables
  d'entrée).

**Rôles publics (Ansible Galaxy) :** autorisés pour les rôles d'infrastructure (`common`,
`nginx`), **interdits pour `fleetinfo`** qui doit être écrit par l'équipe. Tout rôle public doit
être :

- déclaré avec une **version épinglée** dans `requirements.yml` ;
- **justifié** dans la documentation : pourquoi ce rôle plutôt qu'un rôle maison, état de
  maintenance, licence, compatibilité avec Debian 12, variables surchargées, risques identifiés.

**Vérification :** chaque rôle peut être lu et compris sans ouvrir les autres ; un rôle rejoué
seul est idempotent.

## 1.3 Variables — bien placées, documentées, chiffrées si nécessaire

**Attendu :**

- chaque variable est définie **au bon niveau** et ce choix est cohérent avec la précédence
  Ansible :
  - `roles/<rôle>/defaults/main.yml` : valeurs par défaut surchargeables, préfixées par le nom du
    rôle (`fleetinfo_version`, `nginx_listen_port`…) ;
  - `roles/<rôle>/vars/main.yml` : constantes internes au rôle, non destinées à être surchargées ;
  - `inventories/<env>/group_vars/` : ce qui varie selon l'environnement (`local` / `cloud`) ou
    le groupe d'hôtes ;
  - pas de variables métier codées dans les playbooks ;
- chaque variable est **documentée** (commentaire à côté de sa définition + tableau dans le README
  du rôle) ;
- les **secrets** (au minimum le mot de passe de la page `/status`) sont chiffrés avec
  **Ansible Vault** :
  - fichier `vault.yml` chiffré, variables préfixées `vault_` et référencées depuis un `vars.yml`
    en clair, pour que le nom de chaque variable reste lisible sans déchiffrer ;
    
    ```yaml
    # group_vars/all/vault.yml (chiffré)
    vault_nginx_status_password: "MotDePasseSecret123"
    ```
    ```yaml
    # group_vars/all/vars.yml (non chiffré)
    nginx_status_password: "{{ vault_nginx_status_password }}"
    ```

  - mot de passe Vault **jamais committé** (`.gitignore`) ; la documentation explique comment le
    consultant le récupère et comment changer le mot de passe (`ansible-vault rekey`) ;
  - `no_log: true` sur les tâches qui manipulent un secret.

**Vérification :** `git grep` sur le mot de passe ne trouve rien ; changer la version de
l'application ne demande de modifier qu'une seule variable, à un seul endroit.

## 1.4 Templates — générés dynamiquement, identifiables sur le serveur

**Attendu :** au minimum les templates Jinja2 suivants :

- la configuration du site nginx ;
- la page d'accueil de Fleet Info ;
- la réponse de l'endpoint `/health`.

Chaque template :

- produit un fichier qui commence par un en-tête `{{ ansible_managed }}` (ou équivalent adapté au
  format), **pour qu'un administrateur qui ouvre le fichier sur le serveur sache immédiatement
  qu'il ne doit pas le modifier à la main** et d'où il provient ;
- est rangé dans `templates/` avec une convention de nommage claire (`<fichier cible>.j2`) ;
- exploite réellement le moteur de templates : *facts*, conditions (champs cloud présents ou non), filtres (`default`,
  `human_readable`…).

**Vérification :** l'examinateur se connecte sur un serveur, ouvre les fichiers générés et doit
retrouver l'en-tête ; deux serveurs différents affichent deux pages différentes.

## 1.5 Handlers — recharger ou redémarrer seulement quand c'est nécessaire

**Attendu :**

- les handlers doivent avoir être nommés de manière clair et parlante.
- un changement de configuration nginx déclenche un **rechargement** (`reloaded`) ; un
  redémarrage (`restarted`) n'est utilisé que lorsqu'il est réellement nécessaire, et ce choix est
  expliqué ;
- la configuration est **validée** (`nginx -t`) avant d'être rechargée : une configuration
  invalide ne doit jamais être appliquée ;
- les handlers ne s'exécutent que si une tâche a effectivement changé quelque chose ;

**Vérification :** modifier une variable qui n'affecte que la page d'accueil ne recharge pas
nginx ; modifier le port ou la configuration du site le recharge ; un deuxième passage ne
déclenche aucun handler.

## 1.6 Blocks — regrouper le déploiement et revenir en arrière en cas d'échec

**Attendu :** le déploiement de l'application dans le rôle `fleetinfo` est construit autour d'un
`block` / `rescue` / `always` :

- **`block`** : préparer le répertoire de la nouvelle release, y générer les fichiers, basculer
  le lien `current` vers la nouvelle version, recharger ce qui doit l'être, puis **vérifier
  `/health`** (module `ansible.builtin.uri`) et contrôler que la version renvoyée est bien celle
  attendue ;
- **`rescue`** : rebasculer `current` vers la version précédente (qu'il faut donc avoir mémorisée
  avant la bascule), recharger le service, vérifier que le service répond de nouveau, puis faire
  **échouer explicitement** le play avec un message clair (le déploiement a échoué, la version N-1
  est restaurée) ;
- **`always`** : tracer chaque tentative de déploiement (date, version demandée, résultat) dans
  un journal sur le serveur, par exemple `/var/log/fleetinfo/deploy.log`.

Vous devez fournir un **moyen documenté de provoquer un échec** de déploiement pour la
démonstration (par exemple `-e fleetinfo_simulate_failure=true`, ou une release volontairement
cassée), et prouver que :

1. le rollback se déclenche ;
2. le site reste en ligne avec l'ancienne version ;
3. un nouveau déploiement d'une version saine fonctionne ensuite normalement.

Les `block` peuvent aussi être utilisés ailleurs pour factoriser `become`, `when` sur
un groupe de tâches.

## 1.7 Collections — inventaire dynamique Compute Engine

**Attendu :**

- un fichier `requirements.yml` qui déclare les collections utilisées, **versions épinglées**, au
  minimum `google.cloud` (et, le cas échéant, `community.general`, `ansible.posix`…), installables
  en une commande (`ansible-galaxy install -r requirements.yml`) ;
- un inventaire dynamique `inventories/cloud/<nom>.gcp.yml` qui utilise le plugin
  `google.cloud.gcp_compute` :
  - sélection des VM par **filtre** sur les labels ou le tag réseau posés par Terraform (aucune IP
    écrite à la main) ;
  - `compose` pour construire `ansible_host` (IP publique) et les paramètres de connexion ;
  - `keyed_groups` et/ou `groups` pour produire **les mêmes noms de groupes** que l'inventaire
    local (par exemple `web`) ;
  - le `project_id` n'est pas écrit en dur dans un fichier versionné (variable d'environnement,
    fichier non versionné généré depuis les outputs Terraform…) ;

**Vérification :** `ansible-inventory --graph` affiche toutes les VM créées par Terraform dans les
bons groupes ; passer de 2 à 3 VM côté Terraform suffit à ce qu'Ansible configure la troisième,
**sans modifier une seule ligne de code Ansible**.