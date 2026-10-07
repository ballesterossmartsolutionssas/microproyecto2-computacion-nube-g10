#!/bin/bash
# Configura vm-haproxy: instala HAProxy, aplica haproxy.cfg (Problema 2) y deja el servicio activo y habilitado.
# Uso: sudo ./setup-haproxy.sh <IP-privada-de-vm-microservices> [plantilla-haproxy.cfg.j2]
set -euo pipefail

MICROSERVICES_IP="${1:-10.0.1.20}"
TEMPLATE="${2:-/tmp/haproxy.cfg.j2}"
APT="apt-get -o DPkg::Lock::Timeout=600"
export DEBIAN_FRONTEND=noninteractive

echo "=== 0. Esperando a que cloud-init termine el primer arranque ==="
cloud-init status --wait >/dev/null 2>&1 || true

echo "=== 1. Instalando HAProxy ==="
$APT update -y
$APT install -y haproxy

echo "=== 2. Generando /etc/haproxy/haproxy.cfg (misma plantilla que usa el playbook de Ansible) ==="
sed "s/{{ microservices_ip }}/${MICROSERVICES_IP}/g" "$TEMPLATE" > /etc/haproxy/haproxy.cfg

echo "=== 3. Validando, habilitando y reiniciando HAProxy ==="
haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl enable haproxy
systemctl restart haproxy
systemctl is-active haproxy
systemctl is-enabled haproxy
