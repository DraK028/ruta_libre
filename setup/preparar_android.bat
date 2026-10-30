@echo off
title Ruta Libre - preparar Android
echo Configurando el SDK de Android y compilando un APK de prueba (puede tardar varios minutos la primera vez).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0preparar_android.ps1"
