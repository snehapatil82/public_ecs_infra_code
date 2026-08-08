output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.churn.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.churn.arn
}

output "ecs_service_url" {
  description = "HTTP URL for the ECS service via the ALB"
  value       = "http://${data.terraform_remote_state.loadbalancer.outputs.load_balancer_dns_name}"
}
