variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "hub_profile" {
  description = "AWS CLI profile for the hub account (SSO profile)"
  type        = string
}

variable "consumer_profile" {
  description = "AWS CLI profile for the consumer account (SSO profile)"
  type        = string
}

variable "hub_role_arn" {
  description = "IAM role ARN to assume in the hub account (owns the TGW)"
  type        = string
}

variable "consumer_role_arn" {
  description = "IAM role ARN to assume in the consumer account (owns the VPC attachment)"
  type        = string
}

variable "consumer_vpc_id" {
  description = "ID of an existing VPC in the consumer account to attach to the TGW"
  type        = string
}

variable "consumer_subnet_ids" {
  description = "Subnet IDs in the consumer VPC for the TGW attachment (one per AZ)"
  type        = list(string)
}

variable "enable_ram_accepter" {
  description = "Set to false if both accounts are in the same AWS Org with RAM auto-accept enabled"
  type        = bool
  default     = true
}
