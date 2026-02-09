#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting Django Auto Deployment"

APP_DIR="/var/www/app"
PROJECT_NAME="myproject"   # change this
GIT_REPO="https://github.com/sanjayjangir1093/pr-preview.git"   # change this

# Update system
apt update -y
apt upgrade -y

# Install dependencies
apt install -y python3 python3-pip python3-venv nginx git

# Create app dir
mkdir -p $APP_DIR
cd $APP_DIR

# Clone repo
git clone $GIT_REPO .

# Setup venv
python3 -m venv venv
source venv/bin/activate

# Install python deps
pip install --upgrade pip
pip install -r requirements.txt

# Django setup
python manage.py migrate
python manage.py collectstatic --noinput

# Gunicorn service
cat <<EOF >/etc/systemd/system/gunicorn.service
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/gunicorn \
    --access-logfile - \
    --workers 3 \
    --bind unix:/run/gunicorn.sock \
    $PROJECT_NAME.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gunicorn
systemctl start gunicorn

# Nginx config
cat <<EOF >/etc/nginx/sites-available/django
server {
    listen 80;
    server_name _;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root $APP_DIR;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn.sock;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/django /etc/nginx/sites-enabled

nginx -t
systemctl restart nginx

echo "Django Deployment Completed Successfully"
