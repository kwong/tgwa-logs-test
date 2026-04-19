variable "aws_region" {
  description = "AWS region"
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

variable "hub_account_id" {
  description = "Hub AWS account ID"
  type        = string
  default     = "682033473877"
}

variable "consumer_account_id" {
  description = "Consumer AWS account ID"
  type        = string
  default     = "537124943022"
}

variable "hub_sso_role_name" {
  description = "SSO role name in the hub account"
  type        = string
  default     = "AWSReservedSSO_AWSAdministratorAccess_88ead7c87b9b649c"
}

variable "consumer_sso_role_name" {
  description = "SSO role name in the consumer account"
  type        = string
  default     = "AWSReservedSSO_AWSAdministratorAccess_0a91c60135d1d2ba"
}
