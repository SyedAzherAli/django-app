#!/bin/bash

# Go to the application directory
cd /home/ubuntu/django-app

# Activate the virtual environment
source venv/bin/activate

# Install dependencies
venv/bin/pip install -r requirements.txt

# Run migrations
python manage.py migrate

# Collect static files
python manage.py collectstatic --noinput

# Gunicron config
sudo cp -r /home/ubuntu/django-app/scripts/gunicorn.socket /etc/systemd/system/gunicorn.service
sudo cp -r /home/ubuntu/django-app/scripts/gunicorn.service /etc/systemd/system/gunicorn.service
sudo cp -r /home/ubuntu/django-app/scripts/gunicorn.socket /etc/systemd/system/gunicorn.socket
sudo systemctl enable gunicorn

# Nginx config
sudo cp -r /home/ubuntu/django-app/scripts/default /etc/nginx/sites-availabe/default
sudo gpasswd -a www-data ubuntu

# Restart Gunicorn and nginx
sudo systemctl restart gunicorn
sudo systemctl restart nginx
