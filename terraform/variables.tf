variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region to deploy resources"
  type        = string
  default     = "us-east1"
}

variable "zone" {
  description = "GCP zone to deploy resources"
  type        = string
  default     = "us-east1-b"
}

variable "service_account_email" {
  description = "Service Account Email for the instances"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "ecommerce"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "userdb"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "abcd1234"
}

variable "dockerhub_username" {
  description = "Docker Hub username"
  type        = string
}

variable "dockerhub_password" {
  description = "Docker Hub password"
  type        = string
  sensitive   = true
}