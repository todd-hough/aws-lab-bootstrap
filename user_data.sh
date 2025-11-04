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
dnf install -y \
    git \
    curl \
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

# Install Claude Code CLI
echo "Installing Claude Code CLI..."
sudo -u ec2-user bash << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
npm install -g @anthropic/claude-code
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
- Node.js: Run 'source ~/.nvm/nvm.sh && node --version'
- Claude Code CLI: Run 'source ~/.nvm/nvm.sh && claude --version'

Getting Started:
1. Your user is 'ec2-user'
2. Docker is ready to use (no sudo required)
3. To use Node.js and Claude Code, run: source ~/.nvm/nvm.sh
4. Consider adding 'source ~/.nvm/nvm.sh' to ~/.bashrc for automatic loading

Instance Details:
- Project: ${project_name}
- Region: ${aws_region}

Happy coding!
WELCOME

chown ec2-user:ec2-user /home/ec2-user/WELCOME.txt

# Add nvm initialization to bashrc
sudo -u ec2-user bash << 'EOF'
cat >> ~/.bashrc << 'BASHRC'

# Load nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
BASHRC
EOF

echo "User data script completed successfully at $(date)"
