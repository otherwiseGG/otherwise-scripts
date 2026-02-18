#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "--- Starting Docker Installation ---"

# 1. Update system packages
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# 2. Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 3. Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Install Docker Engine, CLI, and Compose
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5. Manage Docker as a non-root user (Optional but recommended)
# This allows you to run 'docker' commands without 'sudo'
sudo usermod -aG docker $USER

echo "--- Installation Complete ---"
echo "NOTE: Please log out and log back in for group changes to take effect."
