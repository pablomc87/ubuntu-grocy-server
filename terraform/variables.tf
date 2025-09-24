# Server Configuration Variables
variable "server_hostname" {
  description = "Hostname for the Ubuntu server"
  type        = string
  default     = "grocy-server"
}

variable "server_ip" {
  description = "IP address of the Ubuntu server"
  type        = string
  default     = "192.168.1.126"
}

variable "server_user" {
  description = "SSH user for the Ubuntu server"
  type        = string
  default     = "ubuntu"
}

variable "ssh_key_path" {
  description = "Path to SSH private key for connecting to the server"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# Network Configuration Variables
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

# Grocy Configuration Variables
variable "grocy_port" {
  description = "Port for Grocy web interface"
  type        = number
  default     = 8080
}

variable "grocy_data_path" {
  description = "Path to store Grocy data on the server"
  type        = string
  default     = "/opt/grocy/data"
}

# GitHub Configuration Variables
variable "github_username" {
  description = "GitHub username for the repository"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "ubuntu-grocy-server"
}

# User Password Configuration
variable "user_password" {
  description = "Password for the server user (required)"
  type        = string
  sensitive   = true
  
  validation {
    condition     = var.user_password != ""
    error_message = "Password is required. Please set user_password in terraform.tfvars."
  }
  
  validation {
    condition     = length(var.user_password) >= 8
    error_message = "Password must be at least 8 characters long."
  }
  
  validation {
    condition     = can(regex(".*[A-Z].*", var.user_password))
    error_message = "Password must contain at least one uppercase letter."
  }
  
  validation {
    condition     = can(regex(".*[a-z].*", var.user_password))
    error_message = "Password must contain at least one lowercase letter."
  }
  
  validation {
    condition     = can(regex(".*[0-9].*", var.user_password))
    error_message = "Password must contain at least one number."
  }
  
  validation {
    condition     = can(regex(".*[^A-Za-z0-9].*", var.user_password))
    error_message = "Password must contain at least one special character."
  }
}

# Deployment Configuration Variables
variable "cloud_init_directory" {
  description = "Directory on the server where cloud-init user-data should be placed"
  type        = string
}
