#!/bin/bash
# Configura vm-microservices: instala Docker, lo habilita al arranque, construye las 3 imágenes
# y levanta 2 instancias de cada microservicio con --restart always.
# Uso: sudo ./setup-microservices.sh <carpeta-con-los-microservicios>
set -euo pipefail

SRC="${1:-/tmp/microservices}"
APT="apt-get -o DPkg::Lock::Timeout=600"
export DEBIAN_FRONTEND=noninteractive

echo "=== 0. Esperando a que cloud-init termine el primer arranque ==="
cloud-init status --wait >/dev/null 2>&1 || true

echo "=== 1. Instalando Docker CE ==="
$APT update -y
$APT install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
$APT update -y
$APT install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

echo "=== 2. Habilitando Docker al inicio del sistema ==="
systemctl enable --now docker
usermod -aG docker azureuser || true

echo "=== 3. Construyendo las imágenes desde los Dockerfile ==="
rm -rf /opt/microservices && cp -r "$SRC" /opt/microservices
for svc in users-service products-service orders-service; do
  docker build -t "$svc:v1" "/opt/microservices/$svc"
done

echo "=== 4. Levantando 2 instancias por microservicio (restart: always) ==="
# nombre  imagen  puerto-host  puerto-contenedor
run() {
  docker rm -f "$1" >/dev/null 2>&1 || true
  docker run -d --name "$1" --restart always -p "$3:$4" -e INSTANCE_NAME="$1" "$2:v1"
}
run users-1    users-service    3001 3001
run users-2    users-service    3011 3001
run products-1 products-service 3002 3002
run products-2 products-service 3012 3002
run orders-1   orders-service   3003 3003
run orders-2   orders-service   3013 3003

echo "=== 5. Verificación ==="
sleep 2
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
for p in 3001 3011 3002 3012 3003 3013; do
  echo "localhost:$p/health -> $(curl -s localhost:$p/health)"
done
