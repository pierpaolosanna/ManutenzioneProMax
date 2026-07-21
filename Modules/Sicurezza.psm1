# ============================================================
# SICUREZZA.psm1 - Sicurezza (Defender, EventLog, HealthCheck)
# Versione: 1.0.2
# ============================================================

function Do-SecurityScan {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Defender..." $global:securityColor
    Flush-LogBuffer; Pump-UI
    
    $mp = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
    if (-not (Test-Path $mp)) { 
        $mp = "${env:ProgramFiles(x86)}\Windows Defender\MpCmdRun.exe" 
    }
    if (-not (Test-Path $mp)) {
        $pl = Get-ChildItem "$env:ProgramData\Microsoft\Windows Defender\Platform" -Directory -ErrorAction SilentlyContinue | 
            Sort-Object Name -Descending | 
            Select-Object -First 1
        if ($pl) { $mp = Join-Path $pl.FullName "MpCmdRun.exe" }
    }
    
    if (Test-Path $mp) {
        Run-ProcessRealtime $mp "-Scan -ScanType 1" "Defender Scan" 30 80
    } else {
        Log "[X] Defender non trovato."
    }
    Update-Progress 100
    Update-Status "[OK] Scan" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-EventLogErrors {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] EventLog..." $global:securityColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="
    Log "[>] Errori (7gg)"
    Log "==============================================================================================="
    try {
        $ev = Get-WinEvent -LogName System -MaxEvents 100 -ErrorAction SilentlyContinue |
            Where-Object { $_.LevelDisplayName -match "Critical|Error" -and $_.TimeCreated -gt (Get-Date).AddDays(-7) } |
            Select-Object -First 10
        if ($ev) {
            foreach ($e in $ev) {
                $m = ($e.Message -split "`n")[0]
                if ($m.Length -gt 60) { $m = $m.Substring(0, 57) + "..." }
                Log " $($e.TimeCreated.ToString('dd/MM HH:mm')) $m"
                Pump-UI
            }
        } else {
            Log " [OK] Nessun errore critico."
        }
    } catch {
        if ($_.Exception.Message -match "No events") {
            Log " [OK] Nessun errore."
        } else {
            Log "[X] $($_.Exception.Message)"
        }
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] EventLog" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-SystemHealth {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Health Check..." $global:securityColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="
    Log "[>] HEALTH CHECK SISTEMA"
    Log "==============================================================================================="
    
    $checks = @()
    Log "[...] Verifica integrità file di sistema..."
    $sfcResult = sfc /verifyonly 2>&1 | Out-String
    if ($sfcResult -match "corruzione") { 
        $checks += @{ Status = "[X]"; Test = "SFC"; Desc = "Corruzione rilevata" } 
    } else { 
        $checks += @{ Status = "[OK]"; Test = "SFC"; Desc = "Integrità OK" } 
    }
    Pump-UI
    
    Log "[...] Verifica immagine sistema..."
    $dismResult = DISM /Online /Cleanup-Image /CheckHealth 2>&1 | Out-String
    if ($dismResult -match "ripristinabile") { 
        $checks += @{ Status = "[!]"; Test = "DISM"; Desc = "Riparazione necessaria" } 
    } else { 
        $checks += @{ Status = "[OK]"; Test = "DISM"; Desc = "Immagine OK" } 
    }
    Pump-UI
    
    Log "[...] Verifica eventi critici recenti..."
    $criticalEvents = Get-WinEvent -LogName System -MaxEvents 100 -ErrorAction SilentlyContinue |
        Where-Object { $_.LevelDisplayName -match "Critical|Error" -and $_.TimeCreated -gt (Get-Date).AddDays(-7) }
    if ($criticalEvents) { 
        $checks += @{ Status = "[!]"; Test = "EventLog"; Desc = "$($criticalEvents.Count) eventi critici" } 
    } else { 
        $checks += @{ Status = "[OK]"; Test = "EventLog"; Desc = "Nessun evento critico" } 
    }
    Pump-UI
    
    Log "[...] Verifica memoria..."
    $mem = Get-CimInstance Win32_OperatingSystem
    $totalMem = [Math]::Round($mem.TotalVisibleMemorySize / 1MB, 0)
    $freeMem = [Math]::Round($mem.FreePhysicalMemory / 1MB, 0)
    $memPercent = [Math]::Round(($freeMem / $totalMem) * 100, 1)
    if ($memPercent -lt 20) { 
        $checks += @{ Status = "[!]"; Test = "Memoria"; Desc = "Bassa ($memPercent% libera)" } 
    } else { 
        $checks += @{ Status = "[OK]"; Test = "Memoria"; Desc = "$memPercent% libera" } 
    }
    Pump-UI
    
    Log ""; Log " RISULTATI HEALTH CHECK:"
    Log " ----------------------"
    foreach ($check in $checks) { Log " $($check.Status) $($check.Test): $($check.Desc)" }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Health check completato" $global:successColor
    Flush-LogBuffer; Pump-UI
}

Export-ModuleMember -Function @(
    'Do-SecurityScan',
    'Do-EventLogErrors',
    'Do-SystemHealth'
)