#!/bin/bash
set -e

LOG=/var/log/user-data.log
exec > >(tee -a $LOG) 2>&1

APP_NAME="pr-preview"
APP_DIR="/var/www/$APP_NAME"
REPO_URL="https://github.com/sanjayjangir1093/pr-preview.git"
DJANGO_PROJECT="pr_preview"   # folder with wsgi.py
BRANCH="${BRANCH:-main}"

echo "🚀 Deploying PR branch: $BRANCH"

apt update -y
apt install -y \
  git python3 python3-pip python3-venv \
  nginx build-essential

mkdir -p /var/www
cd /var/www

git clone -b "$BRANCH" "$REPO_URL" "$APP_DIR"

cd "$APP_DIR"

python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install -r requirements.txt

python manage.py migrate --noinput
python manage.py collectstatic --noinput

pip install gunicorn

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

systemctl daemon-reexec
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
ln -s /etc/nginx/sites-available/pr-preview /etc/nginx/sites-enabled/

nginx -t
systemctl restart nginx

echo "✅ Django PR Preview is LIVE"
