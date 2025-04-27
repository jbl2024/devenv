FROM ubuntu:24.04

# Installer les dépendances nécessaires
RUN apt-get update && \
    apt-get install -y sudo curl git zsh wget gnupg lsb-release ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Créer un utilisateur non-root avec un répertoire personnel
RUN useradd -ms /bin/bash devuser

# Ajouter l'utilisateur au groupe sudo
RUN usermod -aG sudo devuser

# Configurer sudo pour ne pas demander de mot de passe
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers


# Définir le répertoire de travail
WORKDIR /home/devuser

# Copier le script d'installation dans le conteneur
COPY setup-dev-env.sh /home/devuser/setup-dev-env.sh

# Rendre le script exécutable
RUN chmod +x /home/devuser/setup-dev-env.sh

# Définir l'utilisateur courant
RUN echo "devuser:jerome" | chpasswd
USER devuser

# Définir le point d'entrée sur une boucle infinie
ENTRYPOINT ["/bin/bash", "-c", "while true; do sleep 3600; done"]
