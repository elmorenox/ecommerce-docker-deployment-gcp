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
pip3 install docker-compose
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
docker system prune -f
docker logout
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deployment and cleanup complete"