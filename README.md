# Ubuntu Grocy Server Setup

This project configures an Ubuntu Server as a Grocy server using Terraform and Ansible.

## Credits

This project is based on and inspired by [clayshek/raspi-ubuntu-ansible](https://github.com/clayshek/raspi-ubuntu-ansible), which provides excellent Ubuntu Server provisioning using Ansible. We've adapted their cloud-init + ansible-pull approach and added Terraform orchestration for easier configuration management and easier scalability.

## What is Grocy?

Grocy is a self-hosted groceries & household management solution for your home. It helps you manage your household inventory, track expiration dates, plan meals, and create shopping lists. You can find more information [here](https://grocy.info/)

## Architecture

This setup uses a hybrid approach combining Terraform and Ansible:

1. **Terraform** manages the configuration files and orchestrates the deployment
2. **Ansible** (via ansible-pull) handles the actual system configuration on the server
3. **Cloud-init** runs on first boot to set up the initial system and trigger ansible-pull

### Raspberry Pi Optimization

This project was originally designed for Raspberry Pi deployment and includes optimizations for ARM-based systems:
- ARM64 Docker images for better performance
- Optimized memory and CPU settings for single-board computers
- Efficient resource usage for low-power devices

## Prerequisites

- **For Raspberry Pi**: A Raspberry Pi 3B+ or newer with Ubuntu Server 25.04 LTS (it could work with older versions)
- **For other servers**: A computer with Ubuntu Server installed (works on any x86_64 or ARM64 architecture)
- SSH key-based authentication configured
- Terraform installed on your local machine
- Network access to the server
- GitHub repository to store the configuration

## Quick Start

### 1. Configure Your Settings

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your server's details and GitHub info
```

### 2. Generate Configuration Files

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This will generate:
- `user-data` file for cloud-init
- `inventory.yml` for Ansible
- Host variables file
- Main playbook

### 3. Set Up Your Server

#### For Raspberry Pi (Recommended)

1. **Flash Ubuntu Server on your Raspberry Pi SD card**
   - Download Ubuntu Server 25.04 LTS for Raspberry Pi from [ubuntu.com](https://ubuntu.com/download/raspberry-pi)
   - Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) or similar tool to flash the SD card
2. **Copy the generated `user-data` file** to the boot partition of the SD card (the partition labeled "system-boot")
3. **Push your configuration to GitHub** (the Pi will pull from there)
4. **Insert the SD card** into your Raspberry Pi and boot
5. **Wait for cloud-init to complete** (check with: `ssh ubuntu@192.168.1.126 'cloud-init status'`)
6. **Access Grocy** at `http://192.168.1.126:8080`

#### For Other Ubuntu Servers

1. **Install Ubuntu Server on your server**. We recommend using version 25.04 LTS or newer
2. **Copy the generated `user-data` file** to the `/var/lib/cloud/seed/nocloud/` directory on your server, or use cloud-init's built-in mechanisms for your cloud provider
3. **Push your configuration to GitHub** (the server will pull from there)
4. **Boot your server** and wait for cloud-init to complete
5. **Wait for cloud-init to complete** (check with: `ssh ubuntu@192.168.1.126 'cloud-init status'`)
6. **Access Grocy** at `http://192.168.1.126:8080`

## Configuration

### Terraform Variables

Edit `terraform/terraform.tfvars` to customize your setup:

```hcl
# Server connection details
server_hostname = "grocy-server"
server_ip       = "192.168.1.126"
server_user     = "ubuntu"

# SSH configuration
ssh_key_path = "~/.ssh/id_rsa"

# Network configuration
gateway      = "192.168.1.1"
dns_servers  = ["192.168.1.1", "8.8.8.8"]

# Grocy configuration
grocy_port     = 8080
grocy_data_path = "/opt/grocy/data"

# GitHub repository
github_username = "your-github-username"
github_repo     = "your-repo-name"
```

### What Gets Configured

#### System Configuration
- **Hostname**: Sets the servers's hostname
- **Network**: Configures static IP, gateway, and DNS
- **User**: Creates user with SSH key access
- **Packages**: Updates system packages

#### Grocy Setup
- **Docker**: Installs Docker and Docker Compose
- **Grocy Container**: Deploys Grocy using LinuxServer.io image
- **Data Persistence**: Creates data directory with proper permissions
- **Systemd Service**: Sets up auto-start service
- **Firewall**: Configures UFW to allow Grocy access

#### Management Tools
- **Backup Script**: Automated backup of Grocy data
- **Update Script**: Easy Grocy updates
- **Health Check**: System and service monitoring

## File Structure

```
ubuntu-grocy-server/
├── terraform/
│   ├── main.tf                    # Terraform configuration
│   └── terraform.tfvars.example   # Example variables
├── roles/
│   ├── common/                    # Common system setup
│   └── grocy/                     # Grocy-specific setup
│       ├── tasks/main.yml
│       ├── templates/
│       └── handlers/main.yml
├── host_vars/                     # Host-specific variables
├── inventory.yml.tpl              # Ansible inventory template
├── main-grocy.yml                 # Main Ansible playbook
├── user-data-grocy                # Cloud-init template
└── README.md
```

## Management

### Accessing Your Grocy Server

- **Web Interface**: `http://192.168.1.126:8080`
- **SSH Access**: `ssh -i ~/.ssh/id_rsa ubuntu@192.168.1.126`

### Health Check

```bash
ssh -i ~/.ssh/id_rsa ubuntu@192.168.1.126 './health-check.sh'
```

### Backup

```bash
ssh -i ~/.ssh/id_rsa ubuntu@192.168.1.126 './backup-grocy.sh'
```

### Update

```bash
ssh -i ~/.ssh/id_rsa ubuntu@192.168.1.126 './update-grocy.sh'
```

### Service Management

```bash
# Check service status
ssh -i ~/.ssh/id_rsa ubuntu@192.168.1.126 'sudo systemctl status grocy'

# Restart service
ssh -i ~/.ssh/id_rsa ubuntu@192.168.1.126 'sudo systemctl restart grocy'

# View logs
ssh -i ~/.ssh/id_rsa ubuntu@192.168.1.126 'docker compose logs -f'
```

## Troubleshooting

### Raspberry Pi Specific Issues

```bash
# Check if the Pi is booting properly
# Connect a monitor to see boot messages
# Or check the boot partition for any error files

# Verify SD card health
ssh ubuntu@192.168.1.126 'sudo dmesg | grep -i "mmc\|sd"'

# Check temperature (important for Pi)
ssh ubuntu@192.168.1.126 'vcgencmd measure_temp'
```

### Cloud-init Issues

```bash
# Check cloud-init status
ssh ubuntu@192.168.1.126 'cloud-init status'

# View cloud-init logs
ssh ubuntu@192.168.1.126 'sudo tail -f /var/log/cloud-init-output.log'
```

### Ansible Issues

```bash
# Check ansible-pull logs
ssh ubuntu@192.168.1.126 'sudo journalctl -u ansible-pull'

# Manually run ansible-pull
ssh ubuntu@192.168.1.126 'sudo ansible-pull -U https://github.com/your-username/your-repo.git'
```

### Docker Issues

```bash
# Check Docker status
ssh ubuntu@192.168.1.126 'sudo systemctl status docker'

# Check container logs
ssh ubuntu@192.168.1.126 'docker compose logs grocy'
```

## Security Features

- SSH key-based authentication
- UFW firewall configuration
- Non-root user execution

### SSH Key Management

The deployment script supports both SSH key and password authentication:

**Set up SSH key authentication (recommended):**
```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub pablomartincalvo@192.168.1.126
```

- Docker container isolation
- Regular system updates

## Customization

### Adding SSL/HTTPS

1. Modify the Docker Compose template to include Nginx
2. Add SSL certificate configuration
3. Update firewall rules for ports 80 and 443

### Custom Grocy Configuration

1. Modify environment variables in the Docker Compose template
2. Add custom configuration files to the templates directory
3. Update the Grocy role tasks as needed

## Backup and Recovery

### Automated Backups

Set up a cron job for automatic backups:

```bash
# Add to crontab
ssh ubuntu@192.168.1.126 'echo "0 2 * * * /home/ubuntu/backup-grocy.sh" | crontab -'
```

### Data Recovery

In case of data loss:

1. Stop the Grocy service
2. Restore from backup using the backup files
3. Restart the service

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is open source and available under the [MIT License](LICENSE).

## Acknowledgments

- Inspired by [clayshek/raspi-ubuntu-ansible](https://github.com/clayshek/raspi-ubuntu-ansible)
- Uses [LinuxServer.io Grocy Docker image](https://hub.docker.com/r/linuxserver/grocy)
- Built with [Terraform](https://terraform.io) and [Ansible](https://ansible.com)