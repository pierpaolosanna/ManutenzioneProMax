# ============================================================
# PULIZIA.psm1 - Pulizia Completa Sistema
# Versione: 2.0.0 - COMPLETO CON TUTTE LE FUNZIONALITÀ
# ============================================================

#region ===== FUNZIONI HELPER =====

function Get-FolderSizeFast {
    <#
    .SYNOPSIS
    Calcola la dimensione di una cartella in modo efficiente
    #>
    param(
        [string]$Path,
        [switch]$IncludeSubfolders = $true
    )
    
    if (-not (Test-Path $Path)) { return [long]0 }
    
    $size = [long]0
    $params = @{
        Path = $Path
        File = $true
        Force = $true
        ErrorAction = 'SilentlyContinue'
    }
    if ($IncludeSubfolders) { $params['Recurse'] = $true }
    
    try {
        Get-ChildItem @params | ForEach-Object { $size += $_.Length }
    } catch { }
    return $size
}

function Get-FolderItemCount {
    <#
    .SYNOPSIS
    Conta file e cartelle in un percorso
    #>
    param(
        [string]$Path,
        [switch]$FilesOnly = $false
    )
    
    if (-not (Test-Path $Path)) { return 0 }
    
    $params = @{
        Path = $Path
        Force = $true
        Recurse = $true
        ErrorAction = 'SilentlyContinue'
    }
    if ($FilesOnly) { $params['File'] = $true }
    
    try {
        return @(Get-ChildItem @params).Count
    } catch { return 0 }
}

function Remove-ItemSafe {
    <#
    .SYNOPSIS
    Rimuove elementi con gestione errori avanzata
    #>
    param(
        [string]$Path,
        [int]$MaxRetries = 1,
        [int]$RetryDelayMs = 300
    )
    
    $deleted = 0
    $errors = @()
    
    for ($attempt = 0; $attempt -le $MaxRetries; $attempt++) {
        try {
            $items = @(Get-ChildItem -Path $Path -Force -Recurse -ErrorAction SilentlyContinue)
            if ($items.Count -eq 0) { break }
            
            $currentErrors = @()
            $items | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable currentErrors
            
            # Conta cosa è rimasto
            $remaining = @(Get-ChildItem -Path $Path -Force -Recurse -ErrorAction SilentlyContinue)
            $deleted = $items.Count - $remaining.Count
            
            if ($remaining.Count -eq 0) { break }
            if ($attempt -lt $MaxRetries) { 
                Start-Sleep -Milliseconds $RetryDelayMs 
            } else {
                $errors = $currentErrors
            }
        } catch {
            $errors += $_
        }
    }
    
    return @{
        Deleted = $deleted
        Errors = $errors
        HasErrors = ($errors.Count -gt 0)
    }
}

function Format-Size {
    <#
    .SYNOPSIS
    Formatta bytes in stringa leggibile
    #>
    param([long]$Bytes)
    
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

#endregion

#region ===== PULIZIA TEMP =====

function Do-CleanTemp {
    <#
    .SYNOPSIS
    Pulizia file temporanei utente e sistema
    #>
    [CmdletBinding()]
    param(
        [switch]$DryRun
    )
    
    if ($script:isClosing -or (Test-Cancel)) { return @{ MB = 0; Files = 0 } }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] PULIZIA FILE TEMPORANEI$(if ($DryRun) { ' [SIMULAZIONE]' } else { '' })"
    Log "==============================================================================================="
    Update-Progress 10
    Update-Status "[...] Pulizia Temp..." $fgColor
    Flush-LogBuffer; Pump-UI
    
    # Costruisci percorsi senza duplicati
    $addedPaths = @{}
    $paths = @()
    
    $potentialPaths = @(
        @{ Path = $env:TEMP; Name = "User Temp" },
        @{ Path = "$env:LOCALAPPDATA\Temp"; Name = "Local Temp" },
        @{ Path = "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache"; Name = "IE/Edge Cache" },
        @{ Path = "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer"; Name = "Thumbnails"; Filter = "thumbcache_*.db" },
        @{ Path = "$env:USERPROFILE\AppData\Local\CrashDumps"; Name = "Crash Dumps" },
        @{ Path = "$env:USERPROFILE\AppData\LocalLow\Microsoft\CryptnetUrlCache"; Name = "Cryptnet Cache" },
        @{ Path = "$env:LOCALAPPDATA\Microsoft\Windows\WebCache"; Name = "WebCache" }
    )
    
    if ($isAdmin) {
        $potentialPaths += @(
            @{ Path = "$env:WINDIR\Temp"; Name = "Windows Temp" },
            @{ Path = "$env:WINDIR\Prefetch"; Name = "Prefetch" }
        )
    }
    
    # Deduplica
    foreach ($p in $potentialPaths) {
        try {
            $resolved = [System.IO.Path]::GetFullPath($p.Path)
            $key = $resolved.ToLower()
            if (-not $addedPaths.ContainsKey($key)) {
                $paths += $p
                $addedPaths[$key] = $true
            }
        } catch { }
    }
    
    $totalFreed = [long]0
    $totalFiles = 0
    
    foreach ($p in $paths) {
        if (Test-Cancel) { return @{ MB = 0; Files = 0 } }
        
        if (-not (Test-Path $p.Path)) { 
            Pump-UI
            continue 
        }
        
        try {
            # Calcola dimensione prima
            $sizeBefore = Get-FolderSizeFast -Path $p.Path
            $countBefore = Get-FolderItemCount -Path $p.Path -FilesOnly
            
            if ($countBefore -eq 0) {
                Log "   [$($p.Name)] Vuoto"
                Pump-UI
                continue
            }
            
            if ($DryRun) {
                Log "   [SIM] [$($p.Name)] $countBefore file, $(Format-Size $sizeBefore)"
                $totalFreed += $sizeBefore
                $totalFiles += $countBefore
            } else {
                # Esegui cancellazione
                $result = Remove-ItemSafe -Path $p.Path
                
                # Calcola dopo
                $sizeAfter = Get-FolderSizeFast -Path $p.Path
                $freed = $sizeBefore - $sizeAfter
                $deleted = $countBefore - (Get-FolderItemCount -Path $p.Path -FilesOnly)
                
                if ($freed -gt 0) {
                    $totalFreed += $freed
                    $totalFiles += $deleted
                }
                
                $warn = if ($result.HasErrors) { " ⚠" } else { "" }
                Log "   [$($p.Name)] $deleted file, $(Format-Size $freed)$warn"
            }
        } catch {
            Log "   [!] $($p.Name): $($_.Exception.Message)"
        }
        Pump-UI
    }
    
    $mb = [Math]::Round($totalFreed / 1MB, 2)
    Log ""
    Log "[OK] Temp: $(Format-Size $totalFreed) ($totalFiles file)"
    Log "==============================================================================================="
    Log ""
    
    Update-Progress 25
    Update-Status "[OK] Temp puliti ($(Format-Size $totalFreed))" $successColor
    Flush-LogBuffer; Pump-UI
    
    return @{ MB = $mb; Files = $totalFiles }
}

#endregion

#region ===== PULIZIA LOG =====

function Do-CleanLogs {
    <#
    .SYNOPSIS
    Pulizia file di log e report errori
    #>
    [CmdletBinding()]
    param(
        [switch]$DryRun
    )
    
    if ($script:isClosing -or (Test-Cancel)) { return @{ MB = 0; Files = 0 } }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] PULIZIA LOG E REPORT$(if ($DryRun) { ' [SIMULAZIONE]' } else { '' })"
    Log "==============================================================================================="
    Update-Progress 30
    Update-Status "[...] Pulizia Log..." $maintColor
    Flush-LogBuffer; Pump-UI
    
    $logPaths = @(
        @{ Path = "$env:WINDIR\Logs\CBS"; Name = "CBS Logs" },
        @{ Path = "$env:WINDIR\Logs\DISM"; Name = "DISM Logs" },
        @{ Path = "$env:WINDIR\Logs\WindowsUpdate"; Name = "Update Logs" },
        @{ Path = "$env:WINDIR\Panther"; Name = "Panther/Setup Logs" },
        @{ Path = "$env:WINDIR\SoftwareDistribution\ReportingEvents.log"; Name = "WU Report"; IsFile = $true },
        @{ Path = "$env:WINDIR\System32\LogFiles\WMI"; Name = "WMI Logs" },
        @{ Path = "$env:WINDIR\System32\LogFiles\AIMDB"; Name = "AIMDB Logs" },
        @{ Path = "$env:PROGRAMDATA\Microsoft\Windows\WER"; Name = "WER Reports" },
        @{ Path = "$env:LOCALAPPDATA\CrashDumps"; Name = "User CrashDumps" },
        @{ Path = "$env:PROGRAMDATA\Microsoft\Windows\WLXStoreLogs"; Name = "Store Logs" }
    )
    
    $totalFreed = [long]0
    $totalFiles = 0
    
    foreach ($entry in $logPaths) {
        if (Test-Cancel) { return @{ MB = 0; Files = 0 } }
        
        $path = $entry.Path
        $name = $entry.Name
        $isFile = $entry.IsFile -eq $true
        
        if (-not (Test-Path $path)) { 
            Pump-UI
            continue 
        }
        
        try {
            if ($isFile) {
                # Singolo file
                $item = Get-Item -Path $path -Force -ErrorAction SilentlyContinue
                if ($item) {
                    $size = $item.Length
                    if ($DryRun) {
                        Log "   [SIM] [$name] $(Format-Size $size)"
                        $totalFreed += $size
                        $totalFiles++
                    } else {
                        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                        if (-not (Test-Path $path)) {
                            $totalFreed += $size
                            $totalFiles++
                            Log "   [OK] [$name] $(Format-Size $size)"
                        }
                    }
                }
            } else {
                # Cartella
                $sizeBefore = Get-FolderSizeFast -Path $path
                $countBefore = Get-FolderItemCount -Path $path -FilesOnly
                
                if ($countBefore -eq 0) {
                    Pump-UI
                    continue
                }
                
                if ($DryRun) {
                    Log "   [SIM] [$name] $countBefore file, $(Format-Size $sizeBefore)"
                    $totalFreed += $sizeBefore
                    $totalFiles += $countBefore
                } else {
                    $result = Remove-ItemSafe -Path $path
                    $sizeAfter = Get-FolderSizeFast -Path $path
                    $freed = $sizeBefore - $sizeAfter
                    $deleted = $countBefore - (Get-FolderItemCount -Path $path -FilesOnly)
                    
                    if ($freed -gt 0) {
                        $totalFreed += $freed
                        $totalFiles += $deleted
                        Log "   [OK] [$name] $deleted file, $(Format-Size $freed)"
                    }
                }
            }
        } catch {
            Log "   [!] $name : Accesso negato"
        }
        Pump-UI
    }
    
    $mb = [Math]::Round($totalFreed / 1MB, 2)
    Log ""
    Log "[OK] Log: $(Format-Size $totalFreed) ($totalFiles file)"
    Log "==============================================================================================="
    Log ""
    
    Update-Progress 45
    Update-Status "[OK] Log puliti ($(Format-Size $totalFreed))" $successColor
    Flush-LogBuffer; Pump-UI
    
    return @{ MB = $mb; Files = $totalFiles }
}

#endregion

#region ===== PULIZIA BROWSER =====

function Do-CleanBrowserCache {
    <#
    .SYNOPSIS
    Pulizia cache browser (Chrome, Edge, Firefox, Brave)
    #>
    [CmdletBinding()]
    param(
        [switch]$DryRun
    )
    
    if ($script:isClosing -or (Test-Cancel)) { return @{ MB = 0; Files = 0 } }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] PULIZIA CACHE BROWSER$(if ($DryRun) { ' [SIMULAZIONE]' } else { '' })"
    Log "==============================================================================================="
    Update-Progress 50
    Update-Status "[...] Pulizia Browser..." $maintColor
    Flush-LogBuffer; Pump-UI
    
    $browserConfigs = @()
    
    # --- CHROME ---
    $chromeBase = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    if (Test-Path $chromeBase) {
        $chromeProfiles = Get-ChildItem -Path $chromeBase -Directory -ErrorAction SilentlyContinue | 
                          Where-Object { $_.Name -match '^Default$|^Profile' }
        foreach ($prof in $chromeProfiles) {
            $browserConfigs += @(
                @{ Path = "$($prof.FullName)\Cache"; Name = "Chrome Cache [$($prof.Name)]" },
                @{ Path = "$($prof.FullName)\Code Cache"; Name = "Chrome Code Cache [$($prof.Name)]" },
                @{ Path = "$($prof.FullName)\Service Worker\CacheStorage"; Name = "Chrome SW Cache [$($prof.Name)]" },
                @{ Path = "$($prof.FullName)\GPUCache"; Name = "Chrome GPU Cache [$($prof.Name)]" }
            )
        }
    }
    
    # --- EDGE ---
    $edgeBase = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    if (Test-Path $edgeBase) {
        $edgeProfiles = Get-ChildItem -Path $edgeBase -Directory -ErrorAction SilentlyContinue | 
                        Where-Object { $_.Name -match '^Default$|^Profile' }
        foreach ($prof in $edgeProfiles) {
            $browserConfigs += @(
                @{ Path = "$($prof.FullName)\Cache"; Name = "Edge Cache [$($prof.Name)]" },
                @{ Path = "$($prof.FullName)\Code Cache"; Name = "Edge Code Cache [$($prof.Name)]" },
                @{ Path = "$($prof.FullName)\Service Worker\CacheStorage"; Name = "Edge SW Cache [$($prof.Name)]" },
                @{ Path = "$($prof.FullName)\GPUCache"; Name = "Edge GPU Cache [$($prof.Name)]" }
            )
        }
    }
    
    # --- BRAVE ---
    $braveBase = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
    if (Test-Path $braveBase) {
        $braveProfiles = Get-ChildItem -Path $braveBase -Directory -ErrorAction SilentlyContinue | 
                         Where-Object { $_.Name -match '^Default$|^Profile' }
        foreach ($prof in $braveProfiles) {
            $browserConfigs += @(
                @{ Path = "$($prof.FullName)\Cache"; Name = "Brave Cache [$($prof.Name)]" },
                @{ Path = "$($prof.FullName)\Code Cache"; Name = "Brave Code Cache [$($prof.Name)]" }
            )
        }
    }
    
    # --- FIREFOX ---
    $firefoxBase = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $firefoxBase) {
        $firefoxProfiles = Get-ChildItem -Path $firefoxBase -Directory -ErrorAction SilentlyContinue
        foreach ($prof in $firefoxProfiles) {
            $browserConfigs += @(
                @{ Path = "$($prof.FullName)\cache2"; Name = "Firefox Cache [$($prof.Name.Substring(0,8))]" },
                @{ Path = "$($prof.FullName)\thumbnails"; Name = "Firefox Thumbnails [$($prof.Name.Substring(0,8))]" }
            )
        }
    }
    
    # --- OPERA ---
    $operaBase = "$env:APPDATA\Opera Software\Opera Stable"
    if (Test-Path $operaBase) {
        $browserConfigs += @(
            @{ Path = "$operaBase\Cache"; Name = "Opera Cache" },
            @{ Path = "$operaBase\Code Cache"; Name = "Opera Code Cache" }
        )
    }
    
    $totalFreed = [long]0
    $totalFiles = 0
    $foundAny = $false
    
    foreach ($entry in $browserConfigs) {
        if (Test-Cancel) { return @{ MB = 0; Files = 0 } }
        
        $path = $entry.Path
        $name = $entry.Name
        
        if (-not (Test-Path $path)) { 
            Pump-UI
            continue 
        }
        
        $foundAny = $true
        $sizeBefore = Get-FolderSizeFast -Path $path
        $countBefore = Get-FolderItemCount -Path $path -FilesOnly
        
        if ($countBefore -eq 0) {
            Pump-UI
            continue
        }
        
        if ($DryRun) {
            Log "   [SIM] [$name] $countBefore file, $(Format-Size $sizeBefore)"
            $totalFreed += $sizeBefore
            $totalFiles += $countBefore
        } else {
            $result = Remove-ItemSafe -Path $path
            $sizeAfter = Get-FolderSizeFast -Path $path
            $freed = $sizeBefore - $sizeAfter
            $deleted = $countBefore - (Get-FolderItemCount -Path $path -FilesOnly)
            
            if ($freed -gt 0) {
                $totalFreed += $freed
                $totalFiles += $deleted
                Log "   [OK] [$name] $deleted file, $(Format-Size $freed)"
            }
        }
        Pump-UI
    }
    
    $mb = [Math]::Round($totalFreed / 1MB, 2)
    Log ""
    if ($foundAny) {
        Log "[OK] Browser: $(Format-Size $totalFreed) ($totalFiles file)"
    } else {
        Log "[i] Nessun browser rilevato"
    }
    Log "==============================================================================================="
    Log ""
    
    Update-Progress 60
    Update-Status "[OK] Browser puliti" $successColor
    Flush-LogBuffer; Pump-UI
    
    return @{ MB = $mb; Files = $totalFiles }
}

#endregion

#region ===== CESTINO =====

function Do-EmptyRecycleBin {
    <#
    .SYNOPSIS
    Svuota il cestino
    #>
    [CmdletBinding()]
    param(
        [switch]$DryRun
    )
    
    if ($script:isClosing -or (Test-Cancel)) { return @{ MB = 0; Files = 0 } }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] SVUOTAMENTO CESTINO$(if ($DryRun) { ' [SIMULAZIONE]' } else { '' })"
    Log "==============================================================================================="
    Update-Progress 65
    Update-Status "[...] Svuotamento Cestino..." $maintColor
    Flush-LogBuffer; Pump-UI
    
    $totalFreed = [long]0
    $totalFiles = 0
    
    try {
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.NameSpace(0x0a)
        $items = $recycleBin.Items()
        $count = $items.Count
        
        if ($count -eq 0) {
            Log "   [i] Cestino già vuoto"
        } else {
            # Stima dimensione (non precisa ma indicativa)
            $sizeEstimate = [long]0
            foreach ($item in $items) {
                try {
                    $sizeEstimate += $item.Size
                } catch { }
            }
            
            if ($DryRun) {
                Log "   [SIM] $count elementi, $(Format-Size $sizeEstimate)"
                $totalFreed = $sizeEstimate
                $totalFiles = $count
            } else {
                Clear-RecycleBin -Force -ErrorAction Stop
                Log "   [OK] Cestino svuotato ($count elementi)"
                $totalFreed = $sizeEstimate
                $totalFiles = $count
            }
        }
    } catch {
        Log "   [!] Errore: $($_.Exception.Message)"
    }
    
    $mb = [Math]::Round($totalFreed / 1MB, 2)
    Log ""
    Log "[OK] Cestino: $(Format-Size $totalFreed)"
    Log "==============================================================================================="
    Log ""
    
    Update-Progress 70
    Update-Status "[OK] Cestino svuotato" $successColor
    Flush-LogBuffer; Pump-UI
    
    return @{ MB = $mb; Files = $totalFiles }
}

#endregion

#region ===== WINDOWS OLD E VERSIONI PRECEDENTI =====

function Do-CleanWindowsOld {
    <#
    .SYNOPSIS
    Pulizia vecchie versioni Windows (Windows.old, $WINDOWS.~BT, ecc.)
    #>
    [CmdletBinding()]
    param(
        [switch]$DryRun
    )
    
    if ($script:isClosing -or (Test-Cancel)) { return @{ MB = 0; Files = 0 } }
    
    if (-not $isAdmin) {
        Log ""
        Log "[X] Richiesti privilegi amministrativi per pulire vecchie versioni Windows"
        return @{ MB = 0; Files = 0 }
    }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] PULIZIA VECCHIE VERSIONI WINDOWS$(if ($DryRun) { ' [SIMULAZIONE]' } else { '' })"
    Log "==============================================================================================="
    Update-Progress 75
    Update-Status "[...] Analisi versioni precedenti..." $warningColor
    Flush-LogBuffer; Pump-UI
    
    $oldVersionPaths = @(
        @{ Path = "C:\Windows.old"; Name = "Windows.old" },
        @{ Path = "C:\Windows.old.000"; Name = "Windows.old.000" },
        @{ Path = "C:\Windows.old.001"; Name = "Windows.old.001" },
        @{ Path = "C:\$WINDOWS.~BT"; Name = "Windows Setup Temp" },
        @{ Path = "C:\$WINDOWS.~Q"; Name = "Windows Rollback" },
        @{ Path = "C:\$WINDOWS.~WS"; Name = "Windows Setup WS" }
    )
    
    $totalFreed = [long]0
    $totalFiles = 0
    $foundOld = $false
    
    foreach ($entry in $oldVersionPaths) {
        if (Test-Cancel) { return @{ MB = 0; Files = 0 } }
        
        $path = $entry.Path
        $name = $entry.Name
        
        if (-not (Test-Path $path)) { 
            Pump-UI
            continue 
        }
        
        $foundOld = $true
        $sizeBefore = Get-FolderSizeFast -Path $path
        $countBefore = Get-FolderItemCount -Path $path
        
        Log ""
        Log "   [!] Trovato: $name"
        Log "       Dimensione: $(Format-Size $sizeBefore)"
        Log "       Elementi: $countBefore"
        
        if ($name -like "Windows.old*") {
            Log "       ⚠️  ATTENZIONE: Questo permette il rollback alla versione precedente!"
        }
        
        if ($DryRun) {
            Log "   [SIM] Verrebbe cancellato: $(Format-Size $sizeBefore)"
            $totalFreed += $sizeBefore
            $totalFiles += $countBefore
        } else {
            # Chiedi conferma
            $msg = "Confermi la cancellazione di $name?`n`nDimensione: $(Format-Size $sizeBefore)`nElementi: $countBefore"
            if ($name -like "Windows.old*") {
                $msg += "`n`n⚠️ NON POTRAI PIÙ FARE ROLLBACK!"
            }
            
            $confirm = [System.Windows.Forms.MessageBox]::Show(
                $msg,
                "Conferma Cancellazione",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            
            if ($confirm -eq [System.Windows.Forms.DialogResult]::Yes) {
                Log "   [...] Cancellazione in corso..."
                Pump-UI
                
                try {
                    # Usa takeown e icacls per forzare i permessi
                    $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c rd /s /q `"$path`"" -Wait -PassThru -NoNewWindow -ErrorAction Stop
                    
                    if (-not (Test-Path $path)) {
                        Log "   [OK] $name cancellato: $(Format-Size $sizeBefore)"
                        $totalFreed += $sizeBefore
                        $totalFiles += $countBefore
                    } else {
                        Log "   [!] Alcuni file non sono stati cancellati (in uso o permessi)"
                        # Prova cancellazione normale
                        $result = Remove-ItemSafe -Path $path -MaxRetries 2
                        $sizeAfter = Get-FolderSizeFast -Path $path
                        $freed = $sizeBefore - $sizeAfter
                        if ($freed -gt 0) {
                            Log "   [~] Parzialmente cancellato: $(Format-Size $freed)"
                            $totalFreed += $freed
                        }
                    }
                } catch {
                    Log "   [X] Errore: $($_.Exception.Message)"
                }
            } else {
                Log "   [i] Saltato dall'utente"
            }
        }
        Pump-UI
    }
    
    # Pulizia componenti Windows disinstallati
    $compPath = "$env:WINDIR\WinSxS\Backup"
    if (Test-Path $compPath) {
        $sizeBefore = Get-FolderSizeFast -Path $compPath
        if ($sizeBefore -gt 1MB) {
            Log ""
            Log "   [i] WinSxS Backup: $(Format-Size $sizeBefore)"
            if (-not $DryRun) {
                $result = Remove-ItemSafe -Path $compPath
                $sizeAfter = Get-FolderSizeFast -Path $compPath
                $freed = $sizeBefore - $sizeAfter
                if ($freed -gt 0) {
                    Log "   [OK] Pulito: $(Format-Size $freed)"
                    $totalFreed += $freed
                }
            } else {
                Log "   [SIM] Verrebbe pulito: $(Format-Size $sizeBefore)"
                $totalFreed += $sizeBefore
            }
        }
    }
    
    $mb = [Math]::Round($totalFreed / 1MB, 2)
    Log ""
    if ($foundOld) {
        Log "[OK] Vecchie versioni: $(Format-Size $totalFreed)"
    } else {
        Log "[i] Nessuna vecchia versione trovata"
    }
    Log "==============================================================================================="
    Log ""
    
    Update-Progress 80
    Update-Status "[OK] Versioni precedenti" $successColor
    Flush-LogBuffer; Pump-UI
    
    return @{ MB = $mb; Files = $totalFiles }
}

#endregion

#region ===== WINDOWS UPDATE CACHE =====

function Do-CleanWindowsUpdate {
    <#
    .SYNOPSIS
    Pulizia cache Windows Update e file di installazione obsoleti
    #>
    [CmdletBinding()]
    param(
        [switch]$DryRun
    )
    
    if ($script:isClosing -or (Test-Cancel)) { return @{ MB = 0; Files = 0 } }
    
    if (-not $isAdmin) {
        Log ""
        Log "[X] Richiesti privilegi amministrativi"
        return @{ MB = 0; Files = 0 }
    }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] PULIZIA WINDOWS UPDATE$(if ($DryRun) { ' [SIMULAZIONE]' } else { '' })"
    Log "==============================================================================================="
    Update-Progress 85
    Update-Status "[...] Pulizia Windows Update..." $maintColor
    Flush-LogBuffer; Pump-UI
    
    $wuPaths = @(
        @{ Path = "$env:WINDIR\SoftwareDistribution\Download"; Name = "WU Download Cache" },
        @{ Path = "$env:WINDIR\SoftwareDistribution\DataStore\DataStore.edb"; Name = "WU DataStore"; IsFile = $true }
    )
    
    $totalFreed = [long]0
    $totalFiles = 0
    
    # Ferma il servizio Windows Update
    $wuService = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
    $wasRunning = $false
    if ($wuService -and $wuService.Status -eq 'Running') {
        $wasRunning = $true
        if (-not $DryRun) {
            Log "   [i] Arresto servizio Windows Update..."
            Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 500
        }
    }
    
    foreach ($entry in $wuPaths) {
        if (Test-Cancel) { break }
        
        $path = $entry.Path
        $name = $entry.Name
        $isFile = $entry.IsFile -eq $true
        
        if (-not (Test-Path $path)) { 
            Pump-UI
            continue 
        }
        
        try {
            if ($isFile) {
                $item = Get-Item -Path $path -Force -ErrorAction SilentlyContinue
                if ($item) {
                    $size = $item.Length
                    if ($DryRun) {
                        Log "   [SIM] [$name] $(Format-Size $size)"
                        $totalFreed += $size
                        $totalFiles++
                    } else {
                        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                        if (-not (Test-Path $path)) {
                            $totalFreed += $size
                            $totalFiles++
                            Log "   [OK] [$name] $(Format-Size $size)"
                        } else {
                            Log "   [!] [$name] Impossibile cancellare (in uso)"
                        }
                    }
                }
            } else {
                $sizeBefore = Get-FolderSizeFast -Path $path
                $countBefore = Get-FolderItemCount -Path $path -FilesOnly
                
                if ($countBefore -eq 0) {
                    Pump-UI
                    continue
                }
                
                if ($DryRun) {
                    Log "   [SIM] [$name] $countBefore file, $(Format-Size $sizeBefore)"
                    $totalFreed += $sizeBefore
                    $totalFiles += $countBefore
                } else {
                    $result = Remove-ItemSafe -Path $path
                    $sizeAfter = Get-FolderSizeFast -Path $path
                    $freed = $sizeBefore - $sizeAfter
                    $deleted = $countBefore - (Get-FolderItemCount -Path $path -FilesOnly)
                    
                    if ($freed -gt 0) {
                        $totalFreed += $freed
                        $totalFiles += $deleted
                        Log "   [OK] [$name] $deleted file, $(Format-Size $freed)"
                    }
                }
            }
        } catch {
            Log "   [!] $name : $($_.Exception.Message)"
        }
        Pump-UI
    }
    
    # Riavvia il servizio
    if ($wasRunning -and -not $DryRun) {
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        Log "   [i] Servizio Windows Update riavviato"
    }
    
    $mb = [Math]::Round($totalFreed / 1MB, 2)
    Log ""
    Log "[OK] Windows Update: $(Format-Size $totalFreed) ($totalFiles file)"
    Log "==============================================================================================="
    Log ""
    
    Update-Progress 90
    Update-Status "[OK] WU pulito" $successColor
    Flush-LogBuffer; Pump-UI
    
    return @{ MB = $mb; Files = $totalFiles }
}

#endregion

#region ===== DISK CLEANUP =====

function Do-DiskCleanup {
    <#
    .SYNOPSIS
    Esegue Disk Cleanup di Windows con configurazione automatica
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeSystemFiles
    )
    
    if ($script:isClosing -or (Test-Cancel)) { return }
    
    if (-not $isAdmin) {
        Log ""
        Log "[X] Richiesti privilegi amministrativi per Disk Cleanup"
        Update-Status "[!] Admin richiesto" $warningColor
        Flush-LogBuffer; Update-Progress 100
        Pump-UI
        return
    }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] DISK CLEANUP WINDOWS"
    Log "==============================================================================================="
    Update-Status "[...] Configurazione Disk Cleanup..." $maintColor
    Flush-LogBuffer; Pump-UI
    
    try {
        $stateFlagsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        
        # Categorie standard
        $standardCategories = @(
            "Active Setup Temp Folders",
            "Downloaded Program Files",
            "Internet Cache Files",
            "Memory Dump Files",
            "Offline Pages Files",
            "Old ChkDsk Files",
            "Recycle Bin",
            "Temporary Files",
            "Temporary Setup Files",
            "Thumbnail Cache",
            "Windows Error Reporting Archive Files",
            "Windows Error Reporting Files",
            "Windows Error Reporting System Queue Files",
            "Windows Error Reporting Temp Files"
        )
        
        # Categorie file di sistema
        $systemCategories = @(
            "Previous Installations",
            "Service Pack Cleanup",
            "System error memory dump files",
            "System error minidump files",
            "Update Cleanup",
            "Upgrade Discarded Files",
            "Windows Upgrade Log Files",
            "Device Driver Packages",
            "Windows ESD installation files"
        )
        
        # Configura profilo
        Log "   [i] Configurazione categorie..."
        foreach ($cat in $standardCategories) {
            $keyPath = "$stateFlagsPath\$cat"
            if (Test-Path $keyPath) {
                Set-ItemProperty -Path $keyPath -Name "StateFlags0001" -Value 2 -ErrorAction SilentlyContinue
            }
        }
        
        if ($IncludeSystemFiles) {
            foreach ($cat in $systemCategories) {
                $keyPath = "$stateFlagsPath\$cat"
                if (Test-Path $keyPath) {
                    Set-ItemProperty -Path $keyPath -Name "StateFlags0001" -Value 2 -ErrorAction SilentlyContinue
                }
            }
            Log "   [i] File di sistema: INCLUSI"
        } else {
            Log "   [i] File di sistema: ESCLUSI"
        }
        
        Pump-UI
        
        # Esegui
        Log "   [...] Esecuzione Disk Cleanup..."
        $proc = Start-Process -FilePath "cleanmgr" -ArgumentList "/sagerun:1 /autoclean" -Wait -PassThru -NoNewWindow -ErrorAction Stop
        
        if ($proc.ExitCode -eq 0) {
            Log "   [OK] Disk Cleanup completato"
        } else {
            Log "   [~] Completato con codice: $($proc.ExitCode)"
        }
        
    } catch {
        Log "   [X] Errore: $($_.Exception.Message)"
    }
    
    Log "==============================================================================================="
    Log ""
    
    Update-Progress 95
    Update-Status "[OK] Disk Cleanup" $successColor
    Flush-LogBuffer; Pump-UI
}

#endregion

#region ===== ANALISI DISCO =====

function Do-DiskAnalysis {
    <#
    .SYNOPSIS
    Analisi dettagliata dello spazio su disco
    #>
    [CmdletBinding()]
    param()
    
    if ($script:isClosing -or (Test-Cancel)) { return }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] ANALISI SPAZIO DISCO"
    Log "==============================================================================================="
    Update-Status "[...] Analisi Disco..." $maintColor
    Flush-LogBuffer; Pump-UI
    
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    $totalSizeAll = [double]0
    $totalFreeAll = [double]0
    
    foreach ($drive in $drives) {
        if (Test-Cancel) { return }
        
        $size = [Math]::Round($drive.Size / 1GB, 2)
        $free = [Math]::Round($drive.FreeSpace / 1GB, 2)
        $used = [Math]::Round($size - $free, 2)
        $percent = if ($size -gt 0) { [Math]::Round(($used / $size) * 100, 1) } else { 0 }
        
        # Barra visuale
        $barLen = 20
        $filled = [Math]::Floor($percent / 100 * $barLen)
        $empty = $barLen - $filled
        $bar = "[$('█' * $filled)$('░' * $empty)]"
        
        Log "   $($drive.DeviceID) $bar $percent%"
        Log "      Usato: ${used}GB | Libero: ${free}GB | Totale: ${size}GB"
        
        if ($percent -gt 90) {
            Log "      ⚠️  SPAZIO CRITICO!"
        } elseif ($percent -gt 75) {
            Log "      ⚡ Spazio basso"
        }
        
        $totalSizeAll += $size
        $totalFreeAll += $free
        Pump-UI
    }
    
    $totalUsedAll = [Math]::Round($totalSizeAll - $totalFreeAll, 2)
    $totalPercent = if ($totalSizeAll -gt 0) { [Math]::Round(($totalUsedAll / $totalSizeAll) * 100, 1) } else { 0 }
    
    Log ""
    Log "   ─────────────────────────────────────────────────"
    Log "   TOTALE: ${totalUsedAll}GB / $([Math]::Round($totalSizeAll, 2))GB ($totalPercent%)"
    Log "   LIBERO: $([Math]::Round($totalFreeAll, 2))GB"
    
    # Suggerimenti
    if ($totalPercent -gt 80) {
        Log ""
        Log "   ─────────────────────────────────────────────────"
        Log "   💡 SUGGERIMENTI:"
        
        # Downloads
        try {
            $downloadsPath = [Environment]::GetFolderPath('UserProfile') + "\Downloads"
            if (Test-Path $downloadsPath) {
                $dlSize = Get-FolderSizeFast -Path $downloadsPath
                $dlCount = Get-FolderItemCount -Path $downloadsPath -FilesOnly
                if ($dlCount -gt 0) {
                    Log "      → Downloads: $dlCount file, $(Format-Size $dlSize)"
                }
            }
        } catch { }
        
        # Desktop
        try {
            $desktopPath = [Environment]::GetFolderPath('Desktop')
            if (Test-Path $desktopPath) {
                $dtSize = Get-FolderSizeFast -Path $desktopPath
                $dtCount = Get-FolderItemCount -Path $desktopPath -FilesOnly
                if ($dtCount -gt 0) {
                    Log "      → Desktop: $dtCount file, $(Format-Size $dtSize)"
                }
            }
        } catch { }
        
        Log "      → Esegui pulizia completa per liberare spazio"
    }
    
    Log "==============================================================================================="
    Log ""
    
    Update-Progress 100
    Update-Status "[OK] Analisi disco" $successColor
    Flush-LogBuffer; Pump-UI
}

#endregion

#region ===== PULIZIA COMPLETA =====

function Do-CleanAll {
    <#
    .SYNOPSIS
    Esegue pulizia completa del sistema
    #>
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
    
    Log ""
    Log "╔══════════════════════════════════════════════════════════════════════════════════════════╗"
    Log "║                    PULIZIA COMPLETA SISTEMA - [$mode]                                   ║"
    Log "╚══════════════════════════════════════════════════════════════════════════════════════════╝"
    
    $results = @{}
    $startTime = Get-Date
    
    # 1. Temp
    $tempResult = Do-CleanTemp -DryRun:$DryRun
    $results["File Temporanei"] = $tempResult
    
    if (Test-Cancel) { return }
    
    # 2. Log
    $logResult = Do-CleanLogs -DryRun:$DryRun
    $results["Log e Report"] = $logResult
    
    if (Test-Cancel) { return }
    
    # 3. Browser
    if (-not $SkipBrowser) {
        $browserResult = Do-CleanBrowserCache -DryRun:$DryRun
        $results["Cache Browser"] = $browserResult
    }
    
    if (Test-Cancel) { return }
    
    # 4. Cestino
    $binResult = Do-EmptyRecycleBin -DryRun:$DryRun
    $results["Cestino"] = $binResult
    
    if (Test-Cancel) { return }
    
    # 5. Windows Update
    $wuResult = Do-CleanWindowsUpdate -DryRun:$DryRun
    $results["Windows Update"] = $wuResult
    
    if (Test-Cancel) { return }
    
    # 6. Vecchie versioni Windows
    if (-not $SkipWindowsOld) {
        $oldResult = Do-CleanWindowsOld -DryRun:$DryRun
        $results["Vecchie Versioni"] = $oldResult
    }
    
    # 7. Disk Cleanup (opzionale)
    if ($IncludeDiskCleanup -and -not $DryRun) {
        Do-DiskCleanup -IncludeSystemFiles:$IncludeSystemFiles
    }
    
    # Report finale
    if (-not (Test-Cancel)) {
        $elapsed = (Get-Date) - $startTime
        Log ""
        Log "[i] Tempo impiegato: $([Math]::Round($elapsed.TotalSeconds, 1)) secondi"
        Show-CleanupReport -Results $results -DryRun:$DryRun
    }
    
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}

#endregion

#region ===== REPORT =====

function Show-CleanupReport {
    <#
    .SYNOPSIS
    Mostra report finale della pulizia
    #>
    param(
        [hashtable]$Results,
        [switch]$DryRun
    )
    
    Log ""
    Log "╔══════════════════════════════════════════════════════════════════════════════════════════╗"
    Log "║                           REPORT PULIZIA                                                ║"
    if ($DryRun) {
        Log "║                         ⚠️  MODALITÀ SIMULAZIONE ⚠️                                      ║"
    }
    Log "╠══════════════════════════════════════════════════════════════════════════════════════════╣"
    Log "║  Categoria                    Spazio          File                                     ║"
    Log "║  ──────────────────────────── ─────────────── ─────────────────                         ║"
    
    $totalMB = [double]0
    $totalFiles = 0
    
    foreach ($key in $Results.Keys) {
        $val = $Results[$key]
        $mb = [double]$val.MB
        $files = [int]$val.Files
        $totalMB += $mb
        $totalFiles += $files
        
        $sizeStr = "{0,14} MB" -f [Math]::Round($mb, 2)
        $fileStr = "{0,16} file" -f $files
        $nameStr = "{0,-28}" -f $key.Substring(0, [Math]::Min($key.Length, 28))
        
        Log "║  $nameStr $sizeStr $fileStr  ║"
    }
    
    Log "╠══════════════════════════════════════════════════════════════════════════════════════════╣"
    
    $totalSizeStr = "{0,14} MB" -f [Math]::Round($totalMB, 2)
    $totalFileStr = "{0,16} file" -f $totalFiles
    Log "║  {0,-28} {1} {2}  ║" -f "TOTALE", $totalSizeStr, $totalFileStr
    
    if ($totalMB -ge 1024) {
        Log "║                                        ≈ $([Math]::Round($totalMB/1024, 2)) GB                              ║"
    }
    
    Log "╚══════════════════════════════════════════════════════════════════════════════════════════╝"
    Log ""
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
    'Show-CleanupReport',
    'Get-FolderSizeFast',
    'Remove-ItemSafe',
    'Format-Size'
)

#endregion
