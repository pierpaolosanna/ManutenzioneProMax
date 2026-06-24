@echo off
echo ========================================
echo   Manutenzione PRO MAX v3.0
echo ========================================
echo.
echo  [1] Esegui come UTENTE
echo  [2] Esegui come AMMINISTRATORE
echo.
set /p scelta="Scegli (1 o 2): "

:: =====================================================
:: Verifica presenza di PowerShell 7 (pwsh)
:: =====================================================
where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    echo PowerShell 7 rilevato.
    set "PS=pwsh"
) else (
    echo.
    echo *** PowerShell 7 NON è installato ***
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
if "%scelta%"=="2" (
    %PS% -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%PS%' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0Manutenzione_PRO_MAX_v3.ps1\"' -Verb RunAs"
) else (
    %PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manutenzione_PRO_MAX_v3.ps1"
)
