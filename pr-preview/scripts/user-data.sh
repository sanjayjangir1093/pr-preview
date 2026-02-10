#!/bin/bash
set -e

LOG=/var/log/user-data.log
exec > >(tee -a $LOG) 2>&1

APP_DIR="/var/www/pr-preview"
REPO_URL="https://github.com/sanjayjangir1093/pr-preview.git"
DJANGO_PROJECT="pr_preview"

echo "===== USER DATA START ====="

apt update -y
apt install -y git python3 python3-pip python3-venv nginx

mkdir -p /var/www
cd /var/www

echo "Cloning repo..."
git clone $REPO_URL pr-preview

echo "Repo content:"
ls -la /var/www/pr-preview

cd $APP_DIR

python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt
pip install gunicorn

python manage.py migrate --noinput || true
python manage.py collectstatic --noinput || true

cat >/etc/systemd/system/gunicorn.service <<EOF
[Unit]
Description=gunicorn
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/gunicorn \
  --workers 3 \
  --bind unix:/run/gunicorn.sock \
  $DJANGO_PROJECT.wsgi:application

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
ln -s /etc/nginx/sites-available/pr-preview /etc/nginx/sites-enabled/pr-preview

nginx -t
systemctl restart nginx

echo "===== USER DATA COMPLETE ====="
