#!/usr/bin/env bash

# Script de déploiement de ComptaLibre sur serveur
# Usage: ./deploy.sh

set -e

echo "=========================================="
echo "Déploiement de ComptaLibre sur serveur"
echo "=========================================="

# Arrêt des conteneurs existants
echo "Arrêt des conteneurs existants..."
docker-compose down 2>/dev/null || true

# Construction et démarrage
echo "Construction et démarrage..."
docker-compose up --build -d

# Attente et vérification
echo "Vérification du statut..."
sleep 10
docker-compose ps

echo ""
echo "=========================================="
echo "✅ Déploiement terminé !"
echo "=========================================="
echo "Accès : http://<IP_DU_SERVEUR>/base"
echo "Login : superadmin / comptalibre"
