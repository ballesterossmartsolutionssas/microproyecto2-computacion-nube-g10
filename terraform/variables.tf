variable "subscription_id" {
  description = "ID de la suscripción de Azure for Students"
  type        = string
  default     = "7117851d-1620-4ed4-a048-a91f8e6267f9"
}

variable "resource_group_name" {
  description = "Nombre del Resource Group"
  type        = string
  default     = "rg-microproyecto2"
}

variable "location" {
  description = "Región de Azure (permitida por la suscripción estudiantil)"
  type        = string
  default     = "northcentralus"
}

variable "admin_username" {
  description = "Usuario administrador de las máquinas virtuales"
  type        = string
  default     = "azureuser"
}

variable "vm_size_haproxy" {
  description = "Tamaño de VM para HAProxy"
  type        = string
  default     = "Standard_B2ats_v2"
}

variable "vm_size_microservices" {
  description = "Tamaño de VM para los microservicios Docker"
  type        = string
  default     = "Standard_B2ats_v2"
}
