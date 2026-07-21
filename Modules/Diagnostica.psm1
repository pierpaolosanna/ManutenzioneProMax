# ============================================================
# DIAGNOSTICA.psm1 - Diagnostica sistema (Info, Batteria, Uptime, Processi, Startup, Disco, Servizi)
# Versione: 1.0.0
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
            $r.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object { Log " $($_.Name)" }
        }
        $ru = Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue
        if ($ru) {
            $ru.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object { Log " $($_.Name)" }
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

Export-ModuleMember -Function @(
    'Do-SystemInfo',
    'Do-BatteryReport',
    'Do-Uptime',
    'Do-TopProcesses',
    'Do-StartupPrograms',
    'Do-DiskSpace',
    'Do-ServiceStatus'
)