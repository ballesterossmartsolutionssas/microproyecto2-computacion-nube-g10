# Microproyecto 2 — Computación en la Nube
**Universidad Autónoma de Occidente (UAO)**  
**Facultad de Ingeniería — Semestre 2026-2**  
**Profesor:** Oscar H. Mondragón  

---

## 👥 Integrantes — Grupo 10

| Nombre | Correo Electrónico |
|---|---|
| **Juan Camilo Ballesteros** | `juan_cam.ballesteros@uao.edu.co` |
| **Valentina Valestegui** | `valentina.valestegui@uao.edu.co` |
| **Juan Miguel Carabali** | `juan_miguel.carabali@uao.edu.co` |

---

## 📋 Descripción del Proyecto

Este proyecto implementa una arquitectura cloud de microservicios distribuida, resiliente y de alta disponibilidad desplegada en **Microsoft Azure**, estructurada en tres componentes principales más una implementación opcional de infraestructura como código avanzada:

1. **Problema 1 — Aprovisionamiento Automatizado de Infraestructura (IaaS):**
   * **Control-Node local:** Máquina virtual provisionada con **Vagrant** (Ubuntu 22.04 LTS en VirtualBox) equipada con Terraform, Azure CLI, Docker, Ansible y kubectl.
   * **Máquinas Virtuales en Azure:** Despliegue con **Terraform** de red virtual (VNet 10.0.0.0/16), subred, NSG con reglas de seguridad específicas y 2 máquinas virtuales (`Standard_B2ats_v2`):
     * `vm-microservices`: Alberga los 3 microservicios containerizados en Docker (Users, Products y Orders), con 2 réplicas por servicio (6 contenedores en total) ejecutándose con `--restart always`.
     * `vm-haproxy`: Servidor balanceador de carga con HAProxy instalado, activo y habilitado al inicio del sistema.
   * **Aprovisionamiento:** Scripts Shell automatizados e idempotentes y alternativa completa en **Ansible** (`playbook.yml` con plantilla Jinja2).

2. **Problema 2 — Balanceo de Carga y Alta Disponibilidad (HAProxy):**
   * **Enrutamiento por Path (ACLs):**  
     * `/api/v1/users` → Backend Users (puertos 3001 y 3011).
     * `/api/v1/products` → Backend Products (puertos 3002 y 3012).
     * `/api/v1/orders` → Backend Orders (puertos 3003 y 3013).
   * **Algoritmo de balanceo:** Round-Robin distribuyendo la carga equitativamente entre las réplicas.
   * **Monitoreo y Health Checks:** Verificación de salud activa cada 2 segundos (`check inter 2000 rise 2 fall 3`). Failover automático ante caída de contenedores sin degradación de servicio para el usuario final.
   * **Panel de Estadísticas:** Dashboard en tiempo real expuesto en `:8080/stats` con autenticación HTTP básica.

3. **Problema 3 — Orquestación de Contenedores en Kubernetes (AKS):**
   * Clúster administrado **Azure Kubernetes Service (AKS)** en Azure.
   * Separación por namespace (`microapp`).
   * Despliegue de los 3 microservicios con 2 réplicas por servicio mediante Deployments y Services de tipo `ClusterIP`.
   * Enrutamiento perimetral unificado mediante **Ingress Controller (NGINX)** con una única IP pública.
   * Resiliencia, auto-recuperación de pods y capacidad de escalado horizontal (`kubectl scale`).

4. **⭐ Opcional (0.5 pts) — Terraform + AKS 100% Automatizado:**
   * Ubicado en `terraform-aks/`.
   * Con un único `terraform apply` despliega:
     * Resource Group, Azure Container Registry (**ACR**) privado y el clúster **AKS**.
     * Permiso RBAC **`AcrPull`** asignado automáticamente a la identidad administrada de AKS.
     * Compilación y subida automática de las imágenes Docker al ACR privado mediante `terraform_data`.
     * Instalación automatizada del controlador `ingress-nginx` y aplicación de todos los manifiestos de Kubernetes.

---

## 📁 Estructura del Repositorio

```text
microproyecto2/
├── kubernetes/                    # Manifiestos de Kubernetes (AKS)
│   ├── 00-namespace.yaml          # Namespace microapp
│   ├── 01-users-service.yaml      # Deployment + Service Users (puerto 3001)
│   ├── 02-products-service.yaml   # Deployment + Service Products (puerto 3002)
│   ├── 03-orders-service.yaml     # Deployment + Service Orders (puerto 3003)
│   ├── 04-ingress.yaml            # Reglas de Ingress por prefijo (/api/...)
│   ├── extra/                     # HPA y métricas adicionales
│   └── ingress-controller/        # Manifiesto de ingress-nginx v1.15.1
├── microservices/                 # Código fuente de los microservicios Node.js
│   ├── users-service/             # Servicio de usuarios + Dockerfile
│   ├── products-service/          # Servicio de productos + Dockerfile
│   └── orders-service/            # Servicio de órdenes + Dockerfile
├── provisioning/                  # Aprovisionamiento de las VMs
│   ├── inventory.ini              # Inventario de Ansible con IPs de Azure
│   ├── playbook.yml               # Playbook de Ansible (Docker + HAProxy)
│   ├── haproxy.cfg.j2             # Plantilla dinámica Jinja2 para HAProxy
│   ├── setup-microservices.sh     # Script Shell de aprovisionamiento de microservicios
│   └── setup-haproxy.sh           # Script Shell de aprovisionamiento de HAProxy
├── terraform/                     # Infraestructura de VMs en Azure (Problema 1 y 2)
│   ├── main.tf                    # Recursos VNet, Subnet, NSG, NICs, VMs y provisioners
│   ├── variables.tf               # Variables de configuración
│   ├── terraform.tfvars           # Parámetros de la suscripción y región
│   └── outputs.tf                 # IPs públicas y comandos de conexión
├── terraform-aks/                 # Despliegue de AKS (Punto Opcional)
│   ├── main.tf                    # AKS, ACR, AcrPull, Docker build/push, Ingress
│   ├── variables.tf               # Variables de AKS
│   └── outputs.tf                 # Credenciales e IP pública del Ingress
├── vagrant/                       # Control-node local
│   ├── Vagrantfile                # Definición de la VM de gestión
│   └── provision-control-node.sh  # Instalación de Terraform, Ansible, Azure CLI, Docker
├── evidencias/                    # Logs y capturas de ejecución y pruebas
├── deploy.ps1                     # Script maestro de orquestación en PowerShell
└── README.md                      # Documentación del proyecto
```

---

## 🚀 Guía Rápida de Despliegue

### 1. Control-Node (Vagrant)
```bash
cd vagrant
vagrant up
vagrant ssh
```

### 2. Infraestructura de VMs (Problema 1 y 2)
```bash
cd ~/microproyecto2/terraform
terraform init
terraform apply -auto-approve
```

### 3. Verificación de HAProxy y Microservicios
```bash
# Probar el balanceador por sus endpoints
curl http://<IP_HAPROXY>/api/v1/users
curl http://<IP_HAPROXY>/api/v1/products
curl http://<IP_HAPROXY>/api/v1/orders

# Ver estadísticas en el navegador
http://<IP_HAPROXY>:8080/stats (Credenciales: admin / admin123)
```

### 4. Despliegue Automatizado de AKS (Punto Opcional)
```bash
cd ~/microproyecto2/terraform-aks
terraform init
terraform apply -auto-approve
```

### 5. Verificación de Kubernetes (AKS)
```bash
kubectl get nodes
kubectl get pods -n microapp -o wide
kubectl get ingress -n microapp

# Probar el Ingress de AKS
curl http://<INGRESS_IP>/api/users
curl http://<INGRESS_IP>/api/products
curl http://<INGRESS_IP>/api/orders
```
