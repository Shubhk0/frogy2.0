#!/usr/bin/env bash
set -euo pipefail

# ---------------------------
# OS Detection and Package Installation
# ---------------------------
echo "Detecting OS..."
OS_TYPE=$(uname -s)
if [ "$OS_TYPE" = "Linux" ]; then
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
  else
    echo "Cannot detect Linux distribution. Exiting."
    exit 1
  fi
elif [ "$OS_TYPE" = "Darwin" ]; then
  OS="macos"
else
  echo "Unsupported OS: $OS_TYPE. Exiting."
  exit 1
fi
echo "Detected OS: $OS"

install_dependencies() {
  echo "Installing common dependencies for Debian/Ubuntu/Kali..."
  sudo apt-get update
  sudo apt-get install -y jq curl unzip sed python3 libpcap-dev whois dnsutils openssl
}

install_dependencies_redhat() {
  echo "Installing common dependencies for RedHat-based systems..."
  if command -v dnf > /dev/null 2>&1; then
    sudo dnf install -y epel-release
    sudo dnf install -y jq curl unzip sed python3 libpcap-devel whois bind-utils openssl
  else
    sudo yum install -y epel-release
    sudo yum install -y jq curl unzip sed python3 libpcap-devel whois bind-utils openssl
  fi
}

install_dependencies_macos() {
  echo "Installing dependencies for macOS using Homebrew..."
  if ! command -v brew &> /dev/null; then
    echo "Homebrew is not installed. Please install Homebrew from https://brew.sh/ and try again."
    exit 1
  fi
  brew update
  brew install jq curl unzip gnu-sed python3 libpcap whois bind openssl
}

case "$OS" in
  ubuntu|debian|kali)
    echo "Using apt-get for installation..."
    install_dependencies
    ;;
  rhel|centos|fedora|redhat)
    echo "Using yum/dnf for installation..."
    install_dependencies_redhat
    ;;
  macos)
    echo "Using Homebrew for installation..."
    install_dependencies_macos
    ;;
  *)
    echo "Unsupported OS: $OS. Exiting."
    exit 1
    ;;
esac

# ---------------------------
# Check for Go and install if missing
# ---------------------------
if ! command -v go &> /dev/null; then
  echo "Go is not installed. Installing Go..."
  case "$OS" in
    ubuntu|debian|kali)
      sudo apt-get install -y golang-go
      ;;
    rhel|centos|fedora|redhat)
      if command -v dnf &> /dev/null; then
        sudo dnf install -y golang
      else
        sudo yum install -y golang
      fi
      ;;
    macos)
      brew install go
      ;;
    *)
      echo "Unsupported OS for automatic Go installation. Please install Go manually."
      exit 1
      ;;
  esac
else
  echo "Go is already installed."
fi

# ---------------------------
# Install Go-Based Tools
# ---------------------------
echo "Installing Go-based tools (ensure your GOPATH/bin is in your PATH)..."

echo "Installing subfinder..."
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

echo "Installing assetfinder..."
go install github.com/tomnomnom/assetfinder@latest

echo "Installing dnsx..."
go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest

echo "Installing naabu..."
go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest

echo "Installing httpx..."
go install github.com/projectdiscovery/httpx/cmd/httpx@latest

# ---------------------------
# Copy binaries to /usr/local/bin if not already in PATH
# ---------------------------
copy_binaries() {
  echo "Copying installed binaries to /usr/local/bin..."
  GOBIN=$(go env GOPATH)/bin
  local tools=("subfinder" "assetfinder" "dnsx" "naabu" "httpx")
  for tool in "${tools[@]}"; do
    if [ -f "$GOBIN/$tool" ]; then
      sudo cp "$GOBIN/$tool" /usr/local/bin/
      echo "$tool copied to /usr/local/bin"
    else
      echo "Warning: $tool not found in $GOBIN"
    fi
  done
}

copy_binaries

# ---------------------------
# Verify binaries are available in PATH
# ---------------------------
check_binaries() {
  echo "Verifying that all tools are installed and available in PATH..."
  local binaries=("subfinder" "assetfinder" "dnsx" "naabu" "httpx")
  local missing=0
  for bin in "${binaries[@]}"; do
    if ! command -v "$bin" &> /dev/null; then
      echo "Error: $bin not found in PATH."
      missing=1
    else
      echo "$bin found at $(command -v $bin)"
    fi
  done

  if [ $missing -ne 0 ]; then
    echo "One or more binaries are missing from your PATH."
    echo "Please ensure that your Go bin directory (typically $(go env GOPATH)/bin) is in your PATH, or the binaries have been copied to /usr/local/bin."
    exit 1
  else
    echo "All binaries are present."
  fi
}

check_binaries

echo "Installation complete."
echo "If you still have issues, verify that /usr/local/bin is in your PATH."
