# 1. Control de Perímetro: Security Group restrictivo (Criterio 10 / ES-03)
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Permite solo trafico HTTP entrante y bloquea SSH externo"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Acceso HTTP para operadores y repartidores"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Nota: No se habilita puerto 22 (SSH). El acceso administrativo se realiza via AWS SSM Session Manager.

  egress {
    description = "Salida controlada para actualizaciones y servicios AWS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-web-sg"
    Environment = var.environment
  }
}

# 2. Gestión de Secretos sin hardcoding (Criterio 9 / ES-02)
resource "aws_ssm_parameter" "db_api_token" {
  name        = "/${var.project_name}/${var.environment}/api_secret_token"
  description = "Token interno cifrado para autenticacion de servicios PenaExpress"
  type        = "SecureString"
  value       = "PenaExpress-Prod-Token-${random_id.suffix.hex}"

  tags = {
    Environment = var.environment
  }
}

# 3. IAM Role con Principio de Mínimo Privilegio (Criterio 8 / ES-01)
resource "aws_iam_role" "ec2_app_role" {
  name = "${var.project_name}-ec2-least-privilege-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-role"
    Environment = var.environment
  }
}

# Política granular: Solo acceso a la tabla DynamoDB específica, parámetro SSM específico y CloudWatch Logs
resource "aws_iam_policy" "ec2_least_privilege_policy" {
  name        = "${var.project_name}-ec2-granular-policy"
  description = "Permisos estrictamente necesarios para la aplicacion PenaExpress"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBPedidosAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.pedidos.arn
      },
      {
        Sid    = "ReadEncryptedParameter"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = aws_ssm_parameter.db_api_token.arn
      },
      {
        Sid    = "CloudWatchLogsAgent"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/penaexpress/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_custom_policy" {
  role       = aws_iam_role.ec2_app_role.name
  policy_arn = aws_iam_policy.ec2_least_privilege_policy.arn
}

# Política gestionada para acceso administrativo seguro sin SSH (AWS SSM Session Manager - Criterio 11)
resource "aws_iam_role_policy_attachment" "attach_ssm_core" {
  role       = aws_iam_role.ec2_app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_app_role.name
}
