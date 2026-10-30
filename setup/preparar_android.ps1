# El Android SDK no soporta rutas con espacios (C:\Users\Asus Vivobook\...).
# Se crea un enlace sin espacios en C:\src\android-sdk que apunta al mismo SDK
# (no copia nada ni requiere administrador) y se compila un APK de prueba.
$ErrorActionPreference = 'Continue'
$env:Path = 'C:\src\flutter\bin;' + [Environment]::GetEnvironmentVariable('Path','User') + ';' + [Environment]::GetEnvironmentVariable('Path','Machine')
$proyecto = Split-Path -Parent $PSScriptRoot
$salida = Join-Path $PSScriptRoot 'salida'
New-Item -ItemType Directory -Force -Path $salida | Out-Null
$estado = Join-Path $salida 'android_estado.txt'
Set-Content $estado 'en curso' -Encoding UTF8

$real = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$enlace = 'C:\src\android-sdk'
if (-not (Test-Path $enlace)) {
  & cmd.exe /c mklink /J "$enlace" "$real" *> (Join-Path $salida 'mklink.txt')
}
if (-not (Test-Path (Join-Path $enlace 'platform-tools'))) {
  Set-Content $estado "ERROR: no se pudo crear el enlace $enlace" -Encoding UTF8
  exit 1
}
[Environment]::SetEnvironmentVariable('ANDROID_HOME', $enlace, 'User')
[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $enlace, 'User')
$env:ANDROID_HOME = $enlace; $env:ANDROID_SDK_ROOT = $enlace
& flutter config --android-sdk="$enlace" *> (Join-Path $salida 'config.txt')
(1..60 | ForEach-Object { 'y' }) | & flutter doctor --android-licenses *> (Join-Path $salida 'licencias.txt')
& flutter doctor -v *> (Join-Path $salida 'doctor.txt')

Set-Location $proyecto
& flutter build apk --debug *> (Join-Path $salida 'apk.txt')
$apk = $LASTEXITCODE
& flutter analyze --no-fatal-infos *> (Join-Path $salida 'analyze.txt')
$a = $LASTEXITCODE
& flutter test *> (Join-Path $salida 'test.txt')
$t = $LASTEXITCODE
Set-Content $estado "apk=$apk analyze=$a test=$t fin=$(Get-Date -Format s)" -Encoding UTF8
