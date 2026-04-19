output "hub_role_arn" {
  description = "ARN of the Terraform role in the hub account — use as hub_role_arn in the main config"
  value       = aws_iam_role.hub.arn
}

output "consumer_role_arn" {
  description = "ARN of the Terraform role in the consumer account — use as consumer_role_arn in the main config"
  value       = aws_iam_role.consumer.arn
}
