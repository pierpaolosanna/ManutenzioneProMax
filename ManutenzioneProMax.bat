@echo off
setlocal enabledelayedexpansion
color 0A

set "BASE=%~dp0"
set "BASE=%BASE:~0,-1%"
set "SCRIPT=%BASE%\Manutenzione_PRO_MAX.ps1"

:MENU
cls
echo:
echo ============================================================
echo MANUTENZIONE PRO MAX Peters
echo ============================================================
echo:
echo Questo launcher installa PowerShell 7 (ultima versione),
echo sblocca tutti i file nella cartella ed esegue lo script.
echo:
echo [1] Esegui come UTENTE
echo [2] Esegui come AMMINISTRATORE
echo:
set /p scelta=" Scegli (1 o 2): "
if "%scelta%"=="1" goto :VERIFICA
if "%scelta%"=="2" goto :VERIFICA
echo Scelta non valida!
pause >nul
goto :MENU

:VERIFICA
rem --- Verifica PowerShell 7 ---
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
    goto :UNBLOCK
)

where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    for /f "delims=" %%A in ('where pwsh 2^>nul') do set "PWSH=%%A"
    goto :UNBLOCK
)

rem --- Installazione PowerShell 7 ---
cls
echo:
echo ============================================================
echo INSTALLAZIONE POWERSHELL 7 DA GITHUB
echo Microsoft Powershell - Attendete l'installazione -
echo ============================================================
echo:
echo Cerco ultima versione stabile...

set "VER="
for /f "delims=" %%A in ('"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command "(Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -UseBasicParsing).tag_name.Substring(1)" 2^>nul') do set "VER=%%A"

if not defined VER set "VER=7.6.3"
echo Versione: v%VER%
echo:

set "MSI=PowerShell-%VER%-win-x64.msi"
set "URL=https://github.com/PowerShell/PowerShell/releases/download/v%VER%/%MSI%"
set "MSI_PATH=%TEMP%\%MSI%"

echo Scarico da GitHub...
%SystemRoot%\System32\curl.exe -L -o "%MSI_PATH%" -S --progress-bar "%URL%"
if %errorlevel% neq 0 (
    echo Download fallito, provo con winget...
    winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements
    timeout /t 5 /nobreak >nul
    goto :DOPO_INSTALLA
)

echo Installazione in corso...
%SystemRoot%\System32\msiexec.exe /i "%MSI_PATH%" /passive /norestart
echo Attendere il completamento dell'installazione...
timeout /t 15 /nobreak >nul
del "%MSI_PATH%" 2>nul

:DOPO_INSTALLA
refreshenv >nul 2>&1

if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
    goto :UNBLOCK
)

where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    for /f "delims=" %%A in ('where pwsh 2^>nul') do set "PWSH=%%A"
    goto :UNBLOCK
)

if exist "%ProgramFiles(x86)%\PowerShell\7\pwsh.exe" (
    set "PWSH=%ProgramFiles(x86)%\PowerShell\7\pwsh.exe"
    goto :UNBLOCK
)

echo:
echo ============================================================
echo ERRORE: PowerShell 7 non è stato installato automaticamente.
echo ============================================================
echo:
echo Scarica manualmente da:
echo %URL%
echo:
pause
exit /b

:UNBLOCK
echo:
echo ============================================================
echo SBLOCCO FILE E CARTELLE
echo ============================================================
echo:
echo Rimozione flag "blocca" da:
echo %BASE%
echo:

"%PWSH%" -NoProfile -Command "Get-ChildItem -Path '%BASE%' -Recurse -File | Unblock-File"

if errorlevel 1 (
    echo Attenzione: alcuni file potrebbero non essere sbloccati.
) else (
    echo OK: tutti i file sbloccati.
)

if not exist "%SCRIPT%" (
    echo:
    echo ERRORE: %SCRIPT% non trovato.
    pause
    exit /b
)

echo:
echo ============================================================
echo AVVIO SCRIPT (PowerShell 7)
echo ============================================================
echo:
echo PowerShell: %PWSH%
echo Script:     %SCRIPT%
echo Modalita':  %scelta%
echo:

if "%scelta%"=="2" (
    "%PWSH%" -NoProfile -ExecutionPolicy Bypass -Command ^
        "Start-Process -FilePath '%PWSH%' -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%SCRIPT%' -Verb RunAs"
) else (
    "%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
)

echo:
echo Fine. Premi un tasto per chiudere.
pause >nul
exit /b
