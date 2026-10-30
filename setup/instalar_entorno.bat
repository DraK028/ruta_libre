@echo off
chcp 65001 >nul
title Ruta Libre - instalacion del entorno
echo Instalando Git, Flutter y Android SDK, y preparando Ruta Libre.
echo Puede tardar de 20 a 40 minutos. No cierres esta ventana.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_entorno.ps1"
echo.
echo Terminado. El resumen esta en setup\estado.txt
pause
