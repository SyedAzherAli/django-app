#!/bin/bash

# Go to the application directory
cd /home/ubuntu/django-app

# Installing python env 
python3 -m venv venv 

# Install dependencies
venv/bin/pip install -r requirements.txt

# Run migrations
venv/bin/python manage.py migrate

# Collect static files
venv/bin/python manage.py collectstatic --noinput

# Gunicron config
if [ -f /etc/systemd/system/gunicorn.socket ] || [ -f /etc/systemd/system/gunicorn.service ]; then 
sudo rm -rf /etc/systemd/system/gunicorn.socket 
sudo rm -rf /etc/systemd/system/gunicorn.service
else
sudo cp -r /home/ubuntu/django-app/scripts/gunicorn.socket /etc/systemd/system/gunicorn.socket
sudo cp -r /home/ubuntu/django-app/scripts/gunicorn.service /etc/systemd/system/gunicorn.service
fi
sudo systemctl enable gunicorn

# Nginx config
sudo rm -rf /etc/nginx/sites-available/default
sudo cp -r /home/ubuntu/django-app/scripts/default /etc/nginx/sites-available/
sudo gpasswd -a www-data ubuntu

# Restart Gunicorn and nginx
sudo systemctl deemon-reload
sudo systemctl restart gunicorn
sudo systemctl restart nginx
