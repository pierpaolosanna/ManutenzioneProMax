# ============================================================
# DIAGNOSTICA.psm1 - Diagnostica sistema (Info, Batteria, Uptime, Processi, Startup, Disco, Servizi, Health Score)
# Versione: 1.1.0
# ============================================================

function Do-SystemInfo {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Sistema..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Info Sistema"; Log "==============================================================================================="
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $ram = Get-CimInstance Win32_PhysicalMemory
        $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
        Pump-UI
        Log " OS: $($os.Caption)"
        Log " CPU: $($cpu.Name)"
        Log " Cores: $($cpu.NumberOfCores)/$($cpu.NumberOfLogicalProcessors)"
        $tr = [Math]::Round(($ram | Measure-Object Capacity -Sum).Sum / 1GB, 1)
        Log " RAM: ${tr}GB"
        Log " GPU: $($gpu.Name)"
        Log ""
        foreach ($d in $disk) {
            $f = [Math]::Round($d.FreeSpace / 1GB, 1)
            $t = [Math]::Round($d.Size / 1GB, 1)
            Log " $($d.DeviceID) $([Math]::Round($t-$f,1))/${t}GB"
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Sistema" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-BatteryReport {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Batteria..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    try {
        $rp = Join-Path $global:tempDir "battery-report.html"
        & powercfg /batteryreport /output "$rp" 2>&1 | Out-Null
        if (Test-Path $rp) {
            Log "[OK] $rp"
            Start-Process $rp
        } else {
            Log "[!] Nessuna batteria."
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Update-Progress 100
    Update-Status "[OK] Batteria" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-Uptime {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Uptime..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Uptime"; Log "==============================================================================================="
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $b = $os.LastBootUpTime
        $u = (Get-Date) - $b
        Log " Boot: $($b.ToString('dd/MM/yyyy HH:mm'))"
        Log " Up: $($u.Days)g $($u.Hours)h"
        if ($u.Days -gt 7) { Log " [!] Riavvio consigliato." }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Uptime" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-TopProcesses {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Processi..." $global:cpuColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Top CPU"; Log "==============================================================================================="
    try {
        $procs = Get-Process | Where-Object { $_.CPU -gt 0 } | Sort-Object CPU -Descending | Select-Object -First 12
        foreach ($p in $procs) {
            Log (" {0,-28} {1,6}s {2,5}MB" -f $p.ProcessName, [Math]::Round($p.CPU, 1), [Math]::Round($p.WorkingSet64 / 1MB, 0))
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Processi" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-StartupPrograms {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Startup..." $global:cpuColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Startup"; Log "==============================================================================================="
    try {
        $r = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
        if ($r) {
            $r.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object { Log " [Registro-Macchina] $($_.Name)" }
        }
        $ru = Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
        if ($ru) {
            $ru.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object { Log " [Registro-Utente] $($_.Name)" }
        }

        # NUOVO: cartelle Startup fisiche (shell:startup), non coperte prima
        $startupFolders = @(
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
        )
        foreach ($folder in $startupFolders) {
            if (Test-Path $folder) {
                Get-ChildItem $folder -File -ErrorAction SilentlyContinue | ForEach-Object {
                    Log " [Cartella] $($_.Name)"
                }
            }
            Pump-UI
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Startup" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-DiskSpace {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Disco..." $global:maintColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Spazio disco"; Log "==============================================================================================="
    try {
        $up = $env:USERPROFILE
        $fl = @("$up\Downloads", "$up\Desktop", "$up\Documents", "$up\AppData\Local", "${env:SystemDrive}\Program Files")
        $res = @()
        foreach ($f in $fl) {
            if (Test-Cancel) { return }
            if (Test-Path $f) {
                try {
                    $sz = (Get-ChildItem $f -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                    if (-not $sz) { $sz = 0 }
                    $res += @{ P = $f; S = $sz }
                } catch { }
            }
            Pump-UI
        }
        $res = $res | Sort-Object { $_.S } -Descending
        foreach ($r in $res) {
            $d = if ($r.S -ge 1GB) { "$([Math]::Round($r.S/1GB,1))GB" } else { "$([Math]::Round($r.S/1MB,0))MB" }
            Log (" {0,-40} {1,7}" -f $r.P.Replace($up, "~"), $d)
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Disco" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-ServiceStatus {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Servizi..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Servizi"; Log "==============================================================================================="
    $svcs = @(
        @{ N = "wuauserv"; D = "WinUpdate" },
        @{ N = "WinDefend"; D = "Defender" },
        @{ N = "mpssvc"; D = "Firewall" },
        @{ N = "BITS"; D = "BITS" },
        @{ N = "Dnscache"; D = "DNS" }
    )
    foreach ($svc in $svcs) {
        try {
            $s = Get-Service -Name $svc.N -ErrorAction Stop
            $st = if ($s.Status -eq "Running") { "OK" } else { "--" }
            Log " [$st] $($svc.D)"
        } catch {
            Log " [??] $($svc.D)"
        }
        Pump-UI
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Servizi" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-DiskHealth {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Salute dischi..." $global:maintColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Salute Dischi (SMART)"; Log "==============================================================================================="
    try {
        $disks = Get-PhysicalDisk -ErrorAction Stop
        foreach ($d in $disks) {
            $tag = switch ($d.HealthStatus) {
                "Healthy"   { "OK" }
                "Warning"   { "!!" }
                "Unhealthy" { "XX" }
                default     { "??" }
            }
            Log (" [{0}] {1} - {2} ({3})" -f $tag, $d.FriendlyName, $d.HealthStatus, $d.MediaType)
            Pump-UI
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Salute dischi" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-EventLogCheck {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Log eventi..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Errori recenti (ultime 48h)"; Log "==============================================================================================="
    try {
        $since = (Get-Date).AddHours(-48)
        $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'System','Application'; Level = 1,2; StartTime = $since } -ErrorAction SilentlyContinue |
            Sort-Object TimeCreated -Descending | Select-Object -First 15)
        if ($events.Count -gt 0) {
            foreach ($e in $events) {
                $lvl = if ($e.Level -eq 1) { "CRIT" } else { "ERR " }
                Log (" [{0}] {1} {2} (ID {3})" -f $lvl, $e.TimeCreated.ToString('dd/MM HH:mm'), $e.ProviderName, $e.Id)
                Pump-UI
            }
        } else {
            Log " Nessun errore critico rilevato."
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Log eventi" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-DefenderStatus {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Windows Defender..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Windows Defender"; Log "==============================================================================================="
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        Log " Protezione real-time: $(if ($mp.RealTimeProtectionEnabled) {'Attiva'} else {'DISATTIVA'})"
        Log " Antivirus attivo: $(if ($mp.AntivirusEnabled) {'Si'} else {'No'})"
        Log " Definizioni: $($mp.AntivirusSignatureVersion) (aggiornate: $($mp.AntivirusSignatureLastUpdated.ToString('dd/MM/yyyy HH:mm')))"
        Log " Ultima scansione rapida: $(if ($mp.QuickScanEndTime) { $mp.QuickScanEndTime.ToString('dd/MM/yyyy HH:mm') } else { 'Mai eseguita' })"
        Log " Ultima scansione completa: $(if ($mp.FullScanEndTime) { $mp.FullScanEndTime.ToString('dd/MM/yyyy HH:mm') } else { 'Mai eseguita' })"
        $age = ((Get-Date) - $mp.AntivirusSignatureLastUpdated).Days
        if ($age -gt 7) { Log " [!] Definizioni antivirus non aggiornate da $age giorni." }
    } catch {
        Log "[i] Windows Defender non disponibile (probabile antivirus di terze parti attivo): $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Windows Defender" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-BitLockerStatus {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] BitLocker..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] BitLocker"; Log "==============================================================================================="
    try {
        $volumes = Get-BitLockerVolume -ErrorAction Stop
        foreach ($v in $volumes) {
            Log (" {0}: {1} (crittografato: {2}%)" -f $v.MountPoint, $v.ProtectionStatus, $v.EncryptionPercentage)
            Pump-UI
        }
    } catch {
        Log "[i] BitLocker non disponibile su questa edizione/sistema."
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] BitLocker" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-PagefileStatus {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Memoria virtuale..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Memoria Virtuale (Pagefile)"; Log "==============================================================================================="
    try {
        $pf = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue
        $auto = (Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile
        Log " Gestione automatica: $(if ($auto) {'Si'} else {'No (manuale)'})"
        if ($pf) {
            foreach ($p in $pf) {
                Log (" {0}: {1}MB allocati, {2}MB in uso attualmente" -f $p.Name, $p.AllocatedBaseSize, $p.CurrentUsage)
            }
        } else {
            Log " Nessun file di paging attivo."
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Memoria virtuale" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-RestorePoints {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Ripristino config..." $global:maintColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Punti di Ripristino"; Log "==============================================================================================="
    try {
        $points = Get-ComputerRestorePoint -ErrorAction Stop | Sort-Object CreationTime -Descending
        if ($points) {
            Log " Trovati $($points.Count) punti di ripristino:"
            foreach ($p in ($points | Select-Object -First 10)) {
                $dt = [Management.ManagementDateTimeConverter]::ToDateTime($p.CreationTime)
                Log ("   - {0} {1}" -f $dt.ToString('dd/MM/yyyy HH:mm'), $p.Description)
                Pump-UI
            }
        } else {
            Log " [!] Nessun punto di ripristino trovato."
        }
    } catch {
        Log "[!] Ripristino configurazione di sistema non disponibile o disattivato."
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Ripristino config." $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-SystemFileCheck {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Integrita sistema..." $global:maintColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Integrita File di Sistema"; Log "==============================================================================================="
    try {
        Log "[...] Controllo rapido componenti Windows (DISM CheckHealth, non invasivo)..."
        $out = & DISM.exe /Online /Cleanup-Image /CheckHealth 2>&1
        foreach ($line in $out) {
            if ($line -match '\S') { Log " $line" }
        }
        Log ""
        Log "[i] Per una scansione approfondita usare 'DISM /ScanHealth' o 'sfc /scannow' (piu lenti)."
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Integrita sistema" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-WindowsUpdateStatus {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Windows Update..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Windows Update"; Log "==============================================================================================="
    try {
        $svc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
        if ($svc) { Log " Servizio Windows Update: $($svc.Status)" }
        Log "[i] Ricerca aggiornamenti in corso, puo richiedere alcuni minuti..."
        Pump-UI
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $result = $searcher.Search("IsInstalled=0 and IsHidden=0")
        Log " Aggiornamenti in sospeso: $($result.Updates.Count)"
        $i = 0
        foreach ($u in $result.Updates) {
            if ($i -ge 10) { break }
            Log "   - $($u.Title)"
            $i++
            Pump-UI
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Windows Update" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-HealthScore {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Calcolo Health Score..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] SYSTEM HEALTH SCORE"; Log "==============================================================================================="

    $score = 100
    $issues = @()

    try {
        # --- Spazio disco di sistema ---
        $sysDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction SilentlyContinue
        if ($sysDisk -and $sysDisk.Size -gt 0) {
            $freePct = [Math]::Round(($sysDisk.FreeSpace / $sysDisk.Size) * 100, 1)
            Log " Spazio libero su $($env:SystemDrive): $freePct%"
            if ($freePct -lt 10) { $score -= 25; $issues += "Spazio disco quasi esaurito ($freePct% libero)" }
            elseif ($freePct -lt 20) { $score -= 15; $issues += "Spazio disco basso ($freePct% libero)" }
            elseif ($freePct -lt 30) { $score -= 5; $issues += "Spazio disco limitato ($freePct% libero)" }
        }
        Pump-UI

        # --- Uptime e RAM ---
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $uptimeDays = ((Get-Date) - $os.LastBootUpTime).Days
            Log " Uptime: $uptimeDays giorni"
            if ($uptimeDays -gt 14) { $score -= 10; $issues += "Sistema attivo da $uptimeDays giorni senza riavvio" }
            elseif ($uptimeDays -gt 7) { $score -= 5; $issues += "Riavvio consigliato (attivo da $uptimeDays giorni)" }

            $ramUsedPct = [Math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 1)
            Log " RAM in uso: $ramUsedPct%"
            if ($ramUsedPct -gt 90) { $score -= 10; $issues += "Utilizzo RAM molto elevato ($ramUsedPct%)" }
            elseif ($ramUsedPct -gt 80) { $score -= 5; $issues += "Utilizzo RAM elevato ($ramUsedPct%)" }
        }
        Pump-UI

        # --- Servizi critici ---
        $criticalSvcs = @(
            @{ N = "WinDefend"; D = "Windows Defender"; W = 15 },
            @{ N = "mpssvc";    D = "Firewall";          W = 15 },
            @{ N = "wuauserv";  D = "Windows Update";    W = 5 },
            @{ N = "BITS";      D = "BITS";              W = 5 }
        )
        foreach ($svc in $criticalSvcs) {
            try {
                $s = Get-Service -Name $svc.N -ErrorAction Stop
                if ($s.Status -ne "Running") {
                    $score -= $svc.W
                    $issues += "Servizio $($svc.D) non attivo"
                    Log " [!] $($svc.D): $($s.Status)"
                } else {
                    Log " [OK] $($svc.D)"
                }
            } catch {
                Log " [??] $($svc.D) non trovato"
            }
            Pump-UI
        }

        # --- Salute dischi (SMART) ---
        try {
            $disks = Get-PhysicalDisk -ErrorAction Stop
            foreach ($d in $disks) {
                if ($d.HealthStatus -eq "Unhealthy") {
                    $score -= 30; $issues += "Disco '$($d.FriendlyName)' in stato critico (SMART)"
                    Log " [XX] $($d.FriendlyName): $($d.HealthStatus)"
                } elseif ($d.HealthStatus -eq "Warning") {
                    $score -= 10; $issues += "Disco '$($d.FriendlyName)' in stato di attenzione (SMART)"
                    Log " [!!] $($d.FriendlyName): $($d.HealthStatus)"
                } else {
                    Log " [OK] $($d.FriendlyName): $($d.HealthStatus)"
                }
            }
        } catch { Log " [??] Impossibile leggere lo stato SMART dei dischi" }
        Pump-UI

        # --- Windows Defender ---
        try {
            $mp = Get-MpComputerStatus -ErrorAction Stop
            $defAge = ((Get-Date) - $mp.AntivirusSignatureLastUpdated).Days
            if (-not $mp.RealTimeProtectionEnabled) {
                $score -= 15; $issues += "Protezione real-time Defender disattivata"
                Log " [!] Protezione real-time disattivata"
            }
            if ($defAge -gt 7) {
                $score -= 10; $issues += "Definizioni antivirus non aggiornate da $defAge giorni"
                Log " [!] Definizioni antivirus vecchie di $defAge giorni"
            } else {
                Log " [OK] Definizioni antivirus aggiornate ($defAge giorni fa)"
            }
        } catch { Log " [i] Windows Defender non disponibile (altro antivirus attivo?)" }
        Pump-UI

        # --- Errori critici recenti ---
        try {
            $since = (Get-Date).AddHours(-48)
            $critEvents = @(Get-WinEvent -FilterHashtable @{ LogName = 'System','Application'; Level = 1,2; StartTime = $since } -ErrorAction SilentlyContinue)
            $count = $critEvents.Count
            Log " Errori critici (ultime 48h): $count"
            if ($count -gt 10) { $score -= 15; $issues += "$count errori critici nelle ultime 48h" }
            elseif ($count -gt 3) { $score -= 5; $issues += "$count errori critici nelle ultime 48h" }
        } catch { Log " [??] Impossibile leggere il registro eventi" }
        Pump-UI

        # --- Riavvio in sospeso ---
        $rebootPending = $false
        if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") { $rebootPending = $true }
        if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") { $rebootPending = $true }
        if ($rebootPending) {
            $score -= 5; $issues += "Riavvio in sospeso per completare aggiornamenti"
            Log " [!] Riavvio in sospeso"
        }

        $score = [Math]::Max(0, [Math]::Min(100, $score))
        $rating = if ($score -ge 90) { "OTTIMO" }
                  elseif ($score -ge 75) { "BUONO" }
                  elseif ($score -ge 60) { "SUFFICIENTE" }
                  elseif ($score -ge 40) { "SCARSO" }
                  else { "CRITICO" }

        Log ""
        Log " PUNTEGGIO COMPLESSIVO: $score/100 - $rating"
        if ($issues.Count -gt 0) {
            Log ""
            Log " Problemi rilevati:"
            foreach ($i in $issues) { Log "   - $i" }
        } else {
            Log " Nessun problema rilevante rilevato."
        }

        # --- Report HTML riepilogativo ---
        try {
            $rp = Join-Path $global:tempDir "health-score-report.html"
            $color = if ($score -ge 75) { "#2ecc71" } elseif ($score -ge 40) { "#f39c12" } else { "#e74c3c" }
            $issuesHtml = if ($issues.Count -gt 0) { ($issues | ForEach-Object { "<li>$_</li>" }) -join "" } else { "<li>Nessun problema rilevante rilevato.</li>" }
            $html = @"
<!DOCTYPE html><html><head><meta charset='utf-8'><title>System Health Report</title>
<style>body{font-family:'Segoe UI',Arial,sans-serif;background:#1e1e1e;color:#eee;padding:30px}
.score{font-size:64px;font-weight:bold;color:$color}
.rating{font-size:24px;color:$color;margin-bottom:20px}
h1{color:#fff} ul{line-height:1.8}</style></head><body>
<h1>System Health Report</h1>
<p>Generato: $(Get-Date -Format 'dd/MM/yyyy HH:mm')</p>
<div class='score'>$score/100</div>
<div class='rating'>$rating</div>
<h2>Problemi rilevati</h2>
<ul>$issuesHtml</ul>
</body></html>
"@
            Set-Content -Path $rp -Value $html -Encoding UTF8
            Log ""
            Log "[OK] Report salvato: $rp"
            Start-Process $rp
        } catch {
            Log "[!] Impossibile generare il report HTML: $($_.Exception.Message)"
        }

    } catch {
        Log "[X] $($_.Exception.Message)"
    }

    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Health Score: $score/100" $(if ($score -ge 75) { $global:successColor } else { $global:infoColor })
    Flush-LogBuffer; Pump-UI
}

Export-ModuleMember -Function @(
    'Do-SystemInfo',
    'Do-BatteryReport',
    'Do-Uptime',
    'Do-TopProcesses',
    'Do-StartupPrograms',
    'Do-DiskSpace',
    'Do-ServiceStatus',
    'Do-DiskHealth',
    'Do-EventLogCheck',
    'Do-DefenderStatus',
    'Do-BitLockerStatus',
    'Do-PagefileStatus',
    'Do-RestorePoints',
    'Do-SystemFileCheck',
    'Do-WindowsUpdateStatus',
    'Do-HealthScore'
)
