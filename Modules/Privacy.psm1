# ============================================================
# PRIVACY.psm1 - Privacy (Windows, Office, Edge, Tasks, All)
# Versione: 1.0.0
# ============================================================

function Set-RegistryPrivacy {
    param([string]$Title, [array]$Settings)
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) {
        Log "[X] Admin richiesto"
        Update-Status "[!] Admin" $global:warningColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    Update-Status "[...] $Title..." $global:securityColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] DISABILITA TELEMETRIA $($Title.ToUpper())"; Log "==============================================================================================="
    $count = 0; $errors = 0
    foreach ($s in $Settings) {
        try {
            if (-not (Test-Path $s.Path)) { New-Item -Path $s.Path -Force | Out-Null }
            Set-ItemProperty -Path $s.Path -Name $s.Name -Value $s.Value -Force -ErrorAction Stop
            $count++; Log "[OK] $($s.Name) = $($s.Value)"
        } catch {
            $errors++; Log "[!] $($s.Name): $($_.Exception.Message)"
        }
        Pump-UI
    }
    Log ""; Log "[OK] Impostazioni $Title : $count OK, $errors errori"
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Privacy $Title ($count modifiche)" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-PrivacyWindows {
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"; Name = "DisabledByGroupPolicy"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableSoftLanding"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name = "DisableWindowsConsumerFeatures"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "DoNotShowFeedbackNotifications"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name = "AllowTelemetry"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"; Name = "TailoredExperiencesWithDiagnosticDataEnabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"; Name = "TailoredExperiencesWithDiagnosticDataEnabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowSearchToUseLocation"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "DisableWebSearch"; Value = 1 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; Name = "CortanaEnabled"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; Name = "AllowSearchToUseLocation"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"; Name = "Disabled"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Consent"; Name = "DefaultConsent"; Value = 0 },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"; Name = "Disabled"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name = "DisableInventory"; Value = 1 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name = "AITEnable"; Value = 0 }
    )
    Set-RegistryPrivacy -Title "Windows" -Settings $settings
}

function Do-PrivacyOffice {
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Instrumentation"; Name = "Enable"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Telemetry"; Name = "Enable"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Telemetry\Instrumentation"; Name = "Enable"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Telemetry\Debug"; Name = "Enable"; Value = 0 }
    )
    Set-RegistryPrivacy -Title "Office" -Settings $settings
}

function Do-PrivacyEdge {
    $settings = @(
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "SearchSuggestEnabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "AutofillAddressEnabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "AutofillCreditCardEnabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "PersonalizationReportingEnabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "UrlDiagnosticDataEnabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "MicrosoftSearchInBingProviderEnabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "AlternateErrorPagesEnabled"; Value = 0 },
        @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name = "ShowRecommendationsEnabled"; Value = 0 }
    )
    Set-RegistryPrivacy -Title "Edge" -Settings $settings
}

function Do-PrivacyTasks {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) {
        Log "[X] Admin richiesto"
        Update-Status "[!] Admin" $global:warningColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    Update-Status "[...] Privacy Task Scheduler..." $global:securityColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] DISABILITA ATTIVITÀ TELEMETRIA"; Log "==============================================================================================="
    $tasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\StartupAppTask",
        "\Microsoft\Windows\Application Experience\Device Census",
        "\Microsoft\Windows\Application Experience\DiskDiagnosticDataCollector",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\Customer Experience Improvement Program\Sqm-Tasks",
        "\Microsoft\Windows\Customer Experience Improvement Program\Proxy",
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
        "\Microsoft\Windows\Feedback\Siuf\DmClient",
        "\Microsoft\Windows\Feedback\Siuf\Siuf",
        "\Microsoft\Windows\NetTrace\GatherNetworkInfo",
        "\Microsoft\Windows\AppID\SmartScreenSpecific"
    )
    $count = 0; $errors = 0
    foreach ($taskPath in $tasks) {
        try {
            $task = Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue
            if ($task) {
                Disable-ScheduledTask -TaskPath $taskPath -ErrorAction Stop
                $count++
                $taskName = Split-Path $taskPath -Leaf
                Log "[OK] Disabilitato: $taskName"
            } else {
                Log "[i] $taskPath - Non trovato"
            }
        } catch {
            $errors++
            Log "[!] ${taskPath}: $($_.Exception.Message)"
        }
        Pump-UI
    }
    Log ""; Log "[OK] Attività disabilitate: $count, errori: $errors"
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Privacy Tasks ($count disabilitate)" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-PrivacyAll {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) {
        Log "[X] Admin richiesto"
        Update-Status "[!] Admin" $global:warningColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    Log ""; Log "##################################################################################################"; Log "# PRIVACY - DISABILITA TUTTO #"; Log "##################################################################################################"; Log ""
    Update-Status "[...] Privacy Completa..." $global:securityColor
    Flush-LogBuffer; Pump-UI
    Do-PrivacyWindows
    if (Test-Cancel) { return }
    Do-PrivacyOffice
    if (Test-Cancel) { return }
    Do-PrivacyEdge
    if (Test-Cancel) { return }
    Do-PrivacyTasks
    if (Test-Cancel) { return }
    Log ""; Log "##################################################################################################"; Log "# PRIVACY COMPLETATA - RIAVVIO CONSIGLIATO #"; Log "##################################################################################################"; Log ""
    Update-Progress 100
    Update-Status "[OK] Privacy Completata!" $global:successColor
    Flush-LogBuffer; Pump-UI
    $response = [System.Windows.Forms.MessageBox]::Show("Privacy configurata!`nRiavviare il PC per applicare tutte le modifiche?", "Riavvio Consigliato", "YesNo", "Question")
    if ($response -eq "Yes") {
        shutdown /r /t 10 /c "Riavvio per applicare modifiche privacy"
        Log "[i] Riavvio in 10 secondi..."
    }
}

Export-ModuleMember -Function @(
    'Set-RegistryPrivacy',
    'Do-PrivacyWindows',
    'Do-PrivacyOffice',
    'Do-PrivacyEdge',
    'Do-PrivacyTasks',
    'Do-PrivacyAll'
)