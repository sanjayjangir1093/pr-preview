#!/bin/bash
set -e

LOG=/var/log/user-data.log
exec > >(tee -a $LOG) 2>&1

echo "Starting Django Auto Deployment"

# Update OS
apt update -y
apt upgrade -y

# Install packages
apt install -y git python3 python3-pip python3-venv nginx

# App config
APP_DIR=/var/www/pr-preview
REPO_URL="https://github.com/sanjayjangir1093/pr-preview.git"

# Clone repo
rm -rf $APP_DIR
git clone $REPO_URL $APP_DIR

cd $APP_DIR

# Setup python env
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt

# Django setup
python manage.py migrate --noinput
python manage.py collectstatic --noinput

# Install gunicorn
pip install gunicorn

# Create gunicorn service
cat > /etc/systemd/system/gunicorn.service <<EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/gunicorn \
          --access-logfile - \
          --workers 3 \
          --bind unix:/run/gunicorn.sock \
          todoapp.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gunicorn
systemctl restart gunicorn

# Nginx config
cat > /etc/nginx/sites-available/pr-preview <<EOF
server {
    listen 80;
    server_name _;

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
ln -s /etc/nginx/sites-available/pr-preview /etc/nginx/sites-enabled/

systemctl restart nginx

echo "Django Auto Deployment Finished"
