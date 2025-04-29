provider "google" {
  project = var.project_id
  region  = "us-east1"
  zone    = "us-east1-a"
}

# Note: SSH keys are managed manually at the project level
# Command to add SSH keys to project metadata:
# gcloud compute project-info add-metadata --metadata ssh-keys="ubuntu:$(cat ~/.ssh/id_rsa.pub)"

# VPC Resources
resource "google_compute_network" "jenkins_vpc" {
  name                    = "jenkins-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "jenkins_subnet" {
  name          = "jenkins-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.jenkins_vpc.id
}

# Firewall Rules
resource "google_compute_firewall" "jenkins_firewall" {
  name    = "jenkins-firewall"
  network = google_compute_network.jenkins_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "8080", "50000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jenkins"]
}

# No need for additional resources to copy config files
# All configuration is embedded directly in the controller-userdata.sh script

# Compute Instances
resource "google_compute_instance" "jenkins_controller" {
  name         = "jenkins-controller"
  machine_type = "e2-small"
  zone         = "us-central1-a"
  tags         = ["jenkins", "controller"]

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

  # Use simple startup script without templating
  metadata_startup_script = file("scripts/controller-userdata.sh")

  # Configure with broad cloud-platform scope (recommended by Google)
  service_account {
    email  = var.service_account_email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_compute_instance" "jenkins_node" {
  name         = "jenkins-node"
  machine_type = "e2-medium"
  zone         = "us-central1-a"
  tags         = ["jenkins", "node"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 30
    }
  }

  network_interface {
    network    = google_compute_network.jenkins_vpc.name
    subnetwork = google_compute_subnetwork.jenkins_subnet.name
    network_ip = "10.0.1.10"  # Static internal IP
    access_config {
      // Ephemeral public IP
    }
  }

  # Add service account key to node via template
  metadata = {
    # No need to include service account key in metadata
  }

  # Use startup script without service account key
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

output "node_public_ip" {
  value = google_compute_instance.jenkins_node.network_interface.0.access_config.0.nat_ip
}

output "node_internal_ip" {
  value = google_compute_instance.jenkins_node.network_interface.0.network_ip
}