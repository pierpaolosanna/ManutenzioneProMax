# ============================================================
# UTILITY.psm1 - Utility varie (RDP, VNC, RustDesk, Shutdown, BIOS, ecc.)
# Versione: 1.0.0
# ============================================================

function Do-VNCViewer {
    if ($script:isClosing -or (Test-Cancel)) { return }
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Assistenza LAN - TightVNC"
    $inputForm.Size = New-Object System.Drawing.Size(400, 180)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = $global:bgColor
    $inputForm.ForeColor = $global:fgColor
    $inputForm.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inserisci l'IP del PC remoto:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(360, 22)
    $lbl.ForeColor = $global:fgColor
    $inputForm.Controls.Add($lbl)
    $txtIP = New-Object System.Windows.Forms.TextBox
    $txtIP.Text = "192.168.1."
    $txtIP.Location = New-Object System.Drawing.Point(20, 50)
    $txtIP.Size = New-Object System.Drawing.Size(340, 26)
    $txtIP.Font = New-Object System.Drawing.Font("Consolas", 12)
    $txtIP.BackColor = $global:bgCard
    $txtIP.ForeColor = $global:fgColor
    $inputForm.Controls.Add($txtIP)
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Connetti"
    $btnOK.Location = New-Object System.Drawing.Point(20, 90)
    $btnOK.Size = New-Object System.Drawing.Size(100, 32)
    $btnOK.BackColor = $global:remoteColor
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
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { Log "[i] Assistenza remota annullata."; return }
    $targetIP = $txtIP.Text.Trim()
    if ([string]::IsNullOrEmpty($targetIP)) { Log "[X] Nessun IP inserito."; return }
    $vncPath = Join-Path $global:scriptRoot "lib\tvnviewer.exe"
    if (-not (Test-Path $vncPath)) {
        Log "[X] Impossibile trovare lib\tvnviewer.exe. Assicurati che il file sia nella cartella."
        Update-Status "[X] tvnviewer.exe mancante" $global:exitColor
        return
    }
    Log ""; Log "==============================================================================================="; Log "[>] AVVIO ASSISTENZA REMOTA (TightVNC Viewer)"; Log "==============================================================================================="
    Log "[OK] Connessione a: $targetIP"
    Log "[OK] Avvio eseguibile portatile..."
    Update-Status "[...] Connessione a $targetIP..." $global:remoteColor
    Flush-LogBuffer; Pump-UI
    try {
        Start-Process -FilePath $vncPath -ArgumentList "$targetIP"
        Log "[OK] Viewer avviato con successo."
        Update-Status "[OK] VNC in esecuzione" $global:successColor
    } catch {
        Log "[X] Errore durante l'avvio di TightVNC: $($_.Exception.Message)"
        Update-Status "[X] Errore avvio VNC" $global:exitColor
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}

function New-RDPFile {
    param([string]$FilePath, [string]$IP, [string]$User)
    $rdpContent = @"
full address:s:$IP
server port:i:3389
username:s:$User
domain:s:
allow font smoothing:i:1
allow desktop composition:i:1
disable wallpaper:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:0
disable cursor i:0
redirectclipboard:i:1
redirectprinters:i:0
redirectcomports:i:0
redirectsmartcards:i:0
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
use redirection server name:i:0
"@
    Set-Content -Path $FilePath -Value $rdpContent -Force
}

function Start-RDPWithCred {
    param([string]$IP, [string]$User, [string]$Pass, [string]$RDPFile)
    try {
        $null = cmdkey /generic:"TERMSRV/$IP" /user:"$User" /pass:"$Pass"
        Start-Process "mstsc.exe" -ArgumentList "`"$RDPFile`""
        Log "[OK] Sessione RDP avviata per $IP"
        Update-Status "[OK] RDP Connesso a $IP" $global:successColor
    } catch {
        Log "[X] Errore avvio RDP: $($_.Exception.Message)"
    }
}

function Do-RDPManager {
    if ($script:isClosing -or (Test-Cancel)) { return }
    $promptDir = Join-Path $global:scriptRoot "Prompt"
    if (-not (Test-Path $promptDir)) { New-Item -ItemType Directory -Force -Path $promptDir | Out-Null }
    $rdpForm = New-Object System.Windows.Forms.Form
    $rdpForm.Text = "Gestore Sessioni RDP"
    $rdpForm.Size = New-Object System.Drawing.Size(500, 450)
    $rdpForm.StartPosition = "CenterParent"
    $rdpForm.FormBorderStyle = "FixedDialog"
    $rdpForm.MaximizeBox = $false
    $rdpForm.MinimizeBox = $false
    $rdpForm.BackColor = $global:bgColor
    $rdpForm.ForeColor = $global:fgColor
    $rdpForm.TopMost = $true
    $lblList = New-Object System.Windows.Forms.Label
    $lblList.Text = "Sessioni Salvate (cartella Prompt):"
    $lblList.Location = New-Object System.Drawing.Point(15, 15)
    $lblList.Size = New-Object System.Drawing.Size(300, 20)
    $lblList.ForeColor = $global:fgColor
    $rdpForm.Controls.Add($lblList)
    $cmbSessions = New-Object System.Windows.Forms.ComboBox
    $cmbSessions.Location = New-Object System.Drawing.Point(15, 40)
    $cmbSessions.Size = New-Object System.Drawing.Size(350, 25)
    $cmbSessions.BackColor = $global:bgCard
    $cmbSessions.ForeColor = $global:fgColor
    $cmbSessions.DropDownStyle = "DropDownList"
    Get-ChildItem -Path $promptDir -Filter "*.rdp" | ForEach-Object { $cmbSessions.Items.Add($_.BaseName) | Out-Null }
    if ($cmbSessions.Items.Count -gt 0) { $cmbSessions.SelectedIndex = 0 }
    $rdpForm.Controls.Add($cmbSessions)
    $btnConnect = New-Object System.Windows.Forms.Button
    $btnConnect.Text = "Connetti"
    $btnConnect.Location = New-Object System.Drawing.Point(375, 38)
    $btnConnect.Size = New-Object System.Drawing.Size(100, 28)
    $btnConnect.BackColor = $global:successColor
    $btnConnect.ForeColor = [System.Drawing.Color]::White
    $btnConnect.FlatStyle = "Flat"
    $rdpForm.Controls.Add($btnConnect)
    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "Elimina"
    $btnDelete.Location = New-Object System.Drawing.Point(375, 72)
    $btnDelete.Size = New-Object System.Drawing.Size(100, 25)
    $btnDelete.BackColor = $global:exitColor
    $btnDelete.ForeColor = [System.Drawing.Color]::White
    $btnDelete.FlatStyle = "Flat"
    $rdpForm.Controls.Add($btnDelete)
    $sep = New-Object System.Windows.Forms.Label
    $sep.Text = "-" * 60
    $sep.Location = New-Object System.Drawing.Point(15, 105)
    $sep.ForeColor = $global:separatorColor
    $rdpForm.Controls.Add($sep)
    $lblNew = New-Object System.Windows.Forms.Label
    $lblNew.Text = "Nuova Connessione RDP:"
    $lblNew.Location = New-Object System.Drawing.Point(15, 125)
    $lblNew.Size = New-Object System.Drawing.Size(200, 20)
    $lblNew.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $rdpForm.Controls.Add($lblNew)
    $txtName = New-Object System.Windows.Forms.TextBox
    $txtName.Text = "Nome PC (es. Server Magazzino)"
    $txtName.Location = New-Object System.Drawing.Point(15, 150)
    $txtName.Size = New-Object System.Drawing.Size(460, 25)
    $txtName.BackColor = $global:bgCard
    $txtName.ForeColor = $global:fgDim
    $rdpForm.Controls.Add($txtName)
    $txtIP = New-Object System.Windows.Forms.TextBox
    $txtIP.Text = "192.168.1."
    $txtIP.Location = New-Object System.Drawing.Point(15, 180)
    $txtIP.Size = New-Object System.Drawing.Size(220, 25)
    $txtIP.Font = New-Object System.Drawing.Font("Consolas", 10)
    $txtIP.BackColor = $global:bgCard
    $txtIP.ForeColor = $global:fgColor
    $rdpForm.Controls.Add($txtIP)
    $txtUser = New-Object System.Windows.Forms.TextBox
    $txtUser.Text = "Administrator"
    $txtUser.Location = New-Object System.Drawing.Point(250, 180)
    $txtUser.Size = New-Object System.Drawing.Size(225, 25)
    $txtUser.BackColor = $global:bgCard
    $txtUser.ForeColor = $global:fgColor
    $rdpForm.Controls.Add($txtUser)
    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Text = "Password"
    $txtPass.Location = New-Object System.Drawing.Point(15, 210)
    $txtPass.Size = New-Object System.Drawing.Size(460, 25)
    $txtPass.PasswordChar = "*"
    $txtPass.BackColor = $global:bgCard
    $txtPass.ForeColor = $global:fgColor
    $rdpForm.Controls.Add($txtPass)
    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "?? Salva e Connetti"
    $btnSave.Location = New-Object System.Drawing.Point(15, 250)
    $btnSave.Size = New-Object System.Drawing.Size(460, 35)
    $btnSave.BackColor = $global:accentColor
    $btnSave.ForeColor = [System.Drawing.Color]::White
    $btnSave.FlatStyle = "Flat"
    $btnSave.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $rdpForm.Controls.Add($btnSave)
    $lblLogTitle = New-Object System.Windows.Forms.Label
    $lblLogTitle.Text = "Stato:"
    $lblLogTitle.Location = New-Object System.Drawing.Point(15, 300)
    $lblLogTitle.ForeColor = $global:fgDim
    $rdpForm.Controls.Add($lblLogTitle)
    $txtFormLog = New-Object System.Windows.Forms.TextBox
    $txtFormLog.Multiline = $true
    $txtFormLog.ReadOnly = $true
    $txtFormLog.Location = New-Object System.Drawing.Point(15, 320)
    $txtFormLog.Size = New-Object System.Drawing.Size(460, 80)
    $txtFormLog.BackColor = $global:logBg
    $txtFormLog.ForeColor = $global:fgDim
    $txtFormLog.Font = New-Object System.Drawing.Font("Consolas", 8)
    $rdpForm.Controls.Add($txtFormLog)
    $btnConnect.Add_Click({
        if ($cmbSessions.SelectedItem) {
            $name = $cmbSessions.SelectedItem
            $rdpFile = Join-Path $promptDir "$name.rdp"
            $jsonFile = Join-Path $promptDir "$name.json"
            if (Test-Path $jsonFile) {
                $data = Get-Content $jsonFile | ConvertFrom-Json
                $txtFormLog.Text = "[...] Connessione a $($data.IP) in corso..."
                Start-RDPWithCred -IP $data.IP -User $data.User -Pass $data.Pass -RDPFile $rdpFile
            } else {
                $txtFormLog.Text = "[X] File credenziali JSON mancante per $name"
            }
        }
    })
    $btnDelete.Add_Click({
        if ($cmbSessions.SelectedItem) {
            $name = $cmbSessions.SelectedItem
            $resp = [System.Windows.Forms.MessageBox]::Show("Eliminare la sessione '$name'?", "Conferma", "YesNo", "Warning")
            if ($resp -eq "Yes") {
                Remove-Item (Join-Path $promptDir "$name.rdp") -Force -ErrorAction SilentlyContinue
                Remove-Item (Join-Path $promptDir "$name.json") -Force -ErrorAction SilentlyContinue
                $cmbSessions.Items.Remove($name)
                $txtFormLog.Text = "[OK] Sessione '$name' eliminata."
            }
        }
    })
    $btnSave.Add_Click({
        $nome = $txtName.Text.Trim()
        $ip = $txtIP.Text.Trim()
        $user = $txtUser.Text.Trim()
        $pass = $txtPass.Text.Trim()
        if ([string]::IsNullOrEmpty($nome) -or [string]::IsNullOrEmpty($ip) -or $ip -eq "192.168.1.") {
            $txtFormLog.Text = "[X] Inserisci un Nome valido e un IP."
            return
        }
        $safeName = ($nome -replace '[\\/:*?"<>|]', '_')
        $rdpPath = Join-Path $promptDir "$safeName.rdp"
        $jsonPath = Join-Path $promptDir "$safeName.json"
        try {
            New-RDPFile -FilePath $rdpPath -IP $ip -User $user
            $credObj = @{ IP = $ip; User = $user; Pass = $pass } | ConvertTo-Json
            Set-Content -Path $jsonPath -Value $credObj -Force
            $txtFormLog.Text = "[OK] Salvataggio completato in Prompt\. Avvio..."
            if (-not $cmbSessions.Items.Contains($safeName)) { $cmbSessions.Items.Add($safeName) }
            $cmbSessions.SelectedItem = $safeName
            Start-RDPWithCred -IP $ip -User $user -Pass $pass -RDPFile $rdpPath
        } catch {
            $txtFormLog.Text = "[X] Errore durante il salvataggio: $($_.Exception.Message)"
        }
    })
    $rdpForm.ShowDialog($script:form) | Out-Null
    Log "[i] Gestore RDP chiuso."
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}

function Do-RemoteAssist {
    if ($script:isClosing -or (Test-Cancel)) { return }
    Update-Status "[...] RustDesk..." $global:remoteColor
    Flush-LogBuffer; Pump-UI
    Log ""; Log "==============================================================================================="; Log "[>] Assistenza Remota"; Log "==============================================================================================="
    $url = "https://github.com/rustdesk/rustdesk/releases/download/1.2.2/rustdesk-1.2.2-x86_64.exe"
    $tp = "C:\Temp\RustDeskPortable"
    $ep = Join-Path $tp "rustdesk.exe"
    if (!(Test-Path $tp)) { New-Item -ItemType Directory -Force -Path $tp | Out-Null }
    if (!(Test-Path $ep)) {
        Log " [DL] Download..."
        Flush-LogBuffer; Pump-UI
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest $url -OutFile $ep -UseBasicParsing -ErrorAction Stop
        } catch {
            Log " [X] $($_.Exception.Message)"
            Update-Status "[X]" $global:exitColor
            Flush-LogBuffer; Pump-UI
            Update-Progress 100
            return
        }
    }
    try {
        Start-Process $ep
        Start-Sleep 4
        Pump-UI
        $id = & $ep --get-id 2>$null
        $pw = & $ep --get-password 2>$null
        if ($id) { Log " ID: $id" }
        if ($pw) { Log " PW: $pw" }
    } catch {
        Log " [X] $($_.Exception.Message)"
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] RustDesk" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-ScheduleShutdown {
    if ($script:isClosing) { return }
    $taskName = "ShutdownGiornalieroForzato"
    Log ""; Log "==============================================================================================="; Log "[>] SHUTDOWN SCHEDULATO"; Log "==============================================================================================="
    Update-Status "[...] Shutdown schedulato..." $global:warningColor
    Flush-LogBuffer; Pump-UI
    if (-not $global:isAdmin) {
        Log "[X] Servono privilegi admin."
        Update-Status "[!] Admin richiesto" $global:warningColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Imposta Ora Shutdown"
    $inputForm.Size = New-Object System.Drawing.Size(320, 180)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = $global:bgColor
    $inputForm.ForeColor = $global:fgColor
    $inputForm.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inserisci ora spegnimento (HH:mm):"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(260, 22)
    $lbl.ForeColor = $global:fgColor
    $inputForm.Controls.Add($lbl)
    $txtTime = New-Object System.Windows.Forms.TextBox
    $txtTime.Text = "22:30"
    $txtTime.Location = New-Object System.Drawing.Point(20, 50)
    $txtTime.Size = New-Object System.Drawing.Size(100, 26)
    $txtTime.Font = New-Object System.Drawing.Font("Consolas", 12)
    $txtTime.BackColor = $global:bgCard
    $txtTime.ForeColor = $global:fgColor
    $inputForm.Controls.Add($txtTime)
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Conferma"
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
        Log "[i] Annullato."
        Update-Status "Annullato" $global:fgDim
        Flush-LogBuffer; Update-Progress 100; return
    }
    $timeInput = $txtTime.Text.Trim()
    if ($timeInput -notmatch '^\d{1,2}:\d{2}$') {
        Log "[X] Formato ora non valido. Usa HH:mm (es. 22:30)"
        Update-Status "[X] Formato non valido" $global:exitColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    try { [datetime]::ParseExact($timeInput, "H:mm", [System.Globalization.CultureInfo]::InvariantCulture) | Out-Null } catch {
        Log "[X] Ora non valida: $timeInput"
        Update-Status "[X] Ora non valida" $global:exitColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    try {
        $argCreate = "/create /tn `"$taskName`" /tr `"shutdown /s /f /t 0`" /sc daily /st $timeInput /ru SYSTEM /f /rl HIGHEST"
        $proc = Start-Process "schtasks.exe" -ArgumentList $argCreate -Wait -NoNewWindow -PassThru
        if ($proc.ExitCode -eq 0) {
            Log "[OK] Task schedulato creato: spegnimento forzato ogni giorno alle $timeInput"
            Log "     Nome task: $taskName"
            Update-Status "[OK] Shutdown alle $timeInput" $global:successColor
        } else {
            Log "[X] Errore creazione task (codice: $($proc.ExitCode))"
            Update-Status "[X] Errore task" $global:exitColor
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
        Update-Status "[X] Errore" $global:exitColor
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}

function Do-RemoveShutdown {
    if ($script:isClosing) { return }
    $taskName = "ShutdownGiornalieroForzato"
    Log ""; Log "==============================================================================================="; Log "[>] RIMOZIONE SHUTDOWN SCHEDULATO"; Log "==============================================================================================="
    Update-Status "[...] Rimozione task..." $global:warningColor
    Flush-LogBuffer; Pump-UI
    if (-not $global:isAdmin) {
        Log "[X] Servono privilegi admin."
        Update-Status "[!] Admin richiesto" $global:warningColor
        Flush-LogBuffer; Update-Progress 100; return
    }
    try {
        $proc = Start-Process "schtasks.exe" -ArgumentList "/delete /tn `"$taskName`" /f" -Wait -NoNewWindow -PassThru
        if ($proc.ExitCode -eq 0) {
            Log "[OK] Task '$taskName' rimosso con successo."
            Update-Status "[OK] Shutdown rimosso" $global:successColor
        } else {
            Log "[X] Task non trovato o errore (codice: $($proc.ExitCode))"
            Update-Status "[!] Task non trovato" $global:warningColor
        }
    } catch {
        Log "[X] $($_.Exception.Message)"
        Update-Status "[X] Errore" $global:exitColor
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}

Export-ModuleMember -Function @(
    'Do-VNCViewer',
    'New-RDPFile',
    'Start-RDPWithCred',
    'Do-RDPManager',
    'Do-RemoteAssist',
    'Do-ScheduleShutdown',
    'Do-RemoveShutdown'
)