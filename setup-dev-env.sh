#!/bin/bash
set -euo pipefail

# Chemin vers le fichier bashrc de l'utilisateur
BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Définitions des fonctions d'installation

install_zsh() {
  echo "→ Installation de Zsh et Oh My Zsh…"
  sudo apt update
  sudo apt install -y zsh git curl

  # Installer Oh My Zsh sans prompt interactif
  RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

  # Forcer Zsh comme shell par défaut
  chsh -s "$(which zsh)"

  # Créer dossier plugins si nécessaire
  mkdir -p "$ZSH_CUSTOM/plugins"

  echo "→ Installation des plugins zsh-autosuggestions et zsh-syntax-highlighting…"
  # zsh-autosuggestions
  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions \
      "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  fi
  # zsh-syntax-highlighting
  if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
      "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  fi

  echo "→ Configuration des plugins dans .zshrc…"
  # Remplacer la ligne plugins=(...) par la configuration souhaitée
  if grep -q '^plugins=' "$ZSHRC"; then
    sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$ZSHRC"
  else
    # ajouter si absent
    echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' >> "$ZSHRC"
  fi

  echo "Zsh, Oh My Zsh et plugins installés et configurés."
}


install_rest() {
  echo "→ Configuration du proxy (si défini)…"
  {
    [[ -n "${http_proxy:-}" ]]  && echo "export http_proxy=$http_proxy"
    [[ -n "${https_proxy:-}" ]] && echo "export https_proxy=$https_proxy"
    [[ -n "${ftp_proxy:-}" ]]   && echo "export ftp_proxy=$ftp_proxy"
    [[ -n "${no_proxy:-}" ]]    && echo "export no_proxy=$no_proxy"
  } >> "$BASHRC"

  # sudoers
  ENV_KEEP=""
  [[ -n "${http_proxy:-}" ]]  && ENV_KEEP+=" http_proxy"
  [[ -n "${https_proxy:-}" ]] && ENV_KEEP+=" https_proxy"
  [[ -n "${ftp_proxy:-}" ]]   && ENV_KEEP+=" ftp_proxy"
  [[ -n "${no_proxy:-}" ]]    && ENV_KEEP+=" no_proxy"
  if [[ -n "$ENV_KEEP" ]]; then
    sudo bash -c "echo 'Defaults env_keep += \"$ENV_KEEP\"' >> /etc/sudoers"
  fi

  echo "→ Installation tzdata…"
  # 1. Pré-seed Debconf
  sudo bash -c "printf '%s\n' \
    'tzdata tzdata/Areas select Europe' \
    'tzdata tzdata/Areas seen true' \
    'tzdata tzdata/Zones/Europe select Paris' \
    'tzdata tzdata/Zones/Europe seen true' \
  | debconf-set-selections"

  # 2. Installation non-interactive
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive \
      apt-get install -y --no-install-recommends tzdata

  # 3. Mise à jour de /etc/timezone et reconfiguration
  echo "Europe/Paris" | sudo tee /etc/timezone
  sudo DEBIAN_FRONTEND=noninteractive \
      dpkg-reconfigure -f noninteractive tzdata

  echo "→ Mise à jour et installation des dépendances de base…"
  sudo apt update
  sudo apt upgrade -y
  sudo apt install -y ca-certificates curl wget gnupg lsb-release git gpg software-properties-common
  sudo apt install -y \
    vim \
    build-essential \
    zlib1g-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libreadline-dev \
    libffi-dev \
    libbz2-dev \
    libssl-dev \
    libsqlite3-dev \
    liblzma-dev \
    tk-dev \
    uuid-dev \
    libgdbm-dev \
    libnss3-dev \
    libedit-dev \
    python3-openssl \
    golang \
    tmux


  echo "→ Installation de Docker…"
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Proxy Docker
  if [[ -n "${http_proxy:-}" || -n "${https_proxy:-}" || -n "${no_proxy:-}" ]]; then
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "proxies": {
    $( [[ -n "${http_proxy:-}" ]]  && echo "\"http-proxy\": \"$http_proxy\"," )
    $( [[ -n "${https_proxy:-}" ]] && echo "\"https-proxy\": \"$https_proxy\"," )
    $( [[ -n "${no_proxy:-}" ]]    && echo "\"no-proxy\": \"$no_proxy\"" )
  }
}
EOF
  fi
  sudo service docker start

  echo "→ Installation de FFmpeg…"
  sudo apt install -y ffmpeg

  echo "→ Installation de Python et asdf…"
  sudo apt install -y python3 python3-pip python3-venv
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1
  echo '. $HOME/.asdf/asdf.sh'       >> ~/.zshrc
  echo '. $HOME/.asdf/completions/asdf.bash' >> ~/.zshrc
  source ~/.asdf/asdf.sh

  echo "   • Python 3.11.1 via asdf"
  asdf plugin-add python
  asdf install python 3.11.1
  asdf global python 3.11.1

  echo "   • Node.js 20.13.1 via asdf"
  asdf plugin-add nodejs
  asdf install nodejs 20.13.1
  asdf global nodejs 20.13.1

  echo "→ Installation de direnv…"
  sudo apt install -y direnv
  echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc

  echo "→ Installation de Overmind…"
  go install github.com/DarthSim/overmind/v2@latest
  echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.zshrc

  echo "Installation des composants restants terminée."
}

# Menu interactif

while true; do
  cat <<EOF

Quel composant souhaitez-vous installer ?
  1) Zsh + Oh My Zsh
  2) Tout le reste (proxy, Docker, FFmpeg, Python, asdf, direnv, overmind…)
  q) Quitter

EOF
  read -r -p "Choix [1/2/q] : " CHOICE
  case "$CHOICE" in
    1) install_zsh;    break ;;
    2) install_rest;   break ;;
    q|Q) echo "Abandon."; exit 0 ;;
    *)  echo "Option invalide."; ;;
  esac
done

echo "Script terminé."  
