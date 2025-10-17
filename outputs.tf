output "application_url" {
  description = "URL of the TaskFlow application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "backend_service_url" {
  description = "URL of the backend API"
  value       = "http://${aws_lb.main.dns_name}/api"
}

output "ecr_backend_repo" {
  description = "Backend ECR repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repo" {
  description = "Frontend ECR repository URL"
  value       = aws_ecr_repository.frontend.repository_url
}