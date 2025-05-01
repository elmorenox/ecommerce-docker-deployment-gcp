#!/bin/bash

# Add logging
exec > >(tee /var/log/monitoring-setup.log) 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting monitoring setup on GCP..."

# Update and install Docker
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updating packages..."
apt-get update
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

sleep 15
sudo sytemctl start docker
sleep 15

# Create directories
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating monitoring directories..."
mkdir -p /etc/prometheus
mkdir -p /etc/grafana

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
    restart: always

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    depends_on:
      - prometheus
    restart: always
EOF

# Create Grafana dashboard configuration
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating Grafana dashboard provisioning..."
mkdir -p /etc/grafana/provisioning/datasources
mkdir -p /etc/grafana/provisioning/dashboards

cat > /etc/grafana/provisioning/datasources/prometheus.yml <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

# Start monitoring stack
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting monitoring stack..."
cd /etc/prometheus
docker compose up -d

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Monitoring setup complete."
echo "Prometheus URL: http://localhost:9090"
echo "Grafana URL: http://localhost:3000"
echo "Grafana login: admin / admin"