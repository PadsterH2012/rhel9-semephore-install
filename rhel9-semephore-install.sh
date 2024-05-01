#!/bin/bash

# Get the database root password from the first script argument
DB_ROOT_PASSWORD=$1

if [ -z "$DB_ROOT_PASSWORD" ]; then
    echo "Usage: $0 <DB_ROOT_PASSWORD>"
    exit 1
fi
echo "DB_ROOT_PASSWORD is: ${DB_ROOT_PASSWORD}"

# Define the database credentials
DB_HOST="localhost"
DB_PORT="3306"
DB_NAME="semaphore_db"

# Update the system and install necessary packages
sudo yum update -y
sudo yum install -y wget expect mariadb-server jq

# Install EPEL repository and Ansible
sudo yum install epel-release -y
sudo yum install ansible -y

# Start and enable MariaDB service
sudo systemctl enable --now mariadb.service

# Secure MariaDB and set the root password non-interactively
sudo mysql -u root <<-EOF
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${DB_ROOT_PASSWORD}');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
EOF

echo "MariaDB is now secured."

# Open port 3000 for Semaphore on the firewall
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload

# Fetch the latest release of Semaphore from GitHub and install it
SEM_VERSION_URL=$(curl -sL https://api.github.com/repos/ansible-semaphore/semaphore/releases/latest | jq -r '.assets[] | select(.name | endswith("_linux_amd64.rpm")) | .browser_download_url')

if [[ $SEM_VERSION_URL == http* ]]; then
    wget "$SEM_VERSION_URL" -O semaphore_latest.rpm
    if [ -f semaphore_latest.rpm ]; then
        sudo yum install -y semaphore_latest.rpm
    else
        echo "Download failed: semaphore_latest.rpm not found."
        exit 1
    fi
else
    echo "Failed to retrieve valid URL for Semaphore. Please check the release structure on GitHub."
    exit 1
fi

# Place the pre-defined config.json into the correct location
sudo mkdir -p /etc/semaphore  # Ensure the directory exists

sudo bash -c "cat > /etc/semaphore/config.json <<EOF
{
    \"mysql\": {
        \"host\": \"${DB_HOST}:${DB_PORT}\",
        \"user\": \"root\",
        \"pass\": \"${DB_ROOT_PASSWORD}\",
        \"name\": \"${DB_NAME}\",
        \"options\": null
    },
    \"bolt\": {
        \"host\": \"\",
        \"user\": \"\",
        \"pass\": \"\",
        \"name\": \"\",
        \"options\": null
    },
    \"postgres\": {
        \"host\": \"\",
        \"user\": \"\",
        \"pass\": \"\",
        \"name\": \"\",
        \"options\": null
    },
    \"dialect\": \"mysql\",
    \"port\": \"\",
    \"interface\": \"\",
    \"tmp_path\": \"/tmp/semaphore\",
    \"ssh_config_path\": \"\",
    \"git_client\": \"\",
    \"web_host\": \"\",
    \"cookie_hash\": \"MpDg9LH+ktbQI3ajhMU1W+BP8wEqTwH0/s3eZF1JMcg=\",
    \"cookie_encryption\": \"C6VMft6rAtmN62bkrpxTpl4/HYdJ7YZVItOAyIS5xb4=\",
    \"access_key_encryption\": \"rm5LIkVDS+ZebU9MM3qzm6vR9WNn9gzzVzOPK/DZzrc=\",
    \"email_alert\": false,
    \"email_sender\": \"\",
    \"email_host\": \"\",
    \"email_port\": \"\",
    \"email_username\": \"\",
    \"email_password\": \"\",
    \"email_secure\": false,
    \"ldap_enable\": false,
    \"ldap_binddn\": \"\",
    \"ldap_bindpassword\": \"\",
    \"ldap_server\": \"\",
    \"ldap_searchdn\": \"\",
    \"ldap_searchfilter\": \"\",
    \"ldap_mappings\": {
        \"dn\": \"\",
        \"mail\": \"\",
        \"uid\": \"\",
        \"cn\": \"\"
    },
    \"ldap_needtls\": false,
    \"telegram_alert\": false,
    \"telegram_chat\": \"\",
    \"telegram_token\": \"\",
    \"slack_alert\": false,
    \"slack_url\": \"\",
    \"rocketchat_alert\": false,
    \"rocketchat_url\": \"\",
    \"microsoft_teams_alert\": false,
    \"microsoft_teams_url\": \"\",
    \"oidc_providers\": null,
    \"max_task_duration_sec\": 0,
    \"max_parallel_tasks\": 0,
    \"runner_registration_token\": \"\",
    \"password_login_disable\": false,
    \"non_admin_can_create_project\": false,
    \"use_remote_runner\": false,
    \"runner\": {
        \"api_url\": \"\",
        \"registration_token\": \"\",
        \"config_file\": \"\",
        \"one_off\": false,
        \"webhook\": \"\",
        \"max_parallel_tasks\": 0
    },
    \"global_integration_alias\": \"\"
}
EOF"

echo "Semaphore configuration file created."

#Create the Semaphore systemd service file
sudo bash -c 'cat > /etc/systemd/system/semaphore.service <<-EOF
[Unit]
Description=Semaphore Ansible
Documentation=https://github.com/ansible-semaphore/semaphore
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/bin/semaphore service --config=/etc/semaphore/config.json
SyslogIdentifier=semaphore
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

# Reload systemd to recognize the new service and start Semaphore
sudo systemctl daemon-reload
sudo systemctl enable --now semaphore

sleep 15

semaphore user add --admin --login admin --name admin --email admin@example.com --password Admin123 --config /etc/semaphore/config.json

echo "Semaphore setup completed and service started."
