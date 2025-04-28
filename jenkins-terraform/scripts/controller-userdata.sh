#!/bin/bash

# Update and install Java 17 with fontconfig
apt update
apt install -y fontconfig openjdk-17-jre

# Install Jenkins with updated repository setup
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

apt update
apt install -y jenkins

# Start Jenkins service
systemctl start jenkins
systemctl enable jenkins