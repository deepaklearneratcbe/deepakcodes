import os
import subprocess

def is_httpd_installed():
    result = subprocess.run(["dpkg", "-l", "apache2"], stdout=subprocess.PIPE)
    return result.returncode == 0

def install_httpd():
    print("Installing Apache HTTP Server (apache2)...")
    subprocess.run(["sudo", "apt", "update"])
    subprocess.run(["sudo", "apt", "install", "-y", "apache2"])

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

        ErrorLog ${{APACHE_LOG_DIR}}/{domain}_error.log
        CustomLog ${{APACHE_LOG_DIR}}/{domain}_access.log combined
    </VirtualHost>
    """

    # Write the virtual host configuration to a temporary file
    temp_config_file = f"/etc/apache2/sites-available/{domain}.conf"
    with open(temp_config_file, "w") as file:
        file.write(virtual_host_config)

    # Enable the site and restart Apache to apply the changes
    subprocess.run(["sudo", "a2ensite", domain])
    subprocess.run(["sudo", "systemctl", "restart", "apache2"])

    print(f"Virtual host for {domain} created successfully.")

if __name__ == "__main__":
    # Check if apache2 is already installed
    if not is_httpd_installed():
        install_httpd()

    # Prompt the user for domain name and document root
    domain = input("Enter the domain name (e.g., example.com): ").strip()
    document_root = input("Enter the document root path: ").strip()

    # Create virtual host
    create_virtual_host(domain, document_root)

