output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.dev_instance.id
}

output "instance_public_ip" {
  description = "Public IP address (Elastic IP) of the EC2 instance"
  value       = aws_eip.dev_instance_eip.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.dev_instance.private_ip
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.dev_instance.id
}

output "ssh_private_key" {
  description = "Private SSH key to connect to the instance (SAVE THIS SECURELY!)"
  value       = tls_private_key.dev_ssh_key.private_key_pem
  sensitive   = true
}

output "ssh_connection_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i dev-key.pem ec2-user@${aws_eip.dev_instance_eip.public_ip}"
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.dev_instance_logs[0].name : "CloudWatch logging disabled"
}

output "bedrock_region" {
  description = "AWS region configured for Bedrock"
  value       = var.aws_region
}

output "bedrock_enabled_models" {
  description = "Anthropic Claude models enabled in AWS Bedrock"
  value = {
    opus = {
      name     = local.bedrock_models.opus.name
      model_id = local.bedrock_models.opus.id
      use_case = local.bedrock_models.opus.use_case
    }
    sonnet = {
      name      = local.bedrock_models.sonnet.name
      model_id  = local.bedrock_models.sonnet.id
      global_id = local.bedrock_models.sonnet.global_id
      use_case  = local.bedrock_models.sonnet.use_case
    }
    haiku = {
      name      = local.bedrock_models.haiku.name
      model_id  = local.bedrock_models.haiku.id
      global_id = local.bedrock_models.haiku.global_id
      use_case  = local.bedrock_models.haiku.use_case
    }
  }
}

output "bedrock_test_command" {
  description = "Command to test Bedrock access from the EC2 instance"
  value       = "aws bedrock list-foundation-models --by-provider anthropic --region ${var.aws_region} --query 'modelSummaries[*].[modelId,modelName]' --output table"
}

output "setup_instructions" {
  description = "Instructions for setting up SSH access and Bedrock"
  value       = <<-EOT
    To connect to your instance:
    1. Save the SSH private key:
       terraform output -raw ssh_private_key > dev-key.pem
       chmod 600 dev-key.pem

    2. Connect via SSH:
       ssh -i dev-key.pem ec2-user@${aws_eip.dev_instance_eip.public_ip}

    3. For VS Code Remote SSH:
       - Install the "Remote - SSH" extension
       - Add to ~/.ssh/config:
         Host ${var.project_name}-dev
           HostName ${aws_eip.dev_instance_eip.public_ip}
           User ec2-user
           IdentityFile /path/to/dev-key.pem
       - Connect using Command Palette: "Remote-SSH: Connect to Host"

    4. Test Bedrock on the EC2 instance:
       - SSH to instance
       - Run: aws bedrock list-foundation-models --by-provider anthropic --region ${var.aws_region}
       - Test Claude Code: claude --help
  EOT
}
