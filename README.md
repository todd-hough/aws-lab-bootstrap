# AWS Lab Bootstrap

Terraform project to bootstrap an AWS development environment with an EC2 instance configured for remote development using VS Code Remote SSH.

## Overview

This project creates a complete AWS development environment including:

- **Networking**: VPC, public subnet, Internet Gateway, and routing
- **Compute**: EC2 instance with configurable size
- **Security**: Security groups with SSH access restricted to specified IP addresses
- **IAM**: Instance profile with AdministratorAccess for AWS operations
- **AI Integration**: AWS Bedrock with Claude models (Opus 4.1, Sonnet 4.5, Haiku 4.5)
- **Monitoring**: CloudWatch Logs integration for system and application logs
- **Storage**: EBS root volume with encryption

### Installed Software

The EC2 instance comes pre-configured with:

- **Git** - Version control
- **Docker & Docker Compose** - Container runtime and orchestration
- **Node.js** (via nvm) - JavaScript runtime (LTS version)
- **Python 3** - Python runtime and pip
- **AWS CLI v2** - Latest AWS command line interface
- **Claude Code CLI** - Anthropic's Claude development assistant (pre-configured for AWS Bedrock)
- **CloudWatch Agent** - AWS monitoring and logging
- **Essential utilities** - curl, wget, vim, tmux, htop, jq, etc.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- AWS account with appropriate credentials configured
- AWS CLI configured with credentials (or environment variables set)

## Quick Start

### 1. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update:
- `allowed_ssh_cidrs` - **IMPORTANT**: Add your IP address (find it with `curl https://checkip.amazonaws.com`)
- `aws_region` - Your preferred AWS region
- `instance_type` - EC2 instance size (default: t3.medium)
- Other optional parameters as needed

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Deploy the Infrastructure

```bash
terraform apply
```

Review the planned changes and type `yes` to confirm.

### 5. Save the SSH Key

After deployment, save the private SSH key:

```bash
terraform output -raw ssh_private_key > dev-key.pem
chmod 600 dev-key.pem
```

**IMPORTANT**: Keep this file secure! It's the only way to access your EC2 instance.

### 6. Connect to Your Instance

```bash
# Get the connection command
terraform output ssh_connection_command

# Connect via SSH
ssh -i dev-key.pem ec2-user@<PUBLIC_IP>
```

## VS Code Remote SSH Setup

### Option 1: Manual Configuration

1. Install the "Remote - SSH" extension in VS Code
2. Add to your `~/.ssh/config` file:

```ssh-config
Host dev-env
  HostName <PUBLIC_IP>
  User ec2-user
  IdentityFile /absolute/path/to/dev-key.pem
```

3. In VS Code, use Command Palette (Cmd/Ctrl+Shift+P):
   - Select "Remote-SSH: Connect to Host"
   - Choose "dev-env"

### Option 2: Quick Connect

1. In VS Code, open Command Palette
2. Select "Remote-SSH: Connect to Host"
3. Enter: `ec2-user@<PUBLIC_IP>`
4. Select the identity file when prompted

## AWS Bedrock Integration

This project includes full integration with AWS Bedrock for using Anthropic's Claude models directly from the EC2 instance.

### Enabled Models

The following Claude models are configured and ready to use:

| Model | Version | Model ID | Use Case |
|-------|---------|----------|----------|
| **Claude Opus 4.1** | 4.1 | `anthropic.claude-opus-4-1-20250805-v1:0` | Most intelligent model for complex reasoning and agentic tasks |
| **Claude Sonnet 4.5** | 4.5 | `anthropic.claude-sonnet-4-5-20250929-v1:0` | Advanced model for agents and coding (default) |
| **Claude Haiku 4.5** | 4.5 | `anthropic.claude-haiku-4-5-20251001-v1:0` | Efficient model with strong performance |

**Note**: Claude Sonnet 4.5 and Haiku 4.5 support cross-region inference using the `global.anthropic` prefix for better availability.

### First-Time Setup

**IMPORTANT**: Before using Bedrock, you must enable model access (one-time setup):

1. Visit the [AWS Bedrock Model Access page](https://console.aws.amazon.com/bedrock/home#/modelaccess) in your region
2. Click "Manage model access"
3. Enable the following models:
   - Claude Opus 4.1
   - Claude Sonnet 4.5
   - Claude Haiku 4.5
4. Click "Save changes"

Approval is typically instant for most AWS accounts. This only needs to be done once per AWS account per region.

### Claude Code Configuration

Claude Code CLI is pre-configured to use AWS Bedrock with the following settings:

- **Provider**: AWS Bedrock
- **Region**: Your configured AWS region (from `aws_region` variable)
- **Default Model**: Claude Sonnet 4.5
- **Authentication**: EC2 IAM role (automatic, no keys needed)

Configuration file location: `~/.config/claude-code/config.json`

### Testing Bedrock Access

After SSH'ing to your EC2 instance, verify Bedrock access:

```bash
# List available Anthropic models
aws bedrock list-foundation-models --by-provider anthropic --region us-east-1

# Test Claude Code
claude --help

# Check AWS credentials (should show IAM role)
aws sts get-caller-identity
```

### Using Claude Code with Bedrock

Once connected to the EC2 instance via VS Code Remote SSH:

```bash
# Start Claude Code
claude

# Claude Code will automatically use AWS Bedrock
# No API key configuration needed!
```

### Model Invocation Logging

If CloudWatch logging is enabled, all Bedrock model invocations are logged to:
- **Log Group**: `/aws/bedrock/<project-name>-model-invocations`
- **Retention**: 7 days

View logs:
```bash
aws logs tail /aws/bedrock/dev-env-model-invocations --follow
```

### Regional Availability

Claude models are available in multiple AWS regions. Common regions:
- `us-east-1` (N. Virginia) - All models
- `us-west-2` (Oregon) - All models
- `eu-west-1` (Ireland) - Most models
- `ap-southeast-1` (Singapore) - Most models

For cross-region inference with Sonnet 4.5 and Haiku 4.5, use the global endpoint format.

## Configuration

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region for deployment | `us-east-1` |
| `project_name` | Prefix for resource names | `dev-env` |
| `instance_type` | EC2 instance type | `t3.medium` |
| `root_volume_size` | Root EBS volume size (GB) | `30` |
| `allowed_ssh_cidrs` | IP addresses allowed for SSH | `[]` (must configure!) |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `public_subnet_cidr` | Public subnet CIDR | `10.0.1.0/24` |
| `enable_cloudwatch_logs` | Enable CloudWatch logging | `true` |

### Common Instance Types

- `t3.small` - 2 vCPU, 2 GB RAM - Light development
- `t3.medium` - 2 vCPU, 4 GB RAM - General development (default)
- `t3.large` - 2 vCPU, 8 GB RAM - Heavier workloads
- `t3.xlarge` - 4 vCPU, 16 GB RAM - Intensive development

## Outputs

After deployment, Terraform provides:

- `instance_public_ip` - Elastic IP address
- `instance_id` - EC2 instance ID
- `ssh_connection_command` - Ready-to-use SSH command
- `setup_instructions` - Complete setup guide (includes Bedrock setup steps)
- `ssh_private_key` - Private key (sensitive)
- `cloudwatch_log_group` - Log group name for monitoring
- `bedrock_region` - AWS region configured for Bedrock
- `bedrock_enabled_models` - Information about enabled Claude models
- `bedrock_test_command` - Command to test Bedrock access

View outputs:
```bash
terraform output
terraform output setup_instructions
```

## Monitoring

If CloudWatch logging is enabled (default), logs are sent to CloudWatch Logs:

- **Log Group**: `/aws/ec2/<project_name>-dev-instance`
- **Streams**:
  - `user-data.log` - Instance initialization logs
  - `messages` - System messages
  - `secure` - Authentication logs

View logs in AWS Console or via CLI:
```bash
aws logs tail /aws/ec2/dev-env-dev-instance --follow
```

## Cost Considerations

Estimated monthly costs (us-east-1):

- **t3.medium instance**: ~$30/month (if running 24/7)
- **EBS storage (30GB gp3)**: ~$2.50/month
- **Elastic IP**: Free while attached to running instance
- **CloudWatch Logs**: ~$0.50/month (typical usage)
- **Data transfer**: Varies based on usage

**Cost Saving Tips**:
- Stop the instance when not in use (Elastic IP remains free)
- Use smaller instance types for lighter workloads
- Disable CloudWatch logging if not needed

## Maintenance

### Stop Instance (Save Costs)
```bash
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)
```

### Start Instance
```bash
aws ec2 start-instances --instance-ids $(terraform output -raw instance_id)
```

### Update Instance Type
1. Edit `instance_type` in `terraform.tfvars`
2. Run `terraform apply`
3. Instance will be stopped and restarted with new type

### Destroy Everything
```bash
terraform destroy
```

**WARNING**: This deletes all resources including the EC2 instance and data!

## Security Best Practices

1. **SSH Access**: Always restrict `allowed_ssh_cidrs` to your specific IP addresses
2. **SSH Key**: Keep `dev-key.pem` secure and never commit it to version control
3. **IAM Permissions**: Consider using a more restrictive IAM role than AdministratorAccess for production
4. **Updates**: Regularly update the instance: `sudo dnf update -y`
5. **Monitoring**: Review CloudWatch logs for suspicious activity

## Troubleshooting

### Cannot connect via SSH
- Verify your IP is in `allowed_ssh_cidrs`
- Check security group rules in AWS Console
- Verify instance is running: `aws ec2 describe-instances --instance-ids <INSTANCE_ID>`

### User data script failed
- SSH to instance and check: `cat /var/log/user-data.log`
- View CloudWatch logs if enabled

### Claude Code not working
- SSH to instance
- Run: `source ~/.nvm/nvm.sh`
- Test: `claude --version`
- Note: nvm is auto-loaded in new shells via .bashrc

## Architecture

```
┌─────────────────────────────────────────┐
│            AWS VPC (10.0.0.0/16)        │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Public Subnet (10.0.1.0/24)     │  │
│  │                                   │  │
│  │  ┌─────────────────────────────┐ │  │
│  │  │   EC2 Instance              │ │  │
│  │  │   - Amazon Linux 2023       │ │  │
│  │  │   - Development Tools       │ │  │
│  │  │   - IAM Role (Admin)        │ │  │
│  │  │   - Elastic IP              │ │  │
│  │  └─────────────────────────────┘ │  │
│  │             ↓ SSH                 │  │
│  └───────────────────────────────────┘  │
│              ↓                          │
│  ┌───────────────────────────────────┐  │
│  │     Internet Gateway              │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
              ↓
    Developer's VS Code
```

## Contributing

Feel free to submit issues or pull requests to improve this project.

## License

This project is provided as-is for educational and development purposes.