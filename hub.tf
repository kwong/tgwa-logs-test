###############################################################################
# Hub account — Transit Gateway + RAM sharing
###############################################################################

data "aws_caller_identity" "consumer" {
  provider = aws.consumer
}

resource "aws_ec2_transit_gateway" "this" {
  provider = aws.hub

  description                     = "Hub TGW for cross-account attachment flow log validation"
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = {
    Name = "tgw-flow-log-lab"
  }
}

# --- RAM share to consumer account ---

resource "aws_ram_resource_share" "tgw" {
  provider = aws.hub

  name                      = "tgw-share-flow-log-lab"
  allow_external_principals = true

  tags = {
    Name = "tgw-share-flow-log-lab"
  }
}

resource "aws_ram_resource_association" "tgw" {
  provider = aws.hub

  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "consumer" {
  provider = aws.hub

  principal          = data.aws_caller_identity.consumer.account_id
  resource_share_arn = aws_ram_resource_share.tgw.arn
}
