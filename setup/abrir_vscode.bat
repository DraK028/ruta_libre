@echo off
title Ruta Libre - abrir en VS Code
set "PATH=C:\src\flutter\bin;%PATH%"
set "CODE=code"
where code >nul 2>nul || set "CODE=%LOCALAPPDATA%\Programs\Microsoft VS Code\bin\code.cmd"
if not exist "%CODE%" if not "%CODE%"=="code" (
  echo No encontre VS Code. Instalalo desde https://code.visualstudio.com y vuelve a abrir este archivo.
  pause
  exit /b 1
)
echo Instalando la extension de Flutter (incluye Dart)...
call "%CODE%" --install-extension Dart-Code.flutter --force
echo Abriendo C:\src\ruta_libre ...
call "%CODE%" "C:\src\ruta_libre"
