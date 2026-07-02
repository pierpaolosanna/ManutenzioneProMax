@echo off
title Manutenzione PRO MAX - Peters
color 0A

echo ================================================
echo   MANUTENZIONE PRO MAX
echo   Avvio in corso...
echo ================================================
echo.

:: =====================================================
:: Verifica presenza di PowerShell 7 (pwsh)
:: =====================================================
where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    echo PowerShell 7 rilevato.
    set "PS=pwsh"
) else (
    echo.
    echo *** PowerShell 7 NON e installato ***
    echo Installazione automatica in corso tramite winget...
    echo.

    winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements

    echo.
    echo Verifica installazione...

    where pwsh >nul 2>&1
    if %errorlevel% equ 0 (
        echo Installazione completata con successo.
        set "PS=pwsh"
    ) else (
        echo ERRORE: impossibile installare PowerShell 7.
        echo Uso PowerShell classico come fallback.
        set "PS=powershell"
    )
)

:: =====================================================
:: Avvio script PowerShell
:: =====================================================
%PS% -NoProfile -ExecutionPolicy Bypass -File "Manutenzione_PRO_MAX.ps1"

if %errorlevel% neq 0 (
    echo.
    echo [X] Errore durante l'esecuzione.
    pause
)
