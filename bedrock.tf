# AWS Bedrock Configuration for Anthropic Claude Models
#
# IMPORTANT: First-time model access requires one-time approval in AWS Console
# 1. Go to AWS Bedrock console in your region
# 2. Navigate to "Model access" in the left sidebar
# 3. Request access for the Claude models below
# 4. Approval is typically instant for most accounts

# Data sources for Anthropic Claude foundation models
# These models are used by the EC2 instance via Claude Code CLI

# Claude Opus 4.1 - Most intelligent model for complex reasoning
data "aws_bedrock_foundation_model" "claude_opus_4_1" {
  model_id = "anthropic.claude-opus-4-1-20250805-v1:0"
}

# Claude Sonnet 4.5 - Advanced model for agents and coding (uses cross-region inference)
data "aws_bedrock_foundation_model" "claude_sonnet_4_5" {
  model_id = "anthropic.claude-sonnet-4-5-20250929-v1:0"
}

# Claude Haiku 4.5 - Efficient model with strong performance (uses cross-region inference)
data "aws_bedrock_foundation_model" "claude_haiku_4_5" {
  model_id = "anthropic.claude-haiku-4-5-20251001-v1:0"
}

# Optional: Enable Bedrock model invocation logging to CloudWatch
resource "aws_cloudwatch_log_group" "bedrock_invocation_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/bedrock/${var.project_name}-model-invocations"
  retention_in_days = 7

  tags = merge(
    {
      Name = "${var.project_name}-bedrock-logs"
    },
    var.tags
  )
}

# Configure Bedrock model invocation logging
resource "aws_bedrock_model_invocation_logging_configuration" "main" {
  count = var.enable_cloudwatch_logs ? 1 : 0

  logging_config {
    embedding_data_delivery_enabled = false
    image_data_delivery_enabled     = false
    text_data_delivery_enabled      = true

    cloudwatch_config {
      log_group_name = aws_cloudwatch_log_group.bedrock_invocation_logs[0].name
      role_arn       = aws_iam_role.bedrock_logging_role[0].arn
    }
  }
}

# IAM role for Bedrock logging (if enabled)
resource "aws_iam_role" "bedrock_logging_role" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  name  = "${var.project_name}-bedrock-logging-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.project_name}-bedrock-logging-role"
    },
    var.tags
  )
}

# IAM policy for Bedrock to write to CloudWatch Logs
resource "aws_iam_role_policy" "bedrock_logging_policy" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  name  = "${var.project_name}-bedrock-logging-policy"
  role  = aws_iam_role.bedrock_logging_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.bedrock_invocation_logs[0].arn}:*"
      }
    ]
  })
}

# Local values for model information
locals {
  bedrock_models = {
    opus = {
      id      = data.aws_bedrock_foundation_model.claude_opus_4_1.model_id
      name    = "Claude Opus 4.1"
      version = "4.1"
      use_case = "Most intelligent model for complex reasoning and agentic tasks"
    }
    sonnet = {
      id      = data.aws_bedrock_foundation_model.claude_sonnet_4_5.model_id
      name    = "Claude Sonnet 4.5"
      version = "4.5"
      use_case = "Advanced model for agents and coding with cross-region inference"
      global_id = "global.anthropic.claude-sonnet-4-5-20250929-v1:0"
    }
    haiku = {
      id      = data.aws_bedrock_foundation_model.claude_haiku_4_5.model_id
      name    = "Claude Haiku 4.5"
      version = "4.5"
      use_case = "Efficient model with strong performance, ideal for cost-effective workloads"
      global_id = "global.anthropic.claude-haiku-4-5-20251001-v1:0"
    }
  }
}
