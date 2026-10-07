# Guía de sustentación — Microproyecto 2 (Grupo 10)

**Computación en la Nube — Prof. Oscar H. Mondragón — miércoles 7 de octubre de 2026, 5:45–6:00 p. m. (Webex)**
Juan Camilo Ballesteros · Valentina Valestegui · Juan Miguel Carabali

Las IP públicas cambian cada vez que se recrea la infraestructura. Nunca las copies de esta guía:
`terraform output` (VMs) y `.\deploy.ps1 -AksTest` (Ingress) las dan siempre actualizadas.

---

## Antes de entrar (4:45 p. m.)

| Hora | Qué | Comando (PowerShell, en `C:\Users\USUARIO\compunube-vagrant\microproyecto2`) |
|---|---|---|
| 4:45 | Si el clúster AKS no existe: crearlo (tarda ~8 min, Docker Desktop abierto) | `.\deploy.ps1 -AksUp` |
| 5:00 | Si las VMs están pausadas: encenderlas | `.\deploy.ps1 -Start` |
| 5:05 | Ensayo general | `.\deploy.ps1 -Test` y `.\deploy.ps1 -AksTest` |
| 5:10 | Dejar abiertos: navegador en `:8080/stats`, 1 terminal en el control-node, 1 SSH a vm-microservices, Cloud Shell | ver abajo |
| 6:00 | Al terminar: borrar AKS (es lo que más cuesta) | `.\deploy.ps1 -AksDown` |

Docker Desktop tiene que estar abierto en el PC para `-AksUp` (construye y sube las imágenes al ACR).

Sesión de Azure dentro del control-node: **ya iniciada el 7 oct** (`az login --use-device-code`, cuenta juan_cam.ballesteros@uao.edu.co). Solo hay que repetirla si se destruye el control-node.

Terminales que conviene tener listas:

```powershell
# control-node (Ubuntu 22.04 con Terraform, Ansible, Azure CLI, kubectl y Docker)
cd C:\Users\USUARIO\compunube-vagrant\microproyecto2\vagrant
vagrant ssh
#   dentro:  cd ~/microproyecto2/terraform && terraform output

# SSH a vm-microservices (la IP sale de terraform output)
ssh -i terraform\id_rsa azureuser@<IP microservices>
```

---

## Problema 1 — Aprovisionamiento (2.0)

**Qué hay:** `vagrant/Vagrantfile` (control-node), `terraform/*.tf` (VMs) y `provisioning/*.sh` (configuración con Shell).
`provisioning/playbook.yml` es la alternativa equivalente en Ansible.

| Req. | Qué mostrar | Dónde |
|---|---|---|
| 1 | Las 2 VMs con red, Ubuntu 22.04 y llave SSH | `terraform/main.tf`: VNet 10.0.0.0/16, subred, NSG (22, 80, 8080 abiertos; 3001–3013 solo dentro de la VNet), IP pública + NIC por VM, `source_image_reference` Ubuntu 22.04 Gen2, `admin_ssh_key` con la llave que genera `tls_private_key` |
| 2 | Docker instalado y habilitado, 3 servicios en 3001/3002/3003, `restart: always` | `provisioning/setup-microservices.sh` → `systemctl enable --now docker`, `docker build` de las 3 imágenes y `docker run --restart always` (2 instancias por servicio: 3001/3011, 3002/3012, 3003/3013). En la VM: `sudo docker ps` |
| 3 | HAProxy instalado, activo y habilitado | `provisioning/setup-haproxy.sh` → `systemctl enable haproxy`. En la VM: `systemctl is-enabled haproxy` |
| 4 | Reproducible: destroy + apply sin pasos manuales | Terraform invoca los scripts solo (`terraform_data` + provisioners `file` y `remote-exec` al final de `main.tf`). Un `terraform apply` deja todo funcionando |

**Cómo se ve la reproducibilidad:** `terraform destroy` y luego `terraform apply` → al terminar, `curl http://<IP haproxy>/api/users` ya responde.
El apply completo tarda ~6 min. Si no hay tiempo de correrlo en vivo, mostrar el log del último apply (`terraform/apply-vms.log`) y ofrecer correrlo.

Para probar el reinicio: `sudo reboot` en vm-microservices → al volver, `sudo docker ps` muestra los 6 contenedores otra vez (`restart always` + Docker habilitado).

## Problema 2 — HAProxy (2.0)

Archivo: `provisioning/haproxy.cfg.j2` (la misma plantilla la usan el script y el playbook; en la VM queda en `/etc/haproxy/haproxy.cfg`).

| Req. | Qué mostrar |
|---|---|
| 5 | `frontend http_front` en `*:80`, ACL `path_beg /api/users`, `/api/products`, `/api/orders` → `users_back`, `products_back`, `orders_back`. Lo que no coincide va a `not_found` (404) |
| 6 | Cada backend tiene 2 servidores con `balance roundrobin`. `.\deploy.ps1 -Test` muestra que la instancia alterna (users-1, users-2, users-1…) |
| 7 | `http://<IP haproxy>:8080/stats` (admin / admin123): 3 backends, servidores UP en verde y columna *Sessions → Total* con el conteo |
| 8 | `.\deploy.ps1 -Test` detiene `users-1` mientras hace 30 peticiones seguidas: **0 fallidas**. En stats `users1` pasa a DOWN (rojo). Enter → lo vuelve a encender y regresa a UP |
| 9 | 3+ peticiones `curl` por ruta con su salida completa: `curl.exe -i http://<IP>/api/users` (la cabecera `X-Backend-Server` dice qué servidor respondió) |

**Por qué no hay interrupción (pregunta segura):** el chequeo `GET /health` corre cada 2 s y marca DOWN tras 2 fallos (`inter 2s fall 2 rise 2`).
En esos ~4 s, `option redispatch` + `retries 3` reintentan en el otro servidor la petición que cayó en el servidor muerto, así que el cliente nunca ve el error.

## Problema 3 — Kubernetes en AKS (1.0)

Manifiestos en `kubernetes/`: `00-namespace`, `01..03-<servicio>` (Deployment + Service), `04-ingress`.
El controlador de Ingress es ingress-nginx v1.15.1 (`kubernetes/ingress-controller/`).

| Req. | Qué mostrar |
|---|---|
| 10 | Namespace `microapp`. Deployments con `replicas: 2`, imagen propia `acrmp2grupo10.azurecr.io/<servicio>:v1`, `containerPort`, `restartPolicy: Always`, readiness y liveness a `/health` |
| 11 | Services `ClusterIP` en 3001/3002/3003. Probar: `kubectl port-forward -n microapp svc/users-svc 3001:3001` y en otra terminal `curl localhost:3001/health` |
| 12 | `curl http://<IP ingress>/api/users` (y products, orders) desde fuera |
| 13 | `kubectl scale deployment orders-service -n microapp --replicas=4` → `kubectl get pods -n microapp -l app=orders-service` muestra 4. `.\deploy.ps1 -AksTest` lo hace con tráfico continuo y cuenta errores (0) |
| 14 | `kubectl get all -n microapp` (y `kubectl get ingress -n microapp`) |

**Dos formas de comprobar el clúster** (lo pide el enunciado):
- **CLI de Azure** (PC o control-node): `az aks get-credentials -g rg-microproyecto2-aks -n aks-microproyecto2` y luego `kubectl get all -n microapp`.
- **Cloud Shell** (portal.azure.com → icono `>_` → Bash): los mismos dos comandos.

`kubernetes/extra/orders-hpa.yaml` es un HPA (2→4 réplicas por CPU) que **no se aplica**: el enunciado pide `kubectl scale`, y con el HPA activo las réplicas volverían a 2 a los pocos minutos.

## Opcional — Terraform + AKS (0.5)

`terraform-aks/` despliega con un solo `terraform apply` **el clúster y su aplicación**:
resource group → ACR privado → AKS (1 nodo `Standard_D2s_v4`, red Azure CNI overlay, región brazilsouth) → permiso `AcrPull` del clúster sobre el ACR → `docker build` + `docker push` de las 3 imágenes → ingress-nginx → `kubectl apply -f kubernetes/`.

Está en su propia carpeta para crearlo y borrarlo sin tocar las VMs.

---

## Preguntas probables (respuestas cortas)

- **¿Por qué northcentralus?** La política de la suscripción de estudiante solo permite 5 regiones; en westus no había capacidad para la serie B.
- **¿Por qué las VMs en northcentralus y AKS en brazilsouth?** La suscripción de estudiante permite solo **3 IP públicas por región**. En northcentralus las 2 VMs gastan 2 y AKS gasta 1 para su salida a internet, así que el Ingress se quedaba en `<pending>` (`PublicIPCountLimitReached`). En otra región AKS tiene sus propias 3 IPs y su propia cuota de 6 vCPU.
- **¿Por qué Standard_B2ats_v2 en las VMs y D2s_v4 en AKS?** B2ats_v2 es la más barata con 2 vCPU. AKS exige nodos con al menos 4 GB de RAM (la B2ats_v2 tiene 1 GB) y en brazilsouth no deja usar la serie B a esta suscripción. D2s_v4 (2 vCPU, 8 GB) sí está permitida y tiene cuota.
- **¿Por qué `skip_shutdown_and_force_delete` en el proveedor?** Sin eso, `terraform destroy` falla si las VMs están pausadas: el proveedor intenta apagarlas y Azure lo rechaza.
- **¿Por qué las imágenes se construyen localmente y no con `az acr build`?** Azure for Students bloquea ACR Tasks (`TasksOperationsNotAllowed`); se construyen con Docker y se suben con `docker push`.
- **¿Dónde está la llave SSH?** La genera Terraform (`tls_private_key`), queda en `terraform/id_rsa` y la pública se inyecta en las VMs.
- **¿Qué pasa si se reinicia vm-microservices?** Docker está habilitado al inicio y los contenedores tienen `--restart always`: vuelven solos.
- **¿Diferencia readiness / liveness?** Readiness decide si el pod recibe tráfico del Service; liveness reinicia el contenedor si deja de responder.
- **¿HAProxy vs Ingress?** Hacen lo mismo (enrutar por prefijo y balancear); HAProxy corre en una VM que administramos nosotros, el Ingress lo maneja Kubernetes y balancea entre los pods que haya en ese momento.
- **¿Por qué ingress-nginx si el proyecto se retiró?** Kubernetes retiró ingress-nginx en marzo de 2026 (ya no saca versiones nuevas), pero el enunciado lo pide y v1.15.1 funciona. En producción usaríamos Gateway API o el add-on de enrutamiento de aplicaciones de AKS.

## Evidencias (salidas reales, 7 oct)

Carpeta `evidencias/`:
- `01` terraform apply de las VMs (17 recursos, ~3 min, sin pasos manuales; `01a` es el log completo)
- `02` docker ps · `03` haproxy.cfg generado en la VM · `04` curl -i completo, 3 por ruta + 404 · `05` estado y conteo en stats
- `06` round-robin, stats 401/200 y caída de users-1: **0 de 30 peticiones fallidas**
- `07` kubectl get all, curl por el Ingress y scale a 4: **4 pods respondiendo, 0 de 40 fallidas**

## Al terminar

```powershell
.\deploy.ps1 -AksDown    # borra AKS + ACR (lo más caro)
.\deploy.ps1 -Destroy    # borra las VMs (o -Pause para conservarlas)
```
