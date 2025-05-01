provider "google" {
  project = var.project_id
  region  = "us-east1"
  zone    = "us-east1-b"
}

# VPC Network
resource "google_compute_network" "ecommerce_vpc" {
  name                    = "ecommerce-vpc"
  auto_create_subnetworks = false
}

# Public subnet for ALB and bastion host
resource "google_compute_subnetwork" "public_subnet" {
  name          = "ecommerce-public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-east1"
  network       = google_compute_network.ecommerce_vpc.id
}

# Private subnet for app and database
resource "google_compute_subnetwork" "private_subnet" {
  name          = "ecommerce-private-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-east1"
  network       = google_compute_network.ecommerce_vpc.id
}

# Router for NAT gateway
resource "google_compute_router" "router" {
  name    = "ecommerce-router"
  region  = "us-east1"
  network = google_compute_network.ecommerce_vpc.id
}

# Cloud NAT for private subnet internet access
resource "google_compute_router_nat" "nat" {
  name                               = "ecommerce-nat"
  router                             = google_compute_router.router.name
  region                             = "us-east1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  
  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Firewall rule for public subnet
resource "google_compute_firewall" "public_firewall" {
  name    = "ecommerce-public-firewall"
  network = google_compute_network.ecommerce_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "3000", "9090"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["public"]
}

resource "google_compute_firewall" "lb_health_checks" {
  name = "ecommerce-healh-checks"
  network = google_compute_network.ecommerce_vpc.name


  allow { 
    protocol = "tcp"
    ports = ["3000"] 
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["app"] 
}

# Firewall rule for private subnet (access from public subnet)
resource "google_compute_firewall" "private_firewall" {
  name    = "ecommerce-private-firewall"
  network = google_compute_network.ecommerce_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "3000", "8000", "5432", "9100"]
  }

  source_ranges = ["10.0.1.0/24"]
  target_tags   = ["private"]
}

# Bastion host
resource "google_compute_instance" "bastion" {
  name         = "ecommerce-bastion"
  machine_type = "e2-micro"
  zone         = "us-east1-b"
  tags         = ["public", "bastion"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network    = google_compute_network.ecommerce_vpc.name
    subnetwork = google_compute_subnetwork.public_subnet.name
    access_config {
      // Ephemeral public IP
    }
  }

  metadata = {
      ssh_private_key  = file("/home/ubuntu/.ssh/id_rsa")
  }

  metadata_startup_script = file("${path.module}/bastion.sh")


  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }
}

# Reserve an IP range for the service networking connection
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.ecommerce_vpc.id
}

# Create the service networking connection
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.ecommerce_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Update your SQL instance to depend on the connection
resource "google_sql_database_instance" "postgres" {
  name             = "ecommerce-db-instance"
  database_version = "POSTGRES_14"
  region           = var.region
  depends_on       = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-f1-micro"
    
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.ecommerce_vpc.id
    }
  }

  deletion_protection = false
}

# Database
resource "google_sql_database" "database" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}

# Database user
resource "google_sql_user" "user" {
  name     = var.db_username
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}

# App instance
resource "google_compute_instance" "app" {
  name         = "ecommerce-app"
  machine_type = "e2-small"
  zone         = "us-east1-b"
  tags         = ["private", "app"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    network    = google_compute_network.ecommerce_vpc.name
    subnetwork = google_compute_subnetwork.private_subnet.name
  }

  metadata_startup_script = templatefile("${path.module}/deploy.sh", {
    docker_user = var.dockerhub_username,
    docker_pass = var.dockerhub_password,
    docker_compose = templatefile("${path.module}/compose.yaml", {
      database_endpoint = "${google_sql_database_instance.postgres.private_ip_address}:5432"
    })
  })

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  depends_on = [google_sql_database.database, google_sql_user.user]
}

# Monitoring instance
resource "google_compute_instance" "monitoring" {
  name         = "ecommerce-monitoring"
  machine_type = "e2-small"
  zone         = "us-east1-b"
  tags         = ["public", "monitoring"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    network    = google_compute_network.ecommerce_vpc.name
    subnetwork = google_compute_subnetwork.public_subnet.name
    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = templatefile("${path.module}/monitoring-setup.sh", {
    app_private_ip = google_compute_instance.app.network_interface.0.network_ip
  })

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }
}

# Load Balancer
# Reserve a static external IP address
resource "google_compute_global_address" "lb_ip" {
  name = "ecommerce-lb-ip"
}

# HTTP health check
resource "google_compute_health_check" "http_health_check" {
  name               = "ecommerce-http-health-check"
  timeout_sec        = 5
  check_interval_sec = 10

  http_health_check {
    port         = 3000
    request_path = "/"
  }
}

# Backend service
resource "google_compute_backend_service" "backend" {
  name                  = "ecommerce-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.http_health_check.id]
  load_balancing_scheme = "EXTERNAL"

  backend {
    group = google_compute_instance_group.app_group.id
  }
}

# Instance group
resource "google_compute_instance_group" "app_group" {
  name      = "ecommerce-instance-group"
  zone      = "us-east1-b"
  instances = [google_compute_instance.app.id]

  named_port {
    name = "http"
    port = 3000
  }
}

# URL map
resource "google_compute_url_map" "url_map" {
  name            = "ecommerce-url-map"
  default_service = google_compute_backend_service.backend.id
}

# HTTP proxy
resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "ecommerce-http-proxy"
  url_map = google_compute_url_map.url_map.id
}

# Global forwarding rule
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name                  = "ecommerce-forwarding-rule"
  ip_protocol           = "TCP"
  port_range            = "80"
  target                = google_compute_target_http_proxy.http_proxy.id
  ip_address            = google_compute_global_address.lb_ip.id
  load_balancing_scheme = "EXTERNAL"
}
