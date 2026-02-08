#!/bin/bash
set -e

APP_DIR=/var/www/django-app

echo "Installing packages..."
sudo apt update -y
sudo apt install -y python3 python3-pip python3-venv nginx git

echo "Creating app directory..."
sudo mkdir -p /var/www
sudo chown -R ubuntu:ubuntu /var/www
cd /var/www

if [ ! -d django-app ]; then
  git clone https://github.com/sanjayjangir1093/pr-preview.git django-app
fi

cd django-app

echo "Setting up virtualenv..."
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip

if [ -f requirements.txt ]; then
  pip install -r requirements.txt
fi

echo "Running migrations..."
python manage.py migrate || true
python manage.py collectstatic --noinput || true

echo "Creating Gunicorn service..."
sudo tee /etc/systemd/system/gunicorn.service > /dev/null <<EOF
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
          --bind unix:$APP_DIR/gunicorn.sock \
          backend.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start gunicorn
sudo systemctl enable gunicorn

echo "Configuring Nginx..."
sudo tee /etc/nginx/sites-available/django > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://unix:$APP_DIR/gunicorn.sock;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/django /etc/nginx/sites-enabled/django
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t
sudo systemctl restart nginx

echo "Django deployed successfully 🚀"
