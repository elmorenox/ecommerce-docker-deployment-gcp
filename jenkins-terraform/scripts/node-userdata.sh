#!/bin/bash

# Update and install required packages
apt update

# Install Java (same version as controller)
apt update
apt install -y openjdk-17-jdk 
update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java

# Verify Java installation
java -version
update-alternatives --config java

# Create symbolic link to ensure consistent path
ln -sf /usr/lib/jvm/java-17-openjdk-amd64/bin/java /usr/bin/java

apt install -y fontconfig openssh-server curl apt-transport-https ca-certificates gnupg

# Install Docker with updated key handling
apt install -y apt-transport-https ca-certificates curl software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io
usermod -aG docker ubuntu

# Install Google Cloud SDK (needed for the pipeline)
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
apt-get update && apt-get install -y google-cloud-cli

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
apt update
apt install -y terraform

# Install Python and pip
apt install -y python3 python3-pip

# Create Jenkins work directory
mkdir -p /home/ubuntu/jenkins
chown -R ubuntu:ubuntu /home/ubuntu/jenkins