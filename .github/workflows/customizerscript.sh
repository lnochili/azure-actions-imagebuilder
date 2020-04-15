#!/bin/sh
### Node.js Installation
sudo curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
sudo apt install nodejs
sudo node --version

## Creating Hello World App
sudo mkdir -p /var/www/myapp
sudo cd /var/www/myapp
sudo npm init --yes
sudo echo "var http = require('http'); 
http.createServer(function(req,res){ 
        res.writeHead(200, { 'Content-Type': 'text/plain' }); 
        res.end('Hello World!');
}).listen(8080);
console.log('Server started on localhost:8080...!');"  > server.js
