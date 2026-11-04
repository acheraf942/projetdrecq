# Rôle fleetinfo

Déploie le site Fleet Info et revient automatiquement à l'ancienne version si le déploiement
échoue.

Sur le serveur :

```
/opt/fleetinfo/releases/1.0.0/    une version (index.html, health.json, DEPLOYED_AT)
/opt/fleetinfo/releases/1.1.0/    une autre version
/opt/fleetinfo/current            lien vers la version affichée
/var/log/fleetinfo/deploy.log     journal des déploiements
```

## Fonctionnement

1. On regarde où pointe `current` pour retenir la version actuelle.
2. **block** : on crée la nouvelle version, on fait pointer `current` dessus, puis on teste
   `/health`.
3. **rescue** (si le block échoue) : on remet `current` sur l'ancienne version et on arrête le play
   avec un message.
4. **always** : on écrit une ligne dans le journal.

## Variables

| Variable | Défaut | Description |
|---|---|---|
| `fleetinfo_version` | `1.0.0` | Version à déployer (la vraie valeur est dans `group_vars/all/vars.yml`) |
| `fleetinfo_base_dir` | `/opt/fleetinfo` | Dossier de l'application |
| `fleetinfo_log_dir` | `/var/log/fleetinfo` | Dossier du journal |
| `fleetinfo_env` | valeur de `fleet_env` | Environnement affiché |
| `fleetinfo_team` | valeur de `fleet_team` | Équipe affichée |
| `fleetinfo_health_url` | `http://127.0.0.1/health` | Adresse testée après le déploiement |
| `fleetinfo_simulate_failure` | `false` | `true` = version cassée exprès, pour tester le rollback |
| `fleetinfo_cloud_zone` | non définie | Zone GCP (donnée par l'inventaire cloud) |
| `fleetinfo_cloud_machine_type` | non définie | Type de machine GCP (idem) |

## Remarques

- La date de déploiement est écrite une seule fois par version, sinon la page changerait à
  chaque passage et on n'aurait jamais `changed=0`.
- Pour tester le rollback, il faut demander une version **différente** de celle en ligne.

Dépendances : le rôle `nginx` doit passer avant.

Exemple :

```bash
ansible-playbook site.yml -e fleetinfo_version=1.2.0 -e fleetinfo_simulate_failure=true
```
