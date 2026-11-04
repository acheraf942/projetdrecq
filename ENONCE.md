# Projet d'équipe — « Socle Web Automatisé » : Terraform + Ansible sur Google Cloud

**Équipe :** 5 étudiantes / étudiants
**Prérequis :** modules Cloud (fondamentaux GCP), Terraform (fondamentaux + atelier), Ansible (labs playbooks, variables, rôles, templates, handlers, blocks, atelier post-Terraform)
**Outils :** Git, VS Code, Terraform, Ansible, Docker Desktop + Docker Compose, gcloud, Google Cloud (Compute Engine)
**Livrables :** un dépôt Git + une documentation de transfert de connaissance (README et/ou slides) + une soutenance avec démonstration

---

## 1. Contexte

**NovaRetail** (entreprise fictive) est une enseigne de distribution d'environ 2 000 salariés. Son
équipe d'exploitation gère aujourd'hui une dizaine de serveurs web internes (portails, pages
d'information, outils de supervision) **à la main** : chaque serveur a été installé différemment,
personne ne sait exactement ce qui tourne où, et chaque mise à jour applicative est une opération
risquée faite en SSH, sans retour arrière possible.

Suite à un incident (une mise en production ratée a rendu un portail indisponible pendant une
demi-journée), la DSI lance le projet **« Socle Web Automatisé »**, dont votre équipe — l'**équipe
Plateforme** — est chargée. Les attentes de la DSI sont les suivantes :

- toute l'infrastructure est décrite **en code** et peut être reconstruite à l'identique, à tout
  moment, sans action manuelle ;
- la configuration des serveurs et le déploiement applicatif sont **automatisés, reproductibles
  et idempotents** : relancer l'automatisation sur un serveur déjà conforme ne change rien ;
- une mise en production qui échoue **revient automatiquement à la version précédente** ;
- les développeurs doivent pouvoir travailler **en local** sur leur poste, avec le même code
  d'automatisation que celui utilisé sur le cloud ;
- aucun secret ne doit apparaître en clair dans le dépôt.

À la fin du projet, le socle sera **repris en exploitation (run) par une société de conseil
externe**. C'est le rôle que joue l'examinateur : un consultant qui découvre votre travail et
doit être capable, **avec votre seule documentation**, de le redéployer, de l'exploiter et de le
faire évoluer. Votre documentation est donc un livrable à part entière, au même titre que le code.

## 2. Ce que vous devez construire

### 2.1 Vue d'ensemble

```
                        ┌──────────────────────────────────────────────┐
                        │            Dépôt Git de l'équipe             │
                        │  terraform/   ansible/   local/   docs/      │
                        └───────────────┬──────────────────┬───────────┘
                                        │                  │
              ENVIRONNEMENT CLOUD       │                  │      ENVIRONNEMENT LOCAL
   ┌────────────────────────────────────▼───┐   ┌──────────▼─────────────────────────────┐
   │ Terraform  ──▶  VPC + sous-réseau      │   │ docker compose up                      │
   │                 règles firewall         │   │   ├── controller (Ansible)             │
   │                 N VM Compute Engine     │   │   ├── node1 (Debian, systemd, sshd)    │
   │                 (labels / tags réseau)  │   │   └── node2 (Debian, systemd, sshd)    │
   │                                         │   │                                        │
   │ Ansible ── inventaire dynamique ────────│   │ Ansible ── inventaire statique         │
   │            google.cloud.gcp_compute     │   │            (mêmes noms de groupes)     │
   └────────────────────┬────────────────────┘   └──────────────────┬─────────────────────┘
                        │                                           │
                        └────────────── MÊMES playbooks ────────────┘
                                         MÊMES rôles
                                         MÊMES templates
                              seuls l'inventaire et les group_vars
                                   d'environnement diffèrent
```

Principe directeur : **Terraform crée l'infrastructure, Ansible la configure et y déploie
l'application.** Les deux outils ne se recouvrent jamais (Ansible ne crée pas de VM, Terraform
n'installe pas de paquet). Le code Ansible est **strictement le même** en local et sur le cloud.

### 2.2 L'application « Fleet Info »

L'application à déployer est une page web d'information sur le serveur qui la sert. Elle permet à
l'équipe d'exploitation de vérifier d'un coup d'œil sur quelle machine elle se trouve et dans
quel état est cette machine.

**Exigences fonctionnelles :**

| Élément | Attendu |
|---|---|
| Page d'accueil `/` | Affiche au minimum : nom de la machine (hostname / FQDN), adresse(s) IP, distribution et version de l'OS, version du noyau, nombre de vCPU, mémoire totale, environnement (`local` / `cloud`), **version de l'application** déployée, date et heure du dernier déploiement. |
| Informations cloud | Sur GCP, afficher en plus la zone et le type de machine. En local, ces champs sont absents : la page doit s'adapter proprement (pas de champ vide ni d'erreur de template). |
| Endpoint `/health` | Renvoie un statut et la version déployée (texte ou JSON). Il sert de **contrôle de santé** après chaque déploiement. |
| Endpoint `/status` | Page technique du serveur web (par exemple `stub_status` de nginx), **protégée par une authentification** dont le mot de passe est un secret géré avec Ansible Vault. |
| Serveur web | nginx (recommandé). |

Le contenu de la page est **généré par Ansible** à partir des *facts* collectés sur chaque
machine et des variables du projet. Deux serveurs doivent donc afficher deux pages différentes,
sans que vous ayez écrit une page par serveur.

**Gestion des versions applicatives :** l'application est livrée sous forme de *releases*
versionnées (par exemple `1.0.0`, `1.1.0`). Une variable définit la version à déployer. Chaque
release est déployée dans son propre répertoire sur le serveur (par exemple
`/opt/fleetinfo/releases/<version>/`) et la version active est désignée par un lien symbolique
(par exemple `/opt/fleetinfo/current`). Ce découpage est ce qui rend le retour arrière possible.

### 2.3 L'infrastructure cloud (Terraform)

| Ressource | Exigence |
|---|---|
| Réseau | Un VPC dédié (pas le réseau `default`) et au moins un sous-réseau. |
| Firewall | HTTP (80) ouvert ; SSH (22) ouvert **uniquement** aux plages nécessaires (justifiez votre choix). Les règles ciblent les VM par **tag réseau**, pas « toutes les instances ». |
| VM | Au moins **2 VM** Compute Engine Debian 12, en nombre paramétrable par une variable (passer de 2 à 3 VM ne doit demander qu'un changement de variable). |
| Identification | Chaque VM porte des **labels** (au minimum `env`, `role`, `team`) et un **tag réseau** commun. Ce sont eux qu'utilise l'inventaire dynamique Ansible. |
| Accès SSH | Clé publique injectée via les métadonnées de la VM (ou OS Login, à justifier). Aucune clé privée dans le dépôt. |
| Paramétrage | `project_id`, région, zone, type de machine, nombre de VM… en **variables** ; aucune valeur propre à une session de lab écrite en dur dans le code. |
| Sorties | Des `outputs` utiles à l'exploitation (IP publiques, noms des VM, URL de la page d'accueil…). |
| Qualité | Versions de Terraform et du provider épinglées, `terraform fmt` et `terraform validate` sans erreur. |

**Idempotence Terraform :** juste après un `terraform apply`, un `terraform plan` doit afficher
`No changes`.

**Gestion du state :** le projet GCP du lab est éphémère, un state local est donc acceptable.
Vous devez en revanche **documenter ce choix** et ce qu'il faudrait faire en entreprise.

### 2.4 L'environnement local (Docker Desktop + Docker Compose)

L'environnement local reproduit le cloud avec des conteneurs qui **se comportent comme des VM** :

- au moins **2 conteneurs « nœuds »** Debian 12 avec `systemd`, `sshd`, `python3` et `sudo`,
  pour qu'Ansible les gère exactement comme des VM (connexion SSH, modules `service`/`systemd`,
  handlers…) ;
- un **conteneur « controller »** qui contient Ansible (et ses collections) et depuis lequel on
  lance les playbooks. Ansible ne s'exécutant pas nativement sous Windows, c'est ce conteneur qui
  sert de poste de contrôle sur les postes Windows (WSL est une alternative acceptée) ;
- les ports HTTP des nœuds sont publiés sur l'hôte (par exemple `8081`, `8082`) pour consulter les
  pages depuis un navigateur ;
- un **inventaire statique** qui utilise **les mêmes noms de groupes** que l'inventaire dynamique
  GCP, pour que `site.yml` fonctionne sans modification dans les deux environnements.

Vous pouvez reprendre les images de conteneurs utilisées dans les labs et les fichiers Docker Compose
pour instancier cet environnement local.
**Les ressources utilisées devront pouvoir être décrites et leur fonctionnement expliqué**.

Les clés SSH utilisées entre le controller et les nœuds sont générées au démarrage ou par un
script, **jamais committées**.

### 2.5 L'environnement cloud (lab Google Skills)

L'environnement cloud est un **projet GCP temporaire** fourni par l'un des labs Google Skills
suivants :

- https://www.skills.google/paths/11/course_templates/443/labs/576066
- https://www.skills.google/paths/11/course_templates/443/labs/508950

Contraintes à anticiper, typiques d'un environnement de lab :

- **durée limitée** : le projet et tout ce qu'il contient sont supprimés à la fin de la session.
  Relevez la durée affichée dans le panneau du lab ; votre déploiement complet (Terraform +
  Ansible) doit tenir **largement** dans ce temps ;
- **identifiants changeants** : `project_id`, compte et identifiants sont différents à chaque
  session. Ils sont passés en variables, jamais écrits dans le code ni committés ;
- **périmètre restreint** : la région, la zone, les types de machine ou les API autorisés peuvent
  être limités par le lab. Relevez ces contraintes dès la première session et documentez-les ;
- **poste de contrôle** : Utiliser votre poste local pour utiliser `Terraform` et `gcloud`. 
- **Consigne : Cloud Shell** : N'utilisez pas Cloud Shell pour développer votre projet car vous risquez de ne pas récupérer votre travail
  avant la suppression du lab.

Conséquence directe, et c'est tout l'intérêt de l'IaC : vous allez **reconstruire votre
environnement de zéro à chaque session**. Si cela demande plus que quelques commandes
documentées, votre automatisation n'est pas terminée.

## 3. Exigences Terraform & Ansible

Pour les exigences sur Ansible voir le fichier ANSIBLE.md
Pour les exigences sur Terraform voir le fichier TERRAFORM.md

## 4. Consignes transverses

- **Idempotence partout** : `terraform plan` après `apply` → `No changes` ; second
  `ansible-playbook site.yml` → `changed=0`.
- **Code commenté** : chaque fichier commence par un commentaire qui explique son rôle ; les choix
  non évidents sont expliqués là où ils sont faits.
- **Un seul code, deux environnements** : aucune condition du type `when: env == 'local'` dans
  les rôles pour contourner une différence d'environnement, sauf cas justifié et documenté.
  Les différences passent par l'inventaire et les `group_vars`.
- **Rien de sensible dans Git** : state Terraform, `.terraform/`, clés SSH, identifiants GCP, mot
  de passe Vault → `.gitignore` dès le premier commit.

## 5. Structure de dépôt attendue

La structure exacte est libre, mais elle doit rester proche de celle-ci et être expliquée dans le
README :

```
socle-web-automatise/
├── README.md                     → documentation de transfert (point d'entrée unique)
├── docs/                         → schémas, décisions techniques, runbooks, slides éventuels
├── terraform/
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── network.tf
│   ├── compute.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example  → modèle à copier, le vrai .tfvars n'est pas versionné
├── local/
│   ├── docker-compose.yml
│   ├── node/Dockerfile
│   └── controller/Dockerfile
└── ansible/
    ├── ansible.cfg
    ├── requirements.yml
    ├── site.yml
    ├── playbooks/
    ├── inventories/
    │   ├── local/
    │   │   ├── hosts.yml
    │   │   └── group_vars/
    │   └── cloud/
    │       ├── fleet.gcp.yml
    │       └── group_vars/
    ├── group_vars/
    │   └── all/
    │       ├── vars.yml
    │       └── vault.yml         → chiffré
    └── roles/
        ├── common/
        ├── nginx/
        └── fleetinfo/
```

## 6. Organisation de l'équipe

Votre équipe est composé de 5 membres.
Vous pouvez vous organiser comme vous le souhaitez pour réaliser ce projet.

La documentation est **l'affaire de tous** : chacun documente ce qu'il produit, le tech lead
assure la cohérence d'ensemble.

Pendant la soutenance, **n'importe quel membre** peut être interrogé sur **n'importe quelle
partie** du projet. Organisez des points réguliers pour que chacun comprenne le travail des
autres.

### Jalons conseillés

1. **Cadrage** : répartition des rôles, dépôt Git initialisé avec sa structure et son
   `.gitignore`, première session de lab pour relever les contraintes de l'environnement cloud.
2. **Local fonctionnel** : `docker compose up` + `ansible-playbook site.yml` déploient Fleet Info
   sur les nœuds locaux.
3. **Cloud fonctionnel** : `terraform apply` + inventaire dynamique + le **même** `site.yml`
   déploient Fleet Info sur les VM GCP.
4. **Robustesse** : rollback démontrable, secrets chiffrés, idempotence vérifiée dans les deux
   environnements, `ansible-lint` propre.
5. **Transfert** : documentation finalisée, puis **répétition générale** : un membre de l'équipe
   redéploie tout de zéro dans une nouvelle session de lab en suivant uniquement le README.

## 7. Documentation de transfert de connaissance

Rédigez votre documentation pour **un consultant qui reprend le run** : il connaît Terraform,
Ansible et GCP, mais ne connaît **ni votre projet, ni vos choix, ni vos conventions**.

**Critère de réussite :** le consultant doit pouvoir, en suivant votre documentation
et en posant des questions, redéployer l'ensemble dans un projet GCP vierge et en local,
puis réaliser les opérations courantes ci-dessous.

Le README principal (éventuellement complété par `docs/` ou par des slides) doit couvrir :

1. **Présentation** : objectif du socle, périmètre, ce qui est automatisé et ce qui ne l'est pas.
2. **Architecture** : schéma des deux environnements, flux réseau, rôle de chaque outil, et la
   frontière entre Terraform et Ansible.
3. **Prérequis et accès** : outils et versions, comptes et droits nécessaires, récupération du
   mot de passe Vault, contraintes de l'environnement de lab.
4. **Déploiement de zéro** : procédure pas à pas, commandes copiables, résultat attendu à chaque
   étape, pour l'environnement local **et** pour le cloud.
5. **Runbooks d'exploitation** — pour chacun : quand l'utiliser, commandes, comment vérifier que
   l'opération a réussi :
   - déployer une nouvelle version de l'application ;
   - revenir manuellement à une version précédente ;
   - ajouter (ou retirer) un serveur ;
   - modifier la configuration du serveur web ;
   - changer le mot de passe de `/status` et le mot de passe Vault ;
   - vérifier l'état de conformité d'un serveur (`--check --diff`) ;
   - détruire l'environnement proprement.
6. **Référence des variables** : où chaque variable est définie, ce qu'elle fait, sa valeur par
   défaut.
7. **Décisions techniques** : chaque choix structurant avec sa justification et les alternatives
   écartées (rôles publics utilisés, image Docker des nœuds, gestion du state, méthode d'accès SSH).
8. **Où regarder en cas de problème** : journaux (déploiement, nginx), fichiers générés sur les
   serveurs, commandes de diagnostic, erreurs déjà rencontrées et leur solution.
9. **Limites connues et dette technique** : ce qui n'est pas terminé, ce qui n'est pas prêt pour
   la production, ce que vous feriez ensuite.

## 8. Soutenance et passation

**Format :** 30-45 minutes par équipe — environ 10-15 minutes de présentation, 15 minutes de
démonstration, 10 à 15 minutes de questions.

La présentation se fait comme une **réunion de passation** au consultant qui reprend le run :
pas de cours sur Terraform ou Ansible, mais *votre* socle, *vos* choix et *comment l'exploiter*.

**Scénario de démonstration imposé** (sur une session de lab neuve, environnement cloud préparé à
l'avance) :

1. `terraform apply` puis `terraform plan` → `No changes`.
2. `ansible-inventory --graph` → les VM apparaissent dans les bons groupes.
3. `ansible-playbook site.yml` → la page Fleet Info s'affiche sur chaque VM, avec des
   informations différentes d'une VM à l'autre.
4. Second `ansible-playbook site.yml` → `changed=0`.
5. Connexion SSH sur une VM : l'examinateur ouvre un fichier généré par un template et vérifie
   l'en-tête.
6. Déploiement d'une nouvelle version → la page affiche la nouvelle version.
7. Déploiement volontairement en échec → le rollback se déclenche, le site reste en ligne en
   version N-1, l'échec est tracé dans le journal de déploiement.
8. Accès à `/status` : refusé sans authentification, accepté avec.
9. Démonstration rapide de l'environnement local : `docker compose up`, même `site.yml`, même
   résultat.
10. `terraform destroy`.

Si l'environnement cloud n'est pas disponible la démonstration se fera sur l'environnement local.
L'environnoment local s'appuie sur Docker Desktop + Docker Compose.

L'examinateur peut aussi demander à un membre de l'équipe, choisi au hasard, de dérouler un
runbook de la documentation en direct.

Tous les membres de l'équipe doivent participer à la soutenance.

## 9. Évaluation

Critères

- Infrastructure Terraform (réseau, firewall, VM, labels, variables, outputs, idempotence) 
- Environnement local Docker Compose (nœuds gérés comme des VM, controller, parité avec le cloud) 
- Playbooks (structure, lisibilité, commentaires, FQCN, tags, idempotence vérifiée, `ansible-lint`) 
- Rôles (découpage, idempotence, README, justification des rôles publics) 
- Variables et secrets (placement, précédence, documentation, Ansible Vault, `no_log`) 
- Templates (génération dynamique depuis les facts, en-tête identifiable, adaptation à l'environnement) 
- Handlers (reload vs restart, validation de la configuration) 
- Blocks et rollback (block/rescue/always, retour arrière démontré, journal de déploiement) 
- Collection et inventaire dynamique `google.cloud.gcp_compute` 
- Documentation de transfert de connaissance (complétude, exactitude, runbooks, décisions) 
- Soutenance et démonstration (clarté, maîtrise individuelle, respect du scénario de passation) 

## 10. Définition de « terminé »

Avant la soutenance, vérifiez que vous pouvez cocher chaque ligne :

- [ ] Une session de lab neuve + le README suffisent à tout redéployer, sans aide orale.
- [ ] `terraform plan` après `apply` → `No changes`.
- [ ] Second `ansible-playbook site.yml` → `changed=0`, en local **et** sur le cloud.
- [ ] Le même `site.yml` et les mêmes rôles servent dans les deux environnements.
- [ ] Ajouter une VM côté Terraform ne demande aucune modification du code Ansible.
- [ ] Un déploiement en échec revient automatiquement à la version précédente, site toujours en
      ligne.
- [ ] Les fichiers générés sur les serveurs sont identifiables comme gérés par Ansible.
- [ ] Aucun secret en clair dans le dépôt ni dans son historique.
- [ ] `terraform fmt -check`, `terraform validate` et `ansible-lint` passent.
- [ ] Chaque rôle a son README, chaque variable est documentée, chaque rôle public est justifié.
- [ ] Chaque membre de l'équipe sait expliquer et exécuter chaque runbook.
