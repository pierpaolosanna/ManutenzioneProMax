@echo off
setlocal enabledelayedexpansion

color 0A

:: =====================================================
:: Controlla se siamo in fase di riavvio post-installazione
:: =====================================================
if "%~1"=="--post-install" goto :POST_INSTALL_CHECK

:: =====================================================
:: HEADER PRINCIPALE
:: =====================================================
cls
echo.
echo ============================================================
echo.
echo              MANUTENZIONE PRO MAX
echo.
echo ============================================================
echo.
echo        [1]  Esegui come UTENTE
echo        [2]  Esegui come AMMINISTRATORE
echo.
echo ------------------------------------------------------------
echo.
set /p scelta="   Scegli (1 o 2): "

:: =====================================================
:: Verifica presenza di PowerShell 7 (pwsh)
:: =====================================================
where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo        [OK] PowerShell 7 rilevato con successo!
    set "PS=pwsh"
    goto :AVVIO_SCRIPT
)

:: =====================================================
:: PowerShell 7 NON trovato - Procedi con installazione
:: =====================================================
cls
echo.
echo ============================================================
echo.
echo          INSTALLAZIONE COMPONENTE RICHIESTA
echo.
echo ============================================================
echo.
echo        Prodotto: Microsoft PowerShell 7
echo        Sorgente: Microsoft Winget Repository
echo        Sviluppatore: Microsoft Corporation
echo.
echo        * Questo e un prodotto Microsoft ufficiale e sicuro.
echo        * Verra installato tramite il gestore pacchetti Winget.
echo        * L installazione e completamente automatica.
echo.
echo        ! ATTENZIONE: L installazione potrebbe richiedere
echo          alcuni minuti. Si prega di NON CHIUDERE questa
echo          finestra. La pazienza e apprezzata!
echo.
echo ------------------------------------------------------------
echo.
echo        Avvio installazione...
echo.

winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements

echo.
echo ------------------------------------------------------------
echo.
echo        Verifica dell installazione in corso...
echo.

where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    echo.
    echo ============================================================
    echo.
    echo      [OK] INSTALLAZIONE COMPLETATA CON SUCCESSO
    echo.
    echo ============================================================
    echo.
    echo        * Microsoft PowerShell 7 installato correttamente!
    echo.
    echo        ---------------------------------------------------
    echo           RIAVVIO NECESSARIO
    echo.
    echo           Per aggiornare le variabili di sistema,
    echo           lo script verra riavviato come Amministratore.
    echo           Questo e normale e sicuro!
    echo        ---------------------------------------------------
    echo.
    
    set "BAT_PATH=%~f0"
    
    echo        Preparazione al riavvio...
    timeout /t 3 /nobreak >nul
    
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '!BAT_PATH!' -ArgumentList '--post-install','%scelta%' -Verb RunAs"
    
    exit /b
) else (
    echo.
    echo ============================================================
    echo.
    echo          [ERRORE] INSTALLAZIONE FALLITA
    echo.
    echo ============================================================
    echo.
    echo        ! Impossibile installare PowerShell 7.
    echo          Non preoccuparti! Verra utilizzato PowerShell classico.
    echo          Le funzionalita base saranno comunque disponibili.
    echo.
    set "PS=powershell"
    goto :AVVIO_SCRIPT
)

:: =====================================================
:: SEZIONE: Verifica post-riavvio
:: =====================================================
:POST_INSTALL_CHECK
cls
echo.
echo ============================================================
echo.
echo          VERIFICA POST-INSTALLAZIONE
echo              Manutenzione PRO MAX v3.0
echo.
echo ============================================================
echo.

set "scelta=%~2"

where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    echo        [OK] PowerShell 7 confermato nel PATH di sistema.
    set "PS=pwsh"
) else (
    echo        [!] PowerShell 7 non trovato nel PATH.
    echo        Ricerca nel percorso di installazione predefinito...
    echo.
    
    if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
        set "PS=%ProgramFiles%\PowerShell\7\pwsh.exe"
        echo        [OK] Trovato in: !PS!
    ) else if exist "%LocalAppData%\Microsoft\PowerShell\pwsh.exe" (
        set "PS=%LocalAppData%\Microsoft\PowerShell\pwsh.exe"
        echo        [OK] Trovato in: !PS!
    ) else (
        echo        [ERRORE] PowerShell 7 non trovato in nessun percorso.
        echo        ! Nessun problema! Uso PowerShell classico come fallback.
        set "PS=powershell"
    )
)

echo.
goto :AVVIO_SCRIPT

:: =====================================================
:: SEZIONE: Avvio script PowerShell
:: =====================================================
:AVVIO_SCRIPT
echo ------------------------------------------------------------
echo.
echo        Avvio di Manutenzione_PRO_MAX.ps1 ...
echo.

if "%scelta%"=="2" (
    echo        Modalita: AMMINISTRATORE
    echo        (Verra richiesta l elevazione dei privilegi)
    echo.
    %PS% -NoProfile -ExecutionPolicy Bypass -Command "Start-Process '%PS%' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0Manutenzione_PRO_MAX.ps1\"' -Verb RunAs"
) else (
    echo        Modalita: UTENTE
    echo.
    %PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manutenzione_PRO_MAX.ps1"
)

endlocal
