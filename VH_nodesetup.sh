#!/bin/bash

# Update system
#echo "Updating the system..."
#sudo dnf update -y

# Install Apache
echo "Installing Apache..."
sudo dnf install httpd -y
sudo systemctl start httpd
sudo systemctl enable httpd

# Configure Firewall
#echo "Configuring firewall..."
#sudo firewall-cmd --add-service=http --permanent
#sudo firewall-cmd --add-service=https --permanent
#sudo firewall-cmd --reload

# Create Virtual Host Directory
echo "Creating directories for growyourroots.co.in..."
sudo mkdir -p /var/www/growyourroots.co.in/public_html
sudo chown -R apache:apache /var/www/growyourroots.co.in
sudo chmod -R 755 /var/www/growyourroots.co.in

# Create Virtual Host Configuration
echo "Configuring virtual host..."
sudo bash -c 'cat > /etc/httpd/conf.d/growyourroots.co.in.conf << EOF
<VirtualHost *:80>
    ServerName growyourroots.co.in
    DocumentRoot /var/www/growyourroots.co.in/public_html
    ErrorLog /var/log/httpd/growyourroots.co.in_error.log
    CustomLog /var/log/httpd/growyourroots.co.in_access.log combined
</VirtualHost>
EOF'

# Test Configuration and Restart Apache
echo "Testing Apache configuration..."
sudo apachectl configtest
sudo systemctl restart httpd

# Install Node.js 22
echo "Installing Node.js 22..."
curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash
sudo dnf install -y nodejs

# Verify Node.js Installation
echo "Verifying Node.js installation..."
node -v
npm -v

echo "Installation complete!"

