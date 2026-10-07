terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
  }
}

provider "azurerm" {
  features {
    virtual_machine {
      # Sin esto `terraform destroy` falla si las VMs están pausadas (deallocated): intenta apagarlas primero
      skip_shutdown_and_force_delete = true
      delete_os_disk_on_deletion     = true
    }
  }
  subscription_id = var.subscription_id
}

# --- 1. Generación de llaves SSH automáticas ---
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/id_rsa"
  file_permission = "0600"
}

# --- 2. Grupo de Recursos y Red ---
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Proyecto   = "Microproyecto 2"
    Asignatura = "Computacion en la Nube"
    Equipo     = "Grupo 10"
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-microproyecto2"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-microproyecto2"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# --- 3. Grupo de Seguridad de Red (NSG) ---
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-microproyecto2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HAProxy-Stats"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Internal-Microservices"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["3001", "3002", "3003", "3011", "3012", "3013"]
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }
}

# --- 4. IPs Públicas e Interfaces de Red (NICs) ---
resource "azurerm_public_ip" "pip_haproxy" {
  name                = "pip-haproxy"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic_haproxy" {
  name                = "nic-haproxy"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.pip_haproxy.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc_haproxy" {
  network_interface_id      = azurerm_network_interface.nic_haproxy.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "pip_microservices" {
  name                = "pip-microservices"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic_microservices" {
  name                = "nic-microservices"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.20"
    public_ip_address_id          = azurerm_public_ip.pip_microservices.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc_microservices" {
  network_interface_id      = azurerm_network_interface.nic_microservices.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# --- 5. Máquinas Virtuales Linux (Ubuntu 22.04 LTS) ---

# Nodo HAProxy
resource "azurerm_linux_virtual_machine" "vm_haproxy" {
  name                  = "vm-haproxy"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = var.vm_size_haproxy
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic_haproxy.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    Rol = "Load-Balancer"
  }
}

# Nodo Microservicios
resource "azurerm_linux_virtual_machine" "vm_microservices" {
  name                  = "vm-microservices"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = var.vm_size_microservices
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic_microservices.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    Rol = "Docker-Host"
  }
}

# --- 6. Configuración automática de los nodos (Shell invocado por Terraform desde el control-node) ---
# Con esto `terraform apply` deja el entorno completo: no hay ningún paso manual después.

resource "terraform_data" "config_microservices" {
  triggers_replace = [
    azurerm_linux_virtual_machine.vm_microservices.id,
    filesha1("${path.module}/../provisioning/setup-microservices.sh"),
    sha1(join("", [for f in fileset("${path.module}/../microservices", "**") : filesha1("${path.module}/../microservices/${f}")])),
  ]

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.pip_microservices.ip_address
    user        = var.admin_username
    private_key = tls_private_key.ssh_key.private_key_pem
  }

  provisioner "file" {
    source      = "${path.module}/../microservices"
    destination = "/tmp"
  }

  provisioner "file" {
    source      = "${path.module}/../provisioning/setup-microservices.sh"
    destination = "/tmp/setup-microservices.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\r$//' /tmp/setup-microservices.sh",
      "sudo bash /tmp/setup-microservices.sh /tmp/microservices",
    ]
  }
}

resource "terraform_data" "config_haproxy" {
  triggers_replace = [
    azurerm_linux_virtual_machine.vm_haproxy.id,
    filesha1("${path.module}/../provisioning/setup-haproxy.sh"),
    filesha1("${path.module}/../provisioning/haproxy.cfg.j2"),
  ]

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.pip_haproxy.ip_address
    user        = var.admin_username
    private_key = tls_private_key.ssh_key.private_key_pem
  }

  provisioner "file" {
    source      = "${path.module}/../provisioning/haproxy.cfg.j2"
    destination = "/tmp/haproxy.cfg.j2"
  }

  provisioner "file" {
    source      = "${path.module}/../provisioning/setup-haproxy.sh"
    destination = "/tmp/setup-haproxy.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sed -i 's/\r$//' /tmp/setup-haproxy.sh /tmp/haproxy.cfg.j2",
      "sudo bash /tmp/setup-haproxy.sh ${azurerm_network_interface.nic_microservices.private_ip_address} /tmp/haproxy.cfg.j2",
    ]
  }
}

# Inventario para la alternativa con Ansible (provisioning/playbook.yml)
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../provisioning/inventory.ini"
  content  = <<-EOT
    [haproxy]
    vm-haproxy ansible_host=${azurerm_public_ip.pip_haproxy.ip_address}

    [microservices]
    vm-microservices ansible_host=${azurerm_public_ip.pip_microservices.ip_address}

    [all:vars]
    ansible_user=${var.admin_username}
    ansible_ssh_private_key_file=~/.ssh/id_rsa_microproyecto2
    ansible_ssh_common_args='-o StrictHostKeyChecking=no'
  EOT
}
