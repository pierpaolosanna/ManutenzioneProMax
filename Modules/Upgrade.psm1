# ============================================================
# UPGRADE.psm1 - Gestione aggiornamenti
# Versione: 1.2.0 - AGGIUNTO SDI DRIVER
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


function Do-RepairWinget {
    <#
    .SYNOPSIS
    Ripristina le origini di winget e risolve gli errori comuni (cache corrotta, 404, ecc.)
    #>
    [CmdletBinding()]
    param()
    
    if ($script:isClosing -or (Test-Cancel)) { return }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] RIPRISTINO WINGET"
    Log "==============================================================================================="
    Update-Progress 10
    Update-Status "[...] Ripristino winget..." $maintColor
    Flush-LogBuffer; Pump-UI
    
    # Timeout per i comandi winget (120 secondi)
    $wingetTimeout = 120000  # millisecondi
    
    # 1. Verifica che winget sia disponibile
    try {
        Log "[...] Verifica winget..."
        Flush-LogBuffer; Pump-UI
        
        $proc = Start-Process -FilePath "winget" -ArgumentList "--version" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\winget_ver.txt" -RedirectStandardError "$env:TEMP\winget_ver.err"
        $proc.WaitForExit($wingetTimeout)
        
        if ($proc.ExitCode -ne 0) {
            $errContent = Get-Content "$env:TEMP\winget_ver.err" -ErrorAction SilentlyContinue -Raw
            Log "[X] winget non risponde (timeout dopo $([Math]::Round($wingetTimeout/1000))s)"
            if ($errContent) { Log "[X] Errore: $errContent" }
            Remove-Item "$env:TEMP\winget_ver*" -Force -ErrorAction SilentlyContinue
            Update-Status "[!] winget non risponde" $warningColor
            Flush-LogBuffer; Update-Progress 100; Pump-UI
            return
        }
        
        $ver = (Get-Content "$env:TEMP\winget_ver.txt" -ErrorAction SilentlyContinue).Trim()
        Remove-Item "$env:TEMP\winget_ver*" -Force -ErrorAction SilentlyContinue
        Log "[OK] winget trovato (v$ver)"
    } catch {
        Log "[X] Errore verifica: $($_.Exception.Message)"
        Update-Status "[X] Errore" $exitColor
        Flush-LogBuffer; Update-Progress 100; Pump-UI
        return
    }
    
    # 2. Pulisci la cache di winget
    Log "[...] Pulizia cache..."
    Flush-LogBuffer; Pump-UI
    
    try {
        $cachePaths = @(
            "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalCache",
            "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir",
            "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\TempState"
        )
        
        $cleaned = 0
        foreach ($path in $cachePaths) {
            if (Test-Path $path) {
                $items = Get-ChildItem -Path $path -Force -ErrorAction SilentlyContinue
                if ($items.Count -gt 0) {
                    Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                    $cleaned += $items.Count
                }
            }
        }
        
        if ($cleaned -gt 0) {
            Log "[OK] Cache pulita ($cleaned file)"
        } else {
            Log "[OK] Cache già pulita"
        }
    } catch {
        Log "[!] Pulizia cache: $($_.Exception.Message)"
    }
    
    # 3. Imposta lingua italiana (per l'output)
    $originalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    try {
        $itCulture = [System.Globalization.CultureInfo]::GetCultureInfo("it-IT")
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $itCulture
    } catch { }
    
    # 4. Resetta le origini
    Log "[...] Reset origini..."
    Flush-LogBuffer; Pump-UI
    
    $resetCommands = @(
        @{ Cmd = "source reset --name winget"; Name = "winget" },
        @{ Cmd = "source reset --name msstore"; Name = "msstore" },
        @{ Cmd = "source reset --force"; Name = "tutte" }
    )
    
    foreach ($item in $resetCommands) {
        if (Test-Cancel) { break }
        
        try {
            Log "[...] $($item.Name)..."
            Flush-LogBuffer; Pump-UI
            
            $proc = Start-Process -FilePath "winget" -ArgumentList $item.Cmd -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\winget_out.txt" -RedirectStandardError "$env:TEMP\winget_err.txt"
            
            # Attendi con timeout
            if (-not $proc.WaitForExit($wingetTimeout)) {
                Log "[!] Timeout reset $($item.Name) ($([Math]::Round($wingetTimeout/1000))s)"
                $proc.Kill()
                continue
            }
            
            $output = Get-Content "$env:Temp\winget_out.txt" -ErrorAction SilentlyContinue | Where-Object { $_.Trim() }
            $errors = Get-Content "$env:TEMP\winget_err.txt" -ErrorAction SilentlyContinue | Where-Object { $_.Trim() }
            
            if ($proc.ExitCode -eq 0 -and -not $errors) {
                Log "[OK] $($item.Name): Reset completato"
            } else {
                Log "[!] $($item.Name): Codice $($proc.ExitCode)"
                if ($errors) {
                    $errors | Select-Object -First 3 | ForEach-Object { Log "    $_" }
                }
            }
            
            Remove-Item "$env:TEMP\winget_*.txt" -Force -ErrorAction SilentlyContinue
        } catch {
            Log "[!] Errore reset: $($_.Exception.Message)"
        }
        
        Pump-UI
    }
    
    # 5. Aggiorna le origini
    Log "[...] Aggiornamento origini..."
    Flush-LogBuffer; Pump-UI
    
    try {
        $proc = Start-Process -FilePath "winget" -ArgumentList "source update" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\winget_out.txt" -RedirectStandardError "$env:TEMP\winget_err.txt"
        
        if (-not $proc.WaitForExit($wingetTimeout)) {
            Log "[!] Timeout aggiornamento ($([Math]::Round($wingetTimeout/1000))s)"
            $proc.Kill()
        }
        
        $output = Get-Content "$env:TEMP\winget_out.txt" -ErrorAction SilentlyContinue | Where-Object { $_.Trim() }
        foreach ($line in $output) {
            Log "   $line"
            Pump-UI
        }
        
        $errors = Get-Content "$env:TEMP\winget_err.txt" -ErrorAction SilentlyContinue | Where-Object { $_.Trim() }
        if ($errors) {
            Log "[!] Errori:"
            $errors | Select-Object -First 3 | ForEach-Object { Log "    $_" }
        }
        
        if ($proc.ExitCode -eq 0) {
            Log "[OK] Origini aggiornate"
        } else {
            Log "[!] Completato con codice: $($proc.ExitCode)"
        }
        
        Remove-Item "$env:TEMP\winget_*.txt" -Force -ErrorAction SilentlyContinue
    } catch {
        Log "[!] Errore aggiornamento: $($_.Exception.Message)"
    }
    
    # 6. Mostra stato finale
    Log ""
    Log "[...] Stato finale..."
    Flush-LogBuffer; Pump-UI
    
    try {
        $proc = Start-Process -FilePath "winget" -ArgumentList "source list" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\winget_out.txt"
        $proc.WaitForExit($wingetTimeout)
        
        $output = Get-Content "$env:TEMP\winget_out.txt" -ErrorAction SilentlyContinue | Where-Object { $_.Trim() }
        
        if ($output.Count -gt 0) {
            Log "   Origini configurate:"
            foreach ($line in $output) {
                Log "   $line"
            }
        } else {
            Log "   [i] Nessuna origine configurata"
        }
        
        Remove-Item "$env:TEMP\winget_out.txt" -Force -ErrorAction SilentlyContinue
    } catch {
        Log "[!] Impossibile elencare origini: $($_.Exception.Message)"
    }
    
    # Ripristina cultura originale
    try {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture
    } catch { }
    
    Log ""
    Log "==============================================================================================="
    Log "[OK] Ripristino winget completato"
    Log "==============================================================================================="
    Log ""
    
    Update-Progress 100
    Update-Status "[OK] Winget ripristinato" $successColor
    Flush-LogBuffer; Pump-UI
}



function Do-InstallChocolatey {
    <#
    .SYNOPSIS
    Verifica/installa Chocolatey automaticamente tramite PowerShell, senza aprire browser.
    #>
    [CmdletBinding()]
    param(
        [switch]$ForceUpdate
    )
    
    if ($script:isClosing -or (Test-Cancel)) { return }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] CHOCOLATEY - Gestore Pacchetti Alternativo"
    Log "==============================================================================================="
    Update-Progress 10
    Update-Status "[...] Chocolatey..." $maintColor
    Flush-LogBuffer; Pump-UI
    
    # 1. Cerca Chocolatey (Nessun ForEach-Object, nessun break)
    $chocoExe = $null
    $chocoPaths = @(
        "$env:ProgramData\chocolatey\bin\choco.exe",
        "$env:ProgramData\chocolatey\choco.exe"
    )
    foreach ($path in $chocoPaths) {
        if (-not $chocoExe -and (Test-Path $path -ErrorAction SilentlyContinue)) {
            $chocoExe = $path
        }
    }
    
    # ================== INSTALLAZIONE AUTOMATICA ==================
    if (-not $chocoExe) {
        Log "[i] Chocolatey non installato. Avvio dell'installazione automatica..."
        Log "[i] Questo potrebbe richiedere alcuni minuti..."
        Flush-LogBuffer; Pump-UI
        
        try {
            # Imposta lingua italiana
            $originalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try {
                $itCulture = [System.Globalization.CultureInfo]::GetCultureInfo("it-IT")
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $itCulture
            } catch { }
            
            # Comando di installazione ufficiale
            $installScript = "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
            
            # Determina quale PowerShell usare
            $psExe = if ($PSVersionTable.PSEdition -eq 'Core') { "pwsh.exe" } else { "powershell.exe" }
            
            Log "[...] Esecuzione script di installazione (richiede privilegi admin)..."
            Flush-LogBuffer; Pump-UI
            
            # Avvia il processo in modo sicuro
            try {
                $proc = Start-Process -FilePath $psExe -ArgumentList "-NoProfile -Command `"$installScript`"" -Wait -PassThru -NoNewWindow -ErrorAction Stop
            } catch {
                Log "[X] Errore nell'avvio del processo di installazione: $($_.Exception.Message)"
                try { [System.Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture } catch { }
                Update-Status "[X] Errore installazione" $exitColor
                Flush-LogBuffer; Update-Progress 100; Pump-UI
                return
            }
            
            # Verifica esito
            if ($proc.ExitCode -eq 0) {
                # Cerca l'eseguibile nuovamente (senza break)
                $newPaths = @("$env:ProgramData\chocolatey\bin\choco.exe", "$env:ProgramData\chocolatey\choco.exe")
                foreach ($path in $newPaths) {
                    if (Test-Path $path -ErrorAction SilentlyContinue) {
                        $chocoExe = $path
                    }
                }
                
                if ($chocoExe) {
                    Log "[OK] Chocolatey installato con successo"
                } else {
                    Log "[!] Installazione completata ma eseguibile non trovato (verifica manuale necessaria)"
                }
            } else {
                Log "[X] Installazione fallita (codice: $($proc.ExitCode))"
            }
            
            # Ripristina lingua
            try { [System.Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture } catch { }
            
        } catch {
            Log "[X] Errore installazione: $($_.Exception.Message)"
            try { [System.Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture } catch { }
            Update-Status "[X] Errore installazione" $exitColor
            Flush-LogBuffer; Update-Progress 100; Pump-UI
            return
        }
    } else {
        Log "[OK] Chocolatey trovato: $chocoExe"
    }
    # ================== FINE INSTALLAZIONE ==================
    
    # 2. Ottieni versione
    $version = "N/D"
    if ($chocoExe) {
        try {
            $proc = Start-Process -FilePath $chocoExe -ArgumentList "--version" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\choco_ver.txt" -RedirectStandardError "$env:TEMP\choco_err.txt"
            if ($proc.WaitForExit(30000)) {
                $version = (Get-Content "$env:TEMP\choco_ver.txt" -ErrorAction SilentlyContinue).Trim()
            }
            Remove-Item "$env:TEMP\choco_*.txt" -Force -ErrorAction SilentlyContinue
        } catch { }
        Log "[OK] Trovato in: $($chocoExe)"
        if ($version -ne "N/D") { Log "[OK] Versione: $version" }
    }
    Log ""
    
    # 3. Configurazione base
    Log "[...] Configurazione..."
    Flush-LogBuffer; Pump-UI
    
    try {
        $configDir = "$env:ProgramData\chocolatey\config"
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Force -Path $configDir | Out-Null
        }
        
        $configPath = "$configDir\chocolatey.config"
        if (-not (Test-Path $configPath)) {
            @"
<?xml version="1.0" encoding="utf-8"?>
<chocolatey xmlns="http://schemas.datacontract.org/2004/07/chocolatey">
  <config>
    <proxy />
    <timeout>300</timeout>
    <shutdown_timeout>30</shutdown_timeout>
  </config>
"@ | Out-File -FilePath $configPath -Encoding UTF8 -Force
            Log "[OK] Configurazione base creata"
        } else {
            Log "[OK] Configurazione già presente"
        }
    } catch {
        Log "[!] Impossibile creare configurazione: $($_.Exception.Message)"
    }
    
    # 4. Aggiorna se richiesto
    if ($ForceUpdate -and $chocoExe) {
        Log "[...] Aggiornamento Chocolatey (potrebbe richiedere parecchi minuti)..."
        Flush-LogBuffer; Pump-UI
        
        try {
            $proc = Start-Process -FilePath $chocoExe -ArgumentList "upgrade chocolatey -y" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\choco_upg.txt" -RedirectStandardError "$env:TEMP\choco_err.txt"
            
            if (-not $proc.WaitForExit(300000)) {
                Log "[!] Timeout, forzato arresto"
                $proc.Kill()
            }
            
            $output = Get-Content "$env:TEMP\choco_upg.txt" -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -and $_ -notmatch "^Chocolatey upgraded" }
            foreach ($line in $output) { Log "   $line"; Pump-UI }
            
            $errors = Get-Content "$env:TEMP\choco_err.txt" -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -and $_ -notmatch "Progress" }
            if ($errors) {
                Log "[!] Errori:"
                $errors | Select-Object -First 5 | ForEach-Object { Log "   $_" }
            }
            
            Log ""
            if ($proc.ExitCode -eq 0) {
                Log "[OK] Chocolatey aggiornato"
            } else {
                Log "[!] Completato con avvisi (codice: $($proc.ExitCode))"
            }
            
            Remove-Item "$env:TEMP\choco_*.txt" -Force -ErrorAction SilentlyContinue
        } catch {
            Log "[!] Errore aggiornamento: $($_.Exception.Message)"
        }
    }
    
    # 5. Pulizia cache vecchi
    Log "[...] Pulizia cache..."
    Flush-LogBuffer; Pump-UI
    
    try {
        $cachePath = "$env:LOCALAPPDATA\chocolatey\cache"
        if (Test-Path $cachePath) {
            $oldFiles = Get-ChildItem -Path $cachePath -File -ErrorAction SilentlyContinue | 
                        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
            if ($oldFiles.Count -gt 0) {
                $oldFiles | Remove-Item -Force -ErrorAction SilentlyContinue
                Log "[OK] Rimossi $($oldFiles.Count) file cache vecchi"
            } else {
                Log "[OK] Cache pulita"
            }
        }
    } catch {
        Log "[!] Pulizia cache: $($_.Exception.Message)"
    }
    
    # 6. Stato finale
    Log "[...] Stato..."
    Flush-LogBuffer; Pump-UI
    
    try {
        $proc = Start-Process -FilePath $chocoExe -ArgumentList "list --local-only" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\choco_list.txt" -RedirectStandardError "$env:TEMP\choco_err.txt"
        $proc.WaitForExit(60000)
        
        $output = Get-Content "$env:TEMP\choco_list.txt" -ErrorAction SilentlyContinue | Where-Object { $_.Trim() }
        
        if ($output.Count -gt 0) {
            $installed = ($output | Where-Object { $_ -notmatch "^Chocolatey v" }).Count
            Log "[OK] Pacchetti installati: $installed"
        } else {
            Log "[i] Nessun pacchetto installato"
        }
        
        Remove-Item "$env:TEMP\choco_*.txt" -Force -ErrorAction SilentlyContinue
    } catch {
        Log "[!] Impossibile elencare pacchetti"
    }
    
    Log ""
    Log "==============================================================================================="
    Log "[OK] Chocolatey pronto"
    Log ""
    Log "╔═══════════════════════════════════════════════════════════════════════════════╗"
    Log "║  COMANDI CHOCOLATEY:                                                      ║"
    Log "╠═══════════════════════════════════════════════════════════════════════════════╣"
    Log "║                                                                           ║"
    Log "║  choco install <pacchetto>        Installa un pacchetto                      ║"
    Log "║  choco upgrade <pacchetto>        Aggiorna un pacchetto                    ║"
    Log "║  choco uninstall <pacchetto>      Disinstalla un pacchetto                 ║"
    Log "║  choco search <pacchetto>         Cerca un pacchetto                     ║"
    Log "║  choco list --local-only         Elenca pacchetti installati           ║"
    Log "║                                                                       ║"
    Log "║  Alternativa veloce:                                                         ║"
    Log "║    choco upgrade all -y            Aggiorna TUTTI i pacchetti              ║"
    Log "║                                                                       ║"
    Log "╚═════════════════════════════════════════════════════════════════════════════╝"
    Log "==============================================================================================="
    Log ""
    
    Update-Progress 100
    Update-Status "[OK] Chocolatey pronto" $successColor
    Flush-LogBuffer; Pump-UI
}

function Do-ChocolateyUpgrade {
    <#
    .SYNOPSIS
    Aggiorna tutti i pacchetti installati con Chocolatey.
    Mostra prima i pacchetti con aggiornamenti disponibili.
    Equivalente a: choco upgrade all -y (o con --force se specificato)
    #>
    [CmdletBinding()]
    param(
        [switch]$Force,
        [switch]$DryRun
    )
    
    if ($script:isClosing -or (Test-Cancel)) { return }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] CHOCOLATEY - Aggiornamento Pacchetti$(if ($DryRun) { ' [SIMULAZIONE]' } else { '' })"
    Log "==============================================================================================="
    Update-Progress 10
    Update-Status "[...] Verifica Chocolatey..." $maintColor
    Flush-LogBuffer; Pump-UI
    
    # 1. Verifica che Chocolatey sia installato
    $chocoExe = $null
    @(
        "$env:ProgramData\chocolatey\bin\choco.exe",
        "$env:ProgramData\chocolatey\choco.exe"
    ) | ForEach-Object {
        if (-not $chocoExe -and (Test-Path $_)) { $chocoExe = $_ }
    }
    
    if (-not $chocoExe) {
        Log "[X] Chocolatey non installato. Usa 'Installa Chocolatey' prima."
        Update-Status "[X] Chocolatey non trovato" $warningColor
        Flush-LogBuffer; Update-Progress 100; Pump-UI
        return
    }
    
    # Ottieni versione di Chocolatey
    try {
        $proc = Start-Process -FilePath $chocoExe -ArgumentList "--version" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\choco_ver.txt"
        $proc.WaitForExit(30000)
        $ver = (Get-Content "$env:TEMP\choco_ver.txt" -ErrorAction SilentlyContinue).Trim()
        Remove-Item "$env:TEMP\choco_ver.txt" -Force -ErrorAction SilentlyContinue
        Log "[OK] Chocolatey v$ver"
    } catch {
        Log "[i] Impossibile ottenere versione"
    }
    
    # 2. Verifica se ci sono pacchetti installati
    Log "[...] Verifica pacchetti installati..."
    Flush-LogBuffer; Pump-UI
    
    $packages = Get-ChocolateyPackages
    
    if (-not $packages -or $packages.Count -eq 0) {
        Log "[i] Nessun pacchetto installato con Chocolatey."
        Update-Status "[OK] Nessun pacchetto" $successColor
        Flush-LogBuffer; Update-Progress 100; Pump-UI
        return
    }
    
    Log "[OK] Trovati $($packages.Count) pacchetti installati"
    foreach ($pkg in $packages) {
        Log "   - $($pkg.Name) ($($pkg.Version))"
        Pump-UI
    }
    Log ""
    
    # 3. Verifica pacchetti obsoleti
    Log "[...] Controllo aggiornamenti disponibili..."
    Flush-LogBuffer; Pump-UI
    
    $outdated = Get-ChocolateyOutdated
    
    if ($outdated -and $outdated.Count -gt 0) {
        Log "[OK] Trovati $($outdated.Count) pacchetti con aggiornamenti:"
        foreach ($pkg in $outdated) {
            Log "   - $($pkg.Name): $($pkg.Current) → $($pkg.Latest)"
            Pump-UI
        }
        Log ""
    } else {
        if ($Force) {
            Log "[i] Nessun aggiornamento disponibile, ma il flag -Force eseguirà il re-install."
        } else {
            Log "[OK] Nessun pacchetto da aggiornare."
            Log "   Suggerimento: usa -Force per forzare il re-install anche senza aggiornamenti."
            Update-Status "[OK] Già aggiornato" $successColor
            Flush-LogBuffer; Update-Progress 100; Pump-UI
            return
        }
    }
    
    # 4. Se è una simulazione, termina qui
    if ($DryRun) {
        Log ""
        if ($outdated -and $outdated.Count -gt 0) {
            Log "[SIM] Verrebbero aggiornati $($outdated.Count) pacchetti:"
            foreach ($pkg in $outdated) {
                Log "   - $($pkg.Name): $($pkg.Current) → $($pkg.Latest)"
            }
        } elseif ($Force) {
            Log "[SIM] Forzato re-install di tutti i $($packages.Count) pacchetti."
        } else {
            Log "[SIM] Nessuna operazione da eseguire."
        }
        Update-Status "[OK] Simulazione completata" $successColor
        Flush-LogBuffer; Update-Progress 100; Pump-UI
        return
    }
    
    # 5. Chiedi conferma solo se ci sono aggiornamenti o se è forzato
    if ($outdated -and $outdated.Count -gt 0) {
        $msg = "Trovati $($outdated.Count) pacchetti aggiornabili:`n`n"
        $outdated | ForEach-Object { $msg += "$($_.Name): $($_.Current) → $($_.Latest)`n" }
        $msg += "`nProcedere con l'aggiornamento?"
        $confirm = [System.Windows.Forms.MessageBox]::Show($msg, "Conferma Aggiornamento", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    } elseif ($Force) {
        $msg = "Nessun aggiornamento disponibile, ma il flag -Force forzerà il re-install.`n`nProcedere?"
        $confirm = [System.Windows.Forms.MessageBox]::Show($msg, "Conferma Forzatura", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    } else {
        return
    }
    
    if ($confirm -ne "Yes") {
        Log "[i] Operazione annullata dall'utente"
        Update-Status "[OK] Annullato" $successColor
        Flush-LogBuffer; Update-Progress 100; Pump-UI
        return
    }
    
    # 6. Esegui l'aggiornamento
    Log ""
    Log "[...] Aggiornamento pacchetti Chocolatey in corso..."
    Log "[i] Questo potrebbe richiedere diversi minuti..."
    Flush-LogBuffer; Pump-UI
    
    try {
        # Costruisci il comando
        $args = "upgrade all -y"
        if ($Force) { $args += " --force" }
        
        # Aggiungi --limit-output per facilitare il parsing (opzionale)
        # $args += " --limit-output"
        
        $proc = Start-Process -FilePath $chocoExe -ArgumentList $args -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\choco_upgrade.txt" -RedirectStandardError "$env:TEMP\choco_upgrade.err"
        
        # Timeout 10 minuti
        $timeout = 600000
        $elapsed = 0
        while (-not $proc.HasExited -and $elapsed -lt $timeout) {
            Start-Sleep -Milliseconds 500
            $elapsed += 500
            if ($elapsed % 5000 -eq 0) {
                Update-Status "[...] Chocolatey in corso... $([Math]::Round($elapsed/1000))s" $maintColor
                Flush-LogBuffer; Pump-UI
            }
            if (Test-Cancel) { $proc.Kill(); return }
        }
        
        if (-not $proc.HasExited) {
            Log "[!] Timeout superato ($([Math]::Round($timeout/60000)) minuti), forzato arresto..."
            $proc.Kill()
            Start-Sleep -Milliseconds 500
            Log "[!] Processo terminato forzatamente"
        }
        
        # Leggi output
        $output = Get-Content "$env:TEMP\choco_upgrade.txt" -ErrorAction SilentlyContinue | Where-Object { $_.Trim() }
        $errors = Get-Content "$env:TEMP\choco_upgrade.err" -ErrorAction SilentlyContinue | Where-Object { $_.Trim() }
        
        # Mostra le righe significative (escludi quelle di progresso)
        $showLines = $output | Where-Object { 
            $_ -notmatch "^Progress" -and 
            $_ -notmatch "^  \(" -and
            $_ -notmatch "_____" -and
            $_.Trim() -ne ""
        }
        
        $counter = 0
        foreach ($line in $showLines) {
            if ($counter -ge 30) { 
                Log "   ... (altre righe omesse)"
                break 
            }
            if ($line -match "\[(OK|FAIL|WARN)\]" -or $line -match "upgraded|success|error|warning" -or $line -match "Installing|Downloading") {
                Log "   $line"
                $counter++
            }
            Pump-UI
        }
        
        if ($errors) {
            Log "[!] Errori riscontrati:"
            $errors | Select-Object -First 5 | ForEach-Object { Log "   $_" }
        }
        
        if ($proc.ExitCode -eq 0) {
            Log ""
            Log "[OK] Aggiornamento Chocolatey completato con successo"
        } else {
            Log ""
            Log "[!] Aggiornamento completato con codice: $($proc.ExitCode)"
        }
        
        Remove-Item "$env:TEMP\choco_upgrade.txt" -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\choco_upgrade.err" -Force -ErrorAction SilentlyContinue
        
        # Mostra riepilogo finale
        $newOutdated = Get-ChocolateyOutdated
        if ($newOutdated -and $newOutdated.Count -gt 0) {
            Log ""
            Log "[!] Attenzione: alcuni pacchetti non sono stati aggiornati:"
            foreach ($pkg in $newOutdated) {
                Log "   - $($pkg.Name): $($pkg.Current) (latest: $($pkg.Latest))"
            }
        } else {
            Log "[OK] Tutti i pacchetti sono aggiornati!"
        }
        
    } catch {
        Log "[X] Errore durante l'aggiornamento: $($_.Exception.Message)"
    }
    
    Log ""
    Log "==============================================================================================="
    Log "[OK] Chocolatey Upgrade completato"
    Log "==============================================================================================="
    Log ""
    
    Update-Progress 100
    Update-Status "[OK] Chocolatey Upgrade" $successColor
    Flush-LogBuffer; Pump-UI
}



function Get-ChocolateyPackages {
    <#
    .SYNOPSIS
    Ottiene l'elenco dei pacchetti installati con Chocolatey, filtrando eventuali righe corrotte (nome vuoto).
    #>
    $chocoExe = $null
    @("$env:ProgramData\chocolatey\bin\choco.exe", "$env:ProgramData\chocolatey\choco.exe") | ForEach-Object {
        if (-not $chocoExe -and (Test-Path $_)) { $chocoExe = $_ }
    }
    
    if (-not $chocoExe) { return $null }
    
    try {
        $tempFile = "$env:TEMP\choco_list_$([guid]::NewGuid().ToString('N')).txt"
        $proc = Start-Process -FilePath $chocoExe -ArgumentList "list --local-only --limit-output" -NoNewWindow -PassThru -RedirectStandardOutput $tempFile -RedirectStandardError "$tempFile.err"
        $proc.WaitForExit(30000)
        
        # Filtro per escludere righe con Name vuoto (il famoso "()" o "| |")
        $packages = Get-Content $tempFile -ErrorAction SilentlyContinue | Where-Object { $_ -match "\|" } | ForEach-Object {
            $parts = $_ -split "\|"
            if ($parts.Count -ge 2 -and $parts[0].Trim() -ne "") {
                [PSCustomObject]@{ 
                    Name = $parts[0].Trim(); 
                    Version = $parts[1].Trim() 
                }
            }
        }
        
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        Remove-Item "$tempFile.err" -Force -ErrorAction SilentlyContinue
        return $packages
    } catch {
        return $null
    }
}



function Get-ChocolateyOutdated {
    <#
    .SYNOPSIS
    Mostra i pacchetti Chocolatey che possono essere aggiornati, escludendo le voci corrotte.
    #>
    [CmdletBinding()]
    param()
    
    $chocoExe = $null
    @("$env:ProgramData\chocolatey\bin\choco.exe", "$env:ProgramData\chocolatey\choco.exe") | ForEach-Object {
        if (-not $chocoExe -and (Test-Path $_)) { $chocoExe = $_ }
    }
    
    if (-not $chocoExe) {
        Log "[X] Chocolatey non installato."
        return $null
    }
    
    try {
        $tempFile = "$env:TEMP\choco_outdated_$([guid]::NewGuid().ToString('N')).txt"
        $proc = Start-Process -FilePath $chocoExe -ArgumentList "outdated --limit-output" -NoNewWindow -PassThru -RedirectStandardOutput $tempFile -RedirectStandardError "$tempFile.err"
        $proc.WaitForExit(60000)  # Più tempo perché contatta i repository
        
        # Filtro per escludere righe con Name vuoto (il bug del ciclo infinito)
        $outdated = Get-Content $tempFile -ErrorAction SilentlyContinue | Where-Object { $_ -match "\|" } | ForEach-Object {
            $parts = $_ -split "\|"
            if ($parts.Count -ge 4 -and $parts[0].Trim() -ne "") {
                [PSCustomObject]@{
                    Name    = $parts[0].Trim()
                    Current = $parts[1].Trim()
                    Latest  = $parts[2].Trim()
                    Pin     = $parts[3].Trim()
                }
            }
        }
        
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        Remove-Item "$tempFile.err" -Force -ErrorAction SilentlyContinue
        
        return $outdated
    } catch {
        Log "[!] Errore: $($_.Exception.Message)"
        return $null
    }
}



function Update-EdgeBrowser {
    if (Test-Cancel) { return }
    if (-not (Test-WingetAvailable)) { return }
    
    Log ""
    Log "==============================================================================================="
    Log "[>] AGGIORNAMENTO EDGE"
    Log "==============================================================================================="
    Update-Status "[...] Edge..." $fgColor
    Flush-LogBuffer; Pump-UI
    
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
    
    winget upgrade "Microsoft.Edge" --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    
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
        Flush-LogBuffer; Update-Progress 100; return
    }
    
    $wuDrivers = @()
    $wingetDrivers = @()
    
    Log "[1/2] Ricerca driver via Windows Update..."
    Flush-LogBuffer; Pump-UI
    
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $wuResult = $searcher.Search("IsInstalled=0 and Type='Driver'")
        Pump-UI
        
        if ($wuResult.Updates.Count -gt 0) {
            foreach ($d in $wuResult.Updates) {
                $wuDrivers += [PSCustomObject]@{ Source = "WU"; Title = $d.Title; Driver = $d }
            }
            Log "[OK] Windows Update: Trovati $($wuDrivers.Count) driver"
            foreach ($d in $wuDrivers) { Log "      → $($d.Title)"; Pump-UI }
        } else {
            Log "[OK] Windows Update: Nessun driver disponibile"
        }
    } catch {
        Log "[!] Windows Update: $($_.Exception.Message)"
    }
    
    Log ""
    Log "[2/2] Ricerca driver via Winget..."
    Flush-LogBuffer; Pump-UI
    
    if (Test-WingetAvailable) {
        try {
            $tempFile = "$env:TEMP\winget_drivers_$([guid]::NewGuid().ToString('N')).txt"
            $process = Start-Process -FilePath "winget" -ArgumentList "list --upgrade-available --accept-source-agreements" -NoNewWindow -Wait -PassThru -RedirectStandardOutput $tempFile -RedirectStandardError "$tempFile.err"
            $output = Get-Content $tempFile -ErrorAction SilentlyContinue
            
            foreach ($line in $output) {
                if ($line -and $line.Trim() -and 
                    $line -match "driver|Driver|GPU|NVIDIA|nvidia|AMD|amd|Intel|intel|Realtek|realtek|Audio|audio|Wireless|wireless|Bluetooth|bluetooth|Wi-Fi|LAN|Chipset|chipset|Graphics|graphics|Display|display|Network|network" -and
                    $line -notmatch "^---" -and $line -notmatch "^Nome" -and $line -notmatch "^Name" -and $line -notmatch "Nessun aggiornamento" -and $line -notmatch "non è stato trovato" -and $line -notmatch "include-unknown") {
                    $parts = $line -split "\s{2,}"
                    $id = if ($parts.Count -ge 2) { $parts[1].Trim() } else { $null }
                    $wingetDrivers += [PSCustomObject]@{ Source = "Winget"; Title = $line.Trim(); Id = $id }
                }
            }
            
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            Remove-Item "$tempFile.err" -Force -ErrorAction SilentlyContinue
            
            if ($wingetDrivers.Count -gt 0) {
                Log "[OK] Winget: Trovati $($wingetDrivers.Count) driver"
                foreach ($d in $wingetDrivers) { Log "      → $($d.Title)"; Pump-UI }
            } else {
                Log "[OK] Winget: Nessun driver disponibile"
            }
        } catch {
            Log "[!] Winget: $($_.Exception.Message)"
        }
    } else {
        Log "[!] Winget: Non disponibile"
    }
    
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
    
    $response = [System.Windows.Forms.MessageBox]::Show("Trovati $totalDrivers driver aggiornabili:`n`nWindows Update: $($wuDrivers.Count)`nWinget: $($wingetDrivers.Count)`n`nScegliere fonte:", "Aggiornamento Driver", "YesNoCancel", "Question")
    
    $installWU = $false
    $installWinget = $false
    
    if ($response -eq [System.Windows.Forms.DialogResult]::Cancel) {
        Log "[i] Operazione annullata dall'utente"
        Log "==============================================================================================="
        Log ""
        Update-Progress 100; Update-Status "[OK] Driver" $successColor; Flush-LogBuffer; Pump-UI
        return
    }
    
    if ($wuDrivers.Count -gt 0 -and $wingetDrivers.Count -gt 0) {
        if ($response -eq "Yes") { $installWU = $true; $installWinget = $true; Log "[i] Scelta: ENTRAMBI" }
        elseif ($response -eq "No") { $installWinget = $true; Log "[i] Scelta: Solo Winget" }
    } elseif ($wuDrivers.Count -gt 0) {
        if ($response -eq "Yes") { $installWU = $true; Log "[i] Scelta: Windows Update" }
    } elseif ($wingetDrivers.Count -gt 0) {
        if ($response -eq "Yes") { $installWinget = $true; Log "[i] Scelta: Winget" }
    }
    
    Log ""
    
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
                
                Log ""; Log "[RISULTATI WU]:"
                for ($i = 0; $i -lt $wuResult.Updates.Count; $i++) {
                    $res = $installResult.GetUpdateResult($i)
                    $status = if ($res.ResultCode -eq 2) { "[OK]" } else { "[X] Codice: $($res.ResultCode)" }
                    Log "   $status $($wuResult.Updates.Item($i).Title)"
                    Pump-UI
                }
                if ($installResult.RebootRequired) { Log ""; Log "[!] RIAVVIO NECESSARIO per attivare i driver WU" }
            } else {
                Log "[X] Errore download (codice: $($downloadResult.ResultCode))"
            }
        } catch {
            Log "[X] Errore installazione WU: $($_.Exception.Message)"
        }
        Log ""
    }
    
    if ($installWinget -and $wingetDrivers.Count -gt 0) {
        Log "==============================================================================================="
        Log "[INSTALLAZIONE] Winget - $($wingetDrivers.Count) driver"
        Log "==============================================================================================="
        Flush-LogBuffer; Pump-UI
        
        $installed = 0; $failed = 0
        foreach ($d in $wingetDrivers) {
            if (Test-Cancel) { break }
            if ($d.Id) {
                Log "[i] Installazione: $($d.Id)"
                Flush-LogBuffer; Pump-UI
                winget upgrade $d.Id --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) { Log "[OK] Installato: $($d.Id)"; $installed++ }
                elseif ($LASTEXITCODE -eq -1978335189) { Log "[OK] Già aggiornato: $($d.Id)"; $installed++ }
                else { Log "[!] Errore ($LASTEXITCODE): $($d.Id)"; $failed++ }
                Pump-UI
            }
        }
        Log ""; Log "[RIEPILOGO WINGET]: Successo: $installed | Errori: $failed"; Log ""
    }
    
    Log "==============================================================================================="
    Log "[OK] Aggiornamento driver completato"
    Log "==============================================================================================="
    Log ""
    Update-Progress 100
    Update-Status "[OK] Driver" $successColor
    Flush-LogBuffer; Pump-UI
}

# ===== SDI DRIVER - PORTATILE =====
# ===== SDI DRIVER - COMPLETO FUNZIONANTE =====
function Do-DriverSDI {
    if (Test-Cancel) { return }

    Log ""
    Log "==============================================================================================="
    Log "[>] SNAPPY DRIVER INSTALLER (Portatile)"
    Log "==============================================================================================="
    Update-Status "[...] SDI..." $accentColor
    Flush-LogBuffer; Pump-UI

    # Percorsi
    $libDir   = Join-Path $global:scriptRoot "lib"
    $sdiDir   = Join-Path $libDir "SDI"
    $sdiZip   = Join-Path $libDir "SDI_1.26.1.7z"
    $sevenZip = Join-Path $libDir "7za.exe"     # <-- 7za.exe locale

    # URL corretto
    $sdiUrl  = "https://download.instalki.org/programy/Windows/Narzedzia/zarzadzanie_sterownikami/SDI_1.26.1.7z"

    Log "[i] Cartella lib: $libDir"
    Log ""

    # 1) Crea cartella lib
    if (-not (Test-Path $libDir)) {
        New-Item -ItemType Directory -Force -Path $libDir | Out-Null
        Log "[i] Creata cartella lib"
    }

    # 2) Verifica presenza 7za.exe
    if (-not (Test-Path $sevenZip)) {
        Log "[X] ERRORE: 7za.exe non trovato in lib"
        Log "[i] Percorso atteso: $sevenZip"
        Update-Status "[X] 7za.exe mancante" $warningColor
        Flush-LogBuffer; Pump-UI
        return
    }

    # 3) DOWNLOAD SDI
    if (-not (Test-Path $sdiZip)) {
        Log "[i] Download SDI in: $sdiZip"
        Flush-LogBuffer; Pump-UI

        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $sdiUrl -OutFile $sdiZip
            Log "[OK] Download completato: $sdiZip"
        }
        catch {
            Log "[X] Errore download: $($_.Exception.Message)"
            Update-Status "[X] Errore download SDI" $warningColor
            Flush-LogBuffer; Pump-UI
            return
        }
    }
    else {
        Log "[i] File SDI già presente: $sdiZip"
    }

    # 4) CREA CARTELLA SDI
    if (-not (Test-Path $sdiDir)) {
        New-Item -ItemType Directory -Force -Path $sdiDir | Out-Null
        Log "[i] Creata cartella SDI: $sdiDir"
    }

    # 5) ESTRAZIONE CON 7za.exe
    Log "[i] Estrazione contenuto in: $sdiDir"
    Flush-LogBuffer; Pump-UI

    try {
        # Sintassi corretta per 7za.exe (senza virgolette dopo -o)
        & $sevenZip x $sdiZip "-o$sdiDir" -y 2>&1 | Out-Null
        Log "[OK] Estrazione completata in: $sdiDir"
    }
    catch {
        Log "[X] Errore estrazione: $($_.Exception.Message)"
        Update-Status "[X] Errore estrazione SDI" $warningColor
        Flush-LogBuffer; Pump-UI
        return
    }

    # 6) RICERCA ESEGUIBILI SDI
    Log "[i] Ricerca eseguibili SDI..."
    Flush-LogBuffer; Pump-UI

    $allExe = Get-ChildItem -Path $sdiDir -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue

    # Preferisci 64 bit
    $candidate64 = $allExe | Where-Object {
        $_.Name -match "x64" -or $_.Name -match "64"
    } | Select-Object -First 1

    # Altrimenti 32 bit
    $candidate32 = $allExe | Where-Object {
        $_.Name -notmatch "x64" -and $_.Name -notmatch "64"
    } | Select-Object -First 1

    if ($candidate64) {
        $sdiExe = $candidate64.FullName
        Log "[OK] Eseguibile 64 bit trovato: $($candidate64.Name)"
    }
    elseif ($candidate32) {
        $sdiExe = $candidate32.FullName
        Log "[OK] Eseguibile 32 bit trovato: $($candidate32.Name)"
    }
    else {
        Log "[X] Nessun eseguibile SDI trovato dopo l’estrazione."
        Log "[i] Contenuto cartella SDI:"
        Get-ChildItem -Path $sdiDir -Recurse | ForEach-Object {
            Log " - $($_.FullName)"
        }
        Update-Status "[X] SDI non avviabile" $warningColor
        Flush-LogBuffer; Pump-UI
        return
    }

    # 7) AVVIO SDI
    Log "[i] Avvio SDI..."
    try {
        Start-Process $sdiExe -Verb RunAs
        Log "[OK] SDI avviato correttamente"
    }
    catch {
        Log "[X] Errore avvio SDI: $($_.Exception.Message)"
        Update-Status "[X] Errore avvio SDI" $warningColor
        Flush-LogBuffer; Pump-UI
        return
    }

    Log "[i] File in: $sdiDir"
    Log "==============================================================================================="
    Update-Progress 100
    Update-Status "[OK] SDI" $successColor
    Flush-LogBuffer; Pump-UI
}





function Remove-SDITemp {
    Log "[i] Pulizia file SDI temporanei..."
    $removed = 0
    Get-ChildItem "$env:TEMP\SDI_*" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Log "[OK] Rimosso: $($_.Name)"
        $removed++
    }
    Remove-Item "$env:TEMP\sdi_*.7z" -Force -ErrorAction SilentlyContinue
    
    if ($removed -eq 0) {
        Log "[OK] Nessun file SDI da pulire"
    } else {
        Log "[OK] Rimossi $removed cartelle SDI"
    }
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
    Update-EdgeBrowser
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
    'Update-EdgeBrowser',
    'Do-StoreUpdate',
    'Do-SearchWU',
    'Do-InstallWU',
    'Do-DriverUpdate',
    'Do-DriverSDI',
    'Do-InstallChocolatey',
    'Do-ChocolateyUpgrade',
    'Remove-SDITemp',
    'Do-RepairWinget',
    'Do-FullUpdate',
    'Do-RunAll',
    'Test-WingetAvailable'
)
