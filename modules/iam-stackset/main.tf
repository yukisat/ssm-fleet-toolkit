terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# service-managed StackSet で Organizations 全体に IAM ロールを配布
resource "aws_cloudformation_stack_set" "investigate_role" {
  name             = var.stackset_name
  description      = "ssm-fleet-toolkit: SSM Document 実行用 IAM ロール配布"
  permission_model = "SERVICE_MANAGED"
  capabilities     = ["CAPABILITY_NAMED_IAM"]

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "ssm-fleet-toolkit: SSM Document 実行用 IAM ロール"

    Parameters = {
      DelegatedAdminAccountId = {
        Type        = "String"
        Description = "ロールを引き受ける委任管理アカウント ID"
      }
      RoleName = {
        Type    = "String"
        Default = var.role_name
      }
    }

    Resources = {
      InvestigateRole = {
        Type = "AWS::IAM::Role"
        Properties = {
          RoleName = { Ref = "RoleName" }
          AssumeRolePolicyDocument = {
            Version = "2012-10-17"
            Statement = [
              {
                Effect = "Allow"
                Principal = {
                  AWS = {
                    "Fn::Sub" = "arn:aws:iam::$${DelegatedAdminAccountId}:root"
                  }
                }
                Action = "sts:AssumeRole"
              }
            ]
          }
          Policies = [
            {
              PolicyName = "AllowClaudeInvestigateDocuments"
              PolicyDocument = {
                Version = "2012-10-17"
                Statement = [
                  {
                    Sid    = "RunInvestigateDocuments"
                    Effect = "Allow"
                    Action = [
                      "ssm:SendCommand"
                    ]
                    Resource = [
                      "arn:aws:ssm:*:*:document/claude-investigate-*",
                      "arn:aws:ec2:*:*:instance/*"
                    ]
                  },
                  {
                    Sid    = "ReadCommandResults"
                    Effect = "Allow"
                    Action = [
                      "ssm:GetCommandInvocation",
                      "ssm:ListCommandInvocations",
                      "ssm:ListCommands",
                      "ssm:DescribeInstanceInformation",
                      "ssm:GetDocument",
                      "ssm:DescribeDocument"
                    ]
                    Resource = "*"
                  }
                ]
              }
            }
          ]
          Tags = [
            { Key = "ssm-fleet:managed-by", Value = "ssm-fleet-toolkit" }
          ]
        }
      }
    }

    Outputs = {
      RoleArn = {
        Value       = { "Fn::GetAtt" = ["InvestigateRole", "Arn"] }
        Description = "配布された IAM ロールの ARN"
      }
    }
  })

  parameters = {
    DelegatedAdminAccountId = var.delegated_admin_account_id
    RoleName                = var.role_name
  }

  tags = merge(
    {
      "ssm-fleet:managed-by" = "ssm-fleet-toolkit"
    },
    var.tags,
  )
}

resource "aws_cloudformation_stack_set_instance" "all_org" {
  count = length(var.target_account_ids) > 0 || var.deploy_to_entire_organization ? 1 : 0

  stack_set_name = aws_cloudformation_stack_set.investigate_role.name

  dynamic "deployment_targets" {
    for_each = var.deploy_to_entire_organization ? [1] : []
    content {
      organizational_unit_ids = var.organizational_unit_ids
    }
  }

  # 個別アカウント指定の場合
  account_id = var.deploy_to_entire_organization ? null : (length(var.target_account_ids) > 0 ? var.target_account_ids[0] : null)

  region = var.region

  operation_preferences {
    failure_tolerance_count = var.failure_tolerance_count
    max_concurrent_count    = var.max_concurrent_count
    region_concurrency_type = "PARALLEL"
  }
}
