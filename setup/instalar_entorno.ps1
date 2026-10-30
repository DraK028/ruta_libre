# Instala lo necesario para desarrollar Ruta Libre en Windows y prepara el
# proyecto. Se puede correr varias veces: cada paso revisa si ya está hecho.
#   - Git (winget)
#   - Flutter estable (zip oficial, en %USERPROFILE%\develop\flutter)
#   - Android SDK: command-line tools, platform-tools y licencias
#   - Proyecto: flutter create, permisos nativos, pub get, analyze y test
# Todo queda registrado en setup\instalacion.log y el resumen en setup\estado.txt

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$setupDir = $PSScriptRoot
$proyecto = Split-Path -Parent $setupDir
$estadoFile = Join-Path $setupDir 'estado.txt'
Start-Transcript -Path (Join-Path $setupDir 'instalacion.log') -Force | Out-Null

$estado = [ordered]@{}
function Guardar-Estado { ($estado.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join "`r`n" | Set-Content -Path $estadoFile -Encoding UTF8 }
function Paso($n, $t) { Write-Host "`n=== $n $t ===" -ForegroundColor Yellow; $estado[$t] = 'en curso'; Guardar-Estado }
function Listo($t, $msg = 'OK') { $estado[$t] = $msg; Guardar-Estado; Write-Host "  -> $msg" -ForegroundColor Green }
function Refrescar-Path { $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') }
function Agregar-PathUsuario($dir) {
  $actual = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not $actual) { $actual = '' }
  $partes = $actual.Split(';') | Where-Object { $_ }
  if ($partes -notcontains $dir) {
    [Environment]::SetEnvironmentVariable('Path', ((@($dir) + $partes) -join ';'), 'User')
  }
  Refrescar-Path
}
function Descargar($url, $destino, $sha256) {
  if ((Test-Path $destino) -and $sha256 -and ((Get-FileHash $destino -Algorithm SHA256).Hash -eq $sha256.ToUpper())) {
    Write-Host "  Ya descargado: $destino"; return
  }
  Write-Host "  Descargando $url"
  if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    & curl.exe -L --fail --retry 3 -o $destino $url
    if ($LASTEXITCODE -ne 0) { throw "Fallo la descarga de $url" }
  } else {
    Invoke-WebRequest -Uri $url -OutFile $destino -UseBasicParsing
  }
  if ($sha256 -and ((Get-FileHash $destino -Algorithm SHA256).Hash -ne $sha256.ToUpper())) {
    Remove-Item $destino -Force
    throw "La descarga de $url no coincide con su SHA-256"
  }
}
function Correr($titulo, [scriptblock]$cmd) {
  & $cmd
  if ($LASTEXITCODE -ne 0) { Listo $titulo "FALLO (codigo $LASTEXITCODE)"; return $false }
  Listo $titulo; return $true
}

try {
  Refrescar-Path

  # ---------------------------------------------------------------- Git
  Paso '1/6' 'Git'
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'No hay winget para instalar Git. Instala Git para Windows y vuelve a correr este script.' }
    Write-Host '  Instalando Git (puede pedir permiso de administrador)...'
    & winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
    Refrescar-Path
    if (-not (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path 'C:\Program Files\Git\cmd\git.exe')) { Agregar-PathUsuario 'C:\Program Files\Git\cmd' }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git no quedo instalado.' }
  }
  Listo 'Git' (& git --version)

  # ------------------------------------------------------------ Flutter
  Paso '2/6' 'Flutter'
  # Flutter falla con espacios en la ruta (p. ej. C:\Users\asus vivobook),
  # asi que se instala en C:\src cuando se puede.
  $develop = 'C:\src'
  try { New-Item -ItemType Directory -Force -Path $develop -ErrorAction Stop | Out-Null }
  catch { $develop = Join-Path $env:USERPROFILE 'develop' }
  if ($develop -match ' ') { Write-Host "  Aviso: la ruta de Flutter tiene espacios ($develop)." -ForegroundColor Yellow }
  $flutterBin = Join-Path $develop 'flutter\bin'
  if (-not (Test-Path (Join-Path $flutterBin 'flutter.bat'))) {
    $rel = Invoke-RestMethod 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
    $r = $rel.releases | Where-Object { $_.hash -eq $rel.current_release.stable -and $_.channel -eq 'stable' } | Select-Object -First 1
    if (-not $r) { throw 'No encontre la version estable de Flutter.' }
    $zip = Join-Path $env:TEMP (Split-Path $r.archive -Leaf)
    Write-Host "  Flutter $($r.version) (cerca de 1.5 GB, puede tardar)"
    Descargar "$($rel.base_url)/$($r.archive)" $zip $r.sha256
    New-Item -ItemType Directory -Force -Path $develop | Out-Null
    Write-Host '  Descomprimiendo...'
    & tar.exe -xf $zip -C $develop
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $flutterBin 'flutter.bat'))) {
      throw "No se pudo descomprimir Flutter. Si tu antivirus bloqueo flutter.bat, agrega una excepcion para $develop."
    }
  }
  Agregar-PathUsuario $flutterBin
  & flutter config --no-analytics | Out-Null
  & flutter --disable-analytics | Out-Null
  & flutter --version
  Listo 'Flutter' ((& flutter --version | Select-Object -First 1) -replace '\s+', ' ')

  # -------------------------------------------------------- Android SDK
  Paso '3/6' 'Android SDK'
  $sdk = $env:ANDROID_HOME
  if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
  if (-not (Test-Path $sdk)) { throw "No encontre el Android SDK en $sdk. Abrelo una vez desde Android Studio (More Actions > SDK Manager)." }
  [Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdk, 'User'); $env:ANDROID_HOME = $sdk

  $studio = @("$env:ProgramFiles\Android\Android Studio", "$env:LOCALAPPDATA\Programs\Android Studio", "${env:ProgramFiles(x86)}\Android\Android Studio") |
    Where-Object { $_ -and (Test-Path "$_\jbr\bin\java.exe") } | Select-Object -First 1
  if ($studio) {
    $env:JAVA_HOME = "$studio\jbr"
    & flutter config --android-studio-dir="$studio" | Out-Null
  } else {
    $jdk = Get-ChildItem "$env:USERPROFILE\.jdks" -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path "$($_.FullName)\bin\java.exe" } | Sort-Object Name -Descending | Select-Object -First 1
    if ($jdk) { $env:JAVA_HOME = $jdk.FullName } else { throw 'No encontre Java (ni el de Android Studio ni en .jdks).' }
  }
  Write-Host "  JAVA_HOME = $env:JAVA_HOME"
  & flutter config --android-sdk="$sdk" | Out-Null

  $sdkmanager = Join-Path $sdk 'cmdline-tools\latest\bin\sdkmanager.bat'
  if (-not (Test-Path $sdkmanager)) {
    Write-Host '  Instalando Android command-line tools...'
    $archivo = 'commandlinetools-win-15859902_latest.zip'
    try {
      $xml = (Invoke-WebRequest 'https://dl.google.com/android/repository/repository2-3.xml' -UseBasicParsing).Content
      $num = [regex]::Matches($xml, 'commandlinetools-win-(\d+)_latest\.zip') | ForEach-Object { [int64]$_.Groups[1].Value } | Sort-Object -Descending | Select-Object -First 1
      if ($num) { $archivo = "commandlinetools-win-$($num)_latest.zip" }
    } catch { Write-Host '  (uso la version conocida de command-line tools)' }
    $zip = Join-Path $env:TEMP $archivo
    Descargar "https://dl.google.com/android/repository/$archivo" $zip $null
    $tmp = Join-Path $env:TEMP 'rl_cmdline_tools'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    & tar.exe -xf $zip -C $tmp
    New-Item -ItemType Directory -Force -Path (Join-Path $sdk 'cmdline-tools') | Out-Null
    $destino = Join-Path $sdk 'cmdline-tools\latest'
    if (Test-Path $destino) { Remove-Item $destino -Recurse -Force }
    Move-Item (Join-Path $tmp 'cmdline-tools') $destino
  }
  Write-Host '  Aceptando licencias de Android...'
  (1..60 | ForEach-Object { 'y' }) | & $sdkmanager --licenses | Out-Null
  & $sdkmanager --install 'platform-tools' | Out-Null
  (1..60 | ForEach-Object { 'y' }) | & flutter doctor --android-licenses | Out-Null
  Listo 'Android SDK' "OK ($sdk)"

  # ----------------------------------------------------------- Proyecto
  Paso '4/6' 'Proyecto'
  Set-Location $proyecto
  & flutter create --org com.drak028 --project-name ruta_libre --platforms android,web .
  if ($LASTEXITCODE -ne 0) { throw 'flutter create fallo.' }
  & dart run tool/patch_platforms.dart
  & flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get fallo: revisa las versiones en pubspec.yaml.' }
  Listo 'Proyecto'

  # ------------------------------------------------- Analisis y pruebas
  Paso '5/6' 'Analisis'
  $null = Correr 'Analisis' { & flutter analyze --no-fatal-infos }
  Paso '5/6' 'Pruebas'
  $null = Correr 'Pruebas' { & flutter test }

  # --------------------------------------------------------- Diagnostico
  Paso '6/6' 'flutter doctor'
  & flutter doctor -v
  & flutter devices
  Listo 'flutter doctor' 'ver log'
  $estado['FIN'] = (Get-Date -Format 's')
  Guardar-Estado
}
catch {
  $estado['ERROR'] = $_.Exception.Message
  Guardar-Estado
  Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
  Stop-Transcript | Out-Null
}
