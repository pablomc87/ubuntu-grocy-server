# Grocy Access Information
output "grocy_url" {
  description = "URL to access Grocy web interface"
  value       = "http://${var.server_ip}:${var.grocy_port}"
}

# SSH Connection Information
output "ssh_connection" {
  description = "SSH connection details"
  value       = "ssh -i ${pathexpand(var.ssh_key_path)} ${var.server_user}@${var.server_ip}"
}

# Generated Files Information
output "user_data_file" {
  description = "Path to the generated user-data file"
  value       = local_file.user_data.filename
}

output "deploy_script" {
  description = "Path to the deployment script"
  value       = "${path.module}/deploy-generated.sh"
}

# Password Status
output "password_status" {
  description = "Password configuration status"
  value       = "✅ Password has been configured and hashed using SHA-256 (format: $5$...)"
}

# Setup Instructions
output "setup_instructions" {
  description = "Instructions for setting up the Ubuntu server"
  value = <<-EOT
    For Raspberry Pi:
    1. Flash Ubuntu Server 24.04 LTS on your Raspberry Pi SD card
    2. Copy the user-data file to the boot partition of the SD card
    3. Insert the SD card into your Raspberry Pi and boot
    4. Wait for cloud-init to complete (check with: ssh ${var.server_user}@${var.server_ip} 'cloud-init status')
    5. Run: terraform apply to configure the system
    6. Run: ./deploy.sh to deploy the configuration and reboot the server
    7. Access Grocy at: http://${var.server_ip}:${var.grocy_port}
    
    For other Ubuntu servers:
    1. Install Ubuntu Server on your server
    2. Copy the user-data file to /var/lib/cloud/seed/nocloud/ or use cloud-init mechanisms
    3. Boot your server and wait for cloud-init to complete
    4. Wait for cloud-init to complete (check with: ssh ${var.server_user}@${var.server_ip} 'cloud-init status')
    5. Run: terraform apply to configure the system
    6. Run: ./deploy.sh to deploy the configuration and reboot the server
    7. Access Grocy at: http://${var.server_ip}:${var.grocy_port}
  EOT
}
