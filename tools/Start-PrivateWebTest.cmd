@echo off
setlocal
title Argentum - Servidor privado WSS
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Start-PrivateWebTest.ps1"
set "launcherExit=%ERRORLEVEL%"
if not "%launcherExit%"=="0" (
    echo.
    echo El lanzador termino con un error. Copia el mensaje que aparece arriba.
    pause
)
exit /b %launcherExit%
