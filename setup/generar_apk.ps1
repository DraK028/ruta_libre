# Revisa el codigo y genera el APK de prueba (release, firmado con la clave de depuracion)
$ErrorActionPreference = 'Continue'
$env:Path = 'C:\src\flutter\bin;' + [Environment]::GetEnvironmentVariable('Path','User') + ';' + [Environment]::GetEnvironmentVariable('Path','Machine')
$proyecto = Split-Path -Parent $PSScriptRoot
$salida = Join-Path $PSScriptRoot 'salida'
New-Item -ItemType Directory -Force -Path $salida | Out-Null
Set-Location $proyecto
$estado = Join-Path $salida 'apk_estado.txt'
Set-Content $estado 'en curso: pub get' -Encoding UTF8
Write-Host 'Ruta Libre - generando APK. No cierres esta ventana (tarda unos minutos).'
& flutter pub get *> (Join-Path $salida 'pub_get.txt')
# Permisos y nombre nativos (seguro de correr varias veces)
& dart run tool/patch_platforms.dart *> (Join-Path $salida 'patch.txt')
Set-Content $estado 'en curso: analyze' -Encoding UTF8
Write-Host '1/3 Revisando el codigo...'
& flutter analyze --no-fatal-infos *> (Join-Path $salida 'analyze.txt')
$a = $LASTEXITCODE
Set-Content $estado 'en curso: test' -Encoding UTF8
Write-Host '2/3 Corriendo pruebas...'
& flutter test --reporter expanded *> (Join-Path $salida 'test.txt')
$t = $LASTEXITCODE
$b = -1
if ($a -eq 0) {
  Set-Content $estado 'en curso: build apk' -Encoding UTF8
  Write-Host '3/3 Construyendo el APK...'
  & flutter build apk --release *> (Join-Path $salida 'apk.txt')
  $b = $LASTEXITCODE
  $origen = Join-Path $proyecto 'build\app\outputs\flutter-apk\app-release.apk'
  if ($b -eq 0 -and (Test-Path $origen)) {
    Copy-Item $origen (Join-Path $proyecto 'RutaLibre.apk') -Force
  }
}
Set-Content $estado "analyze=$a test=$t apk=$b fin=$(Get-Date -Format s)" -Encoding UTF8
if ($b -eq 0) { Write-Host 'Listo: C:\src\ruta_libre\RutaLibre.apk' } else { Write-Host 'Hubo un error; revisa setup\salida' }
