# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: BUSL-1.1

locals {
  // Variables
  aws_mount             = "aws"     # aws engine
  aws_role              = "test-role"
  aws_region            = var.aws_region
  aws_access_key_id     = var.aws_access_key_id
  aws_access_secret_key = var.aws_access_secret_key
  aws_precreated_role  = "vault-assumed-role-credentials-demo"

  // Output
  aws_output = {
    mount             = local.aws_mount
    role              = local.aws_role
    region            = local.aws_region
    access_key_id     = local.aws_access_key_id
    access_secret_key = local.aws_access_secret_key
  }
}

output "aws" {
  value = local.aws_output
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# Vault Mount AWS Config Setup

data "aws_iam_policy" "enos_aws_engine_test_user_permissions" {
  name = "enos-aws-engine-test-user-perm"
}

resource "aws_iam_user" "enos_aws_engine_test_iam_user" {
  name                 = "enos-aws-engine-test-iam-user"
  permissions_boundary = data.aws_iam_policy.enos_aws_engine_test_user_permissions.arn
  force_destroy        = true
}

resource "aws_iam_user_policy_attachment" "enos_aws_engine_test_policy" {
  user       = aws_iam_user.enos_aws_engine_test_iam_user.name
  policy_arn = data.aws_iam_policy.enos_aws_engine_test_user_permissions.arn
}

resource "aws_iam_access_key" "enos_aws_engine_test_iam_access_key" {
  user = aws_iam_user.enos_aws_engine_test_iam_user.name
}

# Vault Mount AWS Role Setup

data "aws_iam_policy_document" "enos_aws_engine_test_iam_role_policy" {
  statement {
    sid       = "EnosAwsEngineTestIamRolePolicy"
    actions   = ["ec2:DescribeRegions"]
    resources = ["*"]
  }
}

data "aws_iam_role" "vault_target_iam_role" {
  name = "vault-assumed-role-credentials-demo"
}

# Enable aws secrets engine
resource "enos_remote_exec" "secrets_enable_aws_secret" {
  environment = {
    ENGINE            = local.aws_mount
    MOUNT             = local.aws_mount
    VAULT_ADDR        = var.vault_addr
    VAULT_TOKEN       = var.vault_root_token
    VAULT_INSTALL_DIR = var.vault_install_dir
  }

  scripts = [abspath("${path.module}/../../scripts/secrets-enable.sh")]

  transport = {
    ssh = {
      host = var.leader_host.public_ip
    }
  }
}

# # Enable kv secrets engine
# resource "enos_remote_exec" "aws_generate_creds" {
#   depends_on = [enos_remote_exec.secrets_enable_aws_secret]
#   for_each   = var.hosts
#   environment = {
#     AWS_PRECREATED_ROLE   = local.aws_precreated_role
#     AWS_REGION            = local.aws_region
#     AWS_ACCESS_KEY_ID     = local.aws_access_key_id
#     AWS_SECRET_ACCESS_KEY = local.aws_access_secret_key
#     AWS_ROLE              = local.aws_role
#     MOUNT                 = local.aws_mount
#     VAULT_ADDR            = var.vault_addr
#     VAULT_TOKEN           = var.vault_root_token
#     VAULT_INSTALL_DIR     = var.vault_install_dir
#   }
#
#   scripts = [abspath("${path.module}/../../scripts/aws-generate-roles.sh")]
#
#   transport = {
#     ssh = {
#       host = var.leader_host.public_ip
#     }
#   }
# }
