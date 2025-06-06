provider "google" {
  project = var.project_id
  region  = "us-east1"
  zone    = "us-east1-b"
}

# VPC Resources
resource "google_compute_network" "jenkins_vpc" {
  name                    = "jenkins-vpc"
  auto_create_subnetworks = false
}

# Public subnet for controller
resource "google_compute_subnetwork" "jenkins_subnet" {
  name          = "jenkins-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-east1"
  network       = google_compute_network.jenkins_vpc.id
}

# Private subnet for worker node
resource "google_compute_subnetwork" "jenkins_private_subnet" {
  name          = "jenkins-private-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-east1"
  network       = google_compute_network.jenkins_vpc.id
}

# Cloud Router for NAT Gateway
resource "google_compute_router" "jenkins_router" {
  name    = "jenkins-router"
  region  = "us-east1"
  network = google_compute_network.jenkins_vpc.id
}

# Cloud NAT configuration (equivalent to AWS NAT Gateway)
resource "google_compute_router_nat" "jenkins_nat" {
  name                               = "jenkins-nat"
  router                             = google_compute_router.jenkins_router.name
  region                             = "us-east1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  
  subnetwork {
    name                    = google_compute_subnetwork.jenkins_private_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Firewall Rules for public access to controller
resource "google_compute_firewall" "jenkins_controller_firewall" {
  name    = "jenkins-controller-firewall"
  network = google_compute_network.jenkins_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "8080", "50000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jenkins-controller"]
}

# Firewall Rules for private access to worker
resource "google_compute_firewall" "jenkins_worker_firewall" {
  name    = "jenkins-worker-firewall"
  network = google_compute_network.jenkins_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["10.0.1.0/24"]
  target_tags   = ["jenkins-node"]
}

# Compute Instances
resource "google_compute_instance" "jenkins_controller" {
  name         = "jenkins-controller"
  machine_type = "e2-small"
  zone         = "us-east1-b"
  tags         = ["jenkins", "jenkins-controller"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    network    = google_compute_network.jenkins_vpc.name
    subnetwork = google_compute_subnetwork.jenkins_subnet.name
    network_ip = "10.0.1.5"  # Static internal IP
    access_config {
      // Ephemeral public IP
    }
  }

  # Provide SSH private key and Docker credentials to the controller via metadata
  metadata = {
    ssh_private_key     = file(var.ssh_private_key_file)
    docker_hub_username = var.docker_hub_username
    docker_hub_password = var.docker_hub_password
  }

  metadata_startup_script = file("scripts/controller-userdata.sh")

  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_compute_instance" "jenkins_node" {
  name         = "jenkins-node"
  machine_type = "e2-medium"
  zone         = "us-east1-b"
  tags         = ["jenkins", "jenkins-node"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
    }
  }

  network_interface {
    network    = google_compute_network.jenkins_vpc.name
    subnetwork = google_compute_subnetwork.jenkins_private_subnet.name
    network_ip = "10.0.2.10"  # Static internal IP in private subnet
    # No access_config block = no external IP
  }

  metadata = {
      ssh_private_key     = file(var.ssh_private_key_file)
  }

  metadata_startup_script = file("scripts/node-userdata.sh")

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }
}

# Outputs
output "controller_public_ip" {
  value = google_compute_instance.jenkins_controller.network_interface.0.access_config.0.nat_ip
}

output "controller_internal_ip" {
  value = google_compute_instance.jenkins_controller.network_interface.0.network_ip
}

output "node_internal_ip" {
  value = google_compute_instance.jenkins_node.network_interface.0.network_ip
}