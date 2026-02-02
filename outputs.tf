output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.server.id
}

output "instance_public_ip" {
  description = "Public IP address (Elastic IP) of the EC2 instance"
  value       = aws_eip.server_eip.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.server.private_ip
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
  value       = aws_security_group.server_sg.id
}

output "ssh_private_key" {
  description = "Private SSH key to connect to the instance (SAVE THIS SECURELY!)"
  value       = tls_private_key.server_ssh_key.private_key_pem
  sensitive   = true
}

output "ssh_connection_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i dev-key.pem ec2-user@${aws_eip.server_eip.public_ip}"
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.server_logs[0].name : "CloudWatch logging disabled"
}

output "setup_instructions" {
  description = "Instructions for setting up SSH access"
  value       = <<-EOT
    To connect to your instance:
    1. Save the SSH private key:
       terraform output -raw ssh_private_key > dev-key.pem
       chmod 600 dev-key.pem

    2. Connect via SSH:
       ssh -i dev-key.pem ec2-user@${aws_eip.server_eip.public_ip}

    3. For VS Code Remote SSH:
       - Install the "Remote - SSH" extension
       - Add to ~/.ssh/config:
         Host ${var.project_name}-server
           HostName ${aws_eip.server_eip.public_ip}
           User ec2-user
           IdentityFile /path/to/dev-key.pem
       - Connect using Command Palette: "Remote-SSH: Connect to Host"
  EOT
}
