
# ============================================================
# PULIZIA.psm1 - Pulizia temporanei, log, disco
# Versione: 1.0.0
# ============================================================

function Do-CleanTemp {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Log ""; Log "==============================================================================================="; Log "[>] PULIZIA Temp"; Log "==============================================================================================="
    Update-Progress 90
    Update-Status "[...] Pulizia..." $fgColor
    Flush-LogBuffer; Pump-UI
    $paths = @(
        @{ Path = $env:TEMP; Name = "Temp" },
        @{ Path = "$env:LOCALAPPDATA\Temp"; Name = "Local" },
        @{ Path = "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache"; Name = "INet" },
        @{ Path = "$env:USERPROFILE\AppData\Local\CrashDumps"; Name = "Crash" }
    )
    if ($isAdmin) { $paths += @{ Path = "$env:WINDIR\Temp"; Name = "WinTemp" } }
    $tot = [long]0
    foreach ($p in $paths) {
        if (Test-Cancel) { return }
        if (Test-Path $p.Path) {
            try {
                $items = Get-ChildItem -Path $p.Path -Force -Recurse -ErrorAction SilentlyContinue
                $sz = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if (-not $sz) { $sz = 0 }
                $cnt = ($items | Measure-Object).Count
                if ($cnt -gt 0) {
                    Remove-Item "$($p.Path)\*" -Recurse -Force -ErrorAction SilentlyContinue
                    $tot += $sz
                }
                Log " [$($p.Name)] $cnt, $([Math]::Round($sz/1MB,1))MB"
            } catch { }
        }
        Pump-UI
    }
    $mb = [Math]::Round($tot / 1MB, 1)
    Log ""; Log "[OK] Liberati: ${mb}MB"
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Pulizia (${mb}MB)" $successColor
    Flush-LogBuffer; Pump-UI
}

function Do-DiskCleanup {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $isAdmin) {
        Log "[X] Admin."
        Update-Status "[!] Admin" $warningColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    Update-Status "[...] Cleanup..." $maintColor
    Flush-LogBuffer; Pump-UI
    try {
        $cp = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        if (Test-Path $cp) {
            Get-ChildItem $cp -ErrorAction SilentlyContinue | ForEach-Object {
                Set-ItemProperty -Path $_.PSPath -Name "StateFlags0100" -Value 2 -ErrorAction SilentlyContinue
            }
        }
        Run-ProcessRealtime "cleanmgr" "/sagerun:100" "Disk Cleanup" 80 95
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Update-Progress 100
    Update-Status "[OK] Cleanup" $successColor
    Flush-LogBuffer; Pump-UI
}

function Do-CleanLogs {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Log pulizia..." $maintColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] PULIZIA FILE DI LOG E DUMP"; Log "==============================================================================================="
    $logPaths = @("$env:WINDIR\Logs\*", "$env:WINDIR\System32\LogFiles\*", "$env:PROGRAMDATA\Microsoft\Windows\WER\*")
    $totalFreed = 0
    foreach ($path in $logPaths) {
        if (Test-Path $path) {
            try {
                $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                $size = ($items | Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
                if ($size -gt 0) {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    $totalFreed += $size
                    Log "[OK] Pulito: $path ($([Math]::Round($size/1MB,1)) MB)"
                }
            } catch {
                Log "[!] Accesso negato a $path"
            }
        }
        Pump-UI
    }
    Log ""; Log "[OK] Liberati $([Math]::Round($totalFreed/1MB,1)) MB"
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Log puliti" $successColor
    Flush-LogBuffer; Pump-UI
}

function Do-DiskAnalysis {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Analisi Disco..." $maintColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] ANALISI SPAZIO DISCO DETTAGLIATA"; Log "==============================================================================================="
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    $totalSize = 0; $totalFree = 0
    foreach ($drive in $drives) {
        $size = [Math]::Round($drive.Size / 1GB, 2)
        $free = [Math]::Round($drive.FreeSpace / 1GB, 2)
        $used = $size - $free
        $percent = [Math]::Round(($used / $size) * 100, 1)
        Log " [$($drive.DeviceID)] $used GB / $size GB ($percent% usato)"
        if ($percent -gt 85) { Log "   [!] ATTENZIONE: Spazio critico!" }
        $totalSize += $size; $totalFree += $free
        Pump-UI
    }
    Log ""; Log " TOTALE: $([Math]::Round($totalSize-$totalFree, 2)) / $([Math]::Round($totalSize, 2)) GB"
    Log " LIBERO: $([Math]::Round($totalFree, 2)) GB"
    if ($totalFree / $totalSize -lt 0.2) {
        Log ""; Log " [!] SUGGERIMENTI:"
        Log "    - Esegui 'Pulizia temp' e 'Disk Cleanup'"
        $downloadsSize = [Math]::Round((Get-ChildItem ~/Downloads -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB, 2)
        Log "    - Controlla Downloads: ${downloadsSize}GB"
        Log "    - Usa 'Spazio Disco' per identificare cartelle grandi"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Analisi disco" $successColor
    Flush-LogBuffer; Pump-UI
}

Export-ModuleMember -Function @(
    'Do-CleanTemp',
    'Do-DiskCleanup',
    'Do-CleanLogs',
    'Do-DiskAnalysis'
)