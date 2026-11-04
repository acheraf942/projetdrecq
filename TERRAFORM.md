# 1. Exigences Terraform

Chaque mécanisme ci-dessous est **obligatoire**. Pour chacun : ce qui est attendu, et comment
l'examinateur le vérifiera.

## 1.1 Variables — tous les arguments variabilisés, bien déclarées, bien placées

**Attendu :**

- aucune valeur codée en dur dans les arguments d'une `resource` ou d'un `module` : `project_id`,
  région, zone, type de machine, plages CIDR, noms… passent systématiquement par une variable ;
- chaque variable est déclarée dans un fichier `variables.tf` dédié — à la racine du projet pour
  les variables globales, et dans chaque module pour ses propres variables d'entrée. Pas de bloc
  `variable` éparpillé dans `main.tf` ou ailleurs ;
- chaque variable renseigne un `type` et une `description` ; un `default` n'est fourni que pour
  les valeurs réellement optionnelles (pas pour `project_id`, qui change à chaque session de lab) ;
- toute variable qui porte une donnée sensible (mot de passe, token, clé) est déclarée avec
  `sensitive = true`, pour qu'elle n'apparaisse jamais en clair dans la sortie de `plan` /
  `apply` ni dans les journaux CI.

**Vérification :** une relecture du code ne trouve aucune valeur métier en dur dans un bloc
`resource` ou `module` ; `terraform plan` sur une variable sensible affiche `(sensitive value)` et
non la valeur réelle.

## 1.2 Valeurs d'entrée — `terraform.tfvars`

**Attendu :**

- les valeurs concrètes — celles qui changent d'une session de lab à l'autre (`project_id`,
  région, zone, nombre de VM…) — sont fournies via un fichier `terraform.tfvars`, jamais codées
  dans `variables.tf` ni dans un module ;
- un `terraform.tfvars.example` (sans valeur réelle, avec des valeurs d'exemple ou vides) est
  committé comme modèle ; le vrai `terraform.tfvars` est ignoré par `.gitignore`.

**Vérification :** `git grep` sur un identifiant réel de projet GCP ne remonte rien dans
l'historique ; `terraform plan -var-file=terraform.tfvars` fonctionne sans variable manquante.

## 1.3 Providers — `versions.tf`

**Attendu :**

- le ou les providers utilisés (`google`, et par exemple `random` si vous générez un suffixe de
  nom) sont déclarés dans un **unique** fichier `versions.tf`, dans un bloc `terraform` avec
  `required_providers` et une contrainte de version épinglée (`~>`) pour chacun ;
- la version minimale de Terraform lui-même y est également fixée avec `required_version` ;
- la configuration du provider elle-même (`provider "google" { project = ... }`) peut rester dans
  `versions.tf` ou être séparée, mais la **déclaration des providers et de leurs versions** ne vit
  qu'à cet endroit : pas de second `required_providers` ailleurs dans le projet.

**Vérification :** `terraform init` s'exécute sans avertissement de version ; `required_providers`
n'apparaît qu'une fois dans le dépôt, dans `versions.tf`.

## 1.4 Outputs — `outputs.tf`

**Attendu :**

- tous les outputs sont déclarés dans un fichier `outputs.tf` dédié — à la racine du projet, et
  exposés par chaque module pour ce qui doit remonter plus haut ;
- au minimum : l'adresse IP publique de chaque VM, le nom du réseau VPC et le nom du sous-réseau —
  et plus généralement toute valeur utile à l'exploitation (noms des VM, URL de la page
  d'accueil…) ;
- chaque output porte une `description` ; un output qui expose une donnée sensible est marqué
  `sensitive = true`.

**Vérification :** après `terraform apply`, `terraform output` affiche l'IP, le nom du VPC et le
nom du sous-réseau sans avoir à aller les chercher dans la console GCP.

## 1.5 Modules — VPC, sous-réseau et VM en modules réutilisables

**Attendu :**

- les ressources principales — réseau VPC, sous-réseau, instance(s) Compute Engine — ne sont pas
  déclarées directement dans le `main.tf` racine, mais encapsulées dans des **modules Terraform**
  locaux, rangés dans un dossier `modules/` du dépôt (par exemple `modules/network/` et
  `modules/compute/`) ;
- chaque module expose ses propres `variables.tf` (ce qu'il reçoit en entrée) et `outputs.tf` (ce
  qu'il remonte à la racine), et reste utilisable indépendamment : pas de référence directe à une
  ressource d'un autre module par son adresse complète ;
- le code racine (`main.tf`) se limite à instancier les modules et à relier leurs outputs à leurs
  variables (par exemple : le module VM reçoit l'ID du sous-réseau en sortie du module réseau).

**Vérification :** l'examinateur retrouve dans `modules/` un module par responsabilité (réseau,
VM) ; passer de 2 à 3 VM ne demande de modifier qu'une variable passée au module `compute`, jamais
le code du module lui-même.

## 1.6 Idempotence

**Attendu :** comme pour Ansible, relancer `terraform apply` sur une infrastructure déjà conforme
ne doit produire aucun changement.

**Vérification :** juste après un `apply`, un `terraform plan` affiche
`No changes. Your infrastructure matches the configuration.`

## 1.7 Documentation — ressources, variables, providers et outputs dans le README

**Attendu :** le README documente, pour la partie Terraform :

- la liste des ressources et des modules utilisés, et leur rôle respectif ;
- un tableau des variables (nom, description, type, valeur par défaut le cas échéant, sensible ou
  non) ;
- les providers utilisés et leur version épinglée ;
- les outputs disponibles et ce qu'ils renvoient.

**Vérification :** un consultant qui n'a jamais ouvert le code doit pouvoir, à la seule lecture du
README, savoir quelles ressources seront créées, quelles variables renseigner dans
`terraform.tfvars`, et quelles informations il récupérera en sortie.