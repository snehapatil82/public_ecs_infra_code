variable "aws_region" {
  description = "AWS region where resources are created"
  type        = string
  default     = "ap-south-2"
}

variable "roll_no" {
  description = "Roll number used to separate ECS Terraform state and resource names"
  type        = string
  default     = "roll-001"
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "krysha-ecs-cluster"
}

variable "service_name" {
  description = "ECS service name"
  type        = string
  default     = "krysha-churn-service"
}

variable "container_image" {
  description = "Docker image for the ECS task"
  type        = string
  default     = "858230644497.dkr.ecr.ap-south-2.amazonaws.com/churn-api:4.0.0"
}

variable "container_port" {
  description = "Container port exposed by the task"
  type        = number
  default     = 8000
}

variable "desired_count" {
  description = "Desired number of ECS task instances"
  type        = number
  default     = 1
}

variable "mlflow_tracking_uri" {
  description = "MLflow tracking URI to set in container environment variable MLFLOW_TRACKING_URI"
  type        = string
  default     = "http://98.130.129.135:5001/"
}
