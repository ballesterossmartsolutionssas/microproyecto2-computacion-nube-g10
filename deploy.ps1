# ==============================================================================
# Microproyecto 2 - atajos para la sustentacion (Grupo 10)
# Integrantes: Juan Camilo Ballesteros, Valentina Valestegui, Juan Miguel Carabali
#
#   .\deploy.ps1 -Apply     terraform apply  (crea VMs + Docker + 6 contenedores + HAProxy)
#   .\deploy.ps1 -Destroy   terraform destroy de las VMs
#   .\deploy.ps1 -Start     enciende las VMs pausadas y espera a que todo responda
#   .\deploy.ps1 -Pause     pausa (deallocate) las VMs: computo a 0 USD/h
#   .\deploy.ps1 -Test      curl a las 3 rutas + stats + prueba de caida de users-1 (-Auto: sin pausa)
#   .\deploy.ps1 -AksUp     terraform apply del cluster AKS + ACR + aplicacion (opcional)
#   .\deploy.ps1 -AksTest   kubectl get all, curl por el Ingress y kubectl scale a 4
#   .\deploy.ps1 -AksDown   terraform destroy del cluster AKS
# ==============================================================================
param(
    [switch]$Apply, [switch]$Destroy, [switch]$Start, [switch]$Pause, [switch]$Test,
    [switch]$AksUp, [switch]$AksTest, [switch]$AksDown, [switch]$Auto
)

$PROJ   = $PSScriptRoot
$TF_DIR = "$PROJ\terraform"
$AKS_DIR = "$PROJ\terraform-aks"
$RG     = "rg-microproyecto2"
$KEY    = "$TF_DIR\id_rsa"
$SSH    = @("-i", $KEY, "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=NUL", "-o", "LogLevel=ERROR")

function Header($msg) {
    Write-Host "`n==============================================================================" -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
}

function Get-Ips {
    Push-Location $TF_DIR
    $script:HAPROXY_IP = (terraform output -raw haproxy_public_ip).Trim()
    $script:MICRO_IP   = (terraform output -raw microservices_public_ip).Trim()
    Pop-Location
}

function Instance($url) {
    $raw = curl.exe -s -m 5 -w "`n%{http_code}" $url
    $lines = $raw -split "`n"
    $code = $lines[-1]
    $inst = "-"
    try { $inst = (($lines[0..($lines.Length - 2)] -join "`n") | ConvertFrom-Json).instance } catch {}
    return "HTTP $code  instancia=$inst"
}

if ($Apply) {
    Header "TERRAFORM APPLY: infraestructura + configuracion de los dos nodos"
    Push-Location $TF_DIR
    terraform init -input=false
    terraform apply -auto-approve
    Pop-Location
    exit 0
}

if ($Destroy) {
    Header "TERRAFORM DESTROY de las VMs"
    Push-Location $TF_DIR
    terraform destroy -auto-approve
    Pop-Location
    exit 0
}

if ($Pause) {
    Header "PAUSANDO (deallocate) LAS VMS"
    az vm deallocate --resource-group $RG --name vm-haproxy --no-wait
    az vm deallocate --resource-group $RG --name vm-microservices --no-wait
    Write-Host "Orden enviada. Las VMs quedan sin cobro de computo." -ForegroundColor Green
    exit 0
}

if ($Start) {
    Header "ENCENDIENDO LAS VMS"
    az vm start --resource-group $RG --name vm-haproxy --no-wait
    az vm start --resource-group $RG --name vm-microservices
    Get-Ips
    Write-Host "Esperando a que HAProxy y los contenedores respondan..." -ForegroundColor Gray
    for ($i = 0; $i -lt 40; $i++) {
        $code = curl.exe -s -m 3 -o NUL -w "%{http_code}" "http://$HAPROXY_IP/api/orders"
        if ($code -eq "200") { break }
        Start-Sleep 3
    }
    Write-Host "HAProxy:          http://$HAPROXY_IP  (ultimo codigo: $code)" -ForegroundColor Green
    Write-Host "Stats:            http://${HAPROXY_IP}:8080/stats  (admin / admin123)" -ForegroundColor Green
    Write-Host "vm-microservices: ssh -i terraform\id_rsa azureuser@$MICRO_IP" -ForegroundColor Green
    exit 0
}

if ($Test) {
    Get-Ips
    Header "ENRUTAMIENTO Y ROUND-ROBIN EN HAPROXY ($HAPROXY_IP)"
    foreach ($svc in "users", "products", "orders") {
        Write-Host "`n--- /api/$svc ---" -ForegroundColor Yellow
        for ($i = 1; $i -le 4; $i++) { Write-Host "  peticion $i -> $(Instance "http://$HAPROXY_IP/api/$svc")" -ForegroundColor Green }
    }

    Header "PAGINA DE ESTADISTICAS"
    $noauth = curl.exe -s -o NUL -w "%{http_code}" "http://${HAPROXY_IP}:8080/stats"
    $auth   = curl.exe -s -o NUL -w "%{http_code}" -u admin:admin123 "http://${HAPROXY_IP}:8080/stats"
    Write-Host "  sin credenciales -> HTTP $noauth   |   admin:admin123 -> HTTP $auth" -ForegroundColor Green

    Header "CAIDA DE users-1: peticiones continuas mientras se detiene el contenedor"
    $job = Start-Job { param($k, $ip) ssh -i $k -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o LogLevel=ERROR azureuser@$ip "sudo docker stop users-1" } -ArgumentList $KEY, $MICRO_IP
    $fails = 0
    for ($i = 1; $i -le 30; $i++) {
        $r = Instance "http://$HAPROXY_IP/api/users"
        if ($r -notlike "HTTP 200*") { $fails++ }
        Write-Host "  t=$([math]::Round($i * 0.5, 1))s -> $r"
        Start-Sleep -Milliseconds 500
    }
    Receive-Job $job -Wait | Out-Null
    Write-Host "  Peticiones fallidas durante la caida: $fails de 30" -ForegroundColor $(if ($fails -eq 0) { "Green" } else { "Red" })
    Write-Host "  (en http://${HAPROXY_IP}:8080/stats users1 debe verse DOWN en rojo)" -ForegroundColor Gray
    $csv = curl.exe -s -u admin:admin123 "http://${HAPROXY_IP}:8080/stats;csv" | Where-Object { $_ -like "users_back,users*" }
    foreach ($row in $csv) { $c = $row -split ","; Write-Host "  Estado en HAProxy: $($c[1]) = $($c[17])" -ForegroundColor Gray }
    if (-not $Auto) {
        Write-Host "`n  Pulsa Enter para volver a encender users-1..." -ForegroundColor Yellow
        [void](Read-Host)
    }
    ssh @SSH azureuser@$MICRO_IP "sudo docker start users-1" | Out-Null
    Start-Sleep 6
    Write-Host "  users-1 encendido; el round-robin vuelve a repartir:" -ForegroundColor Cyan
    for ($i = 1; $i -le 4; $i++) { Write-Host "  peticion $i -> $(Instance "http://$HAPROXY_IP/api/users")" -ForegroundColor Green }
    exit 0
}

if ($AksUp) {
    Header "TERRAFORM APPLY: AKS + ACR + IMAGENES + INGRESS + APLICACION"
    Push-Location $AKS_DIR
    terraform init -input=false
    terraform apply -auto-approve
    Pop-Location
    exit 0
}

if ($AksTest) {
    az aks get-credentials --resource-group rg-microproyecto2-aks --name aks-microproyecto2 --overwrite-existing 2>$null | Out-Null
    Header "kubectl get all -n microapp"
    kubectl get all -n microapp
    kubectl get ingress -n microapp
    $IP = kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    Header "ACCESO EXTERNO POR EL INGRESS ($IP)"
    foreach ($svc in "users", "products", "orders") {
        Write-Host "`n--- /api/$svc ---" -ForegroundColor Yellow
        for ($i = 1; $i -le 3; $i++) { Write-Host "  peticion $i -> $(Instance "http://$IP/api/$svc")" -ForegroundColor Green }
    }
    Header "kubectl scale deployment orders-service --replicas=4 (con trafico continuo)"
    kubectl scale deployment orders-service -n microapp --replicas=4
    $fails = 0; $seen = @{}
    for ($i = 1; $i -le 40; $i++) {
        $r = Instance "http://$IP/api/orders"
        if ($r -notlike "HTTP 200*") { $fails++ } else { $seen[($r -split "instancia=")[1]] = 1 }
        Start-Sleep -Milliseconds 500
    }
    kubectl get pods -n microapp -l app=orders-service -o wide
    Write-Host "`n  Pods distintos que respondieron: $($seen.Count)  ->  $($seen.Keys -join ', ')" -ForegroundColor Green
    Write-Host "  Peticiones fallidas durante el escalado: $fails de 40" -ForegroundColor $(if ($fails -eq 0) { "Green" } else { "Red" })
    exit 0
}

if ($AksDown) {
    Header "TERRAFORM DESTROY del cluster AKS"
    Push-Location $AKS_DIR
    terraform destroy -auto-approve
    Pop-Location
    exit 0
}

Write-Host "Uso: .\deploy.ps1 -Apply | -Destroy | -Start | -Pause | -Test | -AksUp | -AksTest | -AksDown"
