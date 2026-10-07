output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "location" {
  value = azurerm_resource_group.rg.location
}

output "haproxy_public_ip" {
  description = "IP pública del balanceador HAProxy (acceso web y stats)"
  value       = azurerm_public_ip.pip_haproxy.ip_address
}

output "haproxy_private_ip" {
  description = "IP privada de vm-haproxy en la VNet"
  value       = azurerm_network_interface.nic_haproxy.private_ip_address
}

output "microservices_public_ip" {
  description = "IP pública de vm-microservices (SSH y administración)"
  value       = azurerm_public_ip.pip_microservices.ip_address
}

output "microservices_private_ip" {
  description = "IP privada de vm-microservices en la VNet"
  value       = azurerm_network_interface.nic_microservices.private_ip_address
}

output "ssh_command_haproxy" {
  value = "ssh -i id_rsa ${var.admin_username}@${azurerm_public_ip.pip_haproxy.ip_address}"
}

output "ssh_command_microservices" {
  value = "ssh -i id_rsa ${var.admin_username}@${azurerm_public_ip.pip_microservices.ip_address}"
}

output "url_stats" {
  value = "http://${azurerm_public_ip.pip_haproxy.ip_address}:8080/stats  (admin / admin123)"
}

output "url_api" {
  value = "http://${azurerm_public_ip.pip_haproxy.ip_address}/api/users  |  /api/products  |  /api/orders"
}
