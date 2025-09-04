#!/bin/bash

# --- Update system ---
apt update -y
apt upgrade -y

# --- Install Apache, PHP, AWS CLI, and tools ---
 apt install -y apache2 ghostscript libapache2-mod-php mysql-client \
    php php-bcmath php-curl php-imagick php-intl php-json php-mbstring \
    php-mysql php-xml php-zip unzip jq curl wget
snap install aws-cli --classic

# --- Enable & start Apache ---
systemctl enable apache2
systemctl start apache2 

# --- Setup WordPress directory ---
mkdir -p /srv/www
chown www-data:www-data /srv/www 
curl -s -o /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz
tar -xzf /tmp/wordpress.tar.gz -C /srv/www
chown -R www-data:www-data /srv/www/wordpress

# --- Apache VirtualHost ---
cat <<'EOF' >/etc/apache2/sites-available/wordpress.conf
<VirtualHost *:80>
    DocumentRoot /srv/www/wordpress
    <Directory /srv/www/wordpress>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

a2ensite wordpress
a2enmod rewrite
a2dissite 000-default
systemctl reload apache2

# --- Fetch RDS credentials from Secrets Manager ---
SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "${db_secrets_name}" \
    --query SecretString --output text)

DBUSER=$(echo "$SECRET" | jq -r .username)
DBPASS=$(echo "$SECRET" | jq -r .password)
DBHOST=$(echo "$SECRET" | jq -r .endpoint)
DBNAME=$(echo "$SECRET" | jq -r .dbname)

# --- Configure WordPress ---
cp /srv/www/wordpress/wp-config-sample.php /srv/www/wordpress/wp-config.php
sed -i "s/database_name_here/$DBNAME/" /srv/www/wordpress/wp-config.php
sed -i "s/username_here/$DBUSER/" /srv/www/wordpress/wp-config.php
sed -i "s/password_here/$DBPASS/" /srv/www/wordpress/wp-config.php
sed -i "s/localhost/$DBHOST/" /srv/www/wordpress/wp-config.php

# --- Replace default salts ---
sed -i "/put your unique phrase here/d" /srv/www/wordpress/wp-config.php
curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> /srv/www/wordpress/wp-config.php

# --- Permissions ---
chown -R www-data:www-data /srv/www/wordpress

echo "✅ WordPress installation and configuration complete."
