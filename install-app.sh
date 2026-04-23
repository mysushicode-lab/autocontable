#!/bin/bash
# Installation de l'application (à exécuter dans /opt/carrosserie-app)

set -e

echo "🔧 Installation de l'application..."

APP_DIR="/opt/carrosserie-app"
cd $APP_DIR

# 1. Python Virtual Environment
echo "🐍 Configuration Python..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 2. Frontend Build
echo "⚛️  Build React..."
cd frontend
npm install
npm run build
cd ..

# 3. Base de données
echo "🗄️  Initialisation SQLite..."
python -m src.storage.init_db

# 4. Droits
echo "🔐 Configuration droits..."
chmod -R 755 $APP_DIR
chmod -R 777 $APP_DIR/data

# 5. Configuration Nginx
echo "🌐 Configuration Nginx..."
cat > /etc/nginx/sites-available/carrosserie << 'EOF'
server {
    listen 80;
    server_name _;

    # Frontend (React build)
    location / {
        root /opt/carrosserie-app/frontend/build;
        try_files $uri /index.html;
        add_header Cache-Control "public, max-age=31536000";
    }

    # Backend API
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Docs API (Swagger)
    location /docs {
        proxy_pass http://127.0.0.1:8000/docs;
        proxy_set_header Host $host;
    }

    # Static files backend
    location /exports {
        alias /opt/carrosserie-app/data/exports;
        autoindex off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/carrosserie /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx

# 6. Service Systemd Backend
echo "⚙️  Configuration service API..."
cat > /etc/systemd/system/carrosserie-api.service << EOF
[Unit]
Description=Carrosserie API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
Environment="DATABASE_URL=sqlite:///data/accounting.db"
Environment="PYTHONPATH=$APP_DIR"
ExecStart=$APP_DIR/venv/bin/uvicorn src.api.main:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# 7. Service Scheduler
echo "⏰ Configuration Scheduler..."
cat > /etc/systemd/system/carrosserie-scheduler.service << EOF
[Unit]
Description=Carrosserie Scheduler
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
Environment="DATABASE_URL=sqlite:///data/accounting.db"
Environment="PYTHONPATH=$APP_DIR"
ExecStart=$APP_DIR/venv/bin/python -m src.scheduler.main
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 8. Démarrer services
echo "🚀 Démarrage services..."
systemctl daemon-reload
systemctl enable carrosserie-api
systemctl enable carrosserie-scheduler
systemctl start carrosserie-api
systemctl start carrosserie-scheduler

# 9. Status
echo ""
echo "✅ Installation terminée !"
echo ""
echo "📊 Status :"
systemctl status carrosserie-api --no-pager -l
systemctl status carrosserie-scheduler --no-pager -l
echo ""
echo "🌐 URLs :"
echo "   - Application : http://$(curl -s ifconfig.me)"
echo "   - API Docs    : http://$(curl -s ifconfig.me)/docs"
echo ""
echo "📁 Logs :"
echo "   - API : journalctl -u carrosserie-api -f"
echo "   - Scheduler : journalctl -u carrosserie-scheduler -f"
echo "   - Nginx : tail -f /var/log/nginx/access.log"
echo ""
