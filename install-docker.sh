#!/bin/bash
set -e

echo "--- Fixing Docker Repo for Debian Trixie ---"

# 1. Clean up the old, incorrect list file
sudo rm -f /etc/apt/sources.list.d/docker.list

# 2. Ensure dependencies are there
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# 3. Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 4. Set up the repo (Manually pointing to 'bookworm' since 'trixie' isn't live yet)
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  bookworm stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Install
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. Permissions
sudo usermod -aG docker $USER

echo "--- Success! ---"
echo "Please log out and back in to use docker without sudo."
