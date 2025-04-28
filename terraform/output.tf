output "rds_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "ec2_private_ip" {
  value = aws_instance.app.private_ip
}

output "vpc_id" {
  value = aws_vpc.main.id
}