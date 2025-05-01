#!/bin/bash

# Add logging
exec > >(tee /var/log/monitoring-setup.log) 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting monitoring setup on GCP..."

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
sleep 5

# Create directories
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating monitoring directories..."
mkdir -p /etc/prometheus
mkdir -p /etc/grafana/provisioning/datasources
mkdir -p /etc/grafana/provisioning/dashboards

# Create prometheus.yml
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating Prometheus configuration..."
cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['${app_private_ip}:9100']
EOF

# Create Grafana datasource provisioning configuration
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating Grafana datasource configuration..."
cat > /etc/grafana/provisioning/datasources/prometheus.yml <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    jsonData:
      httpMethod: POST
EOF

# Create docker-compose.yml for monitoring
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating docker-compose.yml..."
cat > /etc/prometheus/docker-compose.yml <<EOF
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - /etc/prometheus:/etc/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--web.enable-admin-api'
    restart: always

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
    volumes:
      - /etc/grafana/provisioning:/etc/grafana/provisioning
    depends_on:
      - prometheus
    restart: always
EOF

# Start monitoring stack
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting monitoring stack..."
cd /etc/prometheus
sudo docker compose up -d

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitoring setup complete."
echo "Prometheus URL: http://localhost:9090"
echo "Grafana URL: http://localhost:3000"
echo "Grafana login: Not required (anonymous access enabled)"