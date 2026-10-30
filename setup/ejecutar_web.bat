@echo off
chcp 65001 >nul
title Ruta Libre - version web local
cd /d "%~dp0.."
set "PATH=C:\src\flutter\bin;%USERPROFILE%\develop\flutter\bin;%PATH%"
echo Abriendo Ruta Libre en el navegador (http://localhost:8080).
echo Para recargar tras un cambio: tecla r. Para salir: tecla q.
echo.
flutter devices | findstr /i "chrome" >nul && (
  flutter run -d chrome --web-port 8080
) || (
  flutter run -d edge --web-port 8080
)
pause
