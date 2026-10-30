@echo off
title Ruta Libre - instalar NDK y compilar APK
echo Descargando el NDK de Android y compilando el APK. No cierres esta ventana.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_ndk.ps1"
