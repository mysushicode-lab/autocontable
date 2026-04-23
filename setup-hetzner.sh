#!/bin/bash
# Script d'installation initiale sur Hetzner Cloud
# À exécuter une seule fois sur le serveur frais

echo "🚀 Installation Carrosserie Pro sur Hetzner"

# 1. Mise à jour système
echo "⬆️  Mise à jour système..."
apt update && apt upgrade -y

# 2. Installation des paquets nécessaires
echo "📦 Installation dépendances..."
apt install -y \
    git \
    nginx \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    tesseract-ocr \
    tesseract-ocr-fra \
    supervisor \
    curl \
    ufw

# 3. Configuration pare-feu
echo "🔥 Configuration pare-feu..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# 4. Création dossier application
echo "📁 Création structure..."
APP_DIR="/opt/carrosserie-app"
mkdir -p $APP_DIR
cd $APP_DIR
mkdir -p data

# 5. Message de suite
echo ""
echo "✅ Système prêt !"
echo ""
echo "Prochaines étapes :"
echo "1. Upload du code : scp -r . root@$(curl -s ifconfig.me):$APP_DIR/"
echo "2. Ou cloner : git clone <votre-repo> ."
echo "3. Configurer : cd $APP_DIR && ./install-app.sh"
echo ""
