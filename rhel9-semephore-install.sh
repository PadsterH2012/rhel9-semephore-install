#!/bin/bash

# Define the version of Semaphore
SEM_VERSION="2.9.75"

# Define database settings
DB_HOST="localhost"
DB_PORT="3306"
DB_NAME="semaphore_db"
DB_USER="semaphore_user"
DB_PASSWORD="your_password"
SEM_PORT="3000"
SEM_SESSION_TIMEOUT="1800"  # Timeout in seconds

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

# Create Semaphore configuration directory and file
sudo mkdir -p /etc/semaphore
cat << EOF > /etc/semaphore/config.json
{
  "port": "${SEM_PORT}",
  "mysql": {
    "host": "${DB_HOST}:${DB_PORT}",
    "user": "${DB_USER}",
    "pass": "${DB_PASSWORD}",
    "name": "${DB_NAME}"
  },
  "sessionTimeout": ${SEM_SESSION_TIMEOUT}
}
EOF

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
