#!/bin/bash
set -e
echo "===== USER DATA START ====="

# Update packages
apt update -y
apt upgrade -y

# Install required packages
apt install -y python3-pip python3-dev python3-venv build-essential nginx git

# Clone your repo (replace with your repo)
cd /var/www
if [ ! -d "pr-preview" ]; then
    git clone git@github.com:sanjayjangir1093/pr-preview.git
fi

cd pr-preview

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies from requirements.txt if exists
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    pip install django gunicorn
fi

# Django migrations & collectstatic
export DJANGO_SETTINGS_MODULE=pr_preview.settings
python manage.py migrate --noinput
python manage.py collectstatic --noinput

# Create Gunicorn systemd service
cat > /etc/systemd/system/gunicorn.service <<EOL
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/var/www/pr-preview
ExecStart=/var/www/pr-preview/venv/bin/gunicorn \\
    --workers 3 \\
    --bind unix:/run/gunicorn.sock \\
    --chmod-socket=666 \\
    pr_preview.wsgi:application

[Install]
WantedBy=multi-user.target
EOL

# Start and enable Gunicorn
systemctl daemon-reload
systemctl enable gunicorn
systemctl restart gunicorn

# Configure Nginx
cat > /etc/nginx/sites-available/pr-preview <<EOL
server {
    listen 80;
    server_name _;

    location /static/ {
        alias /var/www/pr-preview/static/;
    }

    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_pass http://unix:/run/gunicorn.sock;
    }
}
EOL

# Enable Nginx site
ln -sf /etc/nginx/sites-available/pr-preview /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx

echo "===== USER DATA FINISHED ====="
