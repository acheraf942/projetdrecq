# Image des nœuds : une Debian 12 qui se comporte comme une VM (systemd + SSH).
FROM debian:12

# Indique à systemd qu'il tourne dans un conteneur.
ENV container=docker DEBIAN_FRONTEND=noninteractive

# systemd pour les services, sshd pour Ansible, python3 et sudo pour les modules.
# iproute2 sert à récupérer les adresses IP dans les facts.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       systemd systemd-sysv dbus openssh-server python3 sudo iproute2 ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# On désactive ce qui ne sert à rien dans un conteneur (console, udev...).
RUN systemctl mask getty.target console-getty.service systemd-udevd.service \
       systemd-firstboot.service systemd-remount-fs.service \
    && systemctl enable ssh.service

# Utilisateur utilisé par Ansible, avec sudo sans mot de passe.
RUN useradd --create-home --shell /bin/bash ansible \
    && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
    && chmod 0440 /etc/sudoers.d/ansible

# Connexion SSH par clé uniquement. La clé autorisée est fournie par le controller
# dans le volume /ssh-pubkey.
RUN printf '%s\n' \
       'PasswordAuthentication no' \
       'PermitRootLogin no' \
       'AuthorizedKeysFile .ssh/authorized_keys /ssh-pubkey/authorized_keys' \
       > /etc/ssh/sshd_config.d/fleet.conf

EXPOSE 22 80

# Signal d'arrêt attendu par systemd.
STOPSIGNAL SIGRTMIN+3

CMD ["/lib/systemd/systemd"]
