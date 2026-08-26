# ============================================================
# UPGRADE.psm1 - Gestion aggiornamenti
# Versione: 1.1.0 - AGGIUNTO SOLO EDGE
# ============================================================

function Test-WingetAvailable {
    try {
        $null = Get-Command winget -ErrorAction Stop
        $test = winget --version 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Winget non risponde" }
        return $true
    } catch {
        Log "[X] Winget non disponibile: $($_.Exception.Message)"
        Update-Status "[X] Winget non trovato" $warningColor
        Flush-LogBuffer; Pump-UI
        return $false
    }
}

function Do-Winget {
    if (Test-Cancel) { return }
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

# ===== UNICA NOVITÀ: EDGE =====
function Update-EdgeBrowser {
    if (Test-Cancel) { return }
    if (-not (Test-WingetAvailable)) { return }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] AGGIORNAMENTO EDGE"
    Log "==============================================================================================="
    Update-Status "[...] Edge..." $fgColor
    Flush-LogBuffer; Pump-UI
    
    # Versione attuale
    $verBefore = $null
    @("$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | ForEach-Object {
        if (-not $verBefore -and (Test-Path $_)) { $verBefore = (Get-Item $_).VersionInfo.FileVersion }
    }
    
    if ($verBefore) {
        Log "[i] Versione: $verBefore"
    } else {
        Log "[!] Edge non trovato"
        Log "==============================================================================================="
        Log ""
        Update-Status "[OK] Edge" $successColor
        Flush-LogBuffer; Pump-UI
        return
    }
    
    # Aggiorna con Winget (silenzioso per evitare popup)
    winget upgrade "Microsoft.Edge" --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    
    # Versione dopo
    $verAfter = $null
    @("$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | ForEach-Object {
        if (-not $verAfter -and (Test-Path $_)) { $verAfter = (Get-Item $_).VersionInfo.FileVersion }
    }
    
    if ($verBefore -eq $verAfter) {
        Log "[OK] Già aggiornato"
    } else {
        Log "[OK] Aggiornato: $verBefore → $verAfter"
    }
    
    Log "==============================================================================================="
    Log ""
    Update-Status "[OK] Edge" $successColor
    Flush-LogBuffer; Pump-UI
}
# ===== FINE NOVITÀ =====

function Do-StoreUpdate {
    if (Test-Cancel) { return }
    if (-not (Test-WingetAvailable)) { return }
    Update-Progress 30
    Update-Status "[...] Store..." $fgColor
    Flush-LogBuffer; Pump-UI
    Run-ProcessRealtime "winget" "upgrade --source msstore --all --accept-package-agreements --accept-source-agreements --include-unknown" "Store Update" 30 40
    
    if ($global:logBox.Text -match "Non è stato trovato alcun pacchetto installato corrispondente ai criteri di input") {
        $global:logBox.SuspendLayout()
        $global:logBox.SelectionStart = $global:logBox.TextLength
        $global:logBox.SelectionLength = 0
        $global:logBox.SelectionColor = $successColor
        $global:logBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
        $global:logBox.AppendText("`r`n[SUGGERIMENTO] CLICCA 'CONTROLLA AGGIORNAMENTI DISPONIBILI' NELLO STORE PER VERIFICARE MANUALMENTE.`r`n")
        $global:logBox.SelectionColor = $global:fgColor
        $global:logBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Regular)
        $global:logBox.ResumeLayout()
        $global:logBox.ScrollToCaret()
    }
    try { Start-Process "ms-windows-store://downloadsandupdates" -WindowStyle Hidden -ErrorAction SilentlyContinue } catch { }
    Log " [OK] Store in background."
    Set-StepProgress 100 30 40
    Update-Progress 100
    Update-Status "[OK] Store" $successColor
    Flush-LogBuffer; Pump-UI
}

function Do-SearchWU {
    if (Test-Cancel) { return }
    Log ""; Log "==============================================================================================="; Log "[>] RICERCA: Windows Update"; Log "==============================================================================================="
    Update-Progress 50
    Update-Status "[...] Ricerca WU..." $fgColor
    Flush-LogBuffer; Pump-UI
    if (-not $global:isAdmin) {
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
    if (Test-Cancel) { return }
    Log ""; Log "==============================================================================================="; Log "[>] INSTALLAZIONE: Windows Update"; Log "==============================================================================================="
    Update-Progress 70
    Update-Status "[...] Installazione WU..." $fgColor
    Flush-LogBuffer; Pump-UI
    if (-not $global:isAdmin) {
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
    if (Test-Cancel) { return }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] AGGIORNAMENTO DRIVER (WU + Winget)"
    Log "==============================================================================================="
    Update-Status "[...] Driver..." $accentColor
    Flush-LogBuffer; Pump-UI
    
    if (-not $global:isAdmin) {
        Log "[X] Richiesti privilegi admin per driver"
        Update-Status "[!] Admin richiesto" $warningColor
        Flush-LogBuffer; Update-Progress 100
        return
    }
    
    $wuDrivers = @()
    $wingetDrivers = @()
    
    # ================================================================
    # PARTE 1: RICERCA DRIVER VIA WINDOWS UPDATE
    # ================================================================
    Log "[1/2] Ricerca driver via Windows Update..."
    Flush-LogBuffer; Pump-UI
    
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $wuResult = $searcher.Search("IsInstalled=0 and Type='Driver'")
        Pump-UI
        
        if ($wuResult.Updates.Count -gt 0) {
            foreach ($d in $wuResult.Updates) {
                $wuDrivers += [PSCustomObject]@{
                    Source = "WU"
                    Title = $d.Title
                    Driver = $d
                }
            }
            Log "[OK] Windows Update: Trovati $($wuDrivers.Count) driver"
            foreach ($d in $wuDrivers) {
                Log "      → $($d.Title)"
                Pump-UI
            }
        } else {
            Log "[OK] Windows Update: Nessun driver disponibile"
        }
    } catch {
        Log "[!] Windows Update: $($_.Exception.Message)"
    }
    
    Log ""
    
    # ================================================================
    # PARTE 2: RICERCA DRIVER VIA WINGET
    # ================================================================
    Log "[2/2] Ricerca driver via Winget..."
    Flush-LogBuffer; Pump-UI
    
    if (Test-WingetAvailable) {
        try {
            $tempFile = "$env:TEMP\winget_drivers_$([guid]::NewGuid().ToString('N')).txt"
            $process = Start-Process -FilePath "winget" `
                -ArgumentList "list --upgrade-available --accept-source-agreements" `
                -NoNewWindow -Wait -PassThru `
                -RedirectStandardOutput $tempFile `
                -RedirectStandardError "$tempFile.err"
            
            $output = Get-Content $tempFile -ErrorAction SilentlyContinue
            
            # Filtra solo righe che sembrano driver
            foreach ($line in $output) {
                if ($line -and $line.Trim() -and 
                    $line -match "driver|Driver|GPU|NVIDIA|nvidia|AMD|amd|Intel|intel|Realtek|realtek|Audio|audio|Wireless|wireless|Bluetooth|bluetooth|Wi-Fi|LAN|Chipset|chipset|Graphics|graphics|Display|display|Network|network" -and
                    $line -notmatch "^---" -and
                    $line -notmatch "^Nome" -and
                    $line -notmatch "^Name" -and
                    $line -notmatch "Nessun aggiornamento" -and
                    $line -notmatch "non è stato trovato" -and
                    $line -notmatch "include-unknown") {
                    
                    # Estrai ID dal Winget (di solito è la seconda colonna)
                    $parts = $line -split "\s{2,}"
                    $id = if ($parts.Count -ge 2) { $parts[1].Trim() } else { $null }
                    
                    $wingetDrivers += [PSCustomObject]@{
                        Source = "Winget"
                        Title = $line.Trim()
                        Id = $id
                    }
                }
            }
            
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            Remove-Item "$tempFile.err" -Force -ErrorAction SilentlyContinue
            
            if ($wingetDrivers.Count -gt 0) {
                Log "[OK] Winget: Trovati $($wingetDrivers.Count) driver"
                foreach ($d in $wingetDrivers) {
                    Log "      → $($d.Title)"
                    Pump-UI
                }
            } else {
                Log "[OK] Winget: Nessun driver disponibile"
            }
        } catch {
            Log "[!] Winget: $($_.Exception.Message)"
        }
    } else {
        Log "[!] Winget: Non disponibile"
    }
    
    # ================================================================
    # PARTE 3: RIEPILOGO E SCELTA
    # ================================================================
    Log ""
    Log "==============================================================================================="
    Log "[RIEPILOGO DRIVER]"
    Log "==============================================================================================="
    Log ""
    Log "   Fonte          │ Quantità"
    Log "   ───────────────┼──────────"
    Log "   Windows Update │ $($wuDrivers.Count)"
    Log "   Winget         │ $($wingetDrivers.Count)"
    Log "   ───────────────┼──────────"
    Log "   TOTALE         │ $($wuDrivers.Count + $wingetDrivers.Count)"
    Log ""
    
    $totalDrivers = $wuDrivers.Count + $wingetDrivers.Count
    
    if ($totalDrivers -eq 0) {
        Log "[OK] Nessun driver da aggiornare - Sistema aggiornato!"
        Log "==============================================================================================="
        Log ""
        Update-Progress 100
        Update-Status "[OK] Driver aggiornati" $successColor
        Flush-LogBuffer; Pump-UI
        return
    }
    
    # Menu scelta
    $options = @()
    if ($wuDrivers.Count -gt 0) { $options += "Windows Update ($($wuDrivers.Count) driver)" }
    if ($wingetDrivers.Count -gt 0) { $options += "Winget ($($wingetDrivers.Count) driver)" }
    if ($wuDrivers.Count -gt 0 -and $wingetDrivers.Count -gt 0) { $options += "ENTRAMBI ($totalDrivers driver)" }
    $options += "Annulla"
    
    $optionsText = $options -join "`n"
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Trovati $totalDrivers driver aggiornabili:`n`nWindows Update: $($wuDrivers.Count)`nWinget: $($wingetDrivers.Count)`n`nScegliere fonte:",
        "Aggiornamento Driver",
        [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    # Mappa risposta
    # Yes = Prima opzione (WU se disponibile, altrimenti Winget)
    # No = Seconda opzione (Winget se disponibile, altrimenti WU)
    # Cancel = Annulla
    
    $installWU = $false
    $installWinget = $false
    
    if ($response -eq [System.Windows.Forms.DialogResult]::Cancel) {
        Log "[i] Operazione annullata dall'utente"
        Log "==============================================================================================="
        Log ""
        Update-Progress 100
        Update-Status "[OK] Driver" $successColor
        Flush-LogBuffer; Pump-UI
        return
    }
    
    if ($wuDrivers.Count -gt 0 -and $wingetDrivers.Count -gt 0) {
        # Entrambi disponibili
        if ($response -eq "Yes") { 
            $installWU = $true
            $installWinget = $true
            Log "[i] Scelta: ENTRAMBI"
        } elseif ($response -eq "No") {
            $installWinget = $true
            Log "[i] Scelta: Solo Winget"
        }
    } elseif ($wuDrivers.Count -gt 0) {
        # Solo WU
        if ($response -eq "Yes") {
            $installWU = $true
            Log "[i] Scelta: Windows Update"
        }
    } elseif ($wingetDrivers.Count -gt 0) {
        # Solo Winget
        if ($response -eq "Yes") {
            $installWinget = $true
            Log "[i] Scelta: Winget"
        }
    }
    
    Log ""
    
    # ================================================================
    # PARTE 4: INSTALLAZIONE WINDOWS UPDATE
    # ================================================================
    if ($installWU -and $wuDrivers.Count -gt 0) {
        Log "==============================================================================================="
        Log "[INSTALLAZIONE] Windows Update - $($wuDrivers.Count) driver"
        Log "==============================================================================================="
        Flush-LogBuffer; Pump-UI
        
        try {
            Log "[DL] Download driver in corso..."
            Flush-LogBuffer; Pump-UI
            
            $session = New-Object -ComObject Microsoft.Update.Session
            $downloader = $session.CreateUpdateDownloader()
            $downloader.Updates = $wuResult.Updates
            $downloadResult = $downloader.Download()
            
            if ($downloadResult.ResultCode -eq 2) {
                Log "[OK] Download completato"
                Log "[PKG] Installazione in corso..."
                Flush-LogBuffer; Pump-UI
                
                $installer = $session.CreateUpdateInstaller()
                $installer.Updates = $wuResult.Updates
                $installResult = $installer.Install()
                
                Log ""
                Log "[RISULTATI WU]:"
                for ($i = 0; $i -lt $wuResult.Updates.Count; $i++) {
                    $res = $installResult.GetUpdateResult($i)
                    $status = if ($res.ResultCode -eq 2) { "[OK]" } else { "[X] Codice: $($res.ResultCode)" }
                    Log "   $status $($wuResult.Updates.Item($i).Title)"
                    Pump-UI
                }
                
                if ($installResult.RebootRequired) {
                    Log ""
                    Log "[!] RIAVVIO NECESSARIO per attivare i driver WU"
                }
            } else {
                Log "[X] Errore download (codice: $($downloadResult.ResultCode))"
                Log "[!] Il driver potrebbe non essere compatibile o richiedere approvazione manuale"
            }
        } catch {
            Log "[X] Errore installazione WU: $($_.Exception.Message)"
        }
        
        Log ""
    }
    
    # ================================================================
    # PARTE 5: INSTALLAZIONE WINGET
    # ================================================================
    if ($installWinget -and $wingetDrivers.Count -gt 0) {
        Log "==============================================================================================="
        Log "[INSTALLAZIONE] Winget - $($wingetDrivers.Count) driver"
        Log "==============================================================================================="
        Flush-LogBuffer; Pump-UI
        
        # Installa ogni driver con ID valido
        $installed = 0
        $failed = 0
        
        foreach ($d in $wingetDrivers) {
            if (Test-Cancel) { break }
            
            if ($d.Id) {
                Log "[i] Installazione: $($d.Id)"
                Flush-LogBuffer; Pump-UI
                
                $output = winget upgrade $d.Id --accept-package-agreements --accept-source-agreements --silent 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Log "[OK] Installato: $($d.Id)"
                    $installed++
                } elseif ($LASTEXITCODE -eq -1978335189) {
                    Log "[OK] Già aggiornato: $($d.Id)"
                    $installed++
                } else {
                    Log "[!] Errore ($LASTEXITCODE): $($d.Id)"
                    $failed++
                }
                Pump-UI
            }
        }
        
        Log ""
        Log "[RIEPILOGO WINGET]: Successo: $installed | Errori: $failed"
        Log ""
    }
    
    # ================================================================
    # PARTE 6: FINALE
    # ================================================================
    Log "==============================================================================================="
    Log "[OK] Aggiornamento driver completato"
    Log "==============================================================================================="
    Log ""
    Update-Progress 100
    Update-Status "[OK] Driver" $successColor
    Flush-LogBuffer; Pump-UI
}


function Do-FullUpdate {
    param([switch]$Force)
    if (Test-Cancel) { return }
    Log ""; Log "==============================================================================================="; if ($Force) { Log "[>] FULL UPDATE FORZATO" } else { Log "[>] FULL UPDATE - AGGIORNAMENTO COMPLETO" }; Log "==============================================================================================="
    Update-Status "[...] Verifica aggiornamento completo..." $infoColor
    Flush-LogBuffer; Pump-UI
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        if (-not $Force) {
            $remoteVersionUrl = $global:githubRawUrl + $global:versionFileName
            $remoteVersion = (Invoke-WebRequest -Uri $remoteVersionUrl -UseBasicParsing -TimeoutSec 20).Content.Trim()
            Log "[OK] Versione locale: $($global:currentVersion)"; Log "[OK] Versione remota: $remoteVersion"
            if ($remoteVersion -eq $global:currentVersion) {
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
        
        $localDir = $global:scriptRoot
        if (-not $localDir -or -not (Test-Path $localDir)) {
            Log "[X] Impossibile determinare la cartella di esecuzione (scriptRoot non valido)."
            Update-Status "[X] Errore percorso" $exitColor
            Update-Progress 100; return
        }
        
        $backupDir = Join-Path $localDir "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        Log "[OK] Backup creato in: $backupDir"

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
        
        $apiUrl = "https://api.github.com/repos/$($global:repoOwner)/$($global:repoName)/contents/"
        Log "[>] Download ricorsivo della repository..."
        Invoke-GitHubDownloadRecursive -ApiUrl $apiUrl -LocalPath $localDir
        
        Log ""; Log "==============================================================================================="; Log "[OK] FULL UPDATE COMPLETATO!"; Log "     Backup salvato in: $backupDir"; Log "==============================================================================================="
        Update-Progress 100
        Update-Status "[OK] Full Update completato!" $successColor
        Flush-LogBuffer; Pump-UI
        
        $response = [System.Windows.Forms.MessageBox]::Show("Aggiornamento completato!`nRiavviare lo script con la nuova versione?", "Riavvio necessario", "YesNo", "Question")
        if ($response -eq "Yes") {
            $exe = if ($global:isPwsh7) { "pwsh.exe" } else { "powershell.exe" }
            $mainScriptPath = Join-Path $global:scriptRoot $global:scriptFileName
            if (Test-Path $mainScriptPath) {
                Start-Process -FilePath $exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$mainScriptPath`"" -WindowStyle Normal
                $global:isClosing = $true
                $global:form.Close()
            } else {
                Log "[X] Script principale non trovato: $mainScriptPath"
                Update-Status "[X] Errore riavvio" $exitColor
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
    if (Test-Cancel) { return }
    Log ""; Log "##################################################################################################"; Log "# UPGRADE PROGRAMMI #"; Log "##################################################################################################"; Log ""
    Update-Progress 0
    Flush-LogBuffer; Pump-UI
    Do-Winget
    if (Test-Cancel) { return }
    Update-EdgeBrowser  # ← AGGIUNTO
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
    'Update-EdgeBrowser',  # ← AGGIUNTO
    'Do-StoreUpdate',
    'Do-SearchWU',
    'Do-InstallWU',
    'Do-DriverUpdate',
    'Do-FullUpdate',
    'Do-RunAll',
    'Test-WingetAvailable'  # ← AGGIUNTO
)
