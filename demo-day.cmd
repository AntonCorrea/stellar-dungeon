@echo off
title Stellar Dungeon - Demo Day
echo ==================================================
echo  Stellar Dungeon — Demo Day
echo.
echo  Se van a abrir DOS ventanas:
echo   1) El MOZO (la conexion con la blockchain)  [NO cerrar]
echo   2) El JUEGO
echo.
echo  Si ya tenes una ventana del MOZO abierta,
echo  cerrala antes de continuar.
echo ==================================================
pause
start "MOZO - relay" cmd /k "cd /d C:\Users\NanoCorrea\Documents\repos\event\stellar-dungeon-backend\relay && powershell -ExecutionPolicy Bypass -File start-live.ps1"
timeout /t 4 /nobreak >nul
powershell -ExecutionPolicy Bypass -File "%~dp0play-live.ps1"