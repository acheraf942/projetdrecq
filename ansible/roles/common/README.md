# Rôle common

Prépare la base de chaque serveur : paquets, fuseau horaire, utilisateur d'exploitation et
message d'accueil (`/etc/motd`).

| Variable | Défaut | Description |
|---|---|---|
| `common_packages` | curl, less, tzdata, ca-certificates | Paquets installés |
| `common_timezone` | `Europe/Paris` | Fuseau horaire |
| `common_ops_user` | `fleetops` | Utilisateur créé |
| `common_env` | valeur de `fleet_env` | Environnement affiché dans le message d'accueil |

Le fuseau horaire est réglé avec un lien vers `/usr/share/zoneinfo` car `timedatectl` ne marche
pas dans un conteneur.

Dépendances : aucune.

Exemple :

```yaml
- hosts: web
  become: true
  roles:
    - common
```
