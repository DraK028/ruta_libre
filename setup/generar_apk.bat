@echo off
title Ruta Libre - generar APK
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0generar_apk.ps1"
timeout /t 15
