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

# Create Virtual Host Configuration
VHOST_CONF="/etc/httpd/conf.d/$DOMAIN.conf"
if [[ "$OS" == "ubuntu" ]]; then
    VHOST_CONF="/etc/apache2/sites-available/$DOMAIN.conf"
fi

cat <<EOF > "$VHOST_CONF"
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot $APP_PATH
    Redirect permanent / https://$DOMAIN/
</VirtualHost>

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

# Enable site and restart Apache
if [[ "$OS" == "ubuntu" ]]; then
    a2ensite "$DOMAIN"
    systemctl restart apache2
else
    systemctl restart httpd
fi

# Ask for Java version
read -p "Enter Java version to install (e.g., 11, 17, 21): " JAVA_VER

# Install Java
if [[ "$OS" == "ubuntu" ]]; then
    apt install -y openjdk-$JAVA_VER-jdk
elif [[ "$OS" == "almalinux" || "$OS" == "amzn" ]]; then
    dnf install -y java-$JAVA_VER-openjdk
fi

# Ask for Tomcat version
read -p "Enter Tomcat version to install (e.g., 9, 10, 11): " TOMCAT_VER

# Install Tomcat
TOMCAT_DIR="/opt/tomcat"
mkdir -p $TOMCAT_DIR
wget https://dlcdn.apache.org/tomcat/tomcat-$TOMCAT_VER/v$TOMCAT_VER.0.80/bin/apache-tomcat-$TOMCAT_VER.0.80.tar.gz -O /tmp/tomcat.tar.gz
tar -xvf /tmp/tomcat.tar.gz -C $TOMCAT_DIR --strip-components=1
chmod +x $TOMCAT_DIR/bin/*.sh
systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat

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

    echo "SSL configured! Restarting Apache..."
    systemctl restart httpd || systemctl restart apache2
else
    echo "Skipping SSL setup."
fi

echo "Setup complete! SSL setup was optional, and Apache + Tomcat are configured!"

