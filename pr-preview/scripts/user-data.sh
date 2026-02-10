#!/bin/bash
set -e

LOG=/var/log/user-data.log
exec > >(tee -a $LOG) 2>&1

APP_DIR="/var/www/pr-preview"
REPO_URL="https://github.com/sanjayjangir1093/pr-preview.git"
DJANGO_PROJECT="pr_preview"  # change if your Django project folder name is different

echo "===== USER DATA START ====="

# Update system & install dependencies
apt update -y
apt install -y git python3 python3-pip python3-venv nginx

# Create app directory
mkdir -p /var/www
cd /var/www

# Remove old folder if exists
rm -rf pr-preview

# Clone repo
echo "Cloning repository..."
git clone $REPO_URL pr-preview

cd $APP_DIR

# Set up virtual environment
python3 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies
if [ -f requirements.txt ]; then
    echo "Installing from requirements.txt..."
    pip install -r requirements.txt
else
    echo "requirements.txt not found. Installing Django + Gunicorn manually..."
    pip install django gunicorn
fi

# Run migrations & collect static files
if [ -f manage.py ]; then
    echo "Running migrations..."
    python manage.py migrate --noinput || true
    echo "Collecting static files..."
    python manage.py collectstatic --noinput || true
else
    echo "manage.py not found! Cannot run migrations."
fi

# Setup Gunicorn systemd service
echo "Configuring Gunicorn..."
cat >/etc/systemd/system/gunicorn.service <<EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 3 --bind unix:/run/gunicorn.sock $DJANGO_PROJECT.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gunicorn
systemctl restart gunicorn || echo "Gunicorn failed to start"

# Setup Nginx
echo "Configuring Nginx..."
cat >/etc/nginx/sites-available/pr-preview <<EOF
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
ln -sf /etc/nginx/sites-available/pr-preview /etc/nginx/sites-enabled/pr-preview

# Test nginx config & restart
nginx -t
systemctl restart nginx

echo "===== USER DATA COMPLETE ====="
