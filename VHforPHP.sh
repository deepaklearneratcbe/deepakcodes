#!/bin/bash

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Unsupported OS"
    exit 1
fi

# Function to install Apache
install_httpd() {
    if command -v apache2 &> /dev/null || command -v httpd &> /dev/null; then
        echo "Apache is already installed"
    else
        echo "Installing Apache..."
        if [[ "$OS" == "ubuntu" ]]; then
            apt update && apt install -y apache2
            systemctl enable apache2
        elif [[ "$OS" == "amzn" || "$OS" == "amazon" ]]; then
            yum install -y httpd
            systemctl enable httpd
        elif [[ "$OS" == "almalinux" ]]; then
            dnf install -y httpd
            systemctl enable httpd
        fi
    fi
}

# Install Apache
install_httpd

# Ask for domain name
read -p "Enter your domain name (example.com): " DOMAIN
read -p "Enter application path (absolute path): " APP_PATH

# Create virtual host configuration
VHOST_CONF="/etc/httpd/conf.d/$DOMAIN.conf"
if [[ "$OS" == "ubuntu" ]]; then
    VHOST_CONF="/etc/apache2/sites-available/$DOMAIN.conf"
fi

cat <<EOF > "$VHOST_CONF"
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot $APP_PATH
    <Directory "$APP_PATH">
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR:-/var/log/httpd}/error.log
    CustomLog ${APACHE_LOG_DIR:-/var/log/httpd}/access.log combined
</VirtualHost>

<VirtualHost *:443>
    ServerName $DOMAIN
    DocumentRoot $APP_PATH
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/$DOMAIN.crt
    SSLCertificateKeyFile /etc/ssl/private/$DOMAIN.key
</VirtualHost>
EOF

# Enable site and restart Apache
if [[ "$OS" == "ubuntu" ]]; then
    a2ensite "$DOMAIN"
    systemctl restart apache2
else
    systemctl restart httpd
fi

# Ask for PHP version
read -p "Enter PHP version to install (e.g., 7.4, 8.0, 8.1): " PHP_VER

# Install PHP and required extensions
if [[ "$OS" == "ubuntu" ]]; then
    apt install -y php$PHP_VER php$PHP_VER-cli php$PHP_VER-fpm php$PHP_VER-mysql php$PHP_VER-curl php$PHP_VER-xml php$PHP_VER-mbstring
elif [[ "$OS" == "almalinux" || "$OS" == "amzn" ]]; then
    dnf install -y php php-cli php-fpm php-mysqlnd php-curl php-xml php-mbstring
fi

# Ask for MySQL version
read -p "Enter MySQL version to install (e.g., 5.7, 8.0): " MYSQL_VER

# Install MySQL
if [[ "$OS" == "ubuntu" ]]; then
    apt install -y mysql-server
elif [[ "$OS" == "almalinux" || "$OS" == "amzn" ]]; then
    dnf install -y mysql mysql-server
fi

systemctl enable mysqld
systemctl start mysqld

# Install phpMyAdmin (Manual for AlmaLinux 8 & 9 + Amazon Linux)
if [[ "$OS" == "ubuntu" ]]; then
    apt install -y phpmyadmin
elif [[ "$OS" == "almalinux" || "$OS" == "amzn" ]]; then
    echo "Manually installing phpMyAdmin..."
    
    # Install dependencies
    dnf install -y wget unzip

    # Define phpMyAdmin version
    PHPMYADMIN_VERSION="5.2.1"

    # Download & Extract phpMyAdmin
    wget https://www.phpmyadmin.net/downloads/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.gz -O /tmp/phpMyAdmin.tar.gz
    mkdir -p /usr/share/phpmyadmin
    tar -xvf /tmp/phpMyAdmin.tar.gz -C /usr/share/phpmyadmin --strip-components=1

    # Configure Apache for phpMyAdmin
    cat <<EOF > /etc/httpd/conf.d/phpmyadmin.conf
Alias /phpmyadmin /usr/share/phpmyadmin

<Directory /usr/share/phpmyadmin>
    Require all granted
    DirectoryIndex index.php
</Directory>
EOF

    systemctl restart httpd
    echo "phpMyAdmin installed and accessible at http://your-server/phpmyadmin"
fi

echo "Setup complete! Ensure SSL certificates are correctly placed in /etc/ssl/"

