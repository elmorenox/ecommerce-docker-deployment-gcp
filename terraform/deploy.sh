#!/bin/bash

# Add logging
exec > >(tee /var/log/user-data-script.log) 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting deployment script on GCP..."

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updating packages..."
apt-get update
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Package update complete"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing Docker..."
apt-get install -y docker.io
apt-get install -y python3-pip
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 3. Verify both Docker and Compose
docker --version
docker compose version
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

sleep 15
sudo systemctl start docker
sleep 15

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pulling Docker images..."
sudo docker compose pull
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Images pulled"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting containers..."
sudo docker compose up -d --force-recreate
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Containers started"

# Install node exporter for monitoring
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing node exporter for Prometheus..."
useradd --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.0/node_exporter-1.6.0.linux-amd64.tar.gz
tar -xvf node_exporter-1.6.0.linux-amd64.tar.gz
mv node_exporter-1.6.0.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-1.6.0.linux-amd64*

# Create node exporter service
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# Start node exporter
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Node exporter started"

# Final cleanup
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running cleanup..."
sudo docker system prune -f
sudo docker logout
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deployment and cleanup complete"