# ============================================================
# RETE.psm1 - Funzioni di rete (DNS, IP, WiFi, SpeedTest, Whois, Blacklist, Traceroute, CambiaDNS)
# Versione: 1.0.5 - Blacklist con lista dettagliata delle segnalazioni
# ============================================================

# ---------- GESTIONE MODULI PER BLACKLIST ----------
function Ensure-BlacklistModules {
    <#
    .SYNOPSIS
        Verifica se i moduli per Blacklist Check sono installati e caricabili.
        Se mancano, esegue install-github-modules.ps1.
        ATTENZIONE: L'installazione può richiedere alcuni minuti.
    #>
    $neededModules = @('PSSharedGoods', 'PSBlackListChecker')
    $allOk = $true
    
    # Verifica presenza e carica i moduli
    foreach ($mod in $neededModules) {
        if (-not (Get-Module -Name $mod -ListAvailable -ErrorAction SilentlyContinue)) {
            $allOk = $false
            Log "[!] Modulo $mod non installato." $global:warningColor
        } else {
            try {
                Import-Module -Name $mod -Force -ErrorAction Stop | Out-Null
                Log "[OK] $mod caricato." $global:successColor
            } catch {
                $allOk = $false
                Log "[!] $mod presente ma non caricabile: $($_.Exception.Message)" $global:warningColor
            }
        }
    }
    
    if ($allOk) {
        return $true
    }
    
    Log "==============================================================================================="
    Log "[i] MODULI PER BLACKLIST CHECK NON TROVATI O NON VALIDI" $global:warningColor
    Log "[i] Avvio installazione automatica. Operazione può richiedere 2-5 minuti..." $global:infoColor
    Log "[i] Si prega di attendere. Non chiudere la finestra." $global:infoColor
    Log "==============================================================================================="
    Flush-LogBuffer; Pump-UI
    
    $installScript = Join-Path $global:scriptRoot "install-github-modules.ps1"
    if (-not (Test-Path $installScript)) {
        Log "[X] install-github-modules.ps1 non trovato in $global:scriptRoot" $global:exitColor
        Log "[i] Scarica manualmente lo script da GitHub o esegui 'Full Update'." $global:infoColor
        return $false
    }
    
    $scope = if ($global:isAdmin) { 'AllUsers' } else { 'CurrentUser' }
    Log "[i] Esecuzione: & `"$installScript`" -Scope $scope -ForceReinstall" $global:infoColor
    Log "[i] Attendere... il download dei moduli può richiedere alcuni minuti." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    try {
        $output = & $installScript -Scope $scope -ForceReinstall 2>&1
        Log-Output $output
        
        # Verifica finale
        $allOk = $true
        foreach ($mod in $neededModules) {
            if (-not (Get-Module -Name $mod -ListAvailable -ErrorAction SilentlyContinue)) {
                $allOk = $false
                Log "[X] Modulo $mod non trovato dopo l'installazione." $global:exitColor
            } else {
                try {
                    Import-Module -Name $mod -Force -ErrorAction Stop | Out-Null
                    Log "[OK] $mod caricato dopo installazione." $global:successColor
                } catch {
                    $allOk = $false
                    Log "[X] $mod installato ma non caricabile: $($_.Exception.Message)" $global:exitColor
                }
            }
        }
        
        if ($allOk) {
            Log "==============================================================================================="
            Log "[OK] MODULI PER BLACKLIST CHECK INSTALLATI E CARICATI CON SUCCESSO!" $global:successColor
            Log "==============================================================================================="
            return $true
        } else {
            Log "[X] Installazione moduli fallita." $global:exitColor
            Log "[i] Verifica la connessione Internet e riprova." $global:infoColor
            return $false
        }
    } catch {
        Log "[X] Errore durante l'esecuzione di install-github-modules.ps1: $($_.Exception.Message)" $global:exitColor
        return $false
    }
}

# ---------- FUNZIONI RETE ----------
function Do-FlushDNS {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] DNS..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Flush DNS"; Log "==============================================================================================="
    try {
        $o = & ipconfig /flushdns 2>&1
        Log-Output $o
        Log "[OK] DNS svuotata."
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] DNS" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-RenewIP {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] IP..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Rinnovo IP"; Log "==============================================================================================="
    try {
        & ipconfig /release 2>&1 | Out-Null
        Pump-UI
        Start-Sleep 2
        Pump-UI
        $o = & ipconfig /renew 2>&1
        Log-Output $o
        Log "[OK] IP rinnovato."
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] IP" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-InfoIP {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Info..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Info Rete"; Log "==============================================================================================="
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5 -ErrorAction Stop
        Log " [??] IP Pubblico : $publicIP"
    } catch {
        Log " [??] IP Pubblico : non rilevato (verifica connessione)"
    }
    Log ""
    try {
        $o = & ipconfig /all 2>&1
        foreach ($l in $o) { Log " $l" }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Info" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-ResetWinsock {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) {
        Log "[X] Admin."
        Update-Status "[!] Admin" $global:warningColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    Update-Status "[...] Winsock..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Winsock Reset"; Log "==============================================================================================="
    try {
        & netsh winsock reset 2>&1 | Out-Null
        & netsh int ip reset 2>&1 | Out-Null
        Log "[OK] Reset. Riavvio consigliato."
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Winsock" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-NetworkReset {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) { Log "[X] Admin richiesto"; Update-Progress 100; return }
    Update-Status "[...] Reset Rete..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] RESET COMPLETO RETE"; Log "==============================================================================================="
    $backupDir = Join-Path $env:TEMP "network_backup_$(Get-Date -Format 'yyyyMMdd')"
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    netsh interface show interface > "$backupDir\interfaces.txt"
    ipconfig /all > "$backupDir\ipconfig.txt"
    Log "[OK] Backup salvato in $backupDir"
    $commands = @(
        @{ cmd = "netsh winsock reset"; desc = "Winsock" },
        @{ cmd = "netsh int ip reset"; desc = "TCP/IP" },
        @{ cmd = "netsh int ipv6 reset"; desc = "IPv6" },
        @{ cmd = "ipconfig /flushdns"; desc = "DNS Cache" },
        @{ cmd = "netsh winhttp reset proxy"; desc = "Proxy" },
        @{ cmd = "netsh int tcp set global autotuninglevel=normal"; desc = "TCP AutoTuning" }
    )
    foreach ($c in $commands) {
        Log "[>] Reset $($c.desc)..."
        & cmd /c $c.cmd 2>&1 | Out-Null
        Pump-UI
        Start-Sleep -Milliseconds 300
    }
    Log ""; Log "[OK] Reset completato. Riavvio consigliato."
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Reset rete" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-WifiPasswords {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Wi-Fi..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Password Wi-Fi"; Log "==============================================================================================="
    try {
        $profiles = & netsh wlan show profiles 2>&1
        $pm = $profiles | Select-String "Tutti i profili utente\s*:\s*(.+)$|Profilo tutti gli utenti\s*:\s*(.+)$|All User Profile\s*:\s*(.+)$|User Profile\s*:\s*(.+)$|Profile\s*:\s*(.+)$"
        if (-not $pm) {
            Log "[i] Nessun profilo."
            Log "==============================================================================================="
            Update-Progress 100
            Update-Status "[OK]" $global:successColor
            Flush-LogBuffer; Pump-UI
            return
        }
        $names = foreach ($m in $pm) {
            $m.Matches[0].Groups | Where-Object { $_.Value -and $_.Value.Trim() -ne "" } | Select-Object -Skip 1 -First 1 | ForEach-Object { $_.Value.Trim() }
        }
        Log "[OK] $($names.Count) reti:"
        Log ""
        foreach ($n in $names) {
            if (Test-Cancel) { return }
            $d = & netsh wlan show profile name="$n" key=clear 2>&1
            $kl = ($d | Select-String "Contenuto chiave\s*:\s*(.+)$|Key Content\s*:\s*(.+)$")
            $pw = "N/D"
            if ($kl) {
                $match = $kl.Matches[0]
                $p1 = $match.Groups[1].Value.Trim()
                $p2 = $match.Groups[2].Value.Trim()
                if ($p1) { $pw = $p1 } elseif ($p2) { $pw = $p2 }
            }
            Log " $n : $pw"
            Pump-UI
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log ""; Log "==============================================================================================="
    Update-Progress 100
    Update-Status "[OK] Wi-Fi" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-SpeedTest {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Ping..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Ping Test"; Log "==============================================================================================="
    $targets = @(
        @{ N = "Google"; I = "8.8.8.8" },
        @{ N = "Cloudflare"; I = "1.1.1.1" },
        @{ N = "OpenDNS"; I = "208.67.222.222" }
    )
    $propName = if ($PSVersionTable.PSVersion.Major -ge 7) { "Latency" } else { "ResponseTime" }
    foreach ($t in $targets) {
        if (Test-Cancel) { return }
        try {
            $ping = Test-Connection -ComputerName $t.I -Count 3 -ErrorAction Stop
            $avg = [Math]::Round(($ping | Measure-Object -Property $propName -Average).Average, 1)
            Log " $($t.N): ${avg}ms"
        } catch {
            Log " [X] $($t.N)"
        }
        Pump-UI
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Ping" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-SpeedInternet {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Speedtest..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Speedtest Cloudflare"; Log "==============================================================================================="
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $latency = 0
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Invoke-WebRequest -Uri "https://speed.cloudflare.com/__down?bytes=0" -Method Get -TimeoutSec 5 -UseBasicParsing | Out-Null
        $sw.Stop()
        $latency = [Math]::Round($sw.Elapsed.TotalMilliseconds, 1)
        Log " Ping: ${latency}ms"
    } catch { }
    Flush-LogBuffer; Pump-UI
    if (Test-Cancel) { return }
    $dl = 0
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $data = Invoke-WebRequest -Uri "https://speed.cloudflare.com/__down?bytes=20000000" -Method Get -TimeoutSec 30 -UseBasicParsing
        $sw.Stop()
        $bytes = $data.RawContentLength
        if ($bytes -and $sw.Elapsed.TotalSeconds -gt 0) {
            $dl = [Math]::Round((($bytes * 8) / 1MB) / $sw.Elapsed.TotalSeconds, 2)
        }
        Log " DL: ${dl} Mbps"
    } catch { }
    Flush-LogBuffer; Pump-UI
    if (Test-Cancel) { return }
    $ul = 0
    try {
        $buf = New-Object byte[](5MB)
        (New-Object Random).NextBytes($buf)
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Invoke-WebRequest -Uri "https://speed.cloudflare.com/__up" -Method Post -Body $buf -TimeoutSec 30 -UseBasicParsing | Out-Null
        $sw.Stop()
        if ($sw.Elapsed.TotalSeconds -gt 0) {
            $ul = [Math]::Round((5 * 8) / $sw.Elapsed.TotalSeconds, 2)
        }
        Log " UP: ${ul} Mbps"
    } catch { }
    Log ""; Log " Ping ${latency}ms | DL ${dl} | UP ${ul} Mbps"
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] DL $dl / UP $ul" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-SpeedOokla {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] Speedtest Ookla..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] SPEEDTEST OOKLA (dettagliato)"; Log "==============================================================================================="
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5 -ErrorAction Stop
        Log " [??] IP Pubblico : $publicIP"
    } catch {
        Log " [??] IP Pubblico : non rilevato (verifica connessione)"
    }
    Log ""
    $speedtestExe = Join-Path $global:scriptRoot "lib" "speedtest.exe"
    if (-not (Test-Path $speedtestExe)) {
        Log "[!] speedtest.exe non trovato in $global:scriptRoot\lib"
        Log "[i] Esegui 'Full Update' per scaricare i file necessari."
        Update-Status "[X] speedtest.exe mancante" $global:exitColor
        Flush-LogBuffer; Pump-UI
        Update-Progress 100
        return
    }
    try {
        Log "[>] Avvio test (potrebbe richiedere 20-30 secondi)..."
        Flush-LogBuffer; Pump-UI
        $process = Start-Process -FilePath $speedtestExe -ArgumentList "--accept-license --accept-gdpr --format=json" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\speedtest_output.json"
        if ($process.ExitCode -ne 0) {
            Log "[X] Errore nell'esecuzione di speedtest (codice: $($process.ExitCode))"
            Update-Status "[X] Errore speedtest" $global:exitColor
            Flush-LogBuffer; Pump-UI
            Update-Progress 100
            return
        }
        $json = Get-Content "$env:TEMP\speedtest_output.json" -Raw | ConvertFrom-Json
        if (-not $json) {
            Log "[X] Impossibile leggere i risultati."
            Update-Status "[X] Errore parsing" $global:exitColor
            Update-Progress 100
            return
        }
        $downloadBps = $json.download.bandwidth
        $uploadBps = $json.upload.bandwidth
        $latencyMs = $json.ping.latency
        $jitterMs = $json.ping.jitter
        $packetLoss = $json.packetLoss * 100
        $serverName = $json.server.name
        $serverLoc = "$($json.server.location), $($json.server.country)"
        $isp = $json.isp
        $downloadMbps = [Math]::Round($downloadBps * 8 / 1e6, 2)
        $uploadMbps = [Math]::Round($uploadBps * 8 / 1e6, 2)
        Log ""; Log "[OK] RISULTATI SPEEDTEST OOKLA"
        Log "---------------------------------------------"
        Log " Server      : $serverName ($serverLoc)"
        Log " Provider    : $isp"
        Log " Download    : $downloadMbps Mbps"
        Log " Upload      : $uploadMbps Mbps"
        Log " Latenza     : $latencyMs ms"
        Log " Jitter      : $jitterMs ms"
        Log " Packet Loss : $([Math]::Round($packetLoss, 2))%"
        Log "---------------------------------------------"; Log ""
        Update-Status "[OK] DL $downloadMbps / UP $uploadMbps Mbps" $global:successColor
    } catch {
        Log "[X] Errore durante il test: $($_.Exception.Message)"
        Update-Status "[X] Errore" $global:exitColor
    }
    try { Remove-Item "$env:TEMP\speedtest_output.json" -Force -ErrorAction SilentlyContinue } catch { }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}

function Do-Traceroute {
    if ($script:isClosing -or (Test-Cancel)) { return }
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Traceroute - Inserisci destinazione"
    $inputForm.Size = New-Object System.Drawing.Size(400, 180)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = $global:bgColor
    $inputForm.ForeColor = $global:fgColor
    $inputForm.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inserisci indirizzo IP o dominio da tracciare:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(340, 22)
    $lbl.ForeColor = $global:fgColor
    $inputForm.Controls.Add($lbl)
    $txtTarget = New-Object System.Windows.Forms.TextBox
    $txtTarget.Text = "8.8.8.8"
    $txtTarget.Location = New-Object System.Drawing.Point(20, 50)
    $txtTarget.Size = New-Object System.Drawing.Size(340, 26)
    $txtTarget.Font = New-Object System.Drawing.Font("Consolas", 12)
    $txtTarget.BackColor = $global:bgCard
    $txtTarget.ForeColor = $global:fgColor
    $inputForm.Controls.Add($txtTarget)
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Avvia"
    $btnOK.Location = New-Object System.Drawing.Point(20, 95)
    $btnOK.Size = New-Object System.Drawing.Size(100, 32)
    $btnOK.BackColor = $global:accentColor
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140, 95)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 32)
    $btnCancel.BackColor = $global:exitColor
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($btnCancel)
    $inputForm.CancelButton = $btnCancel
    $result = $inputForm.ShowDialog($script:form)
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Traceroute annullato."
        Update-Progress 100
        return
    }
    $target = $txtTarget.Text.Trim()
    if ([string]::IsNullOrEmpty($target)) {
        Log "[X] Nessun target inserito."
        Update-Progress 100
        return
    }
    Update-Status "[...] Traceroute verso $target..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] TRACEROUTE VERSO $target"; Log "==============================================================================================="
    Run-ProcessRealtime "tracert" $target "Traceroute verso $target" 0 100
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Traceroute completato" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-ChangeDNS {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) {
        Log "[X] Per cambiare i DNS servono privilegi amministrativi."
        Update-Status "[!] Admin richiesto" $global:warningColor
        Flush-LogBuffer; Pump-UI
        Update-Progress 100
        return
    }
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Cambia Server DNS"
    $inputForm.Size = New-Object System.Drawing.Size(450, 280)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = $global:bgColor
    $inputForm.ForeColor = $global:fgColor
    $inputForm.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Seleziona il provider DNS:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(390, 22)
    $lbl.ForeColor = $global:fgColor
    $inputForm.Controls.Add($lbl)
    $cmbProviders = New-Object System.Windows.Forms.ComboBox
    $cmbProviders.Location = New-Object System.Drawing.Point(20, 50)
    $cmbProviders.Size = New-Object System.Drawing.Size(390, 26)
    $cmbProviders.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbProviders.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $cmbProviders.BackColor = $global:bgCard
    $cmbProviders.ForeColor = $global:fgColor
    $cmbProviders.Items.AddRange(@("Google DNS (8.8.8.8, 8.8.4.4)", "Cloudflare DNS (1.1.1.1, 1.0.0.1)", "OpenDNS (208.67.222.222, 208.67.220.220)", "Quad9 (9.9.9.9, 149.112.112.112)", "Personalizzato (inserisci manualmente)"))
    $cmbProviders.SelectedIndex = 0
    $inputForm.Controls.Add($cmbProviders)
    $lblCustom = New-Object System.Windows.Forms.Label
    $lblCustom.Text = "DNS Primario:"
    $lblCustom.Location = New-Object System.Drawing.Point(20, 95)
    $lblCustom.Size = New-Object System.Drawing.Size(150, 22)
    $lblCustom.ForeColor = $global:fgColor
    $lblCustom.Visible = $false
    $inputForm.Controls.Add($lblCustom)
    $txtPrimary = New-Object System.Windows.Forms.TextBox
    $txtPrimary.Location = New-Object System.Drawing.Point(20, 125)
    $txtPrimary.Size = New-Object System.Drawing.Size(180, 26)
    $txtPrimary.Font = New-Object System.Drawing.Font("Consolas", 12)
    $txtPrimary.BackColor = $global:bgCard
    $txtPrimary.ForeColor = $global:fgColor
    $txtPrimary.Visible = $false
    $inputForm.Controls.Add($txtPrimary)
    $lblCustom2 = New-Object System.Windows.Forms.Label
    $lblCustom2.Text = "DNS Secondario:"
    $lblCustom2.Location = New-Object System.Drawing.Point(220, 95)
    $lblCustom2.Size = New-Object System.Drawing.Size(150, 22)
    $lblCustom2.ForeColor = $global:fgColor
    $lblCustom2.Visible = $false
    $inputForm.Controls.Add($lblCustom2)
    $txtSecondary = New-Object System.Windows.Forms.TextBox
    $txtSecondary.Location = New-Object System.Drawing.Point(220, 125)
    $txtSecondary.Size = New-Object System.Drawing.Size(180, 26)
    $txtSecondary.Font = New-Object System.Drawing.Font("Consolas", 12)
    $txtSecondary.BackColor = $global:bgCard
    $txtSecondary.ForeColor = $global:fgColor
    $txtSecondary.Visible = $false
    $inputForm.Controls.Add($txtSecondary)
    $cmbProviders.Add_SelectedIndexChanged({
        if ($cmbProviders.SelectedItem -eq "Personalizzato (inserisci manualmente)") {
            $lblCustom.Visible = $true
            $txtPrimary.Visible = $true
            $lblCustom2.Visible = $true
            $txtSecondary.Visible = $true
            $inputForm.Height = 330
        } else {
            $lblCustom.Visible = $false
            $txtPrimary.Visible = $false
            $lblCustom2.Visible = $false
            $txtSecondary.Visible = $false
            $inputForm.Height = 280
        }
    })
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Applica"
    $btnOK.Location = New-Object System.Drawing.Point(20, 175)
    $btnOK.Size = New-Object System.Drawing.Size(100, 32)
    $btnOK.BackColor = $global:accentColor
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140, 175)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 32)
    $btnCancel.BackColor = $global:exitColor
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($btnCancel)
    $inputForm.CancelButton = $btnCancel
    $result = $inputForm.ShowDialog($script:form)
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Cambio DNS annullato."
        Update-Progress 100
        return
    }
    $selected = $cmbProviders.SelectedItem
    $dnsPrimary = $null; $dnsSecondary = $null
    if ($selected -eq "Google DNS (8.8.8.8, 8.8.4.4)") { $dnsPrimary = "8.8.8.8"; $dnsSecondary = "8.8.4.4" }
    elseif ($selected -eq "Cloudflare DNS (1.1.1.1, 1.0.0.1)") { $dnsPrimary = "1.1.1.1"; $dnsSecondary = "1.0.0.1" }
    elseif ($selected -eq "OpenDNS (208.67.222.222, 208.67.220.220)") { $dnsPrimary = "208.67.222.222"; $dnsSecondary = "208.67.220.220" }
    elseif ($selected -eq "Quad9 (9.9.9.9, 149.112.112.112)") { $dnsPrimary = "9.9.9.9"; $dnsSecondary = "149.112.112.112" }
    elseif ($selected -eq "Personalizzato (inserisci manualmente)") {
        $dnsPrimary = $txtPrimary.Text.Trim()
        $dnsSecondary = $txtSecondary.Text.Trim()
        if (-not $dnsPrimary) { Log "[X] DNS primario non inserito."; Update-Progress 100; return }
        if ($dnsPrimary -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') { Log "[X] DNS primario non valido: $dnsPrimary"; Update-Progress 100; return }
        if ($dnsSecondary -and $dnsSecondary -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') { Log "[X] DNS secondario non valido: $dnsSecondary"; Update-Progress 100; return }
    }
    Update-Status "[...] Cambio DNS in corso..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] CAMBIO DNS"; Log "==============================================================================================="
    Log "[i] DNS Primario    : $dnsPrimary"
    Log "[i] DNS Secondario  : $dnsSecondary"
    try {
        $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
        if (-not $adapters) {
            Log "[X] Nessuna scheda di rete attiva trovata."
            Update-Status "[X] Nessuna scheda" $global:exitColor
            Update-Progress 100
            return
        }
        $modified = 0
        foreach ($adapter in $adapters) {
            try {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses @($dnsPrimary, $dnsSecondary) -ErrorAction Stop
                Log "[OK] $($adapter.Name): DNS impostati a $dnsPrimary, $dnsSecondary"
                $modified++
            } catch {
                Log "[!] $($adapter.Name): $($_.Exception.Message)"
            }
            Pump-UI
        }
        if ($modified -gt 0) {
            Log "[OK] DNS cambiati su $modified scheda(e)."
            Log "[>] Flush DNS..."
            & ipconfig /flushdns 2>&1 | Out-Null
            Log "[OK] Cache DNS svuotata."
        } else {
            Log "[!] Nessuna scheda modificata."
        }
    } catch {
        Log "[X] Errore durante il cambio DNS: $($_.Exception.Message)"
        Update-Status "[X] Errore" $global:exitColor
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] DNS cambiati" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-Whois {
    if ($script:isClosing -or (Test-Cancel)) { return }
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Whois - Inserisci IP o dominio"
    $inputForm.Size = New-Object System.Drawing.Size(420, 180)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = $global:bgColor
    $inputForm.ForeColor = $global:fgColor
    $inputForm.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inserisci indirizzo IP o dominio:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(360, 22)
    $lbl.ForeColor = $global:fgColor
    $inputForm.Controls.Add($lbl)
    $txtTarget = New-Object System.Windows.Forms.TextBox
    $txtTarget.Text = "google.com"
    $txtTarget.Location = New-Object System.Drawing.Point(20, 50)
    $txtTarget.Size = New-Object System.Drawing.Size(360, 26)
    $txtTarget.Font = New-Object System.Drawing.Font("Consolas", 12)
    $txtTarget.BackColor = $global:bgCard
    $txtTarget.ForeColor = $global:fgColor
    $inputForm.Controls.Add($txtTarget)
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Cerca"
    $btnOK.Location = New-Object System.Drawing.Point(20, 90)
    $btnOK.Size = New-Object System.Drawing.Size(100, 32)
    $btnOK.BackColor = $global:accentColor
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140, 90)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 32)
    $btnCancel.BackColor = $global:exitColor
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($btnCancel)
    $inputForm.CancelButton = $btnCancel
    $result = $inputForm.ShowDialog($script:form)
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Whois annullato."
        Update-Progress 100
        return
    }
    $target = $txtTarget.Text.Trim()
    if ([string]::IsNullOrEmpty($target)) {
        Log "[X] Nessun target inserito."
        Update-Progress 100
        return
    }
    Update-Status "[...] Whois su $target..." $global:networkColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] WHOIS - $target"; Log "==============================================================================================="
    $whoisSuccess = $false
    $isIP = $target -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'
    if ($isIP) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $url = "https://ipinfo.io/$target/json"
            $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop
            if ($response -and $response.ip) {
                $whoisSuccess = $true
                Log ""; Log " [OK] Informazioni su $target (IP)"
                Log " ---------------------------------------------"
                if ($response.ip) { Log " IP           : $($response.ip)" }
                if ($response.hostname) { Log " Hostname     : $($response.hostname)" }
                if ($response.city) { Log " Città        : $($response.city)" }
                if ($response.region) { Log " Regione      : $($response.region)" }
                if ($response.country) { Log " Paese        : $($response.country)" }
                if ($response.loc) { Log " Coordinate   : $($response.loc)" }
                if ($response.org) { Log " Organizzazione: $($response.org)" }
                if ($response.postal) { Log " CAP          : $($response.postal)" }
                if ($response.timezone) { Log " Timezone     : $($response.timezone)" }
                if ($response.asn) { Log " ASN          : $($response.asn)" }
                if ($response.abuse) {
                    Log " Abuse Email  : $($response.abuse.email)"
                    Log " Abuse Phone  : $($response.abuse.phone)"
                }
                Log " ---------------------------------------------"; Log ""
            }
        } catch {
            Log "[X] Errore durante la richiesta per l'IP: $($_.Exception.Message)"
        }
    }
    if (-not $whoisSuccess -and -not $isIP) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $bootstrapUrl = "https://data.iana.org/rdap/dns.json"
            $bootstrap = Invoke-RestMethod -Uri $bootstrapUrl -Method Get -TimeoutSec 10 -ErrorAction Stop
            $parts = $target -split '\.'
            $tld = $parts[-1]
            $rdapServer = $null
            foreach ($service in $bootstrap.services) {
                $tlds = $service[0]
                $urls = $service[1]
                if ($tlds -contains $tld) { $rdapServer = $urls[0]; break }
            }
            if (-not $rdapServer) {
                $fallbackServers = @{
                    "com" = "https://rdap.verisign.com/com/v1/"
                    "net" = "https://rdap.verisign.com/net/v1/"
                    "org" = "https://rdap.publicinterestregistry.org/v1/"
                    "it" = "https://rdap.nic.it/"
                    "uk" = "https://rdap.nominet.uk/"
                    "eu" = "https://rdap.eu/"
                    "fr" = "https://rdap.nic.fr/"
                    "de" = "https://rdap.denic.de/"
                    "nl" = "https://rdap.sidn.nl/"
                    "ch" = "https://rdap.nic.ch/"
                    "be" = "https://rdap.dns.be/"
                }
                if ($fallbackServers.ContainsKey($tld)) {
                    $rdapServer = $fallbackServers[$tld]
                    Log "[OK] Server RDAP da fallback: $rdapServer"
                }
            }
            if ($rdapServer) {
                Log "[>] Tentativo RDAP: $rdapServer"
                if (-not $rdapServer.EndsWith("/")) { $rdapServer += "/" }
                $rdapUrl = "$rdapServer" + "domain/$target"
                $response = Invoke-RestMethod -Uri $rdapUrl -Method Get -TimeoutSec 15 -ErrorAction Stop
                $whoisSuccess = $true
                Log ""; Log " [OK] Informazioni su $target (RDAP)"
                Log " ---------------------------------------------"
                if ($response.rdapConformance) { Log " Protocollo   : RDAP" }
                if ($response.objectClassName) { Log " Tipo         : $($response.objectClassName)" }
                if ($response.handle) { Log " Handle       : $($response.handle)" }
                if ($response.ldhName) { Log " Dominio      : $($response.ldhName)" }
                if ($response.events) {
                    foreach ($event in $response.events) {
                        $date = $event.eventDate -replace 'T.*$', ''
                        if ($event.eventAction -eq "registration") { Log " Creato il    : $date" }
                        if ($event.eventAction -eq "expiration") { Log " Scade il     : $date" }
                        if ($event.eventAction -eq "last changed") { Log " Modificato il: $date" }
                    }
                }
                if ($response.nameservers) {
                    $ns = ($response.nameservers | ForEach-Object { $_.ldhName }) -join ", "
                    Log " Name Server  : $ns"
                }
                if ($response.entities) {
                    foreach ($entity in $response.entities) {
                        $roles = $entity.roles -join ", "
                        if ($roles) {
                            Log " Ruolo        : $roles"
                            if ($entity.fn) { Log "   Nome        : $($entity.fn)" }
                            if ($entity.org) { Log "   Organizzazione: $($entity.org)" }
                            if ($entity.email) { Log "   Email       : $($entity.email)" }
                            if ($entity.tel) { Log "   Telefono    : $($entity.tel)" }
                        }
                    }
                }
                if ($response.links) {
                    foreach ($link in $response.links) {
                        if ($link.rel -eq "self") { Log " Link RDAP    : $($link.href)" }
                        if ($link.rel -eq "alternate" -or $link.rel -eq "related") { Log " Link         : $($link.href)" }
                    }
                }
                Log " ---------------------------------------------"; Log ""
            }
        } catch {
            if (-not $whoisSuccess) { Log "[!] RDAP non disponibile, risolvo IP e provo con ipinfo.io..." }
        }
    }
    if (-not $whoisSuccess -and -not $isIP) {
        try {
            Log "[>] Risoluzione IP del dominio..."
            $nslookup = & nslookup $target 2>&1
            $ipLines = $nslookup | Select-String -Pattern "Addresses:|Address:" | Select-Object -Last 1
            if ($ipLines) {
                $ipMatch = [regex]::Match($ipLines, '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
                if ($ipMatch.Success) {
                    $resolvedIP = $ipMatch.Value
                    Log "[OK] IP risolto: $resolvedIP"
                    Log "[>] Whois sull'IP..."
                    $url = "https://ipinfo.io/$resolvedIP/json"
                    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop
                    if ($response -and $response.ip) {
                        $whoisSuccess = $true
                        Log ""; Log " [OK] Informazioni su $target (tramite IP $resolvedIP)"
                        Log " ---------------------------------------------"
                        Log " Dominio      : $target"
                        if ($response.ip) { Log " IP           : $($response.ip)" }
                        if ($response.hostname) { Log " Hostname     : $($response.hostname)" }
                        if ($response.city) { Log " Città        : $($response.city)" }
                        if ($response.region) { Log " Regione      : $($response.region)" }
                        if ($response.country) { Log " Paese        : $($response.country)" }
                        if ($response.loc) { Log " Coordinate   : $($response.loc)" }
                        if ($response.org) { Log " Organizzazione: $($response.org)" }
                        if ($response.postal) { Log " CAP          : $($response.postal)" }
                        if ($response.timezone) { Log " Timezone     : $($response.timezone)" }
                        if ($response.asn) { Log " ASN          : $($response.asn)" }
                        if ($response.abuse) {
                            Log " Abuse Email  : $($response.abuse.email)"
                            Log " Abuse Phone  : $($response.abuse.phone)"
                        }
                        Log " ---------------------------------------------"; Log ""
                    }
                } else {
                    Log "[X] Impossibile risolvere l'IP del dominio."
                }
            } else {
                Log "[X] Dominio non risolvibile (non esiste o DNS non risponde)."
            }
        } catch {
            Log "[X] Errore durante la risoluzione IP: $($_.Exception.Message)"
        }
    }
    if (-not $whoisSuccess) {
        Log "[X] Nessuna informazione disponibile per '$target'."
        Log "[i] Verifica che il dominio/IP esista e che la connessione Internet sia attiva."
        Update-Status "[X] Errore whois" $global:exitColor
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Whois completato" $global:successColor
    Flush-LogBuffer; Pump-UI
}

# ---------- BLACKLIST CHECK ----------
function Do-BlacklistCheck {
    if ($script:isClosing -or (Test-Cancel)) { return }
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Blacklist Check - Inserisci dominio o IP"
    $inputForm.Size = New-Object System.Drawing.Size(420, 180)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = $global:bgColor
    $inputForm.ForeColor = $global:fgColor
    $inputForm.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inserisci dominio o IP da verificare:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(360, 22)
    $lbl.ForeColor = $global:fgColor
    $inputForm.Controls.Add($lbl)
    $txtTarget = New-Object System.Windows.Forms.TextBox
    $txtTarget.Text = "google.com"
    $txtTarget.Location = New-Object System.Drawing.Point(20, 50)
    $txtTarget.Size = New-Object System.Drawing.Size(360, 26)
    $txtTarget.Font = New-Object System.Drawing.Font("Consolas", 12)
    $txtTarget.BackColor = $global:bgCard
    $txtTarget.ForeColor = $global:fgColor
    $inputForm.Controls.Add($txtTarget)
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Verifica"
    $btnOK.Location = New-Object System.Drawing.Point(20, 90)
    $btnOK.Size = New-Object System.Drawing.Size(100, 32)
    $btnOK.BackColor = $global:accentColor
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140, 90)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 32)
    $btnCancel.BackColor = $global:exitColor
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($btnCancel)
    $inputForm.CancelButton = $btnCancel
    $result = $inputForm.ShowDialog($script:form)
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Verifica blacklist annullata."
        Update-Progress 100
        return
    }
    $target = $txtTarget.Text.Trim()
    if ([string]::IsNullOrEmpty($target)) {
        Log "[X] Nessun target inserito."
        Update-Progress 100
        return
    }
    
    # Array per raccogliere i nomi delle blacklist che segnalano
    $segnalazioniList = @()
    
    Update-Status "[...] Verifica blacklist per $target..." $global:securityColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] BLACKLIST CHECK Attendere - $target"; Log "==============================================================================================="
    
    # Funzione Log-Color (locale)
    function Log-Color {
        param(
            [string]$TextBefore,
            [string]$TextToColor,
            [string]$TextAfter = "",
            [System.Drawing.Color]$Color,
            [string]$FontStyle = "Regular"
        )
        $rtb = $global:logBox
        if ($rtb -and $rtb.GetType().Name -eq "RichTextBox") {
            $rtb.AppendText($TextBefore)
            $startIdx = $rtb.TextLength
            $rtb.AppendText($TextToColor)
            $rtb.Select($startIdx, $TextToColor.Length)
            $rtb.SelectionColor = $Color
            if ($FontStyle -eq "Bold") {
                $rtb.SelectionFont = New-Object System.Drawing.Font($rtb.Font.FontFamily, $rtb.Font.Size, [System.Drawing.FontStyle]::Bold)
            }
            $rtb.SelectionLength = 0
            $rtb.SelectionColor = $global:fgColor   # Resetta al colore predefinito dei log
            $rtb.AppendText($TextAfter + "`r`n")
            $rtb.ScrollToCaret()
        } else {
            Log "$TextBefore$TextToColor$TextAfter"
        }
    }

    # Verifica/installazione moduli
    Log "[i] Verifica moduli per Blacklist Check. Se necessario, l'installazione può richiedere alcuni minuti." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    $moduleOk = Ensure-BlacklistModules
    if (-not $moduleOk) {
        Log "[i] Installazione moduli non riuscita, uso fallback manuale." $global:warningColor
    }
    
    # Risolvi IP
    $isIP = $target -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'
    if ($isIP) {
        $ipToCheck = $target
    } else {
        try {
            $dnsResult = Resolve-DnsName -Name $target -Type A -ErrorAction Stop
            $ipToCheck = if ($dnsResult -is [System.Array]) { $dnsResult[0].IPAddress } else { $dnsResult.IPAddress }
        } catch {
            Log "[X] Errore risoluzione DNS: $($_.Exception.Message)"
            Update-Status "[X] Errore DNS" $global:exitColor
            Update-Progress 100
            return
        }
    }
    
    # ---- PSBlackListChecker (se disponibile) ----
    $moduleListCount = 0
    $moduleListed = 0
    if ($moduleOk) {
        Log ""; Log " [??] CONTROLLO CON PSBlackListChecker"
        Log " -------------------------------------------------------------"
        try {
            Import-Module PSBlackListChecker -Force -ErrorAction Stop
            $results = Search-BlackList -IP $ipToCheck -ReturnAll -ErrorAction Stop
            if ($null -ne $results -and $results.Count -gt 0) {
                $moduleListCount = $results.Count
                foreach ($entry in ($results | Sort-Object -Property IsListed -Descending)) {
                    $listName = if ($entry.BlackList) { $entry.BlackList } else { $entry.BlacklistName }
                    $isListed = [bool]$entry.IsListed
                    if ($isListed) {
                        Log-Color -TextBefore " [??] $($listName.Trim()) : " -TextToColor "SEGNALATO" -Color ([System.Drawing.Color]::Red) -FontStyle "Bold"
                        $moduleListed++
                        $segnalazioniList += $listName.Trim()
                    } else {
                        Log-Color -TextBefore " [?] $($listName.Trim()) : " -TextToColor "PULITO" -Color ([System.Drawing.Color]::Green) -FontStyle "Bold"
                    }
                    Pump-UI
                }
            }
        } catch {
            Log "[!] Errore PSBlackListChecker: $($_.Exception.Message)" $global:warningColor
        }
    }
    
    # ---- CONTROLLO MANUALE ESTESO (lista completa) ----
    Log ""; Log " [??] CONTROLLO MANUALE ESTESO (completo)"
    Log " -------------------------------------------------------------"
    
    # Lista dei server DNSBL (70+ server)
    $fallbackLists = @(
        @{ Name = "Spamhaus ZEN"; QuerySuffix = "zen.spamhaus.org" },
        @{ Name = "Spamhaus DBL"; QuerySuffix = "dbl.spamhaus.org" },
        @{ Name = "SpamCop"; QuerySuffix = "bl.spamcop.net" },
        @{ Name = "SORBS"; QuerySuffix = "dnsbl.sorbs.net" },
        @{ Name = "Barracuda"; QuerySuffix = "b.barracudacentral.org" },
        @{ Name = "UCEPROTECT L1"; QuerySuffix = "l1.uceprotect.net" },
        @{ Name = "UCEPROTECT L2"; QuerySuffix = "l2.uceprotect.net" },
        @{ Name = "SANS EDU"; QuerySuffix = "isc.sans.edu" },
        @{ Name = "DNSBL FR"; QuerySuffix = "dnsbl.spam-rbl.fr" },
        @{ Name = "Mailspike BL"; QuerySuffix = "bl.mailspike.net" },
        @{ Name = "RATS Dyna"; QuerySuffix = "rats-dyn.spamrats.com" },
        @{ Name = "RATS Spam"; QuerySuffix = "spam.spamrats.com" },
        @{ Name = "SEM Black"; QuerySuffix = "bl.semblack.com" },
        @{ Name = "Abuse.ro"; QuerySuffix = "abuse.ro" },
        @{ Name = "DRONE BL"; QuerySuffix = "dnsbl.dronebl.org" },
        @{ Name = "Nix Spam"; QuerySuffix = "ix.dnsbl.manitu.net" },
        @{ Name = "CBL"; QuerySuffix = "cbl.abuseat.org" },
        @{ Name = "NJABL"; QuerySuffix = "dnsbl.njabl.org" },
        @{ Name = "WPBL"; QuerySuffix = "dnsbl.spfbl.net" },
        @{ Name = "KELSEY"; QuerySuffix = "kelsey.net" },
        @{ Name = "SWINOG"; QuerySuffix = "swinog.ch" },
        @{ Name = "NoSolicitado"; QuerySuffix = "nosolicitado.com" },
        @{ Name = "SORBS DUHL"; QuerySuffix = "dul.dnsbl.sorbs.net" },
        @{ Name = "SORBS SMTP"; QuerySuffix = "smtp.dnsbl.sorbs.net" },
        @{ Name = "SORBS WEB"; QuerySuffix = "web.dnsbl.sorbs.net" },
        @{ Name = "SORBS ZOMBIE"; QuerySuffix = "zombie.dnsbl.sorbs.net" },
        @{ Name = "SORBS BLOCK"; QuerySuffix = "block.dnsbl.sorbs.net" },
        @{ Name = "SORBS HTTP"; QuerySuffix = "http.dnsbl.sorbs.net" },
        @{ Name = "SORBS SOCKS"; QuerySuffix = "socks.dnsbl.sorbs.net" },
        @{ Name = "SORBS MISC"; QuerySuffix = "misc.dnsbl.sorbs.net" },
        @{ Name = "RBL"; QuerySuffix = "rbl.interserver.net" },
        @{ Name = "SPAMRATS"; QuerySuffix = "spamrats.com" },
        @{ Name = "SPAMRATS NOPTR"; QuerySuffix = "noptr.spamrats.com" },
        @{ Name = "SPAMRATS DYNA"; QuerySuffix = "dyna.spamrats.com" },
        @{ Name = "SPAMRATS SNARE"; QuerySuffix = "snare.spamrats.com" },
        @{ Name = "SPAMRATS PYTHON"; QuerySuffix = "python.spamrats.com" },
        @{ Name = "SPAMRATS TL"; QuerySuffix = "tl.spamrats.com" },
        @{ Name = "SPAMRATS SI"; QuerySuffix = "si.spamrats.com" },
        @{ Name = "SPAMRATS SE"; QuerySuffix = "se.spamrats.com" },
        @{ Name = "SPAMRATS NO"; QuerySuffix = "no.spamrats.com" },
        @{ Name = "SPAMRATS FR"; QuerySuffix = "fr.spamrats.com" },
        @{ Name = "SPAMRATS NL"; QuerySuffix = "nl.spamrats.com" },
        @{ Name = "SPAMRATS DE"; QuerySuffix = "de.spamrats.com" },
        @{ Name = "SPAMRATS IT"; QuerySuffix = "it.spamrats.com" },
        @{ Name = "SPAMRATS UK"; QuerySuffix = "uk.spamrats.com" },
        @{ Name = "SPAMRATS US"; QuerySuffix = "us.spamrats.com" },
        @{ Name = "SPAMRATS CA"; QuerySuffix = "ca.spamrats.com" },
        @{ Name = "SPAMRATS AU"; QuerySuffix = "au.spamrats.com" },
        @{ Name = "SPAMRATS NZ"; QuerySuffix = "nz.spamrats.com" },
        @{ Name = "SPAMRATS JP"; QuerySuffix = "jp.spamrats.com" },
        @{ Name = "SPAMRATS CN"; QuerySuffix = "cn.spamrats.com" },
        @{ Name = "SPAMRATS RU"; QuerySuffix = "ru.spamrats.com" },
        @{ Name = "SPAMRATS BR"; QuerySuffix = "br.spamrats.com" },
        @{ Name = "SPAMRATS AR"; QuerySuffix = "ar.spamrats.com" },
        @{ Name = "SPAMRATS ZA"; QuerySuffix = "za.spamrats.com" },
        @{ Name = "SPAMRATS IN"; QuerySuffix = "in.spamrats.com" },
        @{ Name = "SPAMRATS MX"; QuerySuffix = "mx.spamrats.com" },
        @{ Name = "SPAMRATS KR"; QuerySuffix = "kr.spamrats.com" },
        @{ Name = "SPAMRATS TW"; QuerySuffix = "tw.spamrats.com" },
        @{ Name = "SPAMRATS HK"; QuerySuffix = "hk.spamrats.com" },
        @{ Name = "SPAMRATS SG"; QuerySuffix = "sg.spamrats.com" },
        @{ Name = "SPAMRATS ID"; QuerySuffix = "id.spamrats.com" },
        @{ Name = "SPAMRATS PH"; QuerySuffix = "ph.spamrats.com" },
        @{ Name = "SPAMRATS TH"; QuerySuffix = "th.spamrats.com" },
        @{ Name = "SPAMRATS VN"; QuerySuffix = "vn.spamrats.com" },
        @{ Name = "SPAMRATS MY"; QuerySuffix = "my.spamrats.com" },
        @{ Name = "SPAMRATS PK"; QuerySuffix = "pk.spamrats.com" },
        @{ Name = "SPAMRATS TR"; QuerySuffix = "tr.spamrats.com" },
        @{ Name = "SPAMRATS IL"; QuerySuffix = "il.spamrats.com" },
        @{ Name = "SPAMRATS SA"; QuerySuffix = "sa.spamrats.com" },
        @{ Name = "SPAMRATS AE"; QuerySuffix = "ae.spamrats.com" },
        @{ Name = "SPAMRATS EG"; QuerySuffix = "eg.spamrats.com" },
        @{ Name = "SPAMRATS NG"; QuerySuffix = "ng.spamrats.com" },
        @{ Name = "SPAMRATS KE"; QuerySuffix = "ke.spamrats.com" },
        @{ Name = "SPAMRATS GH"; QuerySuffix = "gh.spamrats.com" },
        @{ Name = "SPAMRATS ZW"; QuerySuffix = "zw.spamrats.com" }
    )
    
    $ipInvertito = ($ipToCheck -split '\.')[-1..0] -join '.'
    $manualListed = 0
    $manualCount = $fallbackLists.Count
    
    Log "[i] Verifica in corso su $manualCount server DNSBL..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    foreach ($list in $fallbackLists) {
        try {
            $null = Resolve-DnsName -Name "$ipInvertito.$($list.QuerySuffix)" -Type A -ErrorAction Stop -DnsOnly -QuickTimeout
            Log-Color -TextBefore " [??] $($list.Name) : " -TextToColor "SEGNALATO" -Color ([System.Drawing.Color]::Red) -FontStyle "Bold"
            $manualListed++
            $segnalazioniList += $list.Name
        } catch {
            Log-Color -TextBefore " [?] $($list.Name) : " -TextToColor "PULITO" -Color ([System.Drawing.Color]::Green) -FontStyle "Bold"
        }
        Pump-UI
    }
    
    # ---- CONTROLLO WEB MULTIRBL (opzionale) ----
    Log ""; Log " [??] CONTROLLO WEB SU MULTIRBL.VALLI.ORG"
    Log " -------------------------------------------------------------"
    Log "[>] Download e analisi pagina web in corso (15-30 sec)..."
    Flush-LogBuffer; Pump-UI
    
    $webListed = 0
    $webCount = 0
    try {
        $uri = "https://multirbl.valli.org/lookup/$ipToCheck.html"
        $headers = @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
            "Accept-Language" = "it-IT,it;q=0.8,en-US;q=0.5,en;q=0.3"
        }
        $webResponse = Invoke-WebRequest -Uri $uri -Method Get -Headers $headers -TimeoutSec 60 -ErrorAction Stop
        $htmlContent = $webResponse.Content
        if ($htmlContent.Length -lt 5000) {
            Log "[!] Risposta web troppo breve. Possibile blocco anti-bot o CAPTCHA."
        } else {
            $regexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline
            $regex = '<tr\s+class="[^"]*rbl-(?<Status>ok|listed)[^"]*"[^>]*>.*?<a[^>]*>(?<Name>[^<]+)</a>'
            $matches = [regex]::Matches($htmlContent, $regex, $regexOptions)
            if ($matches.Count -gt 0) {
                Log " -------------------------------------------------------------"
                foreach ($match in $matches) {
                    $listName = $match.Groups["Name"].Value.Trim()
                    $status = $match.Groups["Status"].Value.Trim().ToUpper()
                    $webCount++
                    if ($status -eq "LISTED") {
                        Log-Color -TextBefore " [??] $listName : " -TextToColor "SEGNALATO" -TextAfter " (da MultiRBL)" -Color ([System.Drawing.Color]::Red) -FontStyle "Bold"
                        $webListed++
                        $segnalazioniList += $listName
                    } else {
                        Log-Color -TextBefore " [?] $listName : " -TextToColor "PULITO" -Color ([System.Drawing.Color]::Green) -FontStyle "Bold"
                    }
                    Pump-UI
                }
                Log " -------------------------------------------------------------"
                Log " Riepilogo MultiRBL: $webListed SEGNALATI su $webCount liste"
            } else {
                Log "[!] Struttura standard non trovata. Tentativo con parser generico di emergenza..."
                $rows = $htmlContent -split '<tr'
                $fallbackListed = 0
                $fallbackTotal = 0
                foreach ($row in $rows) {
                    if ($row -match '<a[^>]*>([^<]+)</a>') {
                        $linkText = $Matches[1].Trim()
                        if ($linkText.Length -gt 4 -and $linkText -notmatch '^(Home|About|Contact|Login|MultiRBL|Valli\.org|Donate)$') {
                            $fallbackTotal++
                            if ($row -match '\bLISTED\b') {
                                Log-Color -TextBefore " [??] $linkText : " -TextToColor "SEGNALATO" -TextAfter " (da MultiRBL)" -Color ([System.Drawing.Color]::Red) -FontStyle "Bold"
                                $fallbackListed++
                                $segnalazioniList += $linkText
                            } else {
                                Log-Color -TextBefore " [?] $linkText : " -TextToColor "PULITO" -Color ([System.Drawing.Color]::Green) -FontStyle "Bold"
                            }
                            Pump-UI
                        }
                    }
                }
                if ($fallbackTotal -gt 0) {
                    $webCount = $fallbackTotal
                    $webListed = $fallbackListed
                    Log " -------------------------------------------------------------"
                    Log " Riepilogo MultiRBL: $webListed SEGNALATI su $webCount liste (tramite fallback)"
                } else {
                    Log "[!] Impossibile estrarre dati. Il sito potrebbe essere temporaneamente irraggiungibile o aver cambiato radicalmente layout."
                }
            }
        }
    } catch {
        Log "[!] Errore durante la richiesta a MultiRBL: $($_.Exception.Message)" $global:warningColor
    }
    
    # ---- RIEPILOGO ----
    $totalLists = $moduleListCount + $manualCount + $webCount
    $totalListed = $moduleListed + $manualListed + $webListed
    
    Log ""; Log " [??] RIEPILOGO COMPLETO"
    Log " -------------------------------------------------------------"
    Log " Controlli PSBlackListChecker : $moduleListCount liste"
    Log " Controlli manuali estesi     : $manualCount liste"
    Log " Controlli Web (MultiRBL)     : $webCount liste"
    Log " TOTALE LISTE CONTROLLATE     : $totalLists"
    if ($totalListed -gt 0) {
        Log-Color -TextBefore " TOTALE SEGNALAZIONI          : " -TextToColor "$totalListed" -Color ([System.Drawing.Color]::Red) -FontStyle "Bold"
        # Stampa la lista dettagliata delle segnalazioni
        Log " LISTA SEGNALAZIONI:"
        foreach ($item in ($segnalazioniList | Sort-Object -Unique)) {
            Log "   - $item"
        }
    } else {
        Log-Color -TextBefore " TOTALE SEGNALAZIONI          : " -TextToColor "$totalListed" -Color ([System.Drawing.Color]::Green) -FontStyle "Bold"
    }
    Log " -------------------------------------------------------------"
    
    if ($totalListed -gt 0) {
        Update-Status "[??] $totalListed SEGNALAZIONI su $totalLists liste" $global:exitColor
    } else {
        Update-Status "[?] PULITO (0 segnalazioni su $totalLists liste)" $global:successColor
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}

# ---------- ESPORTAZIONE ----------
Export-ModuleMember -Function @(
    'Do-FlushDNS',
    'Do-RenewIP',
    'Do-InfoIP',
    'Do-ResetWinsock',
    'Do-NetworkReset',
    'Do-WifiPasswords',
    'Do-SpeedTest',
    'Do-SpeedInternet',
    'Do-SpeedOokla',
    'Do-Traceroute',
    'Do-ChangeDNS',
    'Do-Whois',
    'Do-BlacklistCheck'
)
