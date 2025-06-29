#!/bin/bash

# --- Go Installation Script for Ubuntu 22.04 ---

# This script downloads the latest version of Go, installs it, and sets up the
# environment variables.

set -e # Exit immediately if a command exits with a non-zero status.

# 1. Fetch the latest Go version number
echo "Fetching the latest Go version..."
GO_VERSION=$(curl -s "https://go.dev/VERSION?m=text" | head -n 1)
if [ -z "$GO_VERSION" ]; then
    echo "Could not fetch the latest Go version. Exiting."
    exit 1
fi
echo "Latest Go version is: $GO_VERSION"

# 2. Define the download URL and filename
DOWNLOAD_URL="https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz"
FILENAME="${GO_VERSION}.linux-amd64.tar.gz"

# 3. Download the Go binary
echo "Downloading Go from $DOWNLOAD_URL..."
wget -q --show-progress -O "/tmp/$FILENAME" "$DOWNLOAD_URL"

# 4. Remove any previous Go installation
echo "Removing any old Go installation from /usr/local/go..."
if [ -d "/usr/local/go" ]; then
    sudo rm -rf /usr/local/go
fi

# 5. Extract the archive
echo "Extracting the Go archive to /usr/local..."
sudo tar -C /usr/local -xzf "/tmp/$FILENAME"

# 6. Clean up the downloaded archive
echo "Cleaning up the downloaded file..."
rm "/tmp/$FILENAME"

# 7. Set up Go environment variables in .profile
# This makes Go available to all shells for the current user.
echo "Setting up environment variables in ~/.profile..."

# Ensure the export lines are not already in the file to avoid duplicates
if ! grep -q 'export GOROOT=/usr/local/go' ~/.profile; then
    echo -e '\n# Go lang environment variables' >> ~/.profile
    echo 'export GOROOT=/usr/local/go' >> ~/.profile
    echo 'export GOPATH=$HOME/go' >> ~/.profile
    echo 'export PATH=$PATH:$GOROOT/bin:$GOPATH/bin' >> ~/.profile
fi

# 8. Inform the user to apply the changes
echo -e "\nInstallation complete!"
echo "Please restart your terminal or run the following command to apply the changes:"
echo "source ~/.profile"
echo -e "\nYou can verify the installation by running:"
echo "go version"