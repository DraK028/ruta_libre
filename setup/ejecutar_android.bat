@echo off
chcp 65001 >nul
title Ruta Libre - en tu telefono Android
cd /d "%~dp0.."
set "PATH=C:\src\flutter\bin;%USERPROFILE%\develop\flutter\bin;%PATH%"
echo Conecta tu telefono por USB con la depuracion USB activada
echo ^(Ajustes ^> Acerca del telefono ^> toca 7 veces "Numero de compilacion",
echo  luego Ajustes ^> Opciones de desarrollador ^> Depuracion USB^).
echo.
flutter devices
echo.
flutter run
pause
