#!/bin/bash
# Grocy Server Deployment Script
# This script deploys the generated user-data to the server and reboots it

set -e  # Exit on any error

# Configuration - these will be set by Terraform environment variables
SERVER_IP="${SERVER_IP:-192.168.1.126}"
SERVER_USER="${SERVER_USER:-pablomartincalvo}"
SSH_KEY="${SSH_KEY:-~/.ssh/id_rsa}"
CLOUD_INIT_DIR="${CLOUD_INIT_DIR:-/var/lib/cloud/seed/nocloud}"
USER_DATA_FILE="${USER_DATA_FILE:-user-data-generated}"

# SSH authentication method
USE_PASSWORD_AUTH=false
# USER_PASSWORD is set by the wrapper script from terraform.tfvars

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Helper functions for SSH commands
ssh_cmd() {
    local cmd="$1"
    if [ "$USE_PASSWORD_AUTH" = true ]; then
        ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "$cmd"
    else
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "$cmd"
    fi
}

# Helper function for SSH commands that need sudo
ssh_sudo_cmd() {
    local cmd="$1"
    if [ "$USE_PASSWORD_AUTH" = true ]; then
        ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "echo '$USER_PASSWORD' | sudo -S $cmd" 2>&1 | grep -v "status: error" || true
    else
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "echo '$USER_PASSWORD' | sudo -S $cmd" 2>&1 | grep -v "status: error" || true
    fi
}

scp_cmd() {
    local src="$1"
    local dst="$2"
    if [ "$USE_PASSWORD_AUTH" = true ]; then
        scp -o StrictHostKeyChecking=no "$src" "$dst"
    else
        scp -i "$SSH_KEY" -o StrictHostKeyChecking=no "$src" "$dst"
    fi
}

ssh_renew() {
    ssh-keygen -R "$SERVER_IP"
    ssh_cmd "echo"
}

# Check if user-data file exists
if [ ! -f "$USER_DATA_FILE" ]; then
    log_error "User-data file '$USER_DATA_FILE' not found!"
    log_info "Please run 'terraform apply' first to generate the user-data file."
    exit 1
fi

log_info "Starting Grocy server deployment..."
log_info "Server: $SERVER_USER@$SERVER_IP"
log_info "Cloud-init directory: $CLOUD_INIT_DIR"

# Test SSH connection
log_info "Testing SSH connection..."
if ! ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o BatchMode=yes "$SERVER_USER@$SERVER_IP" "echo 'SSH connection successful'" >/dev/null 2>&1; then
    log_warning "SSH key authentication failed!"
    log_info "You can set up SSH key authentication with:"
    log_info "  ssh-copy-id -i $SSH_KEY.pub $SERVER_USER@$SERVER_IP"
    echo
    read -p "Would you like to continue with password authentication? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        USE_PASSWORD_AUTH=true
        log_info "Continuing with password authentication..."
        log_info "Using password from terraform.tfvars..."
        log_info "Testing password authentication..."
        if ! ssh -o StrictHostKeyChecking=no "$SERVER_USER@$SERVER_IP" "echo 'SSH connection successful'" >/dev/null 2>&1; then
            log_error "Cannot connect to server via SSH with password!"
            exit 1
        fi
        log_success "SSH password authentication successful"
    else
        log_info "Deployment cancelled. Please set up SSH key authentication first."
        exit 0
    fi
else
    log_success "SSH key authentication successful"
fi

# Create cloud-init directory if it doesn't exist
log_info "Creating cloud-init directory..."
ssh_sudo_cmd "mkdir -p $CLOUD_INIT_DIR"
log_success "Cloud-init directory created"

# Copy user-data to server
log_info "Copying user-data to server..."
scp_cmd "$USER_DATA_FILE" "$SERVER_USER@$SERVER_IP:/tmp/user-data-new"
log_success "User-data copied to server"

# Move user-data to cloud-init directory
log_info "Installing user-data in cloud-init directory..."
ssh_sudo_cmd "cp /tmp/user-data-new $CLOUD_INIT_DIR/user-data"
log_success "User-data installed in cloud-init directory"

# Clean cloud-init state
log_info "Cleaning cloud-init state..."
ssh_sudo_cmd "cloud-init clean"
log_success "Cloud-init state cleaned"

# Clean ansible-pull directory to ensure fresh deployment
log_info "Cleaning ansible-pull directory..."
ssh_sudo_cmd "rm -rf /opt/ansible-pull"
log_success "Ansible-pull directory cleaned"

# Stop and remove any existing Docker containers and services (only if Docker is installed)
log_info "Stopping existing Docker services and containers..."
ssh_sudo_cmd "systemctl stop grocy || true"

# Only try Docker commands if Docker is installed and running
if ssh_sudo_cmd "which docker >/dev/null 2>&1 && systemctl is-active docker >/dev/null 2>&1" >/dev/null 2>&1; then
    log_info "Docker is installed and running, cleaning up containers..."
    ssh_sudo_cmd "sudo docker stop \$(sudo docker ps -aq) 2>/dev/null || true"
    ssh_sudo_cmd "sudo docker rm \$(sudo docker ps -aq) 2>/dev/null || true"
    ssh_sudo_cmd "sudo docker system prune -f 2>/dev/null || true"
    log_success "Docker services and containers stopped"
else
    log_info "Docker not installed or not running, skipping Docker cleanup"
fi

# Clean any existing ansible configurations
log_info "Cleaning existing ansible configurations..."
ssh_sudo_cmd "rm -rf /home/$SERVER_USER/.ansible || true"
ssh_sudo_cmd "rm -rf /root/.ansible || true"
log_success "Ansible configurations cleaned"

# Copy updated inventory files to server
log_info "Copying updated inventory files to server..."
scp_cmd "../inventory.yml" "$SERVER_USER@$SERVER_IP:/tmp/inventory.yml"
scp_cmd "../inventory-generated.yml" "$SERVER_USER@$SERVER_IP:/tmp/inventory-generated.yml"
log_success "Inventory files copied to server"

# Ask for confirmation before reboot
echo
log_warning "The server will now reboot to apply the new configuration."
log_warning "This will:"
log_warning "  - Install ansible-core"
log_warning "  - Run ansible-pull to deploy Grocy"
log_warning "  - Set up Docker and Grocy container"
echo
read -p "Do you want to proceed with the reboot? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Deployment cancelled. You can manually reboot the server later with:"
    log_info "  ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP 'sudo reboot'"
    exit 0
fi

# Reboot server
log_info "Rebooting server..."
ssh_sudo_cmd "reboot" || true
log_success "Server reboot initiated"

# Wait and check server status
log_info "Waiting for server to come back online..."
sleep 10

for i in {1..30}; do
    if ssh_cmd "echo 'Server is online'" >/dev/null 2>&1; then
        log_success "Server is back online!"
        ssh_renew
        break
    fi
    log_info "Waiting for server... (attempt $i/30)"
    sleep 10
done

# Check cloud-init status and wait for completion
log_info "Checking cloud-init status..."
cloud_init_status=$(ssh_sudo_cmd "cloud-init status" 2>/dev/null || echo "status: error")
log_info "Cloud-init status: $cloud_init_status"

# Wait for cloud-init to complete (up to 20 minutes)
# Keep waiting until cloud-init is NOT running (i.e., it's either "done" or "error")
while [[ "$cloud_init_status" == *"running"* ]]; do
    log_info "Cloud-init is still running. Waiting for completion..."
    log_info "This may take several minutes as it installs ansible, runs the playbook, and sets up Docker..."
    
    for i in {1..120}; do
        cloud_init_status=$(ssh_sudo_cmd "cloud-init status" 2>/dev/null || echo "status: error")
        log_info "Cloud-init status check $i/120: $cloud_init_status"
        
        # If it's no longer running, break out of the loop
        if [[ "$cloud_init_status" != *"running"* ]]; then
            break
        fi
        
        sleep 10
    done
    
    # If we've exhausted the retries and it's still running, exit with error
    if [[ "$cloud_init_status" == *"running"* ]]; then
        log_error "Cloud-init did not complete within the timeout period."
        log_info "Current status: $cloud_init_status"
        log_info "You can continue monitoring manually with:"
        if [ "$USE_PASSWORD_AUTH" = true ]; then
            log_info "  ssh $SERVER_USER@$SERVER_IP 'echo \"$USER_PASSWORD\" | sudo -S cloud-init status'"
        else
            log_info "  ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP 'sudo cloud-init status'"
        fi
        log_error "Deployment failed due to cloud-init timeout. Please check the logs and retry."
        exit 1
    fi
done

# Now check the final status
if [[ "$cloud_init_status" == *"done"* ]]; then
    log_success "Cloud-init completed successfully!"
elif [[ "$cloud_init_status" == *"error"* ]]; then
    log_error "Cloud-init encountered an error!"
    log_info "Check the cloud-init logs with:"
    if [ "$USE_PASSWORD_AUTH" = true ]; then
        log_info "  ssh $SERVER_USER@$SERVER_IP 'echo \"$USER_PASSWORD\" | sudo -S cloud-init status --long'"
        log_info "  ssh $SERVER_USER@$SERVER_IP 'echo \"$USER_PASSWORD\" | sudo -S journalctl -u cloud-init -n 50'"
    else
        log_info "  ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP 'sudo cloud-init status --long'"
        log_info "  ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP 'sudo journalctl -u cloud-init -n 50'"
    fi
    log_error "Deployment failed due to cloud-init error. Please check the logs above and fix the issues before retrying."
    exit 1
else
    log_warning "Cloud-init status: $cloud_init_status"
    log_info "This is an unexpected status. Proceeding with caution..."
fi

# Check if ansible was installed
log_info "Checking if ansible was installed..."
if ssh_cmd "which ansible" >/dev/null 2>&1; then
    log_success "Ansible is installed"
else
    log_warning "Ansible is not installed yet. Cloud-init may still be running."
fi

# Check if Docker is running
log_info "Checking Docker status..."
if ssh_sudo_cmd "systemctl is-active docker" >/dev/null 2>&1; then
    log_success "Docker is running"
else
    log_warning "Docker is not running yet. Ansible-pull may still be executing."
fi

# Check if Grocy is running
log_info "Checking Grocy status..."
if ssh_cmd "docker ps | grep grocy" >/dev/null 2>&1; then
    log_success "Grocy container is running!"
    log_success "You can access Grocy at: http://$SERVER_IP:8080"
else
    log_warning "Grocy container is not running yet. The deployment may still be in progress."
        log_info "You can check the status with:"
        if [ "$USE_PASSWORD_AUTH" = true ]; then
            log_info "  ssh $SERVER_USER@$SERVER_IP 'echo \"$USER_PASSWORD\" | sudo -S journalctl -u ansible-pull -f'"
        else
            log_info "  ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP 'sudo journalctl -u ansible-pull -f'"
        fi
fi

echo
log_success "Deployment script completed!"
log_info "Monitor the deployment progress with:"
if [ "$USE_PASSWORD_AUTH" = true ]; then
    log_info "  ssh $SERVER_USER@$SERVER_IP 'echo \"$USER_PASSWORD\" | sudo -S journalctl -u ansible-pull -f'"
    log_info "  ssh $SERVER_USER@$SERVER_IP 'docker ps'"
    log_info "  ssh $SERVER_USER@$SERVER_IP 'cloud-init status'"
else
    log_info "  ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP 'sudo journalctl -u ansible-pull -f'"
    log_info "  ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP 'docker ps'"
    log_info "  ssh -i $SSH_KEY $SERVER_USER@$SERVER_IP 'cloud-init status'"
fi