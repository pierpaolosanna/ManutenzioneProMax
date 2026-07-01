@echo off
title Manutenzione PRO MAX - Peters
color 0A
echo ================================================
echo   MANUTENZIONE PRO MAX
echo   Avvio in corso...
echo ================================================
echo.

:: Verifica se PowerShell 7 è installato
where pwsh >nul 2>nul
if %errorlevel% equ 0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "Manutenzione_PRO_MAX.ps1"
) else (
    echo [!] PowerShell 7 non trovato. Utilizzo PowerShell 5.1...
    powershell -NoProfile -ExecutionPolicy Bypass -File "Manutenzione_PRO_MAX.ps1"
)

if %errorlevel% neq 0 (
    echo.
    echo [X] Errore durante l'esecuzione.
    pause
)
