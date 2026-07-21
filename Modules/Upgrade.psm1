# ============================================================
# UPGRADE.psm1 - Gestione aggiornamenti (Winget, Store, WU, Driver, FullUpdate, RunAll)
# Versione: 1.0.0
# ============================================================

function Do-Winget {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not (Test-WingetAvailable)) { return }
    Update-Progress 10
    Update-Status "[...] Winget..." $fgColor
    Flush-LogBuffer; Pump-UI
    Run-ProcessRealtime "winget" "upgrade --all --force --accept-package-agreements --accept-source-agreements --include-unknown" "Winget Upgrade" 10 25
    Set-StepProgress 100 10 25
    Update-Progress 100
    Update-Status "[OK] Winget" $successColor
    Flush-LogBuffer; Pump-UI
}

function Do-StoreUpdate {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not (Test-WingetAvailable)) { return }
    Update-Progress 30
    Update-Status "[...] Store..." $fgColor
    Flush-LogBuffer; Pump-UI
    Run-ProcessRealtime "winget" "upgrade --source msstore --all --accept-package-agreements --accept-source-agreements --include-unknown" "Store Update" 30 40
    if ($script:logBox.Text -match "Non è stato trovato alcun pacchetto installato corrispondente ai criteri di input") {
        $script:logBox.SuspendLayout()
        $script:logBox.SelectionStart = $script:logBox.TextLength
        $script:logBox.SelectionLength = 0
        $script:logBox.SelectionColor = $successColor
        $script:logBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
        $script:logBox.AppendText("`r`n[SUGGERIMENTO] CLICCA 'CONTROLLA AGGIORNAMENTI DISPONIBILI' NELLO STORE PER VERIFICARE MANUALMENTE.`r`n")
        $script:logBox.SelectionColor = $script:logBox.ForeColor
        $script:logBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Regular)
        $script:logBox.ResumeLayout()
        $script:logBox.ScrollToCaret()
    }
    try { Start-Process "ms-windows-store://downloadsandupdates" -WindowStyle Hidden -ErrorAction SilentlyContinue } catch { }
    Log " [OK] Store in background."
    Set-StepProgress 100 30 40
    Update-Progress 100
    Update-Status "[OK] Store" $successColor
    Flush-LogBuffer; Pump-UI
}

function Do-SearchWU {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Log ""; Log "==============================================================================================="; Log "[>] RICERCA: Windows Update"; Log "==============================================================================================="
    Update-Progress 50
    Update-Status "[...] Ricerca WU..." $fgColor
    Flush-LogBuffer; Pump-UI
    if (-not $isAdmin) {
        Log "[!] Servono privilegi admin."
        Update-Status "[!] Privilegi insufficienti" $warningColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        Pump-UI
        $result = $searcher.Search("IsInstalled=0 and Type='Software'")
        Pump-UI
        if ($result.Updates.Count -gt 0) {
            Log "[OK] Trovati $($result.Updates.Count):"
            for ($i = 0; $i -lt $result.Updates.Count; $i++) {
                $u = $result.Updates.Item($i)
                $kb = ""
                if ($u.KBArticleIDs.Count -gt 0) { $kb = "KB$($u.KBArticleIDs.Item(0)) - " }
                Log " $($i+1). $kb$($u.Title)"
            }
            $script:pendingUpdates = $result
        } else {
            Log "[OK] Nessun aggiornamento."
            $script:pendingUpdates = $null
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Ricerca completata" $successColor
    Flush-LogBuffer; Pump-UI
}

function Do-InstallWU {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Log ""; Log "==============================================================================================="; Log "[>] INSTALLAZIONE: Windows Update"; Log "==============================================================================================="
    Update-Progress 70
    Update-Status "[...] Installazione WU..." $fgColor
    Flush-LogBuffer; Pump-UI
    if (-not $isAdmin) {
        Log "[X] Servono privilegi admin."
        Update-Status "[!] Privilegi insufficienti" $warningColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    try {
        if (-not $script:pendingUpdates) {
            $session = New-Object -ComObject Microsoft.Update.Session
            $script:pendingUpdates = $session.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Software'")
            Pump-UI
        }
        $sr = $script:pendingUpdates
        if ($sr.Updates.Count -eq 0) {
            Log "[OK] Nessun aggiornamento."
        } else {
            Set-StepProgress 10 70 85
            $dlC = New-Object -ComObject Microsoft.Update.UpdateColl
            for ($i = 0; $i -lt $sr.Updates.Count; $i++) {
                $u = $sr.Updates.Item($i)
                if (-not $u.EulaAccepted) { $u.AcceptEula() }
                if (-not $u.IsDownloaded) { $dlC.Add($u) | Out-Null }
            }
            if ($dlC.Count -gt 0) {
                Log " [DL] Download..."
                Flush-LogBuffer; Pump-UI
                $session = New-Object -ComObject Microsoft.Update.Session
                $dl = $session.CreateUpdateDownloader()
                $dl.Updates = $dlC
                $dl.Download() | Out-Null
                Pump-UI
                Set-StepProgress 50 70 85
            }
            $iC = New-Object -ComObject Microsoft.Update.UpdateColl
            for ($i = 0; $i -lt $sr.Updates.Count; $i++) {
                $u = $sr.Updates.Item($i)
                if ($u.IsDownloaded) { $iC.Add($u) | Out-Null }
            }
            if ($iC.Count -gt 0) {
                Log " [PKG] Installazione..."
                Flush-LogBuffer; Pump-UI
                $session = New-Object -ComObject Microsoft.Update.Session
                $inst = $session.CreateUpdateInstaller()
                $inst.Updates = $iC
                Pump-UI
                $ir = $inst.Install()
                Pump-UI
                for ($i = 0; $i -lt $iC.Count; $i++) {
                    $rc = $ir.GetUpdateResult($i).ResultCode
                    $st = switch ($rc) { 2 { "[OK]" } 3 { "[OK*]" } 4 { "[X]" } 5 { "[!]" } default { "[?]" } }
                    Log " $st $($iC.Item($i).Title)"
                    Set-StepProgress ([Math]::Round((($i + 1) / $iC.Count) * 100)) 70 85
                    Pump-UI
                }
                if ($ir.RebootRequired) {
                    Log ""
                    Log "[!] RIAVVIO NECESSARIO."
                }
            }
        }
        $script:pendingUpdates = $null
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Set-StepProgress 100 70 85
    Update-Progress 100
    Update-Status "[OK] Installazione completata" $successColor
    Flush-LogBuffer; Pump-UI
}

function Do-DriverUpdate {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Driver..." $accentColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] AGGIORNAMENTO DRIVER"; Log "==============================================================================================="
    if (-not $isAdmin) {
        Log "[X] Richiesti privilegi admin per driver"
        Update-Status "[!] Admin richiesto" $warningColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    try {
        Log "[>] Ricerca driver via Windows Update..."
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $driverResult = $searcher.Search("IsInstalled=0 and Type='Driver'")
        if ($driverResult.Updates.Count -gt 0) {
            Log "[OK] Trovati $($driverResult.Updates.Count) aggiornamenti driver:"
            foreach ($d in $driverResult.Updates) { Log "   - $($d.Title)" }
            $response = [System.Windows.Forms.MessageBox]::Show("Installare $($driverResult.Updates.Count) aggiornamenti driver?", "Driver Update", "YesNo", "Question")
            if ($response -eq "Yes") {
                Log "[DL] Download driver in corso..."
                $downloader = $session.CreateUpdateDownloader()
                $downloader.Updates = $driverResult.Updates
                $downloadResult = $downloader.Download()
                if ($downloadResult -ne $null -and $downloadResult.ResultCode -eq 2) {
                    Log "[OK] Download completato. Installazione in corso..."
                    $installer = $session.CreateUpdateInstaller()
                    $installer.Updates = $driverResult.Updates
                    $installResult = $installer.Install()
                    if ($installResult -ne $null) {
                        Log "[OK] Installazione driver completata."
                        if ($installResult.RebootRequired) { Log "[!] RIAVVIO NECESSARIO." }
                    } else {
                        Log "[X] Errore durante l'installazione dei driver."
                    }
                } else {
                    $resultCode = if ($downloadResult) { $downloadResult.ResultCode } else { "N/A" }
                    Log "[X] Errore download driver (codice: $resultCode)"
                    Log "[!] Il driver potrebbe non essere compatibile o richiedere approvazione manuale."
                }
            }
        } else {
            Log "[OK] Nessun aggiornamento driver disponibile"
        }
    } catch {
        Log "[X] Errore aggiornamento driver: $($_.Exception.Message)"
        if ($_.Exception.Message -match "Index was outside the bounds") {
            Log "[!] Errore durante l'elaborazione del driver. Riprova o installa manualmente."
        }
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Driver" $successColor
    Flush-LogBuffer; Pump-UI
}

function Do-FullUpdate {
    param([switch]$Force)
    if ($script:isClosing -or (Test-Cancel)) { return }
    Log ""; Log "==============================================================================================="; if ($Force) { Log "[>] FULL UPDATE FORZATO" } else { Log "[>] FULL UPDATE - AGGIORNAMENTO COMPLETO" }; Log "==============================================================================================="
    Update-Status "[...] Verifica aggiornamento completo..." $infoColor
    Flush-LogBuffer; Pump-UI
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        if (-not $Force) {
            $remoteVersionUrl = $script:githubRawUrl + $script:versionFileName
            $remoteVersion = (Invoke-WebRequest -Uri $remoteVersionUrl -UseBasicParsing -TimeoutSec 20).Content.Trim()
            Log "[OK] Versione locale: $($script:currentVersion)"; Log "[OK] Versione remota: $remoteVersion"
            if ($remoteVersion -eq $script:currentVersion) {
                Log "[OK] Tutti i file sono già aggiornati."
                Update-Status "[OK] Già aggiornato" $successColor
                Update-Progress 100
                Flush-LogBuffer; Pump-UI
                return
            }
            Log "[!] Nuova versione completa disponibile!"
        } else {
            Log "[i] Modalità forzata: download di tutti i file indipendentemente dalla versione."
        }
        if (-not $Force) {
            $response = [System.Windows.Forms.MessageBox]::Show("Versione $remoteVersion disponibile.`n`nQuesta operazione aggiornerà TUTTI i file nella repository (escluse Prompt e Docs).`n`nProcedere?", "Full Update Disponibile", "YesNo", "Question")
            if ($response -ne "Yes") { Log "[i] Full Update annullato."; Update-Progress 100; return }
        }
        $localDir = Split-Path -Parent $PSCommandPath
        if (-not $localDir) {
            Log "[X] Impossibile determinare la cartella di esecuzione."
            Update-Status "[X] Errore percorso" $exitColor
            Update-Progress 100; return
        }
        $backupDir = Join-Path $localDir "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        Log "[OK] Backup creato in: $backupDir"

        # Copia i file escludendo le cartelle che iniziano con "backup"
        Get-ChildItem -Path $localDir -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.FullName -match [regex]::Escape($backupDir)) { return }
            $relativePath = $_.FullName.Substring($localDir.Length + 1)
            $skip = $false
            $segments = $relativePath -split "\\"
            foreach ($seg in $segments) {
                if ($seg -match '^backup') {
                    $skip = $true
                    break
                }
            }
            if ($skip) { return }
            $backupFile = Join-Path $backupDir $relativePath
            if ($_.PSIsContainer) {
                New-Item -ItemType Directory -Force -Path $backupFile -ErrorAction SilentlyContinue | Out-Null
            } else {
                $backupParent = Split-Path $backupFile -Parent
                if (-not (Test-Path $backupParent)) {
                    New-Item -ItemType Directory -Force -Path $backupParent | Out-Null
                }
                Copy-Item -Path $_.FullName -Destination $backupFile -Force -ErrorAction SilentlyContinue
            }
        }
        Log "[OK] Backup di tutti i file completato."
        $apiUrl = "https://api.github.com/repos/$($script:repoOwner)/$($script:repoName)/contents/"
        Log "[>] Download ricorsivo della repository..."
        Invoke-GitHubDownloadRecursive -ApiUrl $apiUrl -LocalPath $localDir
        Log ""; Log "==============================================================================================="; Log "[OK] FULL UPDATE COMPLETATO!"; Log "     Backup salvato in: $backupDir"; Log "==============================================================================================="
        Update-Progress 100
        Update-Status "[OK] Full Update completato!" $successColor
        Flush-LogBuffer; Pump-UI
        $response = [System.Windows.Forms.MessageBox]::Show("Aggiornamento completato!`nRiavviare lo script con la nuova versione?", "Riavvio necessario", "YesNo", "Question")
        if ($response -eq "Yes") {
            $exe = if ($isPwsh7) { "pwsh.exe" } else { "powershell.exe" }
            $localScriptPath = $PSCommandPath
            if ($localScriptPath -and (Test-Path $localScriptPath)) {
                Start-Process $exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$localScriptPath`""
                $script:isClosing = $true
                $script:form.Close()
            }
        }
    } catch {
        Log "[X] Errore Full Update: $($_.Exception.Message)"
        Update-Status "[X] Errore" $exitColor
        Update-Progress 100
        Flush-LogBuffer; Pump-UI
    }
}

function Do-RunAll {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Log ""; Log "##################################################################################################"; Log "# UPGRADE PROGRAMMI #"; Log "##################################################################################################"; Log ""
    Update-Progress 0
    Flush-LogBuffer; Pump-UI
    Do-Winget
    if (Test-Cancel) { return }
    Do-StoreUpdate
    if (Test-Cancel) { return }
    Do-SearchWU
    if (Test-Cancel) { return }
    Do-InstallWU
    if (Test-Cancel) { return }
    Do-CleanTemp
    if (Test-Cancel) { return }
    Do-FlushDNS
    if (Test-Cancel) { return }
    Update-Progress 100
    Log ""; Log "##################################################################################################"; Log "# COMPLETATO #"; Log "##################################################################################################"; Log ""
    Update-Status "[OK] Completato!" $successColor
    Flush-LogBuffer; Pump-UI
}

Export-ModuleMember -Function @(
    'Do-Winget',
    'Do-StoreUpdate',
    'Do-SearchWU',
    'Do-InstallWU',
    'Do-DriverUpdate',
    'Do-FullUpdate',
    'Do-RunAll'
)