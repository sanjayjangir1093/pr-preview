#!/bin/bash
# Cloud-init user-data script for deploying Django app with Gunicorn + Nginx

# Exit on error
set -e

# Update packages
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y python3-pip python3-venv python3-dev build-essential git nginx

# Directory where the app will live
APP_DIR="/var/www/pr-preview"

# Remove old directory if exists
rm -rf $APP_DIR

# Clone the public repository
git clone https://github.com/sanjayjangir1093/pr-preview.git $APP_DIR

# Navigate to app directory
cd $APP_DIR

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Upgrade pip and install requirements
pip install --upgrade pip
pip install -r requirements.txt

# Apply Django migrations
python manage.py migrate

# Collect static files
python manage.py collectstatic --noinput

# Deactivate virtualenv
deactivate

# Set up Gunicorn systemd service
cat > /etc/systemd/system/gunicorn.service << EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 3 --bind unix:/run/gunicorn.sock pr_preview.wsgi:application

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start Gunicorn
systemctl daemon-reload
systemctl enable gunicorn
systemctl start gunicorn

# Configure Nginx
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
        proxy_pass http://unix:/run/gunicorn.sock;
    }
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/pr-preview /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
nginx -t
systemctl restart nginx

echo "=== USER DATA FINISHED ==="
