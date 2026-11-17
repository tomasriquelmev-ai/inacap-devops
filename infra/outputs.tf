output "web_server_public_ip" {
  description = "Dirección IP pública del servidor de PeñaExpress"
  value       = aws_instance.web_server.public_ip
}

output "healthcheck_url" {
  description = "Endpoint de verificación de salud del servicio"
  value       = "http://${aws_instance.web_server.public_ip}/health"
}

output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB de pedidos"
  value       = aws_dynamodb_table.pedidos.name
}
