#!/bin/bash

# Add logging
exec > >(tee /var/log/user-data-script.log) 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting deployment script..."

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updating packages..."
sudo apt-get update
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Package update complete"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing Docker..."
sudo apt-get install -y docker.io docker-compose
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Docker installation complete"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempting Docker login..."
echo "${docker_pass}" | docker login -u "${docker_user}" --password-stdin
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Docker login complete"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating app directory..."
mkdir -p /app
cd /app
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Created and moved to /app"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating docker-compose.yml..."
cat > docker-compose.yml <<EOF
${docker_compose}
EOF
echo "[$(date '+%Y-%m-%d %H:%M:%S')] docker-compose.yml created"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pulling Docker images..."
docker-compose pull
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Images pulled"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting containers..."
docker-compose up -d --force-recreate
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Containers started"

# Final cleanup
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running cleanup..."
sudo docker system prune -f
docker logout
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deployment and cleanup complete"
# FIN