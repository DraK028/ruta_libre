@echo off
title Ruta Libre - desplegar servidor de reportes
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0desplegar_servidor.ps1"
pause
