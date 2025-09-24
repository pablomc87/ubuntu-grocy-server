# Terraform Configuration
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

# Generate SHA-256 password hash using openssl (format: $5$...)
data "external" "password_hash" {
  program = ["sh", "-c", <<-EOT
    HASH=$(openssl passwd -5 '${var.user_password}')
    echo "{\"hash\": \"$HASH\"}"
  EOT
  ]
}

# Create user-data file for cloud-init
resource "local_file" "user_data" {
  content = templatefile("${path.module}/../user-data", {
    hostname     = var.server_hostname
    server_user  = var.server_user
    ssh_key      = file("${pathexpand(var.ssh_key_path)}.pub")
    repo_url     = "https://github.com/${var.github_username}/${var.github_repo}.git"
    password_hash = data.external.password_hash.result.hash
  })
  filename = "${path.module}/../user-data-generated"
}

# Create inventory file
resource "local_file" "inventory" {
  content = templatefile("${path.module}/../inventory.yml", {
    hostname = var.server_hostname
    server_ip    = var.server_ip
    server_user  = var.server_user
  })
  filename = "${path.module}/../inventory-generated.yml"
}

# Create host variables file
resource "local_file" "host_vars" {
  content = templatefile("${path.module}/../host_vars/grocy-server.yml", {
    static_ip_and_mask = "${var.server_ip}/24"
    default_gateway    = var.gateway
    dns_server         = join(",", var.dns_servers)
    dns_search_suffix  = "local"
    grocy_port         = var.grocy_port
    grocy_data_path    = var.grocy_data_path
  })
  filename = "${path.module}/../host_vars/${var.server_hostname}-generated.yml"
}

# Create main playbook
resource "local_file" "main_playbook" {
  content = file("${path.module}/../main.yml")
  filename = "${path.module}/../main.yml"
}
# Create a simple wrapper script that sets environment variables and calls the template
resource "local_file" "deploy_script" {
  content = <<-EOT
#!/bin/bash
# Wrapper script to set environment variables and run deploy-template.sh

export SERVER_IP="${var.server_ip}"
export SERVER_USER="${var.server_user}"
export SSH_KEY="${var.ssh_key_path}"
export CLOUD_INIT_DIR="${var.cloud_init_directory}"
export USER_DATA_FILE="${path.module}/../user-data-generated"
export USER_PASSWORD="${var.user_password}"

exec "${path.module}/deploy-template.sh"
EOT
  filename = "${path.module}/deploy.sh"
  file_permission = "0755"
}

# Ansible provisioner to run the playbook
resource "ansible_host" "grocy_server" {
  name   = var.server_hostname
  groups = ["grocy"]
  variables = {
    ansible_host = var.server_ip
    ansible_user = var.server_user
    ansible_ssh_private_key_file = pathexpand(var.ssh_key_path)
    ansible_ssh_common_args = "-o StrictHostKeyChecking=no"
  }
}

resource "ansible_playbook" "grocy_setup" {
  playbook = "${path.module}/../main.yml"
  name     = var.server_hostname
  
  extra_vars = {
    hostname = var.server_hostname
    server_ip    = var.server_ip
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