# play-live.ps1: abre Stellar Dungeon conectado al relay REAL (testnet).
# Requisito: el relay corriendo en otra ventana (stellar\relay> .\start-live.ps1)
# La calidad de las armas la tira el CONTRATO on-chain (no el juego).
$ErrorActionPreference = "Stop"

$env:CHAIN_BACKEND = "relay"   # chain.gd delega en chain_http.gd (HTTP al relay)

$godot = "C:\Users\NanoCorrea\Downloads\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe"
if (-not (Test-Path $godot)) { Write-Host "No encuentro Godot en $godot" -ForegroundColor Red; exit 1 }
& $godot --path .