# Instala el NDK que pide Flutter directamente desde el repositorio oficial de
# Google (el sdkmanager nuevo falla al instalarlo) y vuelve a compilar el APK.
param([string]$Version = '28.2.13676358')
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$env:Path = 'C:\src\flutter\bin;' + [Environment]::GetEnvironmentVariable('Path','User') + ';' + [Environment]::GetEnvironmentVariable('Path','Machine')
$sdk = 'C:\src\android-sdk'
$env:ANDROID_HOME = $sdk; $env:ANDROID_SDK_ROOT = $sdk
$proyecto = Split-Path -Parent $PSScriptRoot
$salida = Join-Path $PSScriptRoot 'salida'
New-Item -ItemType Directory -Force -Path $salida | Out-Null
$estado = Join-Path $salida 'ndk_estado.txt'
function Estado($t) { Set-Content $estado $t -Encoding UTF8; Write-Host $t }

$destino = Join-Path $sdk "ndk\$Version"
if (-not (Test-Path (Join-Path $destino 'source.properties'))) {
  Estado "buscando NDK $Version"
  $repo = 'https://dl.google.com/android/repository/'
  [xml]$xml = (Invoke-WebRequest ($repo + 'repository2-3.xml') -UseBasicParsing).Content
  $paquete = $xml.SelectNodes('//remotePackage') | Where-Object { $_.path -eq "ndk;$Version" } | Select-Object -First 1
  if (-not $paquete) { Estado "ERROR: el repositorio no tiene ndk;$Version"; exit 1 }
  $archivo = $paquete.archives.archive | Where-Object { $_.'host-os' -eq 'windows' } | Select-Object -First 1
  if (-not $archivo) { Estado 'ERROR: no hay NDK para Windows en el repositorio'; exit 1 }
  $url = $repo + $archivo.complete.url
  $sha1 = $archivo.complete.checksum.'#text'
  if (-not $sha1) { $sha1 = $archivo.complete.checksum }
  $zip = Join-Path $env:TEMP $archivo.complete.url
  Estado "descargando $url"
  & curl.exe -L --fail --retry 3 -o $zip $url *> (Join-Path $salida 'ndk_descarga.txt')
  if ($LASTEXITCODE -ne 0) { Estado 'ERROR: fallo la descarga del NDK'; exit 1 }
  if ($sha1 -and ((Get-FileHash $zip -Algorithm SHA1).Hash -ne $sha1.ToUpper())) { Estado 'ERROR: el NDK descargado no coincide con su SHA-1'; exit 1 }
  Estado 'descomprimiendo NDK'
  $tmp = Join-Path $env:TEMP 'rl_ndk'
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null
  & tar.exe -xf $zip -C $tmp
  $carpeta = Get-ChildItem $tmp -Directory | Select-Object -First 1
  New-Item -ItemType Directory -Force -Path (Join-Path $sdk 'ndk') | Out-Null
  Move-Item $carpeta.FullName $destino
  # El SDK identifica el paquete por package.xml; se toma del repositorio.
  $rev = $paquete.revision
  $pkgXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:repository xmlns:ns2="http://schemas.android.com/repository/android/common/02" xmlns:ns3="http://schemas.android.com/repository/android/generic/02"><localPackage path="ndk;$Version" obsolete="false"><type-details xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="ns3:genericDetailsType"/><revision><major>$($rev.major)</major><minor>$($rev.minor)</minor><micro>$($rev.micro)</micro></revision><display-name>$($paquete.'display-name')</display-name></localPackage></ns2:repository>
"@
  Set-Content (Join-Path $destino 'package.xml') $pkgXml -Encoding UTF8
}
$props = Get-Content (Join-Path $destino 'source.properties') -ErrorAction SilentlyContinue | Where-Object { $_ -match 'Pkg.Revision' }
Estado "NDK instalado ($props). Compilando APK..."

Set-Location $proyecto
& flutter build apk --debug *> (Join-Path $salida 'apk.txt')
$apk = $LASTEXITCODE
Estado "apk=$apk ndk=$props fin=$(Get-Date -Format s)"
