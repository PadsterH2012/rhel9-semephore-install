#!/bin/bash

# Define the version of Semaphore
SEM_VERSION="2.9.75"

# Update the system
sudo yum update -y

# Install MariaDB Server
sudo yum install mariadb-server.x86_64 -y

# Enable and start MariaDB service
sudo systemctl enable --now mariadb.service

# Secure MariaDB installation
echo "Please follow the on-screen instructions to secure your MariaDB installation:"
sudo mysql_secure_installation

# Download the specified version of Semaphore
wget "https://github.com/ansible-semaphore/semaphore/releases/download/v${SEM_VERSION}/semaphore_${SEM_VERSION}_linux_amd64.rpm"

# Install the downloaded package using yum
sudo yum install -y "semaphore_${SEM_VERSION}_linux_amd64.rpm"

# Configuration for Semaphore
echo "Please enter the configuration details for Semaphore:"
read -p "Port: " SEM_PORT
read -p "MySQL Host (e.g., localhost): " SEM_MYSQL_HOST
read -p "MySQL Port (default 3306): " SEM_MYSQL_PORT
read -p "MySQL Database Name: " SEM_DB_NAME
read -p "MySQL User: " SEM_DB_USER
read -p "MySQL Password: " SEM_DB_PASSWORD
read -p "Session Timeout (in seconds): " SEM_SESSION_TIMEOUT

# Create Semaphore configuration directory and file
sudo mkdir -p /etc/semaphore
cat << EOF > /tmp/config.json
{
  "port": "${SEM_PORT}",
  "mysql": {
    "host": "${SEM_MYSQL_HOST}:${SEM_MYSQL_PORT}",
    "user": "${SEM_DB_USER}",
    "pass": "${SEM_DB_PASSWORD}",
    "name": "${SEM_DB_NAME}"
  },
  "sessionTimeout": ${SEM_SESSION_TIMEOUT}
}
EOF
sudo cp /tmp/config.json /etc/semaphore/config.json

# Create the Semaphore systemd service file
sudo tee /etc/systemd/system/semaphore.service > /dev/null <<EOF
[Unit]
Description=Semaphore Ansible
Documentation=https://github.com/ansible-semaphore/semaphore
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/bin/semaphore service --config=/etc/semaphore/config.json
SyslogIdentifier=semaphore
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the Semaphore service
sudo systemctl daemon-reload
sudo systemctl enable --now semaphore
echo "Semaphore service enabled and started."
