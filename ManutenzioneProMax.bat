@echo off
echo ========================================
echo   Manutenzione PRO MAX v3.0
echo ========================================
echo.
echo  [1] Esegui come UTENTE
echo  [2] Esegui come AMMINISTRATORE
echo.
set /p scelta="Scegli (1 o 2): "

where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    set PS=pwsh
) else (
    set PS=powershell
)

if "%scelta%"=="2" (
    %PS% -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%PS%' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0Manutenzione_PRO_MAX_v3.ps1\"' -Verb RunAs"
) else (
    %PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manutenzione_PRO_MAX_v3.ps1"
)
