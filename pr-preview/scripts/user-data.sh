#!/bin/bash

LOG=/var/log/user-data.log
exec > >(tee -a $LOG) 2>&1

echo "Starting Django Auto Deployment"

apt update -y
apt install -y git python3 python3-pip python3-venv nginx

APP_DIR=/var/www/pr-preview
REPO_URL="https://github.com/sanjayjangir1093/pr-preview.git"

rm -rf $APP_DIR
git clone $REPO_URL $APP_DIR || echo "Git clone failed"

cd $APP_DIR || exit 1

python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip

if [ -f requirements.txt ]; then
  pip install -r requirements.txt
else
  echo "requirements.txt missing"
fi

if [ -f manage.py ]; then
  python manage.py migrate || echo "Migration failed"
  python manage.py collectstatic --noinput || echo "collectstatic failed"
else
  echo "manage.py not found"
fi

pip install gunicorn

cat > /etc/systemd/system/gunicorn.service <<EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/gunicorn \
  --workers 3 \
  --bind unix:/run/gunicorn.sock \
  projectname.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gunicorn
systemctl restart gunicorn || echo "gunicorn failed"

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

nginx -t && systemctl restart nginx

echo "Django Auto Deployment Finished"
