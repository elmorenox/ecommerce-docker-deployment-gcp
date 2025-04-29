#!/bin/bash

# Update and install Java 17 with fontconfig
apt update
apt install -y fontconfig openjdk-17-jre curl jq git

# Install Jenkins with updated repository setup
wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

apt update
apt install -y jenkins

# Add the hardcoded node IP to hosts file
echo "10.0.2.10 jenkins-node" >> /etc/hosts

# Get the SSH key from metadata
mkdir -p /var/lib/jenkins/.ssh
chmod 700 /var/lib/jenkins/.ssh

# Retrieve SSH private key from metadata
SSH_PRIVATE_KEY=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssh_private_key" -H "Metadata-Flavor: Google")
echo "$SSH_PRIVATE_KEY" > /var/lib/jenkins/.ssh/id_rsa
chmod 600 /var/lib/jenkins/.ssh/id_rsa
chown -R jenkins:jenkins /var/lib/jenkins/.ssh

# Clone the configuration repository with sparse checkout
echo "Cloning configuration repository..."
git clone \
  --depth 1 \
  --filter=blob:none \
  --sparse \
  https://github.com/elmorenox/ecommerce-docker-deployment-gcp.git \
  /tmp/jenkins-config
  
cd /tmp/jenkins-config

git sparse-checkout set jenkins-terraform/config

CONFIG_DIR="/tmp/jenkins-config/jenkins-terraform/config"

echo "config dir: $CONFIG_DIR"

# Start Jenkins service
systemctl start jenkins
systemctl enable jenkins

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
while ! curl -s -o /dev/null http://localhost:8080; do
  sleep 10
done

# Get initial admin password
ADMIN_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
echo "Initial Jenkins admin password: $ADMIN_PASSWORD"

# Download the Jenkins CLI
wget http://localhost:8080/jnlpJars/jenkins-cli.jar -O /tmp/jenkins-cli.jar

echo "sleep 60 after jenkins cli download"
sleep 60

# Install required plugins with force restart
echo "Installing required plugins..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD install-plugin \
  git workflow-aggregator pipeline-model-definition docker-workflow blueocean credentials-binding -restart

# Extended wait for Jenkins to fully restart
echo "Waiting extended time (90s) for Jenkins to restart after plugin installation..."
sleep 90

# Get Docker credentials from metadata for inline XML
DOCKER_USERNAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/docker_hub_username" -H "Metadata-Flavor: Google")
DOCKER_PASSWORD=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/docker_hub_password" -H "Metadata-Flavor: Google")

# Create Docker Hub credentials inline
cat > /tmp/docker-credentials.xml << EOF
<?xml version="1.1" encoding="UTF-8"?>
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>docker-hub-credentials</id>
  <description>Docker Hub Credentials</description>
  <username>${DOCKER_USERNAME}</username>
  <password>${DOCKER_PASSWORD}</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOF

# Create the SSH credentials from config file
echo "Creating SSH credentials..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD create-credentials-by-xml \
  system::system::jenkins _ < "$CONFIG_DIR/credentials.xml" || {
  echo "WARNING: Failed to create SSH credentials but proceeding anyway"
}

# Add the Docker Hub credentials
echo "Adding Docker Hub credentials..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD create-credentials-by-xml \
  system::system::jenkins _ < /tmp/docker-credentials.xml || {
  echo "WARNING: Failed to create Docker credentials but proceeding anyway"
}

# Create the node
echo "Creating node jenkins-node..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD create-node \
  "jenkins-node" < "$CONFIG_DIR/node.xml" || {
  echo "WARNING: Failed to create node but proceeding anyway"
}

# Create the pipeline job
echo "Creating job 'workload_4'..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD create-job \
  workload_4 < "$CONFIG_DIR/job-config.xml" || {
  echo "WARNING: Failed to create job but proceeding anyway"
}

# Final restart with safety checks
echo "Performing safe restart..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD safe-restart || {
  echo "WARNING: Safe restart command failed but proceeding anyway"
}

echo "Jenkins setup completed with possible warnings. Check /var/log/jenkins-startup.log for details."