import os
import subprocess

def is_httpd_installed():
    result = subprocess.run(["rpm", "-q", "httpd"], stdout=subprocess.PIPE)
    return result.returncode == 0

def install_httpd():
    print("Installing Apache HTTP Server (httpd)...")
    subprocess.run(["sudo", "dnf", "install", "-y", "httpd"])

def create_directory(path):
    try:
        # Create the directory if it doesn't exist
        os.makedirs(path, exist_ok=True)
        print(f"Directory '{path}' created successfully.")
    except Exception as e:
        print(f"Error: {e}")

def create_virtual_host(domain, document_root):
    print(f"Creating virtual host for {domain}...")

    # Create the document root directory
    create_directory(document_root)

    # Create the virtual host configuration file
    virtual_host_config = f"""
    <VirtualHost *:80>
        ServerAdmin webmaster@{domain}
        ServerName {domain}
        DocumentRoot {document_root}

        <Directory {document_root}>
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>

        ErrorLog /var/log/httpd/{domain}_error.log
        CustomLog /var/log/httpd/{domain}_access.log combined
    </VirtualHost>
    """

    # Write the virtual host configuration to a temporary file
    temp_config_file = f"/etc/httpd/conf.d/{domain}.conf"
    with open(temp_config_file, "w") as file:
        file.write(virtual_host_config)

    # Restart Apache to apply the changes
    subprocess.run(["sudo", "systemctl", "restart", "httpd"])

    print(f"Virtual host for {domain} created successfully.")

if __name__ == "__main__":
    # Check if httpd is already installed
    if not is_httpd_installed():
        install_httpd()

    # Prompt the user for domain name and document root
    domain = input("Enter the domain name (e.g., example.com): ").strip()
    document_root = input("Enter the document root path for eg: /var/www/html/domainname: ").strip()

    # Create virtual host
    create_virtual_host(domain, document_root)

