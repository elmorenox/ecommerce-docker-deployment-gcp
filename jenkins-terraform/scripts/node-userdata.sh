#!/bin/bash
# Must be run as root or with sudo

# First, fix any conflicting sources
sudo rm -f /etc/apt/sources.list.d/google-cloud-sdk.list

# Install basic packages
sudo apt update
sudo apt install -y fontconfig openssh-server curl apt-transport-https ca-certificates gnupg software-properties-common

sudp apt install python3-dev libjpeg-dev zlib1g-dev libfreetype6-dev liblcms2-dev

# Install Docker with manual key fetching
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install Google Cloud SDK with manual key handling
sudo curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list

# Install Terraform with manual key handling
sudo curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
echo "deb https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Update and install everything
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io google-cloud-cli terraform

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu