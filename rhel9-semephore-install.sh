#!/bin/bash

# Define the version of Semaphore and database credentials
SEM_VERSION="2.9.75"
DB_HOST="localhost"
DB_PORT="3306"
DB_NAME="semaphore_db"
DB_ROOT_PASSWORD="your_root_password"  # Make sure to use a secure password

# Update the system and install necessary packages
sudo yum update -y
sudo yum install -y wget expect mariadb-server

# Start MariaDB service
sudo systemctl enable --now mariadb.service

# Non-interactive secure MariaDB installation
sudo mysql -e "UPDATE mysql.user SET Password=PASSWORD('${DB_ROOT_PASSWORD}') WHERE User='root';"
sudo mysql -e "DELETE FROM mysql.user WHERE User='';"
sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
sudo mysql -e "DROP DATABASE IF EXISTS test;"
sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Open port 3000 for Semaphore on the firewall
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload

# Download and install Semaphore
wget "https://github.com/ansible-semaphore/semaphore/releases/download/v${SEM_VERSION}/semaphore_${SEM_VERSION}_linux_amd64.rpm"
sudo yum install -y "semaphore_${SEM_VERSION}_linux_amd64.rpm"

# Set up Semaphore using expect to automate interactive inputs
expect -c "
spawn semaphore setup
expect \"What database to use: \"
send \"1\\r\"
expect \"DB Hostname (default 127.0.0.1:3306): \"
send \"${DB_HOST}:${DB_PORT}\\r\"
expect \"DB User (default root): \"
send \"root\\r\"
expect \"DB Password:\"
send \"${DB_ROOT_PASSWORD}\\r\"
expect \"DB Name (default semaphore): \"
send \"${DB_NAME}\\r\"
expect \"Playbook path (default /tmp/semaphore): \"
send \"\\r\"
expect \"Web root URL:\"
send \"\\r\"
expect \"Enable email alerts? (yes/no) (default no):\"
send \"no\\r\"
expect \"Enable telegram alerts? (yes/no) (default no):\"
send \"no\\r\"
expect \"Enable slack alerts? (yes/no) (default no):\"
send \"no\\r\"
expect \"Enable Microsoft Team Channel alerts? (yes/no) (default no):\"
send \"no\\r\"
expect eof
"

# Start and enable Semaphore service
sudo systemctl daemon-reload
sudo systemctl enable --now semaphore
echo "Semaphore setup completed and service started."
