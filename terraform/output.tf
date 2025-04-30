# GCP-specific outputs
output "database_endpoint" {
  value = google_sql_database_instance.postgres.private_ip_address
  description = "Cloud SQL database endpoint"
}

output "app_instance_private_ip" {
  value = google_compute_instance.app.network_interface.0.network_ip
  description = "App instance private IP"
}

output "vpc_id" {
  value = google_compute_network.ecommerce_vpc.id
  description = "VPC ID"
}

output "load_balancer_ip" {
  value = google_compute_global_address.lb_ip.address
  description = "Public IP address of the load balancer"
}

output "bastion_public_ip" {
  value = google_compute_instance.bastion.network_interface.0.access_config.0.nat_ip
  description = "Public IP address of the bastion host"
}

output "monitoring_public_ip" {
  value = google_compute_instance.monitoring.network_interface.0.access_config.0.nat_ip
  description = "Public IP address of the monitoring instance"
}

output "database_name" {
  value = var.db_name
  description = "Database name"
}

output "project_id" {
  value = var.project_id
  description = "GCP Project ID"
}