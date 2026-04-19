output "transit_gateway_id" {
  description = "ID of the Transit Gateway in the hub account"
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_attachment_id" {
  description = "ID of the TGW VPC attachment in the consumer account"
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
}

output "flow_log_id" {
  description = "ID of the Flow Log created on the TGW attachment"
  value       = aws_flow_log.tgw_attachment.id
}

output "s3_bucket_name" {
  description = "S3 bucket in the consumer account receiving TGW attachment flow logs"
  value       = aws_s3_bucket.tgw_flow_logs.bucket
}
