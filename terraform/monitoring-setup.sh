#!/bin/bash

# Update and install Docker
apt-get update
apt-get install -y docker.io docker-compose

# Create directories
mkdir -p /etc/prometheus
mkdir -p /etc/grafana

# Create prometheus.yml
cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['${app_private_ip}:9100']
EOF

# Create docker-compose.yml for monitoring
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

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    depends_on:
      - prometheus
EOF

# Start monitoring stack
cd /etc/prometheus
docker-compose up -d