variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "taskflow"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}