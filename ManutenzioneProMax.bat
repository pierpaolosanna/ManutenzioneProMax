@echo off
setlocal enabledelayedexpansion
color 0A

set "BASE=%~dp0"
set "BASE=%BASE:~0,-1%"

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

if exist "%ProgramFiles(x86)%\PowerShell\7\pwsh.exe" (
    set "PWSH=%ProgramFiles(x86)%\PowerShell\7\pwsh.exe"
    goto :PWSH_TROVATO
)

:: ============================================================
:: POWERSHELL 7 NON TROVATO → TENTA INSTALLAZIONE COME ADMIN
:: ============================================================
cls
echo.
echo ============================================================
echo   POWERSHELL 7 NON TROVATO
echo ============================================================
echo.
echo PowerShell 7 non e' installato sul sistema.
echo Per eseguire lo script e' necessario installarlo.
echo.
echo Verranno richiesti privilegi amministrativi per l'installazione.

:: Verifica se siamo già admin per installare
net session >nul 2>&1
if %errorlevel% equ 0 goto :INSTALLA_PWSH

:: Se non siamo admin, ci riavviamo come admin per installare
echo.
echo Riavvio come amministratore per installare PowerShell 7...
timeout /t 2 /nobreak >nul
powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -ArgumentList '--install'"
exit /b

:INSTALLA_PWSH
:: A questo punto siamo admin
cls
echo.
echo ============================================================
echo   INSTALLAZIONE POWERSHELL 7 DA GITHUB
echo ============================================================
echo.
echo Cerco ultima versione stabile su GitHub...

:: ============================================================
:: TENTATIVO 1: Invoke-RestMethod (PowerShell)
:: ============================================================
set "VER="
for /f "delims=" %%A in ('"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -Command "(Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -UseBasicParsing).tag_name.Substring(1)" 2^>nul') do set "VER=%%A"

if defined VER goto :VERSIONE_TROVATA

:: ============================================================
:: TENTATIVO 2: curl.exe + findstr (fallback)
:: ============================================================
echo Invoke-RestMethod fallito, provo con curl...
set "TEMP_JSON=%TEMP%\ps_version_%RANDOM%.json"
%SystemRoot%\System32\curl.exe -s -L -o "%TEMP_JSON%" "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
if exist "%TEMP_JSON%" (
    for /f "tokens=2 delims=:, " %%A in ('findstr "\"tag_name\"" "%TEMP_JSON%" 2^>nul') do (
        set "RAW=%%A"
        set "RAW=!RAW:"=!"
        set "VER=!RAW:v=!"
    )
    del "%TEMP_JSON%" 2>nul
)

if defined VER goto :VERSIONE_TROVATA

:: ============================================================
:: TENTATIVO 3: versione predefinita (ultima stabile nota)
:: ============================================================
echo.
echo ============================================================
echo   IMPOSSIBILE DETERMINARE L'ULTIMA VERSIONE
echo ============================================================
echo.
echo Impossibile contattare GitHub per ottenere l'ultima versione.
echo Verra' installata la versione 7.4.0 (ultima stabile nota).
echo.
echo Se desideri un'altra versione, scaricala manualmente da:
echo https://github.com/PowerShell/PowerShell/releases/latest
echo.
pause
set "VER=7.4.0"

:VERSIONE_TROVATA
echo Versione rilevata: v%VER%
echo.

set "MSI=PowerShell-%VER%-win-x64.msi"
set "URL=https://github.com/PowerShell/PowerShell/releases/download/v%VER%/%MSI%"
set "MSI_PATH=%TEMP%\%MSI%"

echo Scarico da GitHub...
%SystemRoot%\System32\curl.exe -L -o "%MSI_PATH%" -S --progress-bar "%URL%"
if %errorlevel% neq 0 (
    echo.
    echo ============================================================
    echo   ERRORE: Download fallito
    echo ============================================================
    echo.
    echo Verifica la connessione o scarica manualmente da:
    echo %URL%
    echo.
    pause
    exit /b
)

echo Installazione in corso...
%SystemRoot%\System32\msiexec.exe /i "%MSI_PATH%" /passive /norestart
echo Attendere il completamento dell'installazione...

timeout /t 2 /nobreak >nul
del "%MSI_PATH%" 2>nul

:DOPO_INSTALLA

:: ============================================================
:: RICONTROLLO PRESENZA POWERSHELL 7 (max 30 secondi)
:: ============================================================
set "MAX_TRIALS=6"
set "TRIAL=0"
set "PWSH_FOUND=0"

:VERIFICA_INSTALLA
set /a TRIAL+=1

if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set "PWSH=%ProgramFiles%\PowerShell\7\pwsh.exe"
    set "PWSH_FOUND=1"
    goto :INSTALLA_OK
)

where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    for /f "delims=" %%A in ('where pwsh 2^>nul') do set "PWSH=%%A"
    set "PWSH_FOUND=1"
    goto :INSTALLA_OK
)

if exist "%ProgramFiles(x86)%\PowerShell\7\pwsh.exe" (
    set "PWSH=%ProgramFiles(x86)%\PowerShell\7\pwsh.exe"
    set "PWSH_FOUND=1"
    goto :INSTALLA_OK
)

if %TRIAL% lss %MAX_TRIALS% (
    echo PowerShell 7 non ancora rilevato, nuovo tentativo tra 5 secondi (%TRIAL%/%MAX_TRIALS%)...
    timeout /t 5 /nobreak >nul
    goto :VERIFICA_INSTALLA
)

:INSTALLA_OK
if %PWSH_FOUND% equ 0 (
    echo.
    echo ============================================================
    echo   ERRORE: PowerShell 7 non installato
    echo ============================================================
    echo.
    echo Scarica manualmente da:
    echo %URL%
    echo.
    pause
    exit /b
)

echo.
echo [OK] PowerShell 7 installato: %PWSH%
goto :PWSH_TROVATO

:PWSH_TROVATO
echo.
echo [OK] PowerShell 7 rilevato: %PWSH%

:: ============================================================
:: CREAZIONE / SOVRASCRITTURA COLLEGAMENTO SUL DESKTOP
:: ============================================================
if 1==1 (
    echo.
    echo Creazione collegamento sul desktop...
    powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Desktop = [Environment]::GetFolderPath('Desktop'); $LinkPath = Join-Path $Desktop 'PRO MAX Maintenance.lnk'; $Shortcut = $WshShell.CreateShortcut($LinkPath); $Shortcut.TargetPath = '%~f0'; $Shortcut.WorkingDirectory = '%~dp0'; $Shortcut.IconLocation = 'imageres.dll,15'; $Shortcut.Save()"
    if errorlevel 1 (
        echo [ERRORE] Impossibile creare il collegamento.
    ) else (
        echo [OK] Collegamento creato su desktop.
    )
) else (
    echo [INFO] Collegamento non presente sul desktop. Non ne verra' creato uno nuovo.
)

:: ============================================================
:: SBLOCCO FILE E CARTELLE
:: ============================================================
echo.
echo ============================================================
echo   SBLOCCO FILE E CARTELLE
echo ============================================================
echo.
echo Rimozione flag "blocco" da:
echo %BASE%
echo.

:: Verifica che la cartella esista
if not exist "%BASE%" (
    echo [ERRORE] La cartella %BASE% non esiste.
    pause
    exit /b
)

cd /d "%BASE%" 2>nul
if errorlevel 1 (
    echo [ERRORE] Impossibile accedere alla cartella %BASE%.
    pause
    exit /b
)

set "UNBLOCK_PATH=%BASE%"
set "TEMP_PS1=%TEMP%\unblock_%RANDOM%.ps1"

> "%TEMP_PS1%" echo Get-ChildItem -LiteralPath $env:UNBLOCK_PATH -Recurse -File -ErrorAction SilentlyContinue ^| ForEach-Object ^{ Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue ^}

echo [INFO] Esecuzione sblocco file in corso...
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS1%"
if exist "%TEMP_PS1%" del "%TEMP_PS1%" 2>nul

if %errorlevel% neq 0 (
    echo Attenzione: alcuni file potrebbero non essere sbloccati.
) else (
    echo OK: tutti i file sbloccati.
)

:: ============================================================
:: CHIEDI ELEVAZIONE PER LO SCRIPT (DEFAULT = S)
:: ============================================================
:: Verifica se lo script esiste
if not exist "Manutenzione_PRO_MAX.ps1" (
    echo.
    echo ERRORE: Manutenzione_PRO_MAX.ps1 non trovato.
    echo.
    pause
    exit /b
)

echo.
echo ============================================================
echo   PRIVILEGI AMMINISTRATIVI PER LO SCRIPT
echo ============================================================
echo.
echo Lo script Manutenzione_PRO_MAX.ps1 puo' essere eseguito
echo con privilegi amministrativi per ottenere il massimo delle
echo funzionalita'.
echo.
echo Se accetti, verra' visualizzato il controllo UAC e lo script
echo partira' in una nuova finestra elevata.
echo Se lo rifiuti, lo script verra' eseguito con permessi limitati.
echo.
choice /C SN /T 2 /D S /M "Eseguire come amministratore [S/N] (default S in 2 secondi)"
if errorlevel 2 goto :AVVIA_NORMALE
if errorlevel 1 goto :AVVIA_ADMIN

:AVVIA_ADMIN
echo.
echo ============================================================
echo Avvio dello script come amministratore...
echo Verra' aperta una nuova finestra con privilegi elevati.
echo Questa finestra si chiudera' tra 2 secondi.
echo ============================================================
timeout /t 2 /nobreak >nul
powershell -Command "Start-Process -FilePath '%PWSH%' -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"Manutenzione_PRO_MAX.ps1\"'"
exit /b

:AVVIA_NORMALE
echo.
echo [AVVISO] Lo script verra' eseguito con permessi limitati.
echo         Alcune funzioni potrebbero non funzionare.
echo.
echo Premere un tasto per avviare lo script...
pause >nul
"%PWSH%" -NoProfile -ExecutionPolicy Bypass -File "Manutenzione_PRO_MAX.ps1"

:: Se lo script termina, mostra messaggio e pausa
echo.
echo ============================================================
echo [OK] Script completato.
echo Premere un tasto per chiudere questa finestra.
echo ============================================================
pause >nul
exit /b
