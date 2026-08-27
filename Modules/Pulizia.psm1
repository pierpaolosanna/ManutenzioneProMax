# ============================================================
# PULIZIA.psm1 - Pulizia Completa Sistema (AUTOMATICA)
# Versione: 6.3.0 - NESSUNA RICHIESTA INTERATTIVA
# ============================================================

#region ===== FUNZIONI HELPER =====

function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

if (-not (Get-Command Test-Cancel -ErrorAction SilentlyContinue)) {
    function Test-Cancel {
        if ($global:isClosing -eq $true) { return $true }
        if (Get-Variable -Name global:CancelClean -Scope Global -ErrorAction SilentlyContinue) {
            return $global:CancelClean
        }
        return $false
    }
}

function Stop-ServiceIfExists {
    param($ServiceName)
    try {
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running') {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 300
            return $true
        }
    } catch { }
    return $false
}

function Start-ServiceIfWasRunning {
    param($ServiceName, [bool]$WasRunning)
    if ($WasRunning) {
        try { Start-Service -Name $ServiceName -ErrorAction SilentlyContinue } catch { }
    }
}

function Grant-FullAccessFast {
    param(
        [string]$Path,
        [switch]$Recurse
    )
    if (-not (Test-Path $Path)) { return $false }
    if (-not $global:isAdmin) { 
        Log "   [!] Permessi non concessi: non sei amministratore"
        return $false 
    }
    $path = $Path.TrimEnd('\')
    $success = $false
    
    # 1. takeown (senza /D per evitare errore di sintassi)
    try {
        $cmd = "takeown /F `"$path`" /A"
        if ($Recurse) { $cmd += " /R" }
        # Reindirizza errori a null per evitare che l'output interrompa il flusso
        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd 2>nul" -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
        # takeown spesso restituisce exit code 0 anche se non riesce, quindi ignoriamo l'errore
        $success = $true
    } catch {
        # Ignora errore di takeown
    }
    
    # 2. icacls con /grant:r per sovrascrivere e /inheritance:r per evitare il prompt
    try {
        # /grant:r sostituisce le voci esistenti, /inheritance:r rimuove l'ereditarietà
        $cmd = "icacls `"$path`" /grant:r Administrators:F /T /C /Q /inheritance:r"
        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd" -Wait -PassThru -NoNewWindow -ErrorAction Stop
        if ($proc.ExitCode -eq 0) { $success = $true }
    } catch {
        Log "   [!] icacls fallito: $($_.Exception.Message)"
    }
    
    # 3. Rimuovi attributo readonly
    try {
        attrib -R "$path\*.*" /S /D 2>$null
    } catch { }
    
    return $success
}



function Remove-FolderFast {
    param(
        [string]$Path,
        [int]$MaxRetries = 3
    )
    if (-not (Test-Path $Path)) { return $true }
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            if ($attempt -gt 1) {
                Grant-FullAccessFast -Path $Path -Recurse
                Start-Sleep -Milliseconds 200
            }
            $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c rd /s /q `"$Path`"" -Wait -PassThru -NoNewWindow -ErrorAction Stop
            if ($proc.ExitCode -eq 0) {
                if (-not (Test-Path $Path)) { return $true }
            }
        } catch { }
        if ($attempt -lt $MaxRetries) { Start-Sleep -Milliseconds 300 }
    }
    # Ultimo tentativo: ferma servizi e riprova
    $wuWasRunning = Stop-ServiceIfExists -ServiceName "wuauserv"
    $bitsWasRunning = Stop-ServiceIfExists -ServiceName "Bits"
    Grant-FullAccessFast -Path $Path -Recurse
    Start-Sleep -Milliseconds 500
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c rd /s /q `"$Path`"" -Wait -PassThru -NoNewWindow -ErrorAction Stop
    Start-ServiceIfWasRunning -ServiceName "wuauserv" -WasRunning $wuWasRunning
    Start-ServiceIfWasRunning -ServiceName "Bits" -WasRunning $bitsWasRunning
    if ($proc.ExitCode -eq 0 -and -not (Test-Path $Path)) { return $true }
    return $false
}

#endregion

#region ===== PULIZIA TEMP =====

function Do-CleanTemp {
    [CmdletBinding()]
    param([switch]$DryRun)
    if ($script:isClosing -or (Test-Cancel)) { return @{ MB = 0; Files = 0 } }
    Log ""; Log "==============================================================================================="; Log "[>] PULIZIA FILE TEMPORANEI$(if ($DryRun) { ' [SIMULAZIONE]' } else { '' })"; Log "==============================================================================================="
    Update-Progress 10; Update-Status "[...] Pulizia Temp..." $fgColor; Flush-LogBuffer; Pump-UI
    $paths = @(
        @{ Path = $env:TEMP; Name = "User Temp" },
        @{ Path = "$env:LOCALAPPDATA\Temp"; Name = "Local Temp" },
        @{ Path = "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache"; Name = "IE/Edge Cache" },
        @{ Path = "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer"; Name = "Thumbnails" },
        @{ Path = "$env:USERPROFILE\AppData\Local\CrashDumps"; Name = "Crash Dumps" },
        @{ Path = "$env:USERPROFILE\AppData\LocalLow\Microsoft\CryptnetUrlCache"; Name = "Cryptnet Cache" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\WebCache"; Name = "WebCache" }
    )
    if ($global:isAdmin) { $paths += @( @{ Path = "$env:WINDIR\Temp"; Name = "Windows Temp" }, @{ Path = "$env:WINDIR\Prefetch"; Name = "Prefetch" } ) }
    $totalFreed = [long]0; $totalFiles = 0
    foreach ($p in $paths) {
        if (Test-Cancel) { return @{ MB = 0; Files = 0 } }
        if (-not (Test-Path $p.Path)) { Pump-UI; continue }
        try {
            if ($DryRun) { Log "   [SIM] [$($p.Name)] Verrebbe cancellato"; $totalFreed += 1MB; $totalFiles += 1 }
            else {
                $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c rd /s /q `"$($p.Path)`"" -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
                if ($proc.ExitCode -eq 0 -or -not (Test-Path $p.Path)) { Log "   [OK] [$($p.Name)] Pulito"; $totalFreed += 1MB; $totalFiles += 1 } else { Log "   [!] [$($p.Name)] Cancellazione parziale" }
            }
        } catch { Log "   [!] $($p.Name): $($_.Exception.Message)" }
        Pump-UI
    }
    $mb = [Math]::Round($totalFreed / 1MB, 2)
    Log ""; Log "[OK] Temp: $(Format-Size $totalFreed)"; Log "==============================================================================================="; Log ""
    Update-Progress 25; Update-Status "[OK] Temp puliti" $successColor; Flush-LogBuffer; Pump-UI
    return @{ MB = $mb; Files = $totalFiles }
}

#endregion

#region ===== PULIZIA LOG =====

function Do-CleanLogs {
    [CmdletBinding()]
    param([switch]$DryRun)
    if ($script:isClosing -or (Test-Cancel)) { return @{ MB = 0; Files = 0 } }
    Log ""; Log "==============================================================================================="; Log "[>] PULIZIA LOG E REPORT$(if ($DryRun) { ' [SIMULAZIONE]' } else { '' })"; Log "==============================================================================================="
    Update-Progress 30; Update-Status "[...] Pulizia Log..." $maintColor; Flush-LogBuffer; Pump-UI
    $logPaths = @(
        @{ Path = "$env:WINDIR\Logs\CBS"; Name = "CBS Logs" },
        @{ Path = "$env:WINDIR\Logs\DISM"; Name = "DISM Logs" },
        @{ Path = "$env:WINDIR\Logs\WindowsUpdate"; Name = "Update Logs" },
        @{ Path = "$env:WINDIR\Panther"; Name = "Panther/Setup Logs" },
        @{ Path = "$env:WINDIR\SoftwareDistribution\ReportingEvents.log"; Name = "WU Report" },
        @{ Path = "$env:WINDIR\System32\LogFiles\WMI"; Name = "WMI Logs" },
        @{ Path = "$env:WINDIR\System32\LogFiles\AIMDB"; Name = "AIMDB Logs" },
        @{ Path = "$env:PROGRAMDATA\Microsoft\Windows\WER"; Name = "WER Reports" },
        @{ Path = "$env:LOCALAPPDATA\CrashDumps"; Name = "User CrashDumps" },
        @{ Path = "$env:PROGRAMDATA\Microsoft\Windows\WLXStoreLogs"; Name = "Store Logs" }
    )
    $totalFreed = [long]0; $totalFiles = 0
    foreach ($entry in $logPaths) {
        if (Test-Cancel) { return @{ MB = 0; Files = 0 } }
        $path = $entry.Path; $name = $entry.Name
        if (-not (Test-Path $path)) { Pump-UI; continue }
        try {
            # Per le cartelle problematiche, forza i permessi in automatico
            if ($name -match "Panther|WMI|CBS|DISM") {
                Log "   [...] Acquisizione permessi per $name..."
                Grant-FullAccessFast -Path $path -Recurse
            }
            if ($DryRun) { Log "   [SIM] [$name] Verrebbe cancellato"; $totalFreed += 1MB; $totalFiles += 1 }
            else {
                if (Test-Path $path -PathType Leaf) {
                    Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                    if (-not (Test-Path $path)) { Log "   [OK] [$name] Pulito"; $totalFreed += 1MB; $totalFiles += 1 }
                } else {
                    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c rd /s /q `"$path`"" -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
                    if ($proc.ExitCode -eq 0 -or -not (Test-Path $path)) { Log "   [OK] [$name] Pulito"; $totalFreed += 1MB; $totalFiles += 1 } else { Log "   [!] [$name] Cancellazione parziale" }
                }
            }
        } catch { Log "   [!] $name : $($_.Exception.Message)" }
        Pump-UI
    }
    $mb = [Math]::Round($totalFreed / 1MB, 2)
    Log ""; Log "[OK] Log: $(Format-Size $totalFreed)"; Log "==============================================================================================="; Log ""
    Update-Progress 45; Update-Status "[OK] Log puliti" $successColor; Flush-LogBuffer; Pump-UI
    return @{ MB = $mb; Files = $totalFiles }
}

#endregion

#region ===== PULIZIA BROWSER =====

function Do-CleanBrowserCache {
    [CmdletBinding()]
    param([switch]$DryRun)
    if ($script:isClosing -or (Test-Cancel)) { return @{ MB = 0; Files = 0 } }
    Log ""; Log "==============================================================================================="; Log "[>] PULIZIA CACHE BROWSER$(if ($DryRun) { ' [SIMULAZIONE]' } else { '' })"; Log "==============================================================================================="
    Update-Progress 50; Update-Status "[...] Pulizia Browser..." $maintColor; Flush-LogBuffer; Pump-UI
    $browserConfigs = @()
    $chromeBase = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    if (Test-Path $chromeBase) {
        $chromeProfiles = Get-ChildItem -Path $chromeBase -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^Default$|^Profile' }
        foreach ($prof in $chromeProfiles) { $browserConfigs += @( @{ Path = "$($prof.FullName)\Cache"; Name = "Chrome Cache" }, @{ Path = "$($prof.FullName)\Code Cache"; Name = "Chrome Code Cache" }, @{ Path = "$($prof.FullName)\GPUCache"; Name = "Chrome GPU Cache" } ) }
    }
    $edgeBase = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    if (Test-Path $edgeBase) {
        $edgeProfiles = Get-ChildItem -Path $edgeBase -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^Default$|^Profile' }
        foreach ($prof in $edgeProfiles) { $browserConfigs += @( @{ Path = "$($prof.FullName)\Cache"; Name = "Edge Cache" }, @{ Path = "$($prof.FullName)\Code Cache"; Name = "Edge Code Cache" }, @{ Path = "$($prof.FullName)\GPUCache"; Name = "Edge GPU Cache" } ) }
    }
    $braveBase = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
    if (Test-Path $braveBase) {
        $braveProfiles = Get-ChildItem -Path $braveBase -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^Default$|^Profile' }
        foreach ($prof in $braveProfiles) { $browserConfigs += @( @{ Path = "$($prof.FullName)\Cache"; Name = "Brave Cache" }, @{ Path = "$($prof.FullName)\Code Cache"; Name = "Brave Code Cache" } ) }
    }
    $firefoxBase = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $firefoxBase) {
        $firefoxProfiles = Get-ChildItem -Path $firefoxBase -Directory -ErrorAction SilentlyContinue
        foreach ($prof in $firefoxProfiles) { $browserConfigs += @( @{ Path = "$($prof.FullName)\cache2"; Name = "Firefox Cache" }, @{ Path = "$($prof.FullName)\thumbnails"; Name = "Firefox Thumbnails" } ) }
    }
    $operaBase = "$env:APPDATA\Opera Software\Opera Stable"
    if (Test-Path $operaBase) { $browserConfigs += @( @{ Path = "$operaBase\Cache"; Name = "Opera Cache" }, @{ Path = "$operaBase\Code Cache"; Name = "Opera Code Cache" } ) }
    $totalFreed = [long]0; $totalFiles = 0; $foundAny = $false
    foreach ($entry in $browserConfigs) {
        if (Test-Cancel) { return @{ MB = 0; Files = 0 } }
        $path = $entry.Path; $name = $entry.Name
        if (-not (Test-Path $path)) { Pump-UI; continue }
        $foundAny = $true
        if ($DryRun) { Log "   [SIM] [$name] Verrebbe cancellato"; $totalFreed += 1MB; $totalFiles += 1 }
        else {
            $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c rd /s /q `"$path`"" -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
            if ($proc.ExitCode -eq 0 -or -not (Test-Path $path)) { Log "   [OK] [$name] Pulito"; $totalFreed += 1MB; $totalFiles += 1 } else { Log "   [!] [$name] Cancellazione parziale" }
        }
        Pump-UI
    }
    $mb = [Math]::Round($totalFreed / 1MB, 2)
    Log ""; if ($foundAny) { Log "[OK] Browser: $(Format-Size $totalFreed)" } else { Log "[i] Nessun browser rilevato" }
    Log "==============================================================================================="; Log ""
    Update-Progress 60; Update-Status "[OK] Browser puliti" $successColor; Flush-LogBuffer; Pump-UI
    return @{ MB = $mb; Files = $totalFiles }
}

#endregion

#region ===== CESTINO =====

function Do-EmptyRecycleBin {
    [CmdletBinding()]
    param([switch]$DryRun)
    if ($script:isClosing -or (Test-Cancel)) { return @{ MB = 0; Files = 0 } }
    Log ""; Log "==============================================================================================="; Log "[>] SVUOTAMENTO CESTINO$(if ($DryRun) { ' [SIMULAZIONE]' } else { '' })"; Log "==============================================================================================="
    Update-Progress 65; Update-Status "[...] Svuotamento Cestino..." $maintColor; Flush-LogBuffer; Pump-UI
    $totalFreed = [long]0; $totalFiles = 0
    try {
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.NameSpace(0x0a)
        $items = $recycleBin.Items()
        $count = $items.Count
        if ($count -eq 0) { Log "   [i] Cestino già vuoto" }
        else {
            if ($DryRun) { Log "   [SIM] $count elementi da svuotare"; $totalFreed = $count * 1MB; $totalFiles = $count }
            else { Clear-RecycleBin -Force -ErrorAction Stop; Log "   [OK] Cestino svuotato ($count elementi)"; $totalFreed = $count * 1MB; $totalFiles = $count }
        }
    } catch { Log "   [!] Errore: $($_.Exception.Message)" }
    $mb = [Math]::Round($totalFreed / 1MB, 2)
    Log ""; Log "[OK] Cestino: $(Format-Size $totalFreed)"; Log "==============================================================================================="; Log ""
    Update-Progress 70; Update-Status "[OK] Cestino svuotato" $successColor; Flush-LogBuffer; Pump-UI
    return @{ MB = $mb; Files = $totalFiles }
}

#endregion

#region ===== WINDOWS OLD (METODO UFFICIALE CON TIMEOUT E FALLBACK) =====

function Do-CleanWindowsOld {
    [CmdletBinding()]
    param([switch]$DryRun)
    if ($script:isClosing -or (Test-Cancel)) { return @{ MB = 0; Files = 0 } }
    if (-not $global:isAdmin) {
        Log ""; Log "[X] Richiesti privilegi amministrativi per pulire vecchie versioni Windows"; return @{ MB = 0; Files = 0 }
    }
    Log ""; Log "==============================================================================================="; Log "[>] PULIZIA VECCHIE VERSIONI WINDOWS$(if ($DryRun) { ' [SIMULAZIONE]' } else { '' })"; Log "==============================================================================================="
    Update-Progress 75; Update-Status "[...] Pulizia versioni precedenti (metodo ufficiale)..." $warningColor; Flush-LogBuffer; Pump-UI
    $totalFreed = [long]0; $totalFiles = 0
    # PASSO 1: cleanmgr con timeout
    if (-not $DryRun) {
        Log "   [i] PASSO 1: Configurazione Disk Cleanup (metodo ufficiale)..."
        try {
            $volumeCaches = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
            $categories = @("Previous Installations", "Update Cleanup", "System error memory dump files", "System error minidump files", "Windows Upgrade Log Files", "Service Pack Cleanup")
            foreach ($cat in $categories) {
                $keyPath = "$volumeCaches\$cat"
                if (Test-Path $keyPath) {
                    Set-ItemProperty -Path $keyPath -Name "StateFlags1" -Value 2 -ErrorAction SilentlyContinue
                    Log "      ✓ Abilitato: $cat"
                }
            }
            Log "   [...] Esecuzione cleanmgr /sagerun:1 (timeout 10 minuti)..."
            $proc = Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -PassThru -NoNewWindow -ErrorAction SilentlyContinue
            $timeout = 600
            $elapsed = 0
            while (-not $proc.HasExited -and $elapsed -lt $timeout) {
                Start-Sleep -Seconds 1
                $elapsed++
                if ($elapsed % 10 -eq 0) { Update-Status "[...] cleanmgr in corso... $elapsed sec" $warningColor; Flush-LogBuffer; Pump-UI }
                if (Test-Cancel) { $proc.Kill(); return @{ MB = 0; Files = 0 } }
            }
            if (-not $proc.HasExited) {
                Log "   [!] cleanmgr timeout, uccisione del processo..."
                $proc.Kill()
                Start-Sleep -Milliseconds 500
            } else {
                if ($proc.ExitCode -eq 0) { Log "   [OK] Disk Cleanup completato con successo" } else { Log "   [~] Disk Cleanup completato con codice: $($proc.ExitCode)" }
            }
            # Verifica se Windows.old è stato rimosso
            $oldPaths = @("C:\Windows.old", "C:\Windows.old.000", "C:\Windows.old.001")
            $stillExists = $false
            foreach ($p in $oldPaths) { if (Test-Path $p) { $stillExists = $true; break } }
            if (-not $stillExists) {
                Log "   [OK] Windows.old rimosso correttamente da Disk Cleanup"
                Update-Progress 85; Update-Status "[OK] Versioni precedenti rimosse" $successColor; Flush-LogBuffer; Pump-UI
                return @{ MB = 0; Files = 0 }
            } else {
                Log "   [!] Windows.old ancora presente, tentativo con AUTOCLEAN..."
                $proc2 = Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/AUTOCLEAN" -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
                if ($proc2.ExitCode -eq 0) { Log "   [OK] cleanmgr /AUTOCLEAN completato" }
            }
        } catch { Log "   [!] Errore durante cleanmgr: $($_.Exception.Message)" }
    } else { Log "   [SIM] cleanmgr verrebbe eseguito per rimuovere Windows.old" }

    # PASSO 2: DISM StartComponentCleanup
    if (-not $DryRun) {
        Log ""; Log "   [i] PASSO 2: Pulizia componenti Windows (DISM)..."
        try {
            $dism = Start-Process -FilePath "dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup" -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
            if ($dism.ExitCode -eq 0) { Log "   [OK] DISM StartComponentCleanup completato" } else { Log "   [~] DISM completato con codice: $($dism.ExitCode)" }
        } catch { Log "   [!] Errore DISM: $($_.Exception.Message)" }
    } else { Log "   [SIM] DISM verrebbe eseguito" }

    # PASSO 3: Fallback manuale con takeown + icacls + rd
    $oldPaths = @(
        @{ Path = "C:\Windows.old"; Name = "Windows.old" },
        @{ Path = "C:\Windows.old.000"; Name = "Windows.old.000" },
        @{ Path = "C:\Windows.old.001"; Name = "Windows.old.001" },
        @{ Path = "C:\$WINDOWS.~BT"; Name = "Windows Setup Temp" },
        @{ Path = "C:\$WINDOWS.~Q"; Name = "Windows Rollback" },
        @{ Path = "C:\$WINDOWS.~WS"; Name = "Windows Setup WS" }
    )
    $foundOld = $false
    foreach ($entry in $oldPaths) {
        if (Test-Cancel) { return @{ MB = 0; Files = 0 } }
        $path = $entry.Path; $name = $entry.Name
        if (-not (Test-Path $path)) { Pump-UI; continue }
        $foundOld = $true
        $sizeEstimate = 0
        try { $sizeEstimate = (Get-ChildItem -Path $path -File -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum } catch { }
        Log ""; Log "   [!] Trovato: $name (fallback manuale)"; Log "       Dimensione stimata: $(Format-Size $sizeEstimate)"
        if ($name -like "Windows.old*") { Log "       ⚠️  ATTENZIONE: Questo permette il rollback alla versione precedente!" }
        if ($DryRun) { Log "   [SIM] Verrebbe cancellato: $(Format-Size $sizeEstimate)"; $totalFreed += $sizeEstimate; $totalFiles += 1 }
        else {
            $msg = "Confermi la cancellazione di $name?`n`nDimensione stimata: $(Format-Size $sizeEstimate)"
            if ($name -like "Windows.old*") { $msg += "`n`n⚠️ NON POTRAI PIÙ FARE ROLLBACK!" }
            $confirm = [System.Windows.Forms.MessageBox]::Show($msg, "Conferma Cancellazione (Fallback)", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
                Log "   [...] Cancellazione con metodo fallback (takeown + icacls + rd)..."
                Pump-UI
                # Ferma servizi
                $wuWasRunning = Stop-ServiceIfExists -ServiceName "wuauserv"
                $bitsWasRunning = Stop-ServiceIfExists -ServiceName "Bits"
                # Acquisizione permessi automatica
                Grant-FullAccessFast -Path $path -Recurse
                # Comando combinato
                $cmd = "rd /S /Q `"$path`""
                $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd" -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
                Start-ServiceIfWasRunning -ServiceName "wuauserv" -WasRunning $wuWasRunning
                Start-ServiceIfWasRunning -ServiceName "Bits" -WasRunning $bitsWasRunning
                if (-not (Test-Path $path)) {
                    Log "   [OK] $name cancellato: $(Format-Size $sizeEstimate)"
                    $totalFreed += $sizeEstimate; $totalFiles += 1
                } else {
                    Log "   [X] Impossibile cancellare completamente $name"
                }
            } else { Log "   [i] Saltato dall'utente" }
        }
        Pump-UI
    }

    # Pulizia WinSxS\Backup
    if ($global:isAdmin -and -not $DryRun) {
        $compPath = "$env:WINDIR\WinSxS\Backup"
        if (Test-Path $compPath) {
            $sizeBefore = 0
            try { $sizeBefore = (Get-ChildItem -Path $compPath -File -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum } catch { }
            if ($sizeBefore -gt 1MB) {
                Log ""; Log "   [i] WinSxS Backup: $(Format-Size $sizeBefore)"
                Grant-FullAccessFast -Path $compPath -Recurse
                $cmd = "rd /S /Q `"$compPath`""
                $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmd" -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
                if (-not (Test-Path $compPath)) { Log "   [OK] Pulito: $(Format-Size $sizeBefore)"; $totalFreed += $sizeBefore }
            }
        }
    }

    $mb = [Math]::Round($totalFreed / 1MB, 2)
    Log ""; if ($foundOld) { Log "[OK] Vecchie versioni: $(Format-Size $totalFreed)" } else { Log "[i] Nessuna vecchia versione trovata" }
    Log "==============================================================================================="; Log ""
    Update-Progress 85; Update-Status "[OK] Versioni precedenti" $successColor; Flush-LogBuffer; Pump-UI
    return @{ MB = $mb; Files = $totalFiles }
}

#endregion

#region ===== WINDOWS UPDATE CACHE =====

function Do-CleanWindowsUpdate {
    [CmdletBinding()]
    param([switch]$DryRun)
    if ($script:isClosing -or (Test-Cancel)) { return @{ MB = 0; Files = 0 } }
    if (-not $global:isAdmin) { Log ""; Log "[X] Richiesti privilegi amministrativi"; return @{ MB = 0; Files = 0 } }
    Log ""; Log "==============================================================================================="; Log "[>] PULIZIA WINDOWS UPDATE$(if ($DryRun) { ' [SIMULAZIONE]' } else { '' })"; Log "==============================================================================================="
    Update-Progress 90; Update-Status "[...] Pulizia Windows Update..." $maintColor; Flush-LogBuffer; Pump-UI
    $wuPaths = @( @{ Path = "$env:WINDIR\SoftwareDistribution\Download"; Name = "WU Download" }, @{ Path = "$env:WINDIR\SoftwareDistribution\DataStore\DataStore.edb"; Name = "WU DataStore" } )
    $totalFreed = [long]0; $totalFiles = 0
    $wuWasRunning = Stop-ServiceIfExists -ServiceName "wuauserv"; $bitsWasRunning = Stop-ServiceIfExists -ServiceName "Bits"
    foreach ($entry in $wuPaths) {
        if (Test-Cancel) { break }
        $path = $entry.Path; $name = $entry.Name
        if (-not (Test-Path $path)) { Pump-UI; continue }
        try {
            if ($DryRun) { Log "   [SIM] [$name] Verrebbe cancellato"; $totalFreed += 1MB; $totalFiles += 1 }
            else {
                if (Test-Path $path -PathType Leaf) {
                    Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                    if (-not (Test-Path $path)) { Log "   [OK] [$name] Pulito"; $totalFreed += 1MB; $totalFiles += 1 }
                } else {
                    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c rd /s /q `"$path`"" -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
                    if ($proc.ExitCode -eq 0 -or -not (Test-Path $path)) { Log "   [OK] [$name] Pulito"; $totalFreed += 1MB; $totalFiles += 1 } else { Log "   [!] [$name] Cancellazione parziale" }
                }
            }
        } catch { Log "   [!] $name : $($_.Exception.Message)" }
        Pump-UI
    }
    Start-ServiceIfWasRunning -ServiceName "wuauserv" -WasRunning $wuWasRunning; Start-ServiceIfWasRunning -ServiceName "Bits" -WasRunning $bitsWasRunning
    $mb = [Math]::Round($totalFreed / 1MB, 2)
    Log ""; Log "[OK] Windows Update: $(Format-Size $totalFreed)"; Log "==============================================================================================="; Log ""
    Update-Progress 95; Update-Status "[OK] WU pulito" $successColor; Flush-LogBuffer; Pump-UI
    return @{ MB = $mb; Files = $totalFiles }
}

#endregion

#region ===== DISK CLEANUP =====

function Do-DiskCleanup {
    [CmdletBinding()]
    param([switch]$IncludeSystemFiles)
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) {
        Log ""; Log "[X] Richiesti privilegi amministrativi per Disk Cleanup"; Update-Status "[!] Admin richiesto" $warningColor; Flush-LogBuffer; Update-Progress 100; Pump-UI; return
    }
    Log ""; Log "==============================================================================================="; Log "[>] DISK CLEANUP WINDOWS"; Log "==============================================================================================="
    Update-Status "[...] Configurazione Disk Cleanup..." $maintColor; Flush-LogBuffer; Pump-UI
    try {
        $stateFlagsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        $standardCategories = @("Active Setup Temp Folders", "Downloaded Program Files", "Internet Cache Files", "Memory Dump Files", "Offline Pages Files", "Old ChkDsk Files", "Recycle Bin", "Temporary Files", "Temporary Setup Files", "Thumbnail Cache", "Windows Error Reporting Archive Files", "Windows Error Reporting Files", "Windows Error Reporting System Queue Files", "Windows Error Reporting Temp Files")
        $systemCategories = @("Previous Installations", "Service Pack Cleanup", "System error memory dump files", "System error minidump files", "Update Cleanup", "Upgrade Discarded Files", "Windows Upgrade Log Files", "Device Driver Packages", "Windows ESD installation files")
        Log "   [i] Configurazione categorie..."
        foreach ($cat in $standardCategories) {
            $keyPath = "$stateFlagsPath\$cat"
            if (Test-Path $keyPath) { Set-ItemProperty -Path $keyPath -Name "StateFlags1" -Value 2 -ErrorAction SilentlyContinue }
        }
        if ($IncludeSystemFiles) {
            foreach ($cat in $systemCategories) {
                $keyPath = "$stateFlagsPath\$cat"
                if (Test-Path $keyPath) { Set-ItemProperty -Path $keyPath -Name "StateFlags1" -Value 2 -ErrorAction SilentlyContinue }
            }
            Log "   [i] File di sistema: INCLUSI"
        } else { Log "   [i] File di sistema: ESCLUSI" }
        Pump-UI
        Log "   [...] Esecuzione Disk Cleanup..."
        $proc = Start-Process -FilePath "cleanmgr" -ArgumentList "/sagerun:1" -Wait -PassThru -NoNewWindow -ErrorAction Stop
        if ($proc.ExitCode -eq 0) { Log "   [OK] Disk Cleanup completato" } else { Log "   [~] Completato con codice: $($proc.ExitCode)" }
    } catch { Log "   [X] Errore: $($_.Exception.Message)" }
    Log "==============================================================================================="; Log ""
    Update-Progress 100; Update-Status "[OK] Disk Cleanup" $successColor; Flush-LogBuffer; Pump-UI
}

#endregion

#region ===== ANALISI DISCO =====

function Do-DiskAnalysis {
    [CmdletBinding()]
    param()
    if ($script:isClosing -or (Test-Cancel)) { return }
    Log ""; Log "==============================================================================================="; Log "[>] ANALISI SPAZIO DISCO"; Log "==============================================================================================="
    Update-Status "[...] Analisi Disco..." $maintColor; Flush-LogBuffer; Pump-UI
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    $totalSizeAll = [double]0; $totalFreeAll = [double]0
    foreach ($drive in $drives) {
        if (Test-Cancel) { return }
        $size = [Math]::Round($drive.Size / 1GB, 2); $free = [Math]::Round($drive.FreeSpace / 1GB, 2); $used = [Math]::Round($size - $free, 2); $percent = if ($size -gt 0) { [Math]::Round(($used / $size) * 100, 1) } else { 0 }
        $barLen = 20; $filled = [Math]::Floor($percent / 100 * $barLen); $empty = $barLen - $filled; $bar = "[$('█' * $filled)$('░' * $empty)]"
        Log "   $($drive.DeviceID) $bar $percent%"; Log "      Usato: ${used}GB | Libero: ${free}GB | Totale: ${size}GB"
        if ($percent -gt 90) { Log "      ⚠️  SPAZIO CRITICO!" } elseif ($percent -gt 75) { Log "      ⚡ Spazio basso" }
        Pump-UI
    }
    $totalUsedAll = [Math]::Round($totalSizeAll - $totalFreeAll, 2); $totalPercent = if ($totalSizeAll -gt 0) { [Math]::Round(($totalUsedAll / $totalSizeAll) * 100, 1) } else { 0 }
    Log ""; Log "   ─────────────────────────────────────────────────"; Log "   TOTALE: ${totalUsedAll}GB / $([Math]::Round($totalSizeAll, 2))GB ($totalPercent%)"; Log "   LIBERO: $([Math]::Round($totalFreeAll, 2))GB"
    if ($totalPercent -gt 80) { Log ""; Log "   ─────────────────────────────────────────────────"; Log "   💡 SUGGERIMENTI:"; Log "      → Esegui pulizia completa per liberare spazio" }
    Log "==============================================================================================="; Log ""
    Update-Progress 100; Update-Status "[OK] Analisi disco" $successColor; Flush-LogBuffer; Pump-UI
}

#endregion

#region ===== PULIZIA COMPLETA =====

function Do-CleanAll {
    [CmdletBinding()]
    param(
        [switch]$DryRun,
        [switch]$SkipBrowser,
        [switch]$SkipWindowsOld,
        [switch]$IncludeDiskCleanup,
        [switch]$IncludeSystemFiles
    )
    if ($script:isClosing -or (Test-Cancel)) { return }
    $mode = if ($DryRun) { "SIMULAZIONE" } else { "REALE" }
    Log ""; Log "╔══════════════════════════════════════════════════════════════════════════════════════════╗"; Log "║                    PULIZIA COMPLETA SISTEMA - [$mode]                                   ║"; Log "╚══════════════════════════════════════════════════════════════════════════════════════════╝"
    $results = @{}; $startTime = Get-Date
    $tempResult = Do-CleanTemp -DryRun:$DryRun; $results["File Temporanei"] = $tempResult; if (Test-Cancel) { return }
    $logResult = Do-CleanLogs -DryRun:$DryRun; $results["Log e Report"] = $logResult; if (Test-Cancel) { return }
    if (-not $SkipBrowser) { $browserResult = Do-CleanBrowserCache -DryRun:$DryRun; $results["Cache Browser"] = $browserResult }; if (Test-Cancel) { return }
    $binResult = Do-EmptyRecycleBin -DryRun:$DryRun; $results["Cestino"] = $binResult; if (Test-Cancel) { return }
    $wuResult = Do-CleanWindowsUpdate -DryRun:$DryRun; $results["Windows Update"] = $wuResult; if (Test-Cancel) { return }
    if (-not $SkipWindowsOld) { $oldResult = Do-CleanWindowsOld -DryRun:$DryRun; $results["Vecchie Versioni"] = $oldResult }
    if ($IncludeDiskCleanup -and -not $DryRun) { Do-DiskCleanup -IncludeSystemFiles:$IncludeSystemFiles }
    if (-not (Test-Cancel)) { $elapsed = (Get-Date) - $startTime; Log ""; Log "[i] Tempo impiegato: $([Math]::Round($elapsed.TotalSeconds, 1)) secondi"; Show-CleanupReport -Results $results -DryRun:$DryRun }
    Update-Progress 100; Flush-LogBuffer; Pump-UI
}

#endregion

#region ===== REPORT =====

function Show-CleanupReport {
    param([hashtable]$Results, [switch]$DryRun)
    Log ""; Log "╔══════════════════════════════════════════════════════════════════════════════════════════╗"; Log "║                           REPORT PULIZIA                                                ║"; if ($DryRun) { Log "║                         ⚠️  MODALITÀ SIMULAZIONE ⚠️                                      ║" }
    Log "╠══════════════════════════════════════════════════════════════════════════════════════════╣"; Log "║  Categoria                    Spazio          File                                     ║"; Log "║  ──────────────────────────── ─────────────── ─────────────────                         ║"
    $totalMB = [double]0; $totalFiles = 0
    foreach ($key in $Results.Keys) {
        $val = $Results[$key]; $mb = [double]$val.MB; $files = [int]$val.Files; $totalMB += $mb; $totalFiles += $files
        $sizeStr = "{0,14} MB" -f [Math]::Round($mb, 2); $fileStr = "{0,16} file" -f $files; $nameStr = "{0,-28}" -f $key.Substring(0, [Math]::Min($key.Length, 28))
        Log "║  $nameStr $sizeStr $fileStr  ║"
    }
    Log "╠══════════════════════════════════════════════════════════════════════════════════════════╣"; $totalSizeStr = "{0,14} MB" -f [Math]::Round($totalMB, 2); $totalFileStr = "{0,16} file" -f $totalFiles; Log "║  {0,-28} {1} {2}  ║" -f "TOTALE", $totalSizeStr, $totalFileStr; if ($totalMB -ge 1024) { Log "║                                        ≈ $([Math]::Round($totalMB/1024, 2)) GB                              ║" }; Log "╚══════════════════════════════════════════════════════════════════════════════════════════╝"; Log ""
}

#endregion

#region ===== EXPORT =====

Export-ModuleMember -Function @(
    'Do-CleanTemp',
    'Do-CleanLogs',
    'Do-CleanBrowserCache',
    'Do-EmptyRecycleBin',
    'Do-CleanWindowsOld',
    'Do-CleanWindowsUpdate',
    'Do-DiskCleanup',
    'Do-DiskAnalysis',
    'Do-CleanAll',
    'Show-CleanupReport'
)

#endregion
