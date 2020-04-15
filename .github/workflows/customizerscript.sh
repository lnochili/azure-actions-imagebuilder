#!/bin/sh

sudo mkdir -p /var/www/myapp
sudo cd /var/www/myapp
sudo chmod ugo+rwx /var/www/myapp
sudo echo "Hello world" > myapp.out

