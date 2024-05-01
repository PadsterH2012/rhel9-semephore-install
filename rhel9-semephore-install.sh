#!/bin/bash

# Define the version of Semaphore
SEM_VERSION="2.9.75"

# Download the specified version of Semaphore
wget "https://github.com/ansible-semaphore/semaphore/releases/download/v${SEM_VERSION}/semaphore_${SEM_VERSION}_linux_amd64.rpm"

# Install the downloaded package using dnf
sudo dnf install -y "semaphore_${SEM_VERSION}_linux_amd64.rpm"
