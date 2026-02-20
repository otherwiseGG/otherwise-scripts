#!/bin/bash

# 1. Remove any existing Docker-related lists that might be broken
sudo rm -f /etc/apt/sources.list.d/docker.list

# 2. Update and install initial dependencies
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# 3. Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 4. Add the Debian repository (Forcing 'bookworm' for Trixie compatibility)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Install Docker Engine and Plugins
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. Post-install: Add current user to docker group (optional but recommended)
sudo usermod -aG docker $USER

echo "----------------------------------------------------"
echo "Installation complete! Please LOG OUT and LOG BACK IN"
echo "to run Docker without 'sudo'."
echo "----------------------------------------------------"
