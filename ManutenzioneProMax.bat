@echo off
setlocal enabledelayedexpansion

color 0A

:: =====================================================
:: Controlla se siamo in fase di riavvio post-installazione
:: =====================================================
if "%~1"=="--post-install" goto :POST_INSTALL_CHECK

:: =====================================================
:: HEADER PRINCIPALE E SCELTA CON VALIDAZIONE
:: =====================================================
:MENU_PRINCIPALE
cls
echo.
echo ============================================================
echo.
echo              MANUTENZIONE PRO MAX Peters
echo.
echo ============================================================
echo.
echo        [1]  Esegui come UTENTE
echo        [2]  Esegui come AMMINISTRATORE
echo.
echo ------------------------------------------------------------
echo.
set /p scelta="   Scegli (1 o 2): "

:: Validazione input
if "%scelta%"=="1" goto :CONTINUA
if "%scelta%"=="2" goto :CONTINUA

:: Input non valido
echo.
echo ============================================================
echo.
echo        [ERRORE] Scelta non valida!
echo.
echo        Puoi inserire solo 1 o 2.
echo        Premi un tasto per riprovare...
echo.
echo ============================================================
echo.
pause >nul
goto :MENU_PRINCIPALE

:CONTINUA

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
    
    :: Assegna un titolo univoco a questa finestra
    set "WIN_TITLE=Manutenzione_Install_%random%"
    title %WIN_TITLE%
    
    set "BAT_PATH=%~f0"
    
    echo        Preparazione al riavvio...
    timeout /t 3 /nobreak >nul
    
    :: CORRETTO: Sintassi pulita per PowerShell (usata la stringa letterale singola)
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '!BAT_PATH!' -ArgumentList '--post-install','!scelta!','!WIN_TITLE!' -Verb RunAs"
    
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
echo              Manutenzione PRO MAX
echo.
echo ============================================================
echo.

:: Recupera la scelta originale e il titolo della finestra precedente
set "scelta=%~2"
set "WIN_TITLE=%~3"

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

:: Chiudi la finestra precedente usando il suo titolo univoco
if not "%WIN_TITLE%"=="" (
    echo        Chiusura finestra precedente...
    taskkill /FI "WINDOWTITLE eq %WIN_TITLE%" /F >nul 2>&1
    timeout /t 1 /nobreak >nul
    echo        [OK] Finestra precedente chiusa.
    echo.
)

goto :AVVIO_SCRIPT

:: =====================================================
:: SEZIONE: Avvio script PowerShell - ESECUZIONE SINGOLA
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
    
    :: Crea file batch temporaneo
    set "TEMP_BAT=%temp%\manutenzione_admin_%random%.bat"
    echo @echo off > "!TEMP_BAT!"
    echo "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manutenzione_PRO_MAX.ps1" >> "!TEMP_BAT!"
    
    :: CORRETTO: Rimosse le virgolette strane \"' ... '\" che generavano l'errore
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '!TEMP_BAT!' -Verb RunAs"
    
    :: Elimina il file temp e chiudi questo prompt
    ping -n 2 127.0.0.1 >nul
    del "!TEMP_BAT!" >nul 2>&1
    exit /b
    
) else (
    echo        Modalita: UTENTE
    echo.
    "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manutenzione_PRO_MAX.ps1"
)

endlocal
