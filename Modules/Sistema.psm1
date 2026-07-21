# ============================================================
# SISTEMA.psm1 - Ottimizzazioni sistema (Visivi, Avvio, CPU, TPM)
# Versione: 1.0.0
# ============================================================

function Do-OptimizeVisual {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Log ""; Log "==============================================================================================="; Log "[>] OTTIMIZZAZIONE EFFETTI VISIVI"; Log "==============================================================================================="
    Update-Status "[...] Ottimizzazione visiva..." $global:cpuColor
    Flush-LogBuffer; Pump-UI
    try {
        $vfxPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if (!(Test-Path $vfxPath)) { New-Item -Path $vfxPath -Force | Out-Null }
        Set-ItemProperty -Path $vfxPath -Name "VisualFXSetting" -Value 3 -Force
        Log " [OK] Modalita effetti visivi: Personalizzata"
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value "0" -Force
        $wmPath = "HKCU:\Control Panel\Desktop\WindowMetrics"
        if (!(Test-Path $wmPath)) { New-Item -Path $wmPath -Force | Out-Null }
        Set-ItemProperty -Path $wmPath -Name "MinAnimate" -Value "0" -Force
        $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $advPath -Name "TaskbarAnimations" -Value 0 -Force
        Set-ItemProperty -Path $advPath -Name "ListviewAlphaSelect" -Value 0 -Force
        Log " [OK] Animazioni e trasparenze disabilitate"
        $dwmPath = "HKCU:\Software\Microsoft\Windows\DWM"
        if (!(Test-Path $dwmPath)) { New-Item -Path $dwmPath -Force | Out-Null }
        Set-ItemProperty -Path $dwmPath -Name "EnableAeroPeek" -Value 1 -Force
        Log " [OK] Attiva Peek: SI"
        Set-ItemProperty -Path $advPath -Name "IconsOnly" -Value 0 -Force
        Log " [OK] Anteprime anziche icone: SI"
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 1 -Force -ErrorAction SilentlyContinue
        $upm = [byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value $upm -Type Binary -Force
        Log " [OK] Ombreggiatura finestre: SI"
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value "2" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothingType" -Value 2 -Force
        Log " [OK] Smussatura caratteri (ClearType): SI"
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "SmoothScroll" -Value 1 -Force -ErrorAction SilentlyContinue
        Log " [OK] Scorrimento uniforme caselle: SI"
        Set-ItemProperty -Path $advPath -Name "ListviewShadow" -Value 1 -Force
        Log " [OK] Ombreggiatura etichette icone: SI"
        Log ""; Log " [i] Riavvio Explorer per applicare..."
        Flush-LogBuffer; Pump-UI
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Process explorer
        Start-Sleep -Seconds 1
        Log ""; Log "[OK] Effetti visivi ottimizzati!"
        Update-Status "[OK] Effetti visivi ottimizzati" $global:successColor
    } catch {
        Log "[X] $($_.Exception.Message)"
        Update-Status "[X] Errore ottimizzazione" $global:exitColor
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}

function Do-BootOptimization {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) { Log "[X] Admin richiesto"; Update-Progress 100; return }
    Update-Status "[...] Ottimizzazione avvio..." $global:cpuColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] OTTIMIZZAZIONE AVVIO SISTEMA"; Log "==============================================================================================="
    try {
        $activeScheme = powercfg /getactivescheme 2>&1 | Select-String -Pattern "{(.*?)}"
        if ($activeScheme -and $activeScheme.Matches) {
            $guid = $activeScheme.Matches[0].Groups[1].Value
            powercfg /setacvalueindex $guid SUB_SLEEP 94ac6d29-73ce-41a6-809f-6363ba21b47e 1
            powercfg /setdcvalueindex $guid SUB_SLEEP 94ac6d29-73ce-41a6-809f-6363ba21b47e 1
            Log "[OK] Avvio veloce abilitato"
        } else {
            Log "[!] Impossibile determinare il piano energetico attivo"
        }
    } catch {
        Log "[!] Errore avvio veloce: $($_.Exception.Message)"
    }
    $services = @{
        "SysMain" = "Automatic"
        "MapsBroker" = "Disabled"
        "RetailDemo" = "Disabled"
        "XblAuthManager" = "Manual"
        "XboxNetApiSvc" = "Manual"
        "XboxGipSvc" = "Manual"
    }
    foreach ($svc in $services.GetEnumerator()) {
        try {
            Set-Service -Name $svc.Key -StartupType $svc.Value -ErrorAction SilentlyContinue
            Log "[OK] $($svc.Key): $($svc.Value)"
        } catch {
            Log "[!] $($svc.Key): non modificabile"
        }
        Pump-UI
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Ottimizzazione avvio" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-UnlockCPU {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) {
        Log "[X] Admin."
        Update-Status "[!] Admin" $global:warningColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    Update-Status "[...] CPU..." $global:cpuColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] CPU Unlock"; Log "==============================================================================================="
    $cat = "54533251-82be-4824-96c1-47b60b740d00"
    $ss = @(
        "be337238-0d82-4146-a960-4f3749d470c7", "5d76a2ca-e8c0-402f-a133-2158492d58ad",
        "893dee8e-2bef-41e0-89c6-b55d0929964c", "bc5038f7-23e0-4960-96da-33abaf5935ec",
        "0cc5b647-c1df-4637-891a-dec35c318583", "ea062031-0e34-4ff1-9b6d-eb1059334028",
        "68dd2f27-a4ce-4e11-8487-3794e4135dfa", "2ddd5a84-5a71-437e-912a-db0b8c788732",
        "4b92d758-5a24-4851-a470-815d78aee119", "d6ba4903-386f-4c2c-8adb-5c21b3328d25",
        "45bcc044-d885-43e2-8605-ee0ec6e96b59", "36687f9e-e3a5-4dbf-b1dc-15eb381c6863",
        "cfeda3d0-7697-4566-a922-a9086cd49dfa", "fddc842b-8364-4edc-94cf-c17f60de1c80"
    )
    $ok = 0
    foreach ($g in $ss) {
        $p = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$cat\$g"
        if (Test-Path $p) {
            try {
                Set-ItemProperty -Path $p -Name "Attributes" -Value 2 -ErrorAction Stop
                $ok++
            } catch { }
        }
        Pump-UI
    }
    Log "[OK] $ok/$($ss.Count) sbloccate."
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] CPU ($ok)" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-TpmCpuRamUnlock {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Sblocco TPM/CPU/RAM..." $global:securityColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] RIMOZIONE LIMITAZIONI WINDOWS 11"; Log "==============================================================================================="
    try {
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\CompatMarkers" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Shared" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators" -Recurse -Force -ErrorAction SilentlyContinue
        Log "[OK] Pulizia completata."
    } catch {
        Log "[X] Errore pulizia: $($_.Exception.Message)"
    }
    try {
        $path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\HwReqChk"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "HwReqChkVars" -Value @("SQ_SecureBootCapable=TRUE", "SQ_SecureBootEnabled=TRUE", "SQ_TpmVersion=2", "SQ_RamMB=8192") -Type MultiString -Force -ErrorAction Stop
        Log "[OK] Valori hardware applicati."
    } catch {
        Log "[X] Errore impostazione valori: $($_.Exception.Message)"
    }
    try {
        $path = "HKLM:\SYSTEM\Setup\MoSetup"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -Type DWord -Force -ErrorAction Stop
        Log "[OK] Policy abilitata."
    } catch {
        Log "[X] Errore policy: $($_.Exception.Message)"
    }
    try {
        $path = "HKCU:\Software\Microsoft\PCHC"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "UpgradeEligibility" -Value 1 -Type DWord -Force -ErrorAction Stop
        Log "[OK] Flag eleggibilità impostata."
    } catch {
        Log "[X] Errore flag: $($_.Exception.Message)"
    }
    Log ""; Log "[OK] TUTTE LE OPERAZIONI COMPLETATE!"
    Log "[i] Ora puoi avviare l'upgrade a Windows 11 tramite Assistente o setup.exe."
    Log "[i] Nessun riavvio richiesto."
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Sblocco completato" $global:successColor
    Flush-LogBuffer; Pump-UI
    [System.Windows.Forms.MessageBox]::Show("Limiti TPM/CPU/RAM rimossi con successo!`n`nPuoi ora eseguire l'upgrade a Windows 11.`nNessun riavvio è necessario.", "Sblocco Completato", "OK", "Information")
}

Export-ModuleMember -Function @(
    'Do-OptimizeVisual',
    'Do-BootOptimization',
    'Do-UnlockCPU',
    'Do-TpmCpuRamUnlock'
)