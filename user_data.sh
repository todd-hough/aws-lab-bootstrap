#!/bin/bash
set -e

# Log all output to /var/log/user-data.log
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting user data script at $(date)"

# Update system packages
echo "Updating system packages..."
dnf update -y

# Install basic utilities
echo "Installing basic utilities..."
# Note: curl-minimal is already installed on AL2023, so we don't install curl to avoid conflicts
dnf install -y \
    git \
    wget \
    unzip \
    tar \
    jq \
    vim \
    htop \
    tmux

# Install Docker
echo "Installing Docker..."
dnf install -y docker
systemctl start docker
systemctl enable docker

# Install Docker Compose
echo "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
curl -L "https://github.com/docker/compose/releases/download/$${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install Python3 (verify it's installed, AL2023 comes with Python3)
echo "Verifying Python3 installation..."
dnf install -y python3 python3-pip

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install --update
rm -rf aws awscliv2.zip
cd -
aws --version

# Install Node.js via nvm for ec2-user
echo "Installing Node.js via nvm..."
sudo -u ec2-user bash << 'EOF'
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
nvm alias default lts/*
EOF

# Install Claude Code CLI (native version)
echo "Installing Claude Code CLI (native version)..."
sudo -u ec2-user bash << 'EOF'
curl -fsSL https://claude.ai/install.sh | bash
EOF

# Install ccusage (Claude Code usage tracker)
echo "Installing ccusage..."
sudo -u ec2-user bash << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
npm install -g ccusage
EOF

%{ if enable_cloudwatch }
# Install and configure CloudWatch agent
echo "Installing CloudWatch agent..."
dnf install -y amazon-cloudwatch-agent

# Create CloudWatch agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'CWCONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/user-data.log",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/messages",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/secure",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/secure",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CWCONFIG

# Start CloudWatch agent
echo "Starting CloudWatch agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
%{ endif }

# Create a welcome message
cat > /home/ec2-user/WELCOME.txt << 'WELCOME'
Welcome to your AWS Development Environment!

Installed Software:
- Git: $(git --version)
- Docker: $(docker --version)
- Docker Compose: $(docker-compose --version)
- Python: $(python3 --version)
- AWS CLI: $(aws --version)
- Node.js: Run 'source ~/.nvm/nvm.sh && node --version'
- Claude Code CLI: $(~/.local/bin/claude --version 2>/dev/null || echo "Native binary installed")
- ccusage: Run 'source ~/.nvm/nvm.sh && ccusage --version'

AWS Bedrock Configuration:
- Region: ${aws_region}
- Claude Code is configured to use AWS Bedrock
- Environment: CLAUDE_CODE_USE_BEDROCK=1
- Models: Auto-discovered on each login
  * Latest Claude Opus 4.x [ANTHROPIC_DEFAULT_OPUS_MODEL]
  * Latest Claude Sonnet 4.5.x [ANTHROPIC_MODEL - default]
  * Latest Claude Haiku 4.5.x [ANTHROPIC_DEFAULT_HAIKU_MODEL - fast model]
- Authentication: EC2 IAM role (automatic)
- Note: Models are queried from Bedrock on each login via ~/.bashrc

Getting Started:
1. Your user is 'ec2-user'
2. Docker is ready to use (no sudo required)
3. Claude Code is ready to use (configured for AWS Bedrock)
4. AWS credentials are automatically configured via IAM role
5. Note: First login may take a few seconds while querying latest models

Quick Test:
- Test AWS CLI: aws bedrock list-foundation-models --region ${aws_region}
- Test Claude Code: claude --help
- Check Claude Code usage: ccusage
- Check model configuration: echo $ANTHROPIC_MODEL

Instance Details:
- Project: ${project_name}
- Region: ${aws_region}

Happy coding!
WELCOME

chown ec2-user:ec2-user /home/ec2-user/WELCOME.txt

# Add nvm initialization, Claude Code binary, and AWS configuration to bashrc
sudo -u ec2-user bash << 'EOF'
cat >> ~/.bashrc << 'BASHRC'

# AWS Configuration
export AWS_REGION="${aws_region}"
export AWS_DEFAULT_REGION="${aws_region}"

# Claude Code - Enable AWS Bedrock
export CLAUDE_CODE_USE_BEDROCK=1

# Add Claude Code to PATH
export PATH="$HOME/.local/bin:$PATH"

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Claude Code - Model Configuration (auto-discovered from AWS Bedrock on each login)
# Query AWS Bedrock for latest models
export ANTHROPIC_MODEL=$(aws bedrock list-foundation-models \
  --by-provider anthropic \
  --region ${aws_region} \
  --query 'modelSummaries[?contains(modelId, `us.anthropic.claude-sonnet-4-5`)] | sort_by(@, &modelId) | [-1].modelId' \
  --output text 2>/dev/null)

export ANTHROPIC_DEFAULT_HAIKU_MODEL=$(aws bedrock list-foundation-models \
  --by-provider anthropic \
  --region ${aws_region} \
  --query 'modelSummaries[?contains(modelId, `us.anthropic.claude-haiku-4-5`)] | sort_by(@, &modelId) | [-1].modelId' \
  --output text 2>/dev/null)

export ANTHROPIC_DEFAULT_OPUS_MODEL=$(aws bedrock list-foundation-models \
  --by-provider anthropic \
  --region ${aws_region} \
  --query 'modelSummaries[?contains(modelId, `us.anthropic.claude-opus-4`)] | sort_by(@, &modelId) | [-1].modelId' \
  --output text 2>/dev/null)

# Claude Code - Token Limits (prevent Bedrock throttling)
export CLAUDE_CODE_MAX_OUTPUT_TOKENS=4096
export MAX_THINKING_TOKENS=1024
BASHRC
EOF

echo "User data script completed successfully at $(date)"
