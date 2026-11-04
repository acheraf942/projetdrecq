#!/bin/sh
# Donne le mot de passe Vault à Ansible.
# On passe par ce script car sous Windows Ansible essaierait d'exécuter .vault_pass.
if [ ! -f /ansible/.vault_pass ]; then
    exit 1
fi
tr -d '\r' < /ansible/.vault_pass
