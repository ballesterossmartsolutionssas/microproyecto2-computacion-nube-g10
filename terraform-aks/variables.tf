variable "subscription_id" {
  description = "ID de la suscripción de Azure for Students"
  type        = string
  default     = "7117851d-1620-4ed4-a048-a91f8e6267f9"
}

variable "resource_group_name" {
  description = "Resource group del clúster (separado del de las VMs)"
  type        = string
  default     = "rg-microproyecto2-aks"
}

variable "location" {
  description = "Región permitida por la política estudiantil. Distinta a la de las VMs: en northcentralus el límite de 3 IP públicas por región ya lo usan las 2 VMs + la salida de AKS, y el Ingress no conseguía IP"
  type        = string
  default     = "brazilsouth"
}

variable "acr_name" {
  description = "Nombre global del Azure Container Registry (solo minúsculas y números)"
  type        = string
  default     = "acrmp2grupo10"
}

variable "node_count" {
  description = "Nodos del clúster (cuota de 6 vCPU por región en Azure for Students)"
  type        = number
  default     = 1
}

variable "node_vm_size" {
  description = "Tamaño del nodo: AKS exige mínimo 2 vCPU y 4 GB de RAM, y en brazilsouth no permite la serie B a esta suscripción"
  type        = string
  default     = "Standard_D2s_v4"
}
