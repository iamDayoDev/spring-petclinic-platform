output "db_endpoint" {
  description = "Connection endpoint of the RDS instance"
  value       = aws_db_instance.petclinic-mysql.address
}

output "db_port" {
  description = "Port the RDS instance is listening on"
  value       = aws_db_instance.petclinic-mysql.port
}

output "db_name" {
  description = "Name of the database"
  value       = aws_db_instance.petclinic-mysql.db_name
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret containing DB credentials"
  value       = aws_secretsmanager_secret.db_secret.arn
}
