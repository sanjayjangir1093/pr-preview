#!/bin/bash
# Cloud-init user-data script for deploying Django app with Gunicorn + Nginx
set -e

# Variables
APP_DIR="/var/www/pr-preview"
REPO="https://github.com/sanjayjangir1093/pr-preview.git"
VENV_DIR="$APP_DIR/venv"
SOCKET="$APP_DIR/gunicorn.sock"
USER="ubuntu"
GROUP="www-data"
DJANGO_APP="todoApp"  # change to your Django wsgi module if needed

# Update and install packages
apt-get update -y
apt-get upgrade -y
apt-get install -y python3-pip python3-venv python3-dev build-essential git nginx

# Remove old app directory if exists
rm -rf $APP_DIR

# Clone repository
git clone $REPO $APP_DIR
cd $APP_DIR

# Set permissions
chown -R $USER:$GROUP $APP_DIR
chmod -R 775 $APP_DIR

# Create virtual environment and install dependencies
python3 -m venv venv
source $VENV_DIR/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Django setup
python manage.py migrate
python manage.py collectstatic --noinput

# Deactivate venv
deactivate

# Gunicorn systemd service
cat > /etc/systemd/system/gunicorn.service << EOF
[Unit]
Description=Gunicorn daemon for PR Preview
After=network.target

[Service]
User=$USER
Group=$GROUP
WorkingDirectory=$APP_DIR
Environment="PATH=$VENV_DIR/bin:\$PATH"
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind unix:$SOCKET $DJANGO_APP.wsgi:application
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start Gunicorn
systemctl daemon-reload
systemctl enable gunicorn
systemctl restart gunicorn

# Nginx configuration
cat > /etc/nginx/sites-available/pr-preview << EOF
server {
    listen 80;
    server_name _;

    location /static/ {
        alias $APP_DIR/static/;
    }

    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_pass http://unix:$SOCKET;
    }

    access_log /var/log/nginx/pr-preview-access.log;
    error_log /var/log/nginx/pr-preview-error.log;
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/pr-preview /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
nginx -t
systemctl restart nginx

echo "=== USER DATA FINISHED ==="
