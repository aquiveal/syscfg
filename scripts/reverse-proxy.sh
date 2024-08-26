#!/bin/bash

# Install Nginx
apt update
apt install -y nginx

# Get domain name and port from user
read -p "Enter the TLD domain name (e.g., example.com): " domain_name
read -p "Enter the port number: " port

# Generate self-signed SSL certificate and key
openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/private/$domain_name.key -out /etc/ssl/certs/$domain_name.crt \
  -days 365 -nodes -subj "/C=US/ST=CA/L=San Francisco/O=Aryan Singh/CN=$domain_name"

# Configure Nginx
cat > /etc/nginx/sites-available/reverse-proxy.conf <<EOF
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name $domain_name www.$domain_name;

    ssl_certificate /etc/ssl/certs/$domain_name.crt;
    ssl_certificate_key /etc/ssl/private/$domain_name.key;
    ssl_session_timeout 1d;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:DES-CBC3-SHA';
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/ssl/certs/dhparam.pem; # optional: generate with 'openssl dhparam -outform PEM -out /etc/ssl/certs/dhparam.pem 2048'

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass http://localhost:$port;
        proxy_redirect off;
    }
}
EOF

# Enable the site and reload Nginx
ln -s /etc/nginx/sites-available/reverse-proxy.conf /etc/nginx/sites-enabled/
systemctl enable nginx
systemctl restart nginx

# Display success message
echo "Reverse proxy configured successfully!"
echo "Access your service at https://$domain_name"