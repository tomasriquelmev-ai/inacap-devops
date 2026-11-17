terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Sufijo aleatorio para nombres únicos globales (como buckets S3)
resource "random_id" "suffix" {
  byte_length = 4
}

# 1. Red Aislada (VPC) - Requerimiento ES-03
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# 2. Base de Datos Operacional (DynamoDB) - Requerimiento RF-02
resource "aws_dynamodb_table" "pedidos" {
  name         = "${var.project_name}-pedidos"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pedido_id"

  attribute {
    name = "pedido_id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-pedidos-db"
    Environment = var.environment
  }
}

# 3. Instancia de Cómputo EC2 - Requerimiento RF-01
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Protección adicional: IMDSv2 obligatorio (Criterio 11 de rúbrica)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Cifrado del disco raíz EBS (Criterio 11 de rúbrica)
  root_block_device {
    encrypted = true
  }

  # Despliegue automático de app de pedidos + Agente CloudWatch Logs
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3 amazon-cloudwatch-agent
              
              mkdir -p /opt/penaexpress /var/log/penaexpress
              
              cat << 'PYAPP' > /opt/penaexpress/app.py
              from http.server import BaseHTTPRequestHandler, HTTPServer
              import json, datetime

              class Handler(BaseHTTPRequestHandler):
                  def do_GET(self):
                      timestamp = datetime.datetime.utcnow().isoformat()
                      with open("/var/log/penaexpress/app.log", "a") as f:
                          f.write(f"{timestamp} INFO GET {self.path}\n")
                      if self.path == "/health":
                          self.send_response(200)
                          self.send_header("Content-type", "application/json")
                          self.end_headers()
                          self.wfile.write(json.dumps({"status": "ok", "service": "PenaExpress API"}).encode())
                      else:
                          self.send_response(200)
                          self.send_header("Content-type", "text/html; charset=utf-8")
                          self.end_headers()
                          self.wfile.write(b"<h1>PenaExpress SpA - Sistema de Gestion de Pedidos</h1><p>Estado: Operativo</p>")

              HTTPServer(("0.0.0.0", 80), Handler).serve_forever()
              PYAPP

              nohup python3 /opt/penaexpress/app.py > /var/log/penaexpress/server.log 2>&1 &

              cat << 'CWCFG' > /opt/aws/amazon-cloudwatch-agent/bin/config.json
              {
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/var/log/penaexpress/app.log",
                          "log_group_name": "/penaexpress/application",
                          "log_stream_name": "{instance_id}"
                        }
                      ]
                    }
                  }
                }
              }
              CWCFG

              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
              EOF

  tags = {
    Name        = "${var.project_name}-web-server"
    Environment = var.environment
  }
}
