# Corre analisis y pruebas y guarda la salida completa en setup\salida\
$ErrorActionPreference = 'Continue'
$env:Path = 'C:\src\flutter\bin;' + [Environment]::GetEnvironmentVariable('Path','User') + ';' + [Environment]::GetEnvironmentVariable('Path','Machine')
$proyecto = Split-Path -Parent $PSScriptRoot
$salida = Join-Path $PSScriptRoot 'salida'
New-Item -ItemType Directory -Force -Path $salida | Out-Null
Set-Location $proyecto
Set-Content (Join-Path $salida 'estado.txt') 'en curso' -Encoding UTF8
& flutter pub get *> (Join-Path $salida 'pub_get.txt')
& flutter analyze --no-fatal-infos *> (Join-Path $salida 'analyze.txt')
$a = $LASTEXITCODE
& flutter test --reporter expanded *> (Join-Path $salida 'test.txt')
$t = $LASTEXITCODE
& flutter doctor -v *> (Join-Path $salida 'doctor.txt')
& flutter devices *> (Join-Path $salida 'devices.txt')
Set-Content (Join-Path $salida 'estado.txt') "analyze=$a test=$t fin=$(Get-Date -Format s)" -Encoding UTF8
