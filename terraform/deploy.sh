#!/bin/bash
# Add logging
exec > >(tee /var/log/user-data-script.log) 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting deployment script on GCP..."

# Update package lists
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updating packages..."
sudo apt-get update
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Package update complete"

# Install dependencies
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing dependencies..."
sudo apt-get install -y ca-certificates curl gnupg python3-pip
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dependencies installed"

# Set up Docker repository
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting up Docker repository..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists again with the new repository
sudo apt-get update

# Install Docker CE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing Docker CE..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Docker CE installation complete"

# Verify Docker installation
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Verifying Docker installation..."
docker --version
docker compose version

# Enable and start Docker service
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Docker service..."
sudo systemctl enable docker
sudo systemctl start docker
# Wait to ensure Docker is fully started
sleep 15

# Login to Docker Hub
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempting Docker login..."
echo "${docker_pass}" | docker login -u "${docker_user}" --password-stdin
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Docker login complete"

# Setup application
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating app directory..."
mkdir -p /app
cd /app
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Created and moved to /app"

# Create docker-compose.yml
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating docker-compose.yml..."
cat > docker-compose.yml <<EOF
${docker_compose}
EOF
echo "[$(date '+%Y-%m-%d %H:%M:%S')] docker-compose.yml created"

# Pull and start containers
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pulling Docker images..."
sudo docker compose pull
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Images pulled"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting containers..."
sudo docker compose up -d --force-recreate
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Containers started"

# Final cleanup
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running cleanup..."
sudo docker system prune -f
sudo docker logout
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deployment and cleanup complete"