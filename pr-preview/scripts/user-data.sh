#!/bin/bash
set -e

LOG=/var/log/user-data.log
exec > >(tee -a $LOG) 2>&1

echo "===== USER DATA START ====="

# Update system & install packages
apt update -y
apt install -y python3 python3-pip python3-venv git nginx

APP_DIR=/var/www/pr-preview
REPO_URL="https://github.com/sanjayjangir1093/pr-preview.git"

# Clone repo
rm -rf $APP_DIR
git clone $REPO_URL $APP_DIR

cd $APP_DIR

# Rename Django project folder (replace '-' with '_')
if [ -d "pr-preview" ]; then
    mv pr-preview pr_preview
fi

# Create Python virtualenv
python3 -m venv venv
source venv/bin/activate

# Upgrade pip & install dependencies
pip install --upgrade pip
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
else
    pip install django gunicorn
fi

# Apply migrations & collect static files
if [ -f manage.py ]; then
    python manage.py migrate || echo "Migration failed"
    python manage.py collectstatic --noinput || echo "Collectstatic failed"
fi

# Setup Gunicorn systemd service
cat > /etc/systemd/system/gunicorn.service <<EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 3 --bind unix:/run/gunicorn.sock pr_preview.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gunicorn
systemctl restart gunicorn || echo "Gunicorn failed"

# Setup Nginx config
cat > /etc/nginx/sites-available/pr-preview <<EOF
server {
    listen 80;
    server_name _;

    location /static/ {
        alias $APP_DIR/static/;
    }

    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_pass http://unix:/run/gunicorn.sock;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/pr-preview /etc/nginx/sites-enabled

nginx -t
systemctl restart nginx

echo "===== USER DATA FINISHED ====="
