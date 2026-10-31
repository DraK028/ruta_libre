# Despliega el servidor de reportes compartidos en tu cuenta de AWS y guarda
# su URL en setup\servidor_url.txt (generar_apk.bat la usa al compilar).
# Requiere haber corrido una vez "aws configure" con las llaves de tu usuario IAM.
$ErrorActionPreference = 'Continue'
$setup = $PSScriptRoot
$proyecto = Split-Path -Parent $setup
$salida = Join-Path $setup 'salida'
New-Item -ItemType Directory -Force -Path $salida | Out-Null
$estado = Join-Path $salida 'servidor_estado.txt'
function Estado($t) { Set-Content $estado $t -Encoding UTF8; Write-Host $t }
function Refrescar-Path { $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') }

Refrescar-Path
foreach ($p in @(@{cmd='aws'; id='Amazon.AWSCLI'}, @{cmd='sam'; id='Amazon.SAM-CLI'})) {
  if (-not (Get-Command $p.cmd -ErrorAction SilentlyContinue)) {
    Estado "Instalando $($p.id) (puede pedir permiso de administrador)..."
    & winget install --id $p.id -e --silent --accept-package-agreements --accept-source-agreements
    Refrescar-Path
  }
  if (-not (Get-Command $p.cmd -ErrorAction SilentlyContinue)) {
    Estado "ERROR: no se pudo instalar $($p.id). Instálalo a mano y vuelve a abrir este archivo."
    exit 1
  }
}

& aws sts get-caller-identity *> (Join-Path $salida 'aws_identidad.txt')
if ($LASTEXITCODE -ne 0) {
  Estado 'Falta configurar tu cuenta de AWS.'
  Write-Host ''
  Write-Host 'Escribe tus llaves de acceso de AWS (usuario IAM). Region: us-east-1. Formato: json.'
  & aws configure
  & aws sts get-caller-identity *> (Join-Path $salida 'aws_identidad.txt')
  if ($LASTEXITCODE -ne 0) { Estado 'ERROR: las llaves de AWS no funcionaron.'; exit 1 }
}

Set-Location (Join-Path $proyecto 'server')
Estado 'Desplegando el servidor (tarda 2 a 5 minutos)...'
& sam deploy --no-progressbar *> (Join-Path $salida 'servidor_deploy.txt')
if ($LASTEXITCODE -ne 0) { Estado 'ERROR: fallo el despliegue; revisa setup\salida\servidor_deploy.txt'; exit 1 }

$url = (& aws cloudformation describe-stacks --stack-name ruta-libre-reportes --region us-east-1 `
  --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" --output text).Trim()
Set-Content (Join-Path $setup 'servidor_url.txt') $url -Encoding ASCII
Estado "Listo. URL del servidor: $url"
Write-Host 'Ahora abre generar_apk.bat para compilar la app conectada al servidor.'
Write-Host 'Para el APK de GitHub, guarda esa URL como variable de repositorio REPORTS_API_URL.'
