#!/bin/sh
# Lancé au démarrage du controller : crée la clé SSH et donne la clé publique aux nœuds.
set -e

KEY=/root/.ssh/id_ed25519

mkdir -p /root/.ssh
chmod 0700 /root/.ssh

if [ ! -f "$KEY" ]; then
    ssh-keygen -t ed25519 -N '' -C 'fleet-controller' -f "$KEY" -q
fi

# Les nœuds lisent ce fichier comme liste des clés autorisées.
cp "$KEY.pub" /ssh-pubkey/authorized_keys
chmod 0644 /ssh-pubkey/authorized_keys

# Pour le cloud : on recopie la clé GCP avec les bons droits (sinon ssh la refuse sous Windows).
if [ -f /root/.ssh-host/fleet_gcp ]; then
    install -m 0600 /root/.ssh-host/fleet_gcp /root/.ssh/fleet_gcp
fi

exec "$@"
