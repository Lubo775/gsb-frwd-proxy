#!/bin/bash

#addition of nginx repositories to be able to download latest stable version of nginx
sudo touch /etc/apt/sources.list.d/nginx.list
sudo cat <<EOT | sudo tee -a /etc/apt/sources.list.d/nginx.list
# updating APT repositories url to nginx repositories
deb https://nginx.org/packages/ubuntu/ `lsb_release -cs` nginx
deb-src https://nginx.org/packages/ubuntu/ `lsb_release -cs` nginx
EOT

#downloading GPG signing key, dearmoring, saving to a folder
sudo curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/nginx.gpg >/dev/null && sudo chmod 644 /etc/apt/trusted.gpg.d/nginx.gpg

#assigning signing key path to sources list
echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/nginx.gpg] https://nginx.org/packages/ubuntu/ `lsb_release -cs` nginx" | sudo tee /etc/apt/nginx.list

#update nginx repositories
sudo apt-get update

#install nginx 1.26.3 version
sudo apt-get --assume-yes -o DPkg::Lock::Timeout=600 install nginx -y nginx=1.26.3\*

#directives general for each nginx server
cat << EOF | tee /tmp/self-signed.conf
ssl_certificate /etc/nginx/ssl/server-cert.pem;
ssl_certificate_key /etc/nginx/ssl/server-cert.key;
ssl_trusted_certificate /etc/nginx/ssl/VW-CA-ROOT-05.pem;
EOF

cat << EOF | tee /tmp/ssl-params.conf
# from https://cipherli.st/
# and https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html

ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
ssl_ecdh_curve secp384r1;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
#resolver 8.8.8.8 8.8.4.4 valid=300s;
#resolver_timeout 5s;
# Disable preloading HSTS for now.  You can use the commented out header line that includes
# the "preload" directive if you understand the implications.
#add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;

ssl_dhparam /etc/nginx/ssl/dhparam.pem;
EOF

sudo mkdir /etc/nginx/ssl
sudo mkdir /etc/nginx/snippets
sudo chmod 757 /etc/nginx/
sudo cp /tmp/self-signed.conf /etc/nginx/snippets/
sudo cp /tmp/ssl-params.conf /etc/nginx/snippets/

sudo openssl dhparam -dsaparam -out /etc/nginx/ssl/dhparam.pem 2048

#stop prepared service
sudo systemctl disable nginx
sudo systemctl stop nginx
