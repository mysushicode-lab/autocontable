#!/bin/bash
# Script de déploiement Hetzner Cloud
# Exécuter sur le serveur Hetzner après configuration initiale

echo "🚀 Déploiement Carrosserie Pro sur Hetzner"

# Variables
APP_DIR="/opt/carrosserie-app"
BACKEND_PORT="8000"

cd $APP_DIR

# 1. Mettre à jour le code
echo "📥 Pull du code..."
git pull origin main || echo "Pas de git configuré, utiliser SCP"

# 2. Backend
echo "🔧 Mise à jour Backend..."
source venv/bin/activate
pip install -r requirements.txt

# 3. Frontend
echo "🎨 Build Frontend..."
cd frontend
npm install
npm run build
cd ..

# 4. Base de données
echo "🗄️  Initialisation DB..."
python -m src.storage.init_db || echo "DB déjà initialisée"

# 5. Redémarrer services
echo "🔄 Redémarrage des services..."
systemctl restart carrosserie-api || echo "Service API non configuré"
systemctl restart carrosserie-scheduler || echo "Service scheduler non configuré"
systemctl restart nginx

echo "✅ Déploiement terminé !"
echo "🌐 Application disponible sur http://$(curl -s ifconfig.me)"
