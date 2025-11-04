# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Generate SSH key pair
resource "tls_private_key" "dev_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "dev_key" {
  key_name   = "${var.project_name}-dev-key"
  public_key = tls_private_key.dev_ssh_key.public_key_openssh

  tags = merge(
    {
      Name = "${var.project_name}-dev-key"
    },
    var.tags
  )
}

# IAM Role for EC2 instance
resource "aws_iam_role" "dev_instance_role" {
  name = "${var.project_name}-dev-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.project_name}-dev-instance-role"
    },
    var.tags
  )
}

# Attach AdministratorAccess policy
resource "aws_iam_role_policy_attachment" "admin_access" {
  role       = aws_iam_role.dev_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Attach CloudWatchAgentServerPolicy for logging
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count      = var.enable_cloudwatch_logs ? 1 : 0
  role       = aws_iam_role.dev_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "dev_instance_profile" {
  name = "${var.project_name}-dev-instance-profile"
  role = aws_iam_role.dev_instance_role.name

  tags = merge(
    {
      Name = "${var.project_name}-dev-instance-profile"
    },
    var.tags
  )
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "dev_instance_logs" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/ec2/${var.project_name}-dev-instance"
  retention_in_days = 7

  tags = merge(
    {
      Name = "${var.project_name}-dev-instance-logs"
    },
    var.tags
  )
}

# EC2 Instance
resource "aws_instance" "dev_instance" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.dev_instance.id]
  key_name               = aws_key_pair.dev_key.key_name
  iam_instance_profile   = aws_iam_instance_profile.dev_instance_profile.name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      {
        Name = "${var.project_name}-dev-instance-root"
      },
      var.tags
    )
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    enable_cloudwatch = var.enable_cloudwatch_logs
    log_group_name    = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.dev_instance_logs[0].name : ""
    aws_region        = var.aws_region
    project_name      = var.project_name
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(
    {
      Name = "${var.project_name}-dev-instance"
    },
    var.tags
  )
}

# Elastic IP
resource "aws_eip" "dev_instance_eip" {
  instance = aws_instance.dev_instance.id
  domain   = "vpc"

  tags = merge(
    {
      Name = "${var.project_name}-dev-instance-eip"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.main]
}
