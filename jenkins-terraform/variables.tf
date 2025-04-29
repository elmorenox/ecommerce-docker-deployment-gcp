variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "service_account_email" {
  description = "Service Account Email for the instances"
  type        = string
  default     = ""
}

variable "ssh_private_key_file" {
  description = "Path to private SSH key file"
  type        = string
  default     = "~/.ssh/gcp_id_rsa"
}

variable "docker_hub_username" {
  description = "Docker Hub username for Jenkins credentials"
  type        = string
  sensitive   = true
}

variable "docker_hub_password" {
  description = "Docker Hub password for Jenkins credentials"
  type        = string
  sensitive   = true
}