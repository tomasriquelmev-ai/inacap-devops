variable "aws_region" {
  description = "Región de AWS donde se desplegará PeñaExpress"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo para identificar todos los recursos del proyecto"
  type        = string
  default     = "penaexpress"
}

variable "environment" {
  description = "Ambiente de despliegue (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "alert_email" {
  description = "Correo electrónico para recibir alertas tempranas de CloudWatch"
  type        = string
  default     = "operaciones@penaexpress.cl"
}
