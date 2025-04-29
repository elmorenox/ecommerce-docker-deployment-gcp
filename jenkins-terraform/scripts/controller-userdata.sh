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
echo "10.0.1.10 jenkins-node" >> /etc/hosts

# Get the SSH key from metadata
mkdir -p /var/lib/jenkins/.ssh
chmod 700 /var/lib/jenkins/.ssh

# Retrieve SSH private key from metadata
SSH_PRIVATE_KEY=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssh_private_key" -H "Metadata-Flavor: Google")
echo "$SSH_PRIVATE_KEY" > /var/lib/jenkins/.ssh/id_rsa
chmod 600 /var/lib/jenkins/.ssh/id_rsa
chown -R jenkins:jenkins /var/lib/jenkins/.ssh

# Clone the configuration repository or create local config directory
git clone https://github.com/elmorenox/jenkins-config.git /tmp/jenkins-config || {
  echo "Failed to clone config repository, using local config files"
  mkdir -p /opt/jenkins-config
  cp -r /opt/jenkins-config/* /tmp/jenkins-config/ || {
    echo "No local config files found, creating config directory"
    mkdir -p /tmp/jenkins-config
  }
}

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

# Wait for Jenkins to be fully initialized
echo "Waiting for Jenkins to be fully initialized..."
retry_count=0
max_retries=12
until java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD list-plugins > /dev/null 2>&1 || [ $retry_count -eq $max_retries ]; do
  retry_count=$((retry_count+1))
  sleep 30
  echo "Waiting for Jenkins to be ready... ($retry_count/$max_retries)"
done

if [ $retry_count -eq $max_retries ]; then
  echo "Jenkins did not become ready in time. Continuing anyway..."
fi

# Install required plugins
echo "Installing required plugins..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD install-plugin git workflow-aggregator pipeline-model-definition docker-workflow blueocean credentials-binding

# Get Docker credentials from metadata for inline XML
DOCKER_USERNAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/docker_hub_username" -H "Metadata-Flavor: Google")
DOCKER_PASSWORD=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/docker_hub_password" -H "Metadata-Flavor: Google")

# Create Docker Hub credentials inline (with variable substitution)
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
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD create-credentials-by-xml system::system::jenkins _ < /tmp/jenkins-config/config/credentials.xml

# Add the Docker Hub credentials
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD create-credentials-by-xml system::system::jenkins _ < /tmp/docker-credentials.xml

# Create the node using the XML configuration file
echo "Creating node jenkins-node..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD create-node "jenkins-node" < /tmp/jenkins-config/config/node.xml

# Create the pipeline job using the job_config.xml file
echo "Creating job 'workload_4'..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD create-job workload_4 < /tmp/jenkins-config/config/job_config.xml

# Restart Jenkins to apply changes
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD safe-restart