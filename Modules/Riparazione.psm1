# ============================================================
# RIPARAZIONE.psm1 - Riparazione sistema (SFC, DISM, RestorePoint)
# Versione: 1.0.0
# ============================================================

function Do-RestorePoint {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) {
        Log "[X] Admin richiesto."
        Update-Status "[!] Admin" $global:warningColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    Update-Status "[...] Creazione Punto di Ripristino..." $global:repairColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Punto Ripristino"; Log "==============================================================================================="
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    $regName = "SystemRestorePointCreationFrequency"
    $originalValue = $null
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Pump-UI
        if (Test-Path $regPath) {
            $originalValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
            Set-ItemProperty -Path $regPath -Name $regName -Value 0 -Type DWord -ErrorAction Stop
        }
        Checkpoint-Computer -Description "PRO MAX $(Get-Date -Format 'dd/MM HH:mm')" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Log "[OK] Punto di ripristino creato con successo."
    } catch {
        Log "[X] Errore durante la creazione: $($_.Exception.Message)"
    } finally {
        try {
            if ($null -ne $originalValue) {
                Set-ItemProperty -Path $regPath -Name $regName -Value $originalValue -Type DWord -ErrorAction SilentlyContinue
            } else {
                Set-ItemProperty -Path $regPath -Name $regName -Value 1440 -Type DWord -ErrorAction SilentlyContinue
            }
        } catch { }
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Ripristino" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-RepairSystem {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) {
        Log "[X] Admin."
        Update-Status "[!] Admin" $global:warningColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    Update-Status "[...] SFC..." $global:repairColor
    Flush-LogBuffer; Pump-UI
    Run-ProcessRealtime "sfc" "/scannow" "SFC" 20 50
    if (Test-Cancel) { return }
    Update-Status "[...] DISM..." $global:repairColor
    Flush-LogBuffer; Pump-UI
    Run-ProcessRealtime "DISM" "/Online /Cleanup-Image /RestoreHealth" "DISM" 50 85
    Update-Progress 100
    Update-Status "[OK] Riparazione" $global:successColor
    Flush-LogBuffer; Pump-UI
}

Export-ModuleMember -Function @(
    'Do-RestorePoint',
    'Do-RepairSystem'
)