# ============================================================
# DOMINIO.psm1 - Funzioni Active Directory e Dominio
# Versione: 1.0.0
# ============================================================

function Do-DomainInfo {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Info Dominio..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] INFORMAZIONI DOMINIO"; Log "==============================================================================================="
    try {
        $computer = Get-CimInstance Win32_ComputerSystem
        Log " Nome PC      : $($computer.Name)"
        Log " Dominio      : $($computer.Domain)"
        if ($computer.PartOfDomain) {
            Log " Stato        : MEMBRO DEL DOMINIO"
            try {
                Import-Module ActiveDirectory -ErrorAction Stop
                $domain = Get-ADDomain -ErrorAction Stop
                Log " Nome Dominio : $($domain.Name)"
                Log " DC Primario  : $($domain.PDCEmulator)"
                Log " Foresta      : $($domain.Forest)"
            } catch {
                Log "[!] Modulo AD non disponibile. Installare RSAT-AD-PowerShell."
            }
        } else {
            Log " Stato        : WORKGROUP"
        }
        $user = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        Log " Utente       : $($user.Name)"
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Info Dominio" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-DCTest {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Test DC..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] TEST DOMAIN CONTROLLER"; Log "==============================================================================================="
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        $domain = Get-ADDomain -ErrorAction Stop
        $dcs = $domain.ReplicaDirectoryServers
        if (-not $dcs) { $dcs = @($domain.PDCEmulator) }
        foreach ($dc in $dcs) {
            Log "[>] Test $dc..."
            try {
                $ping = Test-Connection -ComputerName $dc -Count 2 -ErrorAction Stop
                $avg = [Math]::Round(($ping | Measure-Object -Property ResponseTime -Average).Average, 1)
                Log "[OK] $dc - ${avg}ms"
            } catch {
                Log "[X] $dc - NON RAGGIUNGIBILE"
            }
            Pump-UI
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Test DC" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-SyncTime {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) { Log "[X] Admin richiesto"; Update-Status "[!] Admin" $global:warningColor; Flush-LogBuffer; Update-Progress 100; return }
    Update-Status "[...] Sincronizzazione Ora..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] SINCRONIZZA ORA CON DC"; Log "==============================================================================================="
    try {
        $result = w32tm /resync /nowait 2>&1
        Log-Output $result
        Log "[OK] Sincronizzazione orario avviata."
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Ora sincronizzata" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-FlushKerberos {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Flush Kerberos..." $global:securityColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] FLUSH KERBEROS TICKET"; Log "==============================================================================================="
    try {
        $result = klist purge 2>&1
        Log-Output $result
        Log "[OK] Cache Kerberos svuotata."
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Kerberos" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-GPOInfo {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] GPO..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] INFORMAZIONI GPO"; Log "==============================================================================================="
    try {
        $result = gpresult /r /scope computer 2>&1 | Select-String -Pattern "Nome|Ultima|OU|GPO"
        foreach ($line in $result) { Log " $line" }
        Log ""
        $userResult = gpresult /r /scope user 2>&1 | Select-String -Pattern "Nome|GPO"
        foreach ($line in $userResult) { Log " $line" }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] GPO" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-ResetNetworkProfile {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) { Log "[X] Admin richiesto"; Update-Status "[!] Admin" $global:warningColor; Flush-LogBuffer; Update-Progress 100; return }
    Update-Status "[...] Reset Profilo Rete..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] RESET PROFILO RETE (ATTENZIONE: DISCONNETTE LA RETE)"; Log "==============================================================================================="
    $confirm = [System.Windows.Forms.MessageBox]::Show("Questa operazione riavvierà la scheda di rete causando una breve disconnessione (1-2 secondi). Continuare?", "Reset Profilo Rete", "YesNo", "Warning")
    if ($confirm -ne "Yes") { Log "[i] Annullato."; Update-Progress 100; return }
    try {
        Log "[>] Reset Winsock..."; netsh winsock reset | Out-Null
        Log "[>] Reset TCP/IP..."; netsh int ip reset | Out-Null
        Log "[>] Rilascio IP..."; ipconfig /release | Out-Null
        Start-Sleep 2
        Log "[>] Rinnovo IP..."; ipconfig /renew | Out-Null
        Log "[OK] Profilo rete reimpostato. Riavvio consigliato."
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Reset Rete" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-DNSTest {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Test DNS..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] TEST DNS DOMINIO"; Log "==============================================================================================="
    try {
        $domain = (Get-CimInstance Win32_ComputerSystem).Domain
        if ($domain -and $domain -ne "WORKGROUP") {
            Log "[>] Risoluzione $domain..."
            $result = nslookup $domain 2>&1
            Log-Output $result
            Log "[OK] Test DNS completato."
        } else {
            Log "[!] PC non in dominio."
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] DNS" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-ADSiteInfo {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Sito AD..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] INFORMAZIONI SITO AD"; Log "==============================================================================================="
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        $site = Get-ADReplicationSubnet -Filter * -ErrorAction Stop | Select-Object -First 5
        if ($site) {
            foreach ($s in $site) { Log " Sito: $($s.Name) - Subnet: $($s.Location)" }
        } else {
            Log "[!] Nessun sito AD trovato."
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Sito AD" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-LDAPTest {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Test LDAP..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] TEST CONNETTIVITÀ LDAP"; Log "==============================================================================================="
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        $domain = Get-ADDomain -ErrorAction Stop
        Log "[OK] Connessione LDAP riuscita!"
        Log " DN: $($domain.DistinguishedName)"
    } catch {
        Log "[X] Errore LDAP: $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] LDAP" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-DomainPassword {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Cambio Password..." $global:securityColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] CAMBIO PASSWORD DOMINIO"; Log "==============================================================================================="
    try {
        $user = $env:USERNAME
        Log "[i] Cambio password per: $user"
        $result = net user $user * /domain 2>&1
        Log-Output $result
        Log "[OK] Operazione completata."
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Password" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-LastLogin {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Ultimo Login..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] ULTIMO LOGIN DOMINIO"; Log "==============================================================================================="
    try {
        $user = $env:USERNAME
        Import-Module ActiveDirectory -ErrorAction Stop
        $adUser = Get-ADUser -Identity $user -Properties LastLogonDate, PasswordLastSet, AccountExpirationDate -ErrorAction Stop
        if ($adUser) {
            Log " Utente       : $($adUser.Name)"
            Log " Ultimo Login : $($adUser.LastLogonDate)"
            Log " Password Set : $($adUser.PasswordLastSet)"
            Log " Scadenza     : $($adUser.AccountExpirationDate)"
        } else {
            Log "[!] Utente non trovato in AD."
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Last Login" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-GroupMembership {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Gruppi..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] GRUPPI DOMINIO UTENTE"; Log "==============================================================================================="
    try {
        $user = $env:USERNAME
        Import-Module ActiveDirectory -ErrorAction Stop
        $groups = Get-ADPrincipalGroupMembership -Identity $user -ErrorAction Stop
        if ($groups) {
            Log " Utente: $user"
            Log " Gruppi:"
            foreach ($g in $groups | Sort-Object Name) { Log "   - $($g.Name)" }
        } else {
            Log "[!] Nessun gruppo trovato."
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Gruppi" $global:successColor
    Flush-LogBuffer; Pump-UI
}

Export-ModuleMember -Function @(
    'Do-DomainInfo',
    'Do-DCTest',
    'Do-SyncTime',
    'Do-FlushKerberos',
    'Do-GPOInfo',
    'Do-ResetNetworkProfile',
    'Do-DNSTest',
    'Do-ADSiteInfo',
    'Do-LDAPTest',
    'Do-DomainPassword',
    'Do-LastLogin',
    'Do-GroupMembership'
)