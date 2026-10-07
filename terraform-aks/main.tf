# ==============================================================================
# OPCIONAL (0.5 pts): Terraform + AKS
# Despliega con un solo `terraform apply` el clúster AKS y su aplicación:
#   1. Resource group, Azure Container Registry (privado) y clúster AKS.
#   2. Permiso AcrPull para que los nodos de AKS descarguen las imágenes del ACR.
#   3. Construcción de las 3 imágenes con Docker en el control-node y publicación en el ACR.
#      (La suscripción Azure for Students no permite ACR Tasks / `az acr build`.)
#   4. Ingress controller (ingress-nginx) y los manifiestos de ../kubernetes.
# Va en su propia carpeta para poder crearlo y destruirlo sin tocar las VMs del Problema 1.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  services = {
    "users-service"    = "../microservices/users-service"
    "products-service" = "../microservices/products-service"
    "orders-service"   = "../microservices/orders-service"
  }
}

resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Proyecto   = "Microproyecto 2"
    Asignatura = "Computacion en la Nube"
    Equipo     = "Grupo 10"
  }
}

# --- Registro privado de imágenes ---
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  sku                 = "Basic"
  admin_enabled       = false
}

# --- Clúster AKS ---
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-microproyecto2"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "aks-microapp"
  sku_tier            = "Free"

  default_node_pool {
    name            = "system"
    node_count      = var.node_count
    vm_size         = var.node_vm_size
    os_disk_size_gb = 30
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    load_balancer_sku   = "standard"
  }

  tags = azurerm_resource_group.aks.tags
}

# Los nodos (kubelet) pueden descargar imágenes del ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

# --- Imágenes: docker build + docker push al ACR desde la máquina que ejecuta Terraform ---
resource "terraform_data" "images" {
  triggers_replace = [
    azurerm_container_registry.acr.id,
    sha1(join("", [for f in fileset("${path.module}/../microservices", "**") : filesha1("${path.module}/../microservices/${f}")])),
  ]

  # Un solo login y las 3 imágenes en secuencia (en paralelo chocan al escribir ~/.docker/config.json)
  provisioner "local-exec" {
    working_dir = path.module
    command = join(" && ", concat(
      ["az acr login --name ${azurerm_container_registry.acr.name}"],
      flatten([for name, dir in local.services : [
        "docker build -t ${azurerm_container_registry.acr.login_server}/${name}:v1 ${dir}",
        "docker push ${azurerm_container_registry.acr.login_server}/${name}:v1",
      ]])
    ))
  }
}

# --- Aplicación: ingress controller + manifiestos de ../kubernetes ---
resource "terraform_data" "app" {
  depends_on = [azurerm_role_assignment.aks_acr_pull, terraform_data.images]

  triggers_replace = [
    azurerm_kubernetes_cluster.aks.id,
    sha1(join("", [for f in fileset("${path.module}/../kubernetes", "*.yaml") : filesha1("${path.module}/../kubernetes/${f}")])),
  ]

  provisioner "local-exec" {
    working_dir = path.module
    command     = "az aks get-credentials --resource-group ${azurerm_resource_group.aks.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing && kubectl apply -f ../kubernetes/ingress-controller/ingress-nginx-v1.15.1.yaml && kubectl wait -n ingress-nginx --for=condition=complete job --all --timeout=300s && kubectl wait -n ingress-nginx --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=300s && kubectl apply -f ../kubernetes/"
  }
}
