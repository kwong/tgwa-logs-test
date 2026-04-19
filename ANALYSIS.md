# TGW Attachment Flow Log — Cross-Account Validation

**Date:** 17 April 2026  
**Region:** ap-southeast-1  
**Hub account:** 682033473877  
**Consumer account:** 537124943022

---

## Objective

Validate whether a consumer account that owns a Transit Gateway (TGW) VPC attachment
can create flow logs for that attachment, where the TGW itself lives in a separate
hub account shared via AWS Resource Access Manager (RAM).

---

## Infrastructure Setup

A Transit Gateway was created in the hub account and shared with the consumer account
via an AWS RAM resource share. The consumer account then created a VPC attachment to
the shared TGW. Both Terraform providers assumed `TerraformTGWLabRole` (with
`AdministratorAccess`) in their respective accounts, ruling out permission gaps as a
cause of failure.

```
Hub account (682033473877)
┌──────────────────────────────────────────────┐
│  aws_ec2_transit_gateway                     │
│    ID: tgw-0f39f68e7bef478cc                 │
│                                              │
│  aws_ram_resource_share                      │
│    → principal: 537124943022                 │
└──────────────────┬───────────────────────────┘
                   │  RAM share (org-level auto-accept)
                   ▼
Consumer account (537124943022)
┌──────────────────────────────────────────────┐
│  aws_ec2_transit_gateway_vpc_attachment      │
│    ID: tgw-attach-02747d71e9a75f2c6          │
│    VPC: vpc-0128ec6125adad939                │
│    Subnet: subnet-0fdb50216b4ebd478          │
└──────────────────────────────────────────────┘
```

---

## Tests Performed

Three attempts were made to create an `aws_flow_log` resource scoped to the TGW VPC
attachment (`transit_gateway_attachment_id`), varying the API caller account and the
log destination account on each attempt.

### Test 1 — Flow log created from consumer account, destination in consumer account

```
Consumer account (537124943022)
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  aws_flow_log  ──► tgw-attach-02747d71e9a75f2c6         │
│    provider = aws.consumer                              │
│    log_destination = arn:aws:logs:...:537124943022:...  │
│                                                         │
│  aws_cloudwatch_log_group                               │
│  aws_iam_role                                           │
└─────────────────────────────────────────────────────────┘
```

**Result:** `EC2:CreateFlowLogs` — HTTP 403  
`UnauthorizedOperation: You are not authorized to perform this operation.`

The consumer account, despite having `AdministratorAccess`, is not permitted to call
`CreateFlowLogs` against a TGW attachment resource. AWS does not expose this
operation to attachment owners when the TGW is in a different account.

---

### Test 2 — Flow log created from hub account, destination in consumer account

```
Hub account (682033473877)
┌──────────────────────────────────────────────────┐
│  aws_flow_log  ──► tgw-attach-02747d71e9a75f2c6  │
│    provider = aws.hub                            │
│    log_destination = arn:aws:logs:...:537124943022│  ← cross-account destination
└──────────────────────────────────────────────────┘

Consumer account (537124943022)
┌──────────────────────────────────────────────┐
│  aws_cloudwatch_log_group                    │
│  aws_iam_role                                │
└──────────────────────────────────────────────┘
```

**Result:** `EC2:CreateFlowLogs` — HTTP 400  
`InvalidParameter: LogDestination must belong to the same account as the API caller.`

The hub account is the required caller for `CreateFlowLogs` on TGW resources, but AWS
additionally requires the log destination to reside in the same account as the API
caller. A cross-account CloudWatch log group destination is rejected.

---

### Test 3 — Flow log created from hub account, destination in hub account ✓

```
Hub account (682033473877)
┌────────────────────────────────────────────────────────────────┐
│  aws_flow_log  ──► tgw-attach-02747d71e9a75f2c6                │
│    provider = aws.hub                                          │
│    log_destination = arn:aws:logs:...:682033473877:log-group:  │
│                      /aws/tgw-flow-logs/attachment             │
│                                                                │
│  aws_cloudwatch_log_group  /aws/tgw-flow-logs/attachment       │
│  aws_iam_role  tgw-attachment-flow-log-role                    │
└────────────────────────────────────────────────────────────────┘

Consumer account (537124943022)
┌──────────────────────────────────────────────────────┐
│  aws_ec2_transit_gateway_vpc_attachment              │
│    ID: tgw-attach-02747d71e9a75f2c6  (attachment     │
│    owner, but NOT flow log creator)                  │
└──────────────────────────────────────────────────────┘
```

**Result:** Success  
Flow log `fl-0a995f0e7daecb47c` created against attachment `tgw-attach-02747d71e9a75f2c6`.  
Logs delivered to `/aws/tgw-flow-logs/attachment` in the hub account (682033473877).

---

## Summary of Results

| Test | Flow log caller  | Log destination account | Outcome                                    |
|------|------------------|-------------------------|--------------------------------------------|
| 1    | Consumer (537…)  | Consumer (537…)         | **403 UnauthorizedOperation**              |
| 2    | Hub (682…)       | Consumer (537…)         | **400 LogDestination must match caller**   |
| 3    | Hub (682…)       | Hub (682…)              | **Success** — `fl-0a995f0e7daecb47c`       |

---

## Conclusion

**TGW attachment flow logs cannot be created from a consumer/spoke account, but logs can be delivered to a consumer account S3 bucket.**

AWS enforces two constraints on `CreateFlowLogs` for Transit Gateway resource types:

1. The API caller must be the **TGW owner's account**, not the attachment owner's account.
2. For **CloudWatch Logs** destinations, the log group must reside in the **same account as the API caller** (i.e., the hub account). Cross-account CloudWatch delivery is rejected.
3. For **S3** destinations, cross-account delivery is supported — the hub calls `CreateFlowLogs` but the log destination can be an S3 bucket in the consumer account, provided the bucket policy grants `delivery.logs.amazonaws.com` write access scoped to the hub account as the source.

---

## Solution: S3 Cross-Account Delivery (Option 1)

The hub account creates the flow log (required), pointing at an S3 bucket owned by the consumer account. Logs are written directly into the consumer's bucket by the AWS log delivery service — no relay, Lambda, or Firehose needed.

```
Hub account (682033473877)
┌──────────────────────────────────────────────────────────┐
│  aws_flow_log  fl-0a5a747aa9ab2f6f3                      │
│    provider            = aws.hub                         │
│    log_destination_type = s3                             │
│    log_destination      = arn:aws:s3:::                  │
│                           tgw-flow-logs-537124943022/... │
└──────────────────────┬───────────────────────────────────┘
                       │ direct S3 write via delivery.logs.amazonaws.com
                       ▼
Consumer account (537124943022)
┌──────────────────────────────────────────────────────────┐
│  aws_s3_bucket  tgw-flow-logs-537124943022               │
│                                                          │
│  Bucket policy:                                          │
│    Principal: delivery.logs.amazonaws.com                │
│    Action: s3:PutObject, s3:GetBucketAcl                 │
│    Condition: aws:SourceAccount = 682033473877           │
└──────────────────────────────────────────────────────────┘
```

**Result:** `aws_flow_log` `fl-0a5a747aa9ab2f6f3` created successfully. Logs deliver to `s3://tgw-flow-logs-537124943022/tgw-flow-logs/` in the consumer account.

### Why this scales to 2000+ consumer accounts

- The bucket policy template is **identical for every consumer account** — only the `aws:SourceAccount` condition value changes.
- The hub creates **one `aws_flow_log` per attachment**, each pointing at the respective consumer's S3 bucket.
- No intermediate relay infrastructure (no Lambda, Firehose, or subscription filters).
- Adding a new consumer requires: one S3 bucket with the standard policy + one `aws_flow_log` resource in the hub.

### Implications for hub-spoke architectures

- The hub account team must call `CreateFlowLogs` for all spoke attachments — consumer accounts cannot self-service this.
- Logs land natively in each consumer's S3 bucket; consumer teams retain full ownership and visibility of their own flow log data.
- Automation (e.g., EventBridge + Lambda in the hub account triggered on `CreateTransitGatewayVpcAttachment`) can automatically create flow logs when new consumer attachments are made.
