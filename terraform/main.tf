provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ecommerce-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ecommerce-igw"
  }
}

# Fetch AZs in the current region
data "aws_availability_zones" "available" {}

# Public subnets in each AZ
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  map_public_ip_on_launch = true

  tags = {
    Name = "ecommerce-public-${count.index + 1}"
  }
}

# Private subnets in each AZ
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "ecommerce-private-${count.index + 1}"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "ecommerce-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# Elastic IP for NAT
resource "aws_eip" "nat" {
  domain = "vpc"
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "ecommerce-public-rt"
  }
}

# Route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "ecommerce-private-rt"
  }
}

# Route table associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security group for RDS
resource "aws_security_group" "rds" {
  name        = "ecommerce-rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id, aws_security_group.bastion.id]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["44.221.216.0/32"] 
  }
}

# Security group for EC2
resource "aws_security_group" "ec2" {
  name        = "ecommerce-ec2-sg"
  description = "Security group for EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "monitoring" {
  name        = "ecommerce-monitoring-sg"
  description = "Security group for monitoring instance"
  vpc_id      = aws_vpc.main.id  # Add VPC ID

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Prometheus UI
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Grafana UI
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # SSH
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecommerce-monitoring-sg"
  }
}


# RDS subnet group
resource "aws_db_subnet_group" "main" {
  name       = "ecommerce-db-subnet"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "ecommerce-db-subnet-group"
  }
}

#monitoring ec2
resource "aws_instance" "monitoring" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public[0].id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.monitoring.id]

  user_data = base64encode(templatefile("${path.module}/monitoring-setup.sh", {
    app_private_ip = aws_instance.app.private_ip
  }))

  tags = {
    Name = "ecommerce-monitoring"
  }
}

# RDS instance
resource "aws_db_instance" "main" {
  identifier           = "ecommerce-db"
  allocated_storage    = 20
  storage_type         = "gp2"
  engine              = "postgres"
  engine_version      = "14.13"
  instance_class      = "db.t3.micro"
  db_name             = var.db_name
  username            = var.db_username
  password            = var.db_password
  skip_final_snapshot = true

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  tags = {
    Name = "ecommerce-db"
  }
}

# EC2 Instance
resource "aws_instance" "app" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private[0].id

  depends_on = [aws_db_instance.main]

  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name              = var.key_name

  user_data = base64encode(templatefile("${path.module}/deploy.sh", {
    rds_endpoint = aws_db_instance.main.endpoint,
    docker_user = var.dockerhub_username,
    docker_pass = var.dockerhub_password,
    docker_compose = templatefile("${path.module}/compose.yaml", {
      rds_endpoint = aws_db_instance.main.endpoint
    })
  }))

  tags = {
    Name = "ecommerce-app"
  }
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "ecommerce-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow public access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB
resource "aws_lb" "frontend" {
  name               = "ecommerce-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "ecommerce-alb"
  }
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"

    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# ALB Target Group for Frontend
resource "aws_lb_target_group" "frontend" {
  name     = "ecommerce-frontend-tg"
  port     = 3000 
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/" 
    interval            = 30
    timeout             = 5
    healthy_threshold  = 2
    unhealthy_threshold = 2
  }
}

# Register EC2 Instance with Target Group for Frontend
resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.app.id
  port             = 3000  
}

# Security Group for Bastion Host
resource "aws_security_group" "bastion" {
  name        = "ecommerce-bastion-sg"
  description = "Security group for Bastion Host"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Bastion Host EC2 Instance
resource "aws_instance" "bastion" {
  ami                    = "ami-0c7217cdde317cfec"
  instance_type         = "t2.micro"
  subnet_id             = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name              = var.key_name  # Ensure you have access to this key

  tags = {
    Name = "ecommerce-bastion"
  }
}
