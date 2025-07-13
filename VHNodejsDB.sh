#!/bin/bash

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Unsupported OS"
    exit 1
fi

# Install Apache (httpd)
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

# Ask for domain name & application path
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
EOF

# Ask whether to install SSL
read -p "Do you want to install SSL using Certbot? (y/n): " SSL_INSTALL
if [[ "$SSL_INSTALL" == "y" ]]; then
    # Install Certbot & Configure SSL
    install_certbot() {
        if [[ "$OS" == "ubuntu" ]]; then
            apt install -y certbot python3-certbot-apache
        elif [[ "$OS" == "almalinux" || "$OS" == "amzn" ]]; then
            dnf install -y certbot python3-certbot-apache
        fi
    }

    install_certbot

    # Request SSL Certificate using Certbot
    certbot --apache -d "$DOMAIN" --non-interactive --agree-tos -m "admin@$DOMAIN"

    # Add HTTPS Virtual Host
    cat <<EOF >> "$VHOST_CONF"
<VirtualHost *:443>
    ServerName $DOMAIN
    DocumentRoot $APP_PATH
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN/privkey.pem
    <Directory "$APP_PATH">
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR:-/var/log/httpd}/error.log
    CustomLog ${APACHE_LOG_DIR:-/var/log/httpd}/access.log combined
</VirtualHost>
EOF

    echo "SSL configured! Restarting Apache..."
    systemctl restart httpd || systemctl restart apache2
else
    echo "Skipping SSL setup."
fi

# Ask for Node.js version
read -p "Enter Node.js version to install (e.g., 16, 18, 20): " NODE_VER

# Install Node.js
curl -fsSL https://rpm.nodesource.com/setup_$NODE_VER.x | bash -
if [[ "$OS" == "ubuntu" ]]; then
    apt install -y nodejs
else
    dnf install -y nodejs
fi

# Install PM2
npm install -g pm2
pm2 startup systemd

# Ask for database choice
echo "Choose a database to install:"
echo "1) MySQL"
echo "2) MongoDB"
echo "3) Skip"
read -p "Enter your choice (1/2/3): " DB_CHOICE

# Install MySQL
if [[ "$DB_CHOICE" == "1" ]]; then
    read -p "Enter MySQL version to install (e.g., 5.7, 8.0): " MYSQL_VER
    if [[ "$OS" == "ubuntu" ]]; then
        apt install -y mysql-server
    elif [[ "$OS" == "almalinux" || "$OS" == "amzn" ]]; then
        dnf install -y mysql mysql-server
    fi
    systemctl enable mysqld
    systemctl start mysqld
fi

# Install MongoDB
if [[ "$DB_CHOICE" == "2" ]]; then
    read -p "Enter MongoDB version to install (e.g., 4.4, 5.0, 6.0): " MONGO_VER
    if [[ "$OS" == "ubuntu" ]]; then
        curl -fsSL https://www.mongodb.org/static/pgp/server-$MONGO_VER.asc | apt-key add -
        echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/$MONGO_VER multiverse" | tee /etc/apt/sources.list.d/mongodb-org-$MONGO_VER.list
        apt update && apt install -y mongodb-org
    elif [[ "$OS" == "almalinux" || "$OS" == "amzn" ]]; then
        echo "[mongodb-org-$MONGO_VER]" > /etc/yum.repos.d/mongodb-org.repo
        echo "name=MongoDB Repository" >> /etc/yum.repos.d/mongodb-org.repo
        echo "baseurl=https://repo.mongodb.org/yum/redhat/$(rpm -E %{rhel})/mongodb-org/$MONGO_VER/x86_64/" >> /etc/yum.repos.d/mongodb-org.repo
        echo "gpgcheck=1" >> /etc/yum.repos.d/mongodb-org.repo
        echo "enabled=1" >> /etc/yum.repos.d/mongodb-org.repo
        dnf install -y mongodb-org
    fi
    systemctl enable mongod
    systemctl start mongod
fi

# Ask for RDS configuration
read -p "Do you want to configure an AWS RDS database? (y/n): " RDS_CONFIG
if [[ "$RDS_CONFIG" == "y" ]]; then
    read -p "Enter AWS RDS endpoint: " RDS_ENDPOINT
    read -p "Enter RDS database name: " RDS_DB
    read -p "Enter RDS username: " RDS_USER
    read -p "Enter RDS password: " RDS_PASS
    echo "Configuring RDS connection..."
    echo "RDS_ENDPOINT=$RDS_ENDPOINT" >> ~/.env
    echo "RDS_DB=$RDS_DB" >> ~/.env
    echo "RDS_USER=$RDS_USER" >> ~/.env
    echo "RDS_PASS=$RDS_PASS" >> ~/.env
    echo "AWS RDS configuration saved in ~/.env"
fi

echo "Setup complete! SSL setup was optional, and Apache is configured!"

