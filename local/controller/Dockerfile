# Image du controller : contient Ansible, c'est d'ici qu'on lance les playbooks.
# Le build part de la racine du dépôt pour pouvoir copier requirements.yml.
FROM python:3.12-slim-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssh-client git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Versions fixées pour que tout le monde ait les mêmes.
# passlib : pour le module htpasswd. google-auth et requests : pour l'inventaire GCP.
RUN pip install --no-cache-dir \
       ansible-core==2.18.19 \
       ansible-lint==25.12.2 \
       passlib==1.7.4 \
       google-auth==2.40.3 \
       requests==2.32.5

COPY ansible/requirements.yml /tmp/requirements.yml
RUN ansible-galaxy collection install -r /tmp/requirements.yml -p /usr/share/ansible/collections

COPY local/controller/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY local/controller/vault-pass.sh /usr/local/bin/vault-pass.sh
# Le sed enlève les fins de ligne Windows au cas où.
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh /usr/local/bin/vault-pass.sh \
    && chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/vault-pass.sh

# Le dossier ansible/ du dépôt est monté ici.
WORKDIR /ansible

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
