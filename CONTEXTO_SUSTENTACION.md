# Microproyecto 2 — Contexto completo para la sustentación (y para cualquier IA que ayude)

> **Para la IA que lea esto (Gemini u otra):** este documento reemplaza al viejo `REPORTE_SUPER_CONTEXTO_MICROPROYECTO2.md` de Descargas, que tenía datos falsos: IPs viejas, "pruebas" de Kubernetes que nunca se hicieron y una rúbrica mal copiada.
> Todo lo que dice aquí se **probó en Azure el 7 de octubre de 2026 entre las 5 y las 6 a. m.**, y las salidas reales están en `evidencias/`.
> Antes de cambiar algo, lee la sección **"Reglas: qué NO hacer"**. Varias cosas que parecen "mejoras obvias" ya se intentaron y rompen el proyecto.

---

## 1. Datos generales

- **Materia:** Computación en la Nube, UAO — Prof. Oscar H. Mondragón
- **Grupo 10:** Juan Camilo Ballesteros (`juan_cam.ballesteros@uao.edu.co`), Valentina Valestegui, Juan Miguel Carabali
- **Sustentación:** miércoles 7 de octubre de 2026, **5:45 – 6:00 p. m.**, Webex. Se califica individualmente; habrá preguntas conceptuales y posibles cambios en caliente.
- **Carpeta del proyecto (PC Windows):** `C:\Users\USUARIO\compunube-vagrant\microproyecto2`
- **Enunciado oficial:** `C:\Users\USUARIO\Downloads\2026-02 Parcial2-Microproyecto.pdf`
- **Suscripción:** Azure for Students `7117851d-1620-4ed4-a048-a91f8e6267f9` (el usuario es Owner)
- **Antes de sustentar hay que subir los archivos al sitio del curso:** `C:\Users\USUARIO\compunube-vagrant\microproyecto2-grupo10-entrega.zip` (37 archivos, sin llave privada ni tfstate)

## 2. Qué pide el enunciado (resumen correcto)

| Parte | Puntos | Qué hay que demostrar |
|---|---|---|
| Problema 1 | 2.0 | **Desde un control-node Ubuntu 22.04**, Terraform crea `vm-haproxy` y `vm-microservices`. Shell o Ansible instala Docker (habilitado al inicio) y levanta users/products/orders en 3001/3002/3003 con `restart: always`, e instala HAProxy activo y habilitado. **Reproducible:** `terraform destroy` + `terraform apply` = mismo entorno sin pasos manuales. Mostrar el apply y `docker ps` |
| Problema 2 | 2.0 | HAProxy en el puerto 80 enruta por prefijo `/api/users`, `/api/products`, `/api/orders`. 2 servidores por backend en round-robin. Stats en el 8080 con usuario y clave. Tumbar un contenedor: el stats lo marca DOWN y el cliente no nota la caída. 3+ curl por ruta con su salida |
| Problema 3 | 1.0 | Kubernetes (AKS o minikube): namespace `microapp`; Deployment con ≥2 réplicas, imagen, puertos y política de reinicio; Service ClusterIP 3001/3002/3003 (probar con port-forward); Ingress por prefijo con acceso externo; **`kubectl scale` de orders a 4** sin interrupción; `kubectl get all -n microapp`. Comprobar el clúster por **Cloud Shell** y por **Azure CLI** |
| Opcional | 0.5 | **Uno solo** de los dos: Chef/Puppet **o** Terraform + AKS "y su aplicación". Elegimos **Terraform + AKS** |

El HPA (autoescalado) **no** lo pide el enunciado: lo que pide es `kubectl scale`.

## 3. Estado actual de la infraestructura (7 oct, 10 a. m.)

Todo **encendido y respondiendo**. Se dejó así a propósito para no recrear nada antes de la sustentación.

| Recurso | Dónde | Detalle |
|---|---|---|
| `vm-haproxy` | `rg-microproyecto2`, **northcentralus** | Standard_B2ats_v2, Ubuntu 22.04 Gen2. IP pública **40.116.88.10**, privada 10.0.1.10 |
| `vm-microservices` | `rg-microproyecto2`, **northcentralus** | Standard_B2ats_v2. IP pública **20.98.51.137**, privada 10.0.1.20. 6 contenedores: users-1/2 (3001/3011), products-1/2 (3002/3012), orders-1/2 (3003/3013) |
| Clúster AKS `aks-microproyecto2` | `rg-microproyecto2-aks`, **brazilsouth** | 1 nodo **Standard_D2s_v4**, Azure CNI overlay, plan Free |
| ACR `acrmp2grupo10` | `rg-microproyecto2-aks`, brazilsouth | Imágenes `acrmp2grupo10.azurecr.io/{users,products,orders}-service:v1`. Los nodos tienen permiso AcrPull |
| Ingress (ingress-nginx v1.15.1) | AKS | IP pública **20.201.50.119** |
| control-node (Vagrant) | PC local, VirtualBox `control-node-microproyecto2` (1 CPU) | Ubuntu 22.04 con Terraform 1.16, Ansible 2.17, az 2.91, kubectl 1.33 y Docker. Ya tiene `az login` hecho con la cuenta de la UAO |

URLs para la sustentación:
- API: `http://40.116.88.10/api/users`, `/api/products`, `/api/orders`
- Stats: `http://40.116.88.10:8080/stats` → usuario `admin`, clave `admin123`
- Ingress: `http://20.201.50.119/api/users`, `/api/products`, `/api/orders`

Las IPs de las VMs **cambian** si se hace destroy + apply. La fuente de verdad es `terraform output` (en `terraform\`), y la IP del Ingress sale de `kubectl get svc -n ingress-nginx`.

## 4. Archivos del proyecto

```
microproyecto2/
├── CONTEXTO_SUSTENTACION.md      ← este documento
├── GUIA_SUSTENTACION.md          ← guía corta requisito por requisito (1–14) + preguntas probables
├── deploy.ps1                    ← atajos (ver sección 6)
├── vagrant/
│   ├── Vagrantfile               ← control-node Ubuntu 22.04 (monta la carpeta del proyecto en ~/microproyecto2)
│   └── provision-control-node.sh ← instala Ansible, Terraform, Azure CLI, kubectl, Docker
├── terraform/                    ← PROBLEMA 1: VMs + red + NSG + configuración automática
│   ├── main.tf                   ← al final: terraform_data.config_microservices / config_haproxy (file + remote-exec)
│   ├── variables.tf, terraform.tfvars, outputs.tf
│   ├── id_rsa                    ← llave privada que genera Terraform (NO SUBIR)
│   ├── terraform.tfstate         ← estado (contiene la llave, NO SUBIR)
│   └── apply-vms.log             ← log del último apply real desde cero
├── provisioning/                 ← scripts que invoca Terraform
│   ├── setup-microservices.sh    ← Docker CE, enable, docker build x3, 6 docker run --restart always
│   ├── setup-haproxy.sh          ← instala HAProxy y genera /etc/haproxy/haproxy.cfg desde la plantilla
│   ├── haproxy.cfg.j2            ← ÚNICA fuente de la config de HAProxy (la usan el .sh y el playbook)
│   ├── playbook.yml              ← alternativa equivalente en Ansible (probada desde el control-node: 0 fallos)
│   └── inventory.ini             ← lo genera Terraform
├── microservices/{users,products,orders}-service/  ← server.js (Node, /health) + Dockerfile
├── kubernetes/                   ← PROBLEMA 3
│   ├── 00-namespace.yaml
│   ├── 01..03-<servicio>.yaml    ← Deployment (2 réplicas, imagen del ACR, readiness + liveness, restartPolicy Always) + Service ClusterIP
│   ├── 04-ingress.yaml           ← ingressClassName nginx, Prefix /api/users|products|orders, sin rewrite
│   ├── ingress-controller/ingress-nginx-v1.15.1.yaml
│   └── extra/orders-hpa.yaml     ← HPA opcional, NO se aplica (ver reglas)
├── terraform-aks/                ← OPCIONAL: RG + ACR + AKS + AcrPull + docker build/push + ingress + kubectl apply
└── evidencias/                   ← salidas reales de las pruebas (01..07)
```

## 5. Cómo funciona (para explicarlo)

**Problema 1.** `terraform apply` en `terraform/`:
1. Genera la llave SSH (`tls_private_key`) y la guarda en `id_rsa`.
2. Crea RG, VNet 10.0.0.0/16, subred 10.0.1.0/24, NSG (22/80/8080 abiertos; 3001–3013 solo desde la VNet), 2 IP públicas estáticas, 2 NIC y 2 VMs Ubuntu 22.04.
3. Dos recursos `terraform_data` se conectan por SSH a cada VM: suben los scripts con el provisioner `file` y los ejecutan con `remote-exec`.

Resultado: un solo comando deja todo funcionando, en unos 3 minutos. El provider tiene `skip_shutdown_and_force_delete = true` porque sin eso `terraform destroy` falla cuando las VMs están pausadas.

**Problema 2.** `haproxy.cfg.j2`:
- `frontend http_front` en `*:80` con ACL `path_beg` hacia `users_back`, `products_back` y `orders_back`. Cualquier otra ruta va a `not_found` (404).
- Cada backend usa `balance roundrobin` y `option httpchk GET /health` con `inter 2s fall 2 rise 2`.
- `option redispatch` + `retries 3`: si una petición cae en un servidor muerto antes de que el chequeo lo marque DOWN (~4 s), se reintenta en el otro. Por eso hay **0 errores** cuando se tumba un contenedor.
- La cabecera `X-Backend-Server` dice qué servidor respondió.
- `listen stats` en `*:8080`, `stats uri /stats`, `stats auth admin:admin123`.

**Problema 3.**
- 3 Deployments (2 réplicas) con la imagen propia del ACR, más 3 Services ClusterIP.
- El Ingress de ingress-nginx enruta por prefijo y **no reescribe la ruta**: los servicios responden a cualquier ruta, igual que detrás de HAProxy.
- `kubectl scale deployment orders-service -n microapp --replicas=4`.

**Opcional.** `terraform apply` en `terraform-aks/` hace todo en orden: RG → ACR → AKS → permiso AcrPull → `docker build` + `docker push` de las 3 imágenes (Docker en la máquina que corre Terraform) → `az aks get-credentials` → aplica ingress-nginx y espera a que esté listo → `kubectl apply -f ../kubernetes/`.

## 6. Comandos (PowerShell en Windows)

**Ojo:** el PowerShell de Windows (5.1) **no acepta `&&`**. Ejecuta un comando por línea.

```powershell
cd C:\Users\USUARIO\compunube-vagrant\microproyecto2

.\deploy.ps1 -Test        # round-robin en las 3 rutas, stats 401/200, tumba users-1 con 30 peticiones seguidas (espera Enter para revivirlo)
.\deploy.ps1 -Test -Auto  # lo mismo, sin esperar el Enter
.\deploy.ps1 -AksTest     # kubectl get all, curl por el Ingress, scale de orders a 4 con tráfico y conteo de errores
.\deploy.ps1 -Start       # enciende las VMs si están pausadas
.\deploy.ps1 -Pause       # pausa las VMs (no cobra cómputo)
.\deploy.ps1 -Apply       # terraform apply de las VMs
.\deploy.ps1 -Destroy     # terraform destroy de las VMs
.\deploy.ps1 -AksUp       # crea AKS + ACR + app (Docker Desktop debe estar abierto)
.\deploy.ps1 -AksDown     # borra AKS + ACR
```

SSH a las VMs (desde `terraform\`):

```powershell
ssh -i id_rsa azureuser@20.98.51.137     # vm-microservices → sudo docker ps
ssh -i id_rsa azureuser@40.116.88.10     # vm-haproxy → cat /etc/haproxy/haproxy.cfg
```

control-node:

```powershell
cd C:\Users\USUARIO\compunube-vagrant\microproyecto2\vagrant
vagrant ssh
# dentro:
cd ~/microproyecto2/terraform
terraform output
terraform plan            # debe decir "No changes"
kubectl get all -n microapp
```

Cloud Shell (lo pide el enunciado): portal.azure.com → icono `>_` → Bash →

```bash
az aks get-credentials -g rg-microproyecto2-aks -n aks-microproyecto2
kubectl get all -n microapp
```

## 7. Plan para la tarde

| Hora | Acción |
|---|---|
| 4:30 | Verificar que el PC no se haya reiniciado. Si el control-node está apagado: sección 9.1 (tarda) |
| 5:00 | `.\deploy.ps1 -Test -Auto` y `.\deploy.ps1 -AksTest`: ambos deben decir **0 fallidas**. Luego `kubectl scale deployment orders-service -n microapp --replicas=2` para dejar orders en 2 y poder mostrar el scale en vivo |
| 5:15 | Dejar abiertos: navegador en stats (logueado), una terminal en `vagrant ssh`, una con SSH a vm-microservices, Cloud Shell en el portal y VS Code con los archivos |
| 5:45 | Sustentar en este orden: P1 (archivos .tf + scripts → `docker ps` → log de `evidencias/01`) → P2 (haproxy.cfg → curl → stats → `-Test` con la caída) → P3 (YAML → `kubectl get all` → curl al Ingress → `kubectl scale` a 4 → Cloud Shell) → opcional (`terraform-aks/main.tf`) |
| 6:00 | Con la nota puesta: `.\deploy.ps1 -AksDown` y `.\deploy.ps1 -Destroy` |

Si el profesor pide destroy + apply en vivo: el apply tarda ~3 min y el destroy ~2–4 min. Se puede correr desde el control-node (`cd ~/microproyecto2/terraform`, luego `terraform destroy -auto-approve`, luego `terraform apply -auto-approve`). Después las IPs cambian: usar `terraform output`.

## 8. Resultados ya comprobados (en `evidencias/`)

- `01` apply desde cero: **17 recursos**, configuración incluida, en ~3 min, sin pasos manuales
- `02` `docker ps`: 6 contenedores Up y Docker `enabled`. También se probó `sudo reboot` de vm-microservices: los 6 contenedores volvieron solos
- `03` haproxy.cfg tal como quedó en la VM, HAProxy `active` y `enabled`
- `04` 3 `curl -i` por ruta (salida completa) + 404 para una ruta desconocida
- `05` stats en CSV: todos UP y conteo de peticiones; sin credenciales da 401
- `06` round-robin alternado; caída de users-1: **0 de 30 peticiones fallidas**, users1 DOWN y luego UP
- `07` `kubectl get all` con todo Running; curl por el Ingress; scale a 4: **4 pods distintos respondiendo, 0 de 40 fallidas**
- `port-forward` de `svc/users-svc` → `/health` respondió UP
- El playbook de Ansible corrió desde el control-node con **0 fallos** y dejó `haproxy.cfg` idéntico al del script (Ansible lo reportó sin cambios)

## 9. Si algo falla

### 9.1 El control-node está apagado (pasa si el PC se reinicia)
```powershell
cd C:\Users\USUARIO\compunube-vagrant\microproyecto2\vagrant
vagrant up --no-provision
```
- **Causa real de la lentitud:** VirtualBox corre encima de Hyper-V (modo NEM, porque Windows tiene WSL/Hyper-V). Con 2 CPU la VM **se congela** en el arranque del kernel (~96 s en la consola). El Vagrantfile ya usa **1 CPU** y así arranca en menos de 1 minuto (probado el 7 oct a las 10:52). Si se vuelve a congelar: `& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" controlvm control-node-microproyecto2 poweroff` y otra vez `vagrant up --no-provision`. No subirle las CPU.
- `vagrant provision` y `vagrant upload` fallan en este PC por un bug de net-ssh. **No reintentar**: usar `vagrant ssh -c "..."`, que sí funciona.
- Si `vagrant up` corta por tiempo pero la VM sí arrancó (`vagrant ssh` entra) y `~/microproyecto2` está vacío, montar la carpeta a mano:
  ```powershell
  & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" sharedfolder add control-node-microproyecto2 --name microproyecto2 --hostpath "C:\Users\USUARIO\compunube-vagrant\microproyecto2" --transient
  vagrant ssh -c "mkdir -p ~/microproyecto2; sudo mount -t vboxsf -o uid=1000,gid=1000 microproyecto2 /home/vagrant/microproyecto2; ls ~/microproyecto2"
  ```
- Las herramientas ya están instaladas en el disco de la VM; no hay que reinstalar. Si faltaran: `vagrant ssh -c "sudo bash ~/microproyecto2/vagrant/provision-control-node.sh"`.
- `az login` normalmente sobrevive al reinicio. Si `az account show` falla: `vagrant ssh -c "az login --use-device-code"`, abrir https://login.microsoft.com/device, pegar el código y entrar con la cuenta de la UAO.
- Plan B si no alcanza a subir: correr Terraform desde Windows. Funciona igual porque el estado es el mismo archivo. Explicar que el control-node es la VM Vagrant y mostrar el Vagrantfile.

### 9.2 Las VMs están pausadas o HAProxy no responde
`.\deploy.ps1 -Start` espera hasta que `/api/orders` dé 200. Docker (`restart always`) y HAProxy (`enabled`) arrancan solos.

### 9.3 El clúster AKS no existe o hay que recrearlo
1. Abrir Docker Desktop **una sola vez** (no abrirlo si ya está abierto) y esperar a que `docker info` responda.
2. `.\deploy.ps1 -AksUp` (~8 min).
3. Si `az acr login` dice "did not issue a challenge": `ipconfig /flushdns` y repetir.
4. La IP del Ingress tarda 1–2 min: `kubectl get svc -n ingress-nginx`.

### 9.4 Errores conocidos de Azure for Students (ya resueltos; no repetirlos)
| Error | Causa | Solución aplicada |
|---|---|---|
| `PublicIPCountLimitReached` (Ingress en `<pending>`) | Máximo **3 IP públicas por región**: 2 VMs + la salida de AKS ya son 3 | AKS en **brazilsouth**, las VMs en northcentralus |
| `The VM size of Standard_B2as_v2 is not allowed ... in location 'brazilsouth'` | AKS no permite la serie B en esa región a esta suscripción | Nodo `Standard_D2s_v4` (`D2as_v4` está restringida) |
| AKS exige ≥4 GB de RAM | B2ats_v2 tiene 1 GB | No usar B2ats_v2 en AKS |
| `TasksOperationsNotAllowed` | Azure for Students bloquea `az acr build` | `docker build` + `docker push` locales |
| `config.json ... Acceso denegado` | Varios `az acr login` en paralelo | Un solo login y builds en secuencia |
| `NoRegisteredProviderFound ... 2023-06-02-preview` | azurerm 3.90 usa una API de AKS retirada | `terraform-aks` usa azurerm **4.81** (`terraform/` sigue en 3.90 y funciona) |
| `Operation 'powerOff' is not allowed ... deallocated` en destroy | azurerm intenta apagar VMs ya pausadas | `skip_shutdown_and_force_delete = true` |
| ACR 404 intermitente / DNS viejo | Se borró y recreó un ACR con el mismo nombre en otra región | Nombre nuevo `acrmp2grupo10` |
| Cuota | 6 vCPU por región | VMs 4 vCPU en northcentralus; AKS 2 vCPU en brazilsouth |

## 10. Reglas: qué NO hacer

1. **No mover AKS a northcentralus** ni agregarle IPs públicas a esa región: el Ingress se queda sin IP.
2. **No cambiar el tamaño del nodo AKS** a la serie B ni a `D2as_v4`.
3. **No cambiar el nombre del ACR.** Si se cambia, hay que actualizar `kubernetes/01..03` y `terraform-aks/variables.tf`.
4. **No usar `az acr build`** (bloqueado en la suscripción).
5. **No aplicar `kubernetes/extra/orders-hpa.yaml` antes de la demo**: devolvería orders a 2 réplicas y estropearía el `kubectl scale` a 4.
6. **No volver** a ConfigMaps con `node:20-alpine`, a `rewrite-target` ni a `pathType: Prefix` con regex. Eso era la versión rota.
7. **No duplicar la config de HAProxy**: `provisioning/haproxy.cfg.j2` es la única fuente.
8. **No subir** `terraform/id_rsa` ni ningún `*.tfstate` a ninguna parte.
9. **No usar `&&`** en Windows PowerShell 5.1.
10. **No hacer `terraform destroy` antes de la sustentación.**

## 11. Preguntas probables del profesor

- **¿Por qué Terraform + Shell y no Ansible?** El enunciado permite cualquiera. Terraform invoca los scripts solo, con `remote-exec`, y además dejamos el playbook equivalente probado.
- **¿Cómo garantizan que sea reproducible?** La configuración va dentro del `apply` (`terraform_data` con triggers por VM y por hash de los scripts). Destroy + apply se probó desde cero: 17 recursos y la app funcionando sin tocar nada.
- **¿Qué pasa si se reinicia vm-microservices?** Docker está `enabled` y los contenedores tienen `--restart always`. Se probó con `sudo reboot`.
- **¿Cómo detecta HAProxy la caída?** `GET /health` cada 2 s; 2 fallos seguidos = DOWN y 2 éxitos = UP.
- **¿Por qué el cliente no ve errores?** `option redispatch` + `retries 3` reintentan en el otro servidor mientras el chequeo aún no detecta la caída.
- **¿Readiness vs liveness?** Readiness decide si el pod recibe tráfico del Service; liveness reinicia el contenedor si deja de responder.
- **¿ClusterIP vs LoadBalancer?** ClusterIP solo es accesible dentro del clúster. La entrada externa la da el Ingress controller, que sí es LoadBalancer con IP pública.
- **¿Por qué no se cae el servicio al escalar?** Los pods nuevos solo reciben tráfico cuando pasan el readiness; además `maxUnavailable: 0`.
- **¿Por qué AKS en otra región?** Por el límite de 3 IP públicas por región de la suscripción (ver 9.4).
- **¿ingress-nginx no está retirado?** Sí: Kubernetes lo retiró en marzo de 2026, pero el enunciado lo pide y v1.15.1 funciona. En producción usaríamos Gateway API o el add-on de enrutamiento de aplicaciones de AKS.
- **¿Costos?** VMs B2ats_v2 (centavos por hora) y AKS en plan Free (sin costo de control plane; solo el nodo). Se destruye todo al terminar.

## 12. Historial de lo que se hizo (7 oct, 4:50–6:00 a. m.)

1. Se auditó lo que dejó Antigravity contra el PDF. P3 nunca se había probado; el HPA y el Ingress estaban rotos; el nodo de AKS era inválido; el apply no configuraba nada; el control-node no existía.
2. Se reescribieron los manifiestos K8s (imagen propia, probes, restartPolicy, Ingress sin regex) y se movió el HPA a `extra/`.
3. Se creó `terraform-aks/` (clúster + app). Tropiezos y arreglos en orden: API de AKS vieja → azurerm 4.81; `az acr build` bloqueado → docker push; logins paralelos → secuencia; límite de IPs → brazilsouth; serie B no permitida → D2s_v4; ACR con nombre reciclado → `acrmp2grupo10`.
4. Se integró la configuración de las VMs en Terraform (`provisioning/`), con HAProxy reforzado (redispatch, chequeos de 2 s, 404, cabecera de servidor). Se corrigió el destroy con VMs pausadas y se probó destroy + apply desde cero.
5. Se creó el control-node con Vagrant: herramientas instaladas, `az login` hecho y `terraform plan` y `kubectl` probados desde ahí. El playbook de Ansible se probó desde ahí.
6. Se generaron las evidencias, la guía y el zip de entrega.
