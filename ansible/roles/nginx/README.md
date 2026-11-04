# Rôle nginx

Installe nginx et configure le site Fleet Info :
- `/` affiche la page de `/opt/fleetinfo/current` ;
- `/health` renvoie le fichier `health.json` ;
- `/status` affiche les statistiques de nginx, avec un mot de passe.

On a écrit ce rôle nous-mêmes (pas de rôle Galaxy) car il ne fait que quelques tâches.

| Variable | Défaut | Description |
|---|---|---|
| `nginx_listen_port` | `80` | Port du site |
| `nginx_server_name` | `_` | Nom de domaine (`_` = tous) |
| `nginx_root` | `/opt/fleetinfo/current` | Dossier affiché |
| `nginx_status_user` | `admin` | Utilisateur de `/status` (projet : `exploit`) |
| `nginx_status_password` | vide | Mot de passe de `/status`, à mettre dans le Vault |

**Handlers :** quand la config change, on lance `nginx -t` pour la vérifier, puis on recharge
nginx. Si la vérification échoue, rien n'est rechargé. On utilise `reloaded` et pas `restarted`
pour ne pas couper les visiteurs.

Dépendances : collection `community.general` (module `htpasswd`).

Exemple :

```yaml
- hosts: web
  become: true
  roles:
    - nginx
```
