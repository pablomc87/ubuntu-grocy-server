terraform {
  required_version = ">= 1.0"
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Variables
variable "pi_hostname" {
  description = "Hostname for the Raspberry Pi"
  type        = string
  default     = "grocy-server"
}

variable "pi_ip" {
  description = "IP address of the Raspberry Pi"
  type        = string
  default     = "192.168.1.126"
}

variable "pi_user" {
  description = "SSH user for the Raspberry Pi"
  type        = string
  default     = "ubuntu"
}

variable "ssh_key_path" {
  description = "Path to SSH private key for connecting to the Pi"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "gateway" {
  description = "Default gateway IP"
  type        = string
  default     = "192.168.1.1"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["192.168.1.1", "8.8.8.8"]
}

variable "grocy_port" {
  description = "Port for Grocy web interface"
  type        = number
  default     = 8080
}

variable "grocy_data_path" {
  description = "Path to store Grocy data on the Pi"
  type        = string
  default     = "/opt/grocy/data"
}

variable "github_username" {
  description = "GitHub username for the repository"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "raspberry-pi-terraform-setup"
}

# Create user-data file for cloud-init
resource "local_file" "user_data" {
  content = templatefile("${path.module}/../user-data", {
    hostname     = var.pi_hostname
    pi_user      = var.pi_user
    ssh_key      = file(pathexpand(var.ssh_key_path))
    repo_url     = "https://github.com/${var.github_username}/${var.github_repo}.git"
  })
  filename = "${path.module}/../user-data-generated"
}

# Create inventory file
resource "local_file" "inventory" {
  content = templatefile("${path.module}/../inventory.yml", {
    hostname = var.pi_hostname
    pi_ip    = var.pi_ip
    pi_user  = var.pi_user
  })
  filename = "${path.module}/../inventory-generated.yml"
}

# Create host variables file
resource "local_file" "host_vars" {
  content = templatefile("${path.module}/../host_vars/grocy-server.yml", {
    static_ip_and_mask = "${var.pi_ip}/24"
    default_gateway    = var.gateway
    dns_server         = join(",", var.dns_servers)
    dns_search_suffix  = "local"
    grocy_port         = var.grocy_port
    grocy_data_path    = var.grocy_data_path
  })
  filename = "${path.module}/../host_vars/${var.pi_hostname}-generated.yml"
}

# Create main playbook
resource "local_file" "main_playbook" {
  content = file("${path.module}/../main.yml")
  filename = "${path.module}/../main-generated.yml"
}

# Ansible provisioner to run the playbook
resource "ansible_host" "grocy_server" {
  inventory_hostname = var.pi_hostname
  groups             = ["grocy"]
  variables = {
    ansible_host = var.pi_ip
    ansible_user = var.pi_user
    ansible_ssh_private_key_file = pathexpand(var.ssh_key_path)
    ansible_ssh_common_args = "-o StrictHostKeyChecking=no"
  }
}

resource "ansible_playbook" "grocy_setup" {
  playbook = "${path.module}/../main-generated.yml"
  name     = var.pi_hostname
  replayable = true
  
  extra_vars = {
    hostname = var.pi_hostname
    pi_ip    = var.pi_ip
    grocy_port = var.grocy_port
    grocy_data_path = var.grocy_data_path
  }

  depends_on = [
    local_file.user_data,
    local_file.inventory,
    local_file.host_vars,
    local_file.main_playbook
  ]
}

# Output information
output "grocy_url" {
  description = "URL to access Grocy web interface"
  value       = "http://${var.pi_ip}:${var.grocy_port}"
}

output "ssh_connection" {
  description = "SSH connection details"
  value       = "ssh -i ${pathexpand(var.ssh_key_path)} ${var.pi_user}@${var.pi_ip}"
}

output "user_data_file" {
  description = "Path to the generated user-data file"
  value       = local_file.user_data.filename
}

output "setup_instructions" {
  description = "Instructions for setting up the Raspberry Pi"
  value = <<-EOT
    1. Flash your Raspberry Pi SD card with Ubuntu Server
    2. Copy the user-data file to the boot partition of the SD card
    3. Insert the SD card into your Raspberry Pi and boot
    4. Wait for cloud-init to complete (check with: ssh ${var.pi_user}@${var.pi_ip} 'cloud-init status')
    5. Run: terraform apply to configure the system
    6. Access Grocy at: http://${var.pi_ip}:${var.grocy_port}
  EOT
}
