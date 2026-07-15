@echo off
setlocal enabledelayedexpansion
color 0A

set "BASE=%~dp0"
set "BASE=%BASE:~0,-1%"

:: ============================================================
:: CREAZIONE / SOVRASCRITTURA COLLEGAMENTO SUL DESKTOP (DISABILITATO) Basta cambiare 0==1 in 1==1:
:: ============================================================
if 0==1 (
    set "LINK_NAME=PRO MAX Maintenance"
    set "DESKTOP=%USERPROFILE%\Desktop"
    set "LINK_PATH=%DESKTOP%\%LINK_NAME%.lnk"
    if exist "%LINK_PATH%" del "%LINK_PATH%"
    echo Creazione collegamento sul desktop...
    powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%LINK_PATH%'); $Shortcut.TargetPath = '%~f0'; $Shortcut.WorkingDirectory = '%~dp0'; $Shortcut.IconLocation = 'imageres.dll,15'; $Shortcut.Save()"
    echo [OK] Collegamento creato: %LINK_PATH%
    echo.
)
) else (
    echo [INFO] Collegamento non presente sul desktop. Non ne verrà creato uno nuovo.
    echo.
)

:: ============================================================
:: VERIFICA PRESENZA POWERSHELL 7
:: ============================================================
set "PWSH="
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
    goto :PWSH_TROVATO
)

where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    for /f "delims=" %%A in ('where pwsh 2^>nul') do set "PWSH=%%A"
    goto :PWSH_TROVATO
)

:: ============================================================
:: POWERSHELL 7 NON TROVATO → RICHIEDI ADMIN
:: ============================================================
cls
echo:
echo ============================================================
echo POWERSHELL 7 NON TROVATO
echo ============================================================
echo:
echo Per installare PowerShell 7 sono necessari
echo privilegi amministrativi.
echo:

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Riavvio del launcher come amministratore...
    timeout /t 2 /nobreak >nul
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ============================================================
:: INSTALLAZIONE POWERSHELL 7
:: ============================================================
cls
echo:
echo ============================================================
echo INSTALLAZIONE POWERSHELL 7 DA GITHUB
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

:: ============================================================
:: POWERSHELL 7 TROVATO
:: ============================================================
:PWSH_TROVATO
echo:
echo [OK] PowerShell 7 rilevato: %PWSH%
echo:
goto :UNBLOCK

:UNBLOCK
echo:
echo ============================================================
echo SBLOCCO FILE E CARTELLE
echo ============================================================
echo:
echo Rimozione flag "blocco" da:
echo %BASE%
echo.

:: ✅ TRUCCO INFALLIBILE: Ci spostiamo nella cartella del programma.
:: Il comando CD gestisce benissimo le virgolette e le parentesi.
cd /d "%BASE%"

set "UNBLOCK_PATH=%BASE%"
set "TEMP_PS1=%TEMP%\unblock_%RANDOM%.ps1"

:: Crea il file ps1 temporaneo per lo sblocco
> "%TEMP_PS1%" echo Get-ChildItem -LiteralPath $env:UNBLOCK_PATH -Recurse -File -ErrorAction SilentlyContinue ^| ForEach-Object ^{ Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue ^}

:: Esegue lo sblocco
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS1%"
if exist "%TEMP_PS1%" del "%TEMP_PS1%" 2>nul

if %errorlevel% neq 0 (
    echo Attenzione: alcuni file potrebbero non essere sbloccati.
) else (
    echo OK: tutti i file sbloccati.
)

:: Controlla se lo script esiste (usando solo il nome file, senza_percorsi_lunghi)
if not exist "Manutenzione_PRO_MAX.ps1" (
    echo:
    echo ERRORE: Manutenzione_PRO_MAX.ps1 non trovato.
    pause
    exit /b
)

echo:
echo ============================================================
echo AVVIO SCRIPT (PowerShell 7)
echo ============================================================
echo:
echo PowerShell: %PWSH%
echo Script:     Manutenzione_PRO_MAX.ps1
echo.

:: ✅ AVVIO FINALE ASSOLUTAMENTE SICURO:
:: Non passiamo più C:\Program Files (x86)\... a PowerShell.
:: Gli passiamo SOLO il nome del file. Essendo già nella cartella giusta, funziona!
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "Manutenzione_PRO_MAX.ps1"

exit /b
