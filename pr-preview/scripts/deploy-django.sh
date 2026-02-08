#!/bin/bash
set -e

echo "Starting Django Deployment"

apt update -y
apt install -y python3 python3-pip python3-venv nginx git

mkdir -p /var/www
cd /var/www

git clone https://github.com/sanjayjangir1093/pr-preview.git app
cd app

python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install django gunicorn

python manage.py migrate || true
python manage.py collectstatic --noinput || true

cat >/etc/systemd/system/gunicorn.service <<EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=root
Group=www-data
WorkingDirectory=/var/www/app
ExecStart=/var/www/app/venv/bin/gunicorn --workers 3 --bind unix:/var/www/app/gunicorn.sock pr_preview.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gunicorn
systemctl restart gunicorn

cat >/etc/nginx/sites-available/pr-preview <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://unix:/var/www/app/gunicorn.sock;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/pr-preview /etc/nginx/sites-enabled
rm -f /etc/nginx/sites-enabled/default

systemctl restart nginx

echo "Deployment Completed Successfully"
