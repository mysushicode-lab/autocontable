#!/bin/bash
# Installation de l'application (à exécuter dans /opt/carrosserie-app)

set -e

echo "🔧 Installation contamail..."

APP_DIR="/opt/contamail"
cd $APP_DIR

# 1. Python Virtual Environment
echo "🐍 Configuration Python..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Install poppler for Vision API (PDF to image conversion)
apt-get install -y poppler-utils

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
cat > /etc/nginx/sites-available/contamail << 'EOF'
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
    # Profile photos and uploaded files
    location /uploads {
        proxy_pass http://127.0.0.1:8000/uploads;
        proxy_set_header Host $host;
    }

    location /exports {
        alias /opt/carrosserie-app/data/exports;
        autoindex off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/contamail /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx

# 6. Service Systemd Backend
echo "⚙️  Configuration service API..."
cat > /etc/systemd/system/contamail-api.service << EOF
[Unit]
Description=contamail API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
Environment="DATABASE_URL=sqlite:///data/accounting.db"
Environment="PYTHONPATH=$APP_DIR"
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/uvicorn src.api.main:app --host 127.0.0.1 --port 8000 --workers 2
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# 7. Service Scheduler
echo "⏰ Configuration Scheduler..."
cat > /etc/systemd/system/contamail-scheduler.service << EOF
[Unit]
Description=contamail Scheduler
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
Environment="DATABASE_URL=sqlite:///data/accounting.db"
Environment="PYTHONPATH=$APP_DIR"
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/venv/bin/python -m src.scheduler.main
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 8. Démarrer services
echo "🚀 Démarrage services..."
systemctl daemon-reload
systemctl enable contamail-api
systemctl enable contamail-scheduler
systemctl start contamail-api
systemctl start contamail-scheduler

# 9. Status
echo ""
echo "✅ Installation terminée !"
echo ""
echo "📊 Status :"
systemctl status contamail-api --no-pager -l
systemctl status contamail-scheduler --no-pager -l
echo ""
echo "🌐 URLs :"
echo "   - Application : http://$(curl -s ifconfig.me)"
echo "   - API Docs    : http://$(curl -s ifconfig.me)/docs"
echo ""
echo "📁 Logs :"
echo "   - API : journalctl -u contamail-api -f"
echo "   - Scheduler : journalctl -u contamail-scheduler -f"
echo "   - Nginx : tail -f /var/log/nginx/access.log"
echo ""
