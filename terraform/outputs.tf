output "public_ip" {
  value       = oci_core_instance.vpn_server.public_ip
  description = "Public IP of the India WireGuard server."
}

output "ssh_command" {
  value       = "ssh opc@${oci_core_instance.vpn_server.public_ip}"
  description = "SSH command to reach the instance (requires admin_cidr to include your current IP)."
}

output "add_client_command" {
  value       = "ssh opc@${oci_core_instance.vpn_server.public_ip} 'sudo /root/add-client.sh <name>'"
  description = "Run this (after copying add-client.sh to the server) to provision a new device."
}
