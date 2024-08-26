#!/bin/bash

echo "Starting script..."

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Get hostname and ask about using it as domain
hostname=$(hostname)
read -p "Use hostname '$hostname' as domain name? (y/n): " use_hostname
use_hostname=${use_hostname,,} # Convert to lowercase

if [[ "$use_hostname" == "y" ]]; then
  domain_name="$hostname"
else
  read -p "Enter the TLD domain name (e.g., example.com): " domain_name
fi

# Install Nginx
apt update || { echo "Failed to update package list" >&2; exit 1; }
apt install -y nginx || { echo "Failed to install Nginx" >&2; exit 1; }

# Set default port
port=8443

# Clean up old configurations
rm -f /etc/nginx/sites-available/reverse-proxy.conf
rm -f /etc/nginx/sites-enabled/reverse-proxy.conf
rm -f /etc/ssl/certs/$domain_name.crt
rm -f /etc/ssl/private/$domain_name.key
rm -f /etc/ssl/certs/$domain_name.van-ayu.ts.net.crt
rm -f /etc/ssl/private/$domain_name.van-ayu.ts.net.key

# Generate self-signed SSL certificate and key
openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/private/$domain_name.key -out /etc/ssl/certs/$domain_name.crt \
  -days 365 -nodes -subj "/C=US/ST=CA/L=San Francisco/O=Aryan Singh/CN=$domain_name" || { echo "Failed to generate SSL certificate" >&2; exit 1; }

echo "SSL certificate and key generated."

# Generate dhparam.pem (without outputting the message)
openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048 > /dev/null 2>&1 || { echo "Failed to generate dhparam.pem" >&2; exit 1; }

echo "dhparam.pem generated."

# Construct tailscale domain
tailscale_domain="$domain_name.van-ayu.ts.net"

# Get Tailscale certificate and key
tailscale cert --cert-file /etc/ssl/certs/$tailscale_domain.crt --key-file /etc/ssl/private/$tailscale_domain.key "$tailscale_domain" || { echo "Failed to get Tailscale certificate" >&2; exit 1; }

echo "Tailscale certificate and key generated."

# Configure Nginx
cat > /etc/nginx/sites-available/reverse-proxy.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain_name www.$domain_name;

    # Redirect HTTP to HTTPS for the main domain
    if (\$scheme != "https") {
        rewrite ^(.*)$ https://\$host\$1 permanent;
    }
}

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
    ssl_dhparam /etc/ssl/certs/dhparam.pem;

    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass http://localhost:$port;
        proxy_redirect off;
    }
}

server {
    listen 80;
    listen [::]:80;
    server_name $tailscale_domain;

    # Redirect HTTP to HTTPS for the Tailscale domain
    if (\$scheme != "https") {
        rewrite ^(.*)$ https://\$host\$1 permanent;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    server_name $tailscale_domain;

    ssl_certificate /etc/ssl/certs/$tailscale_domain.crt;
    ssl_certificate_key /etc/ssl/private/$tailscale_domain.key;
    ssl_session_timeout 1d;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:DES-CBC3-SHA';
    ssl_prefer_server_ciphers on;
    ssl_dhparam /etc/ssl/certs/dhparam.pem;

    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass http://localhost:$port;
        proxy_redirect off;
    }
}
EOF

echo "Nginx configuration created."

# Enable the site and reload Nginx
# Use `rm` first to remove any existing symlink
rm -f /etc/nginx/sites-enabled/reverse-proxy.conf
ln -s /etc/nginx/sites-available/reverse-proxy.conf /etc/nginx/sites-enabled/ || { echo "Failed to create symlink" >&2; exit 1; }
systemctl enable nginx || { echo "Failed to enable Nginx" >&2; exit 1; }
systemctl restart nginx || { echo "Failed to restart Nginx" >&2; exit 1; }

echo "Nginx reloaded."

# Display success message
echo "Reverse proxy configured successfully!"
echo "Access your service at https://$domain_name"
echo "Access your service at https://$tailscale_domain"

echo "Reached the end of the script."