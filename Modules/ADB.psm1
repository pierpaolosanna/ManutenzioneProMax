# ============================================================
# ADB.psm1 - Gestione Android ADB - VERSIONE COMPLETA
# Versione: 2.0.1 - Corretto e completo
# ============================================================

# ---- VARIABILI DI STATO ----
$script:adbPath = $null
$script:deviceSerial = $null
$script:lastBackupFile = $null

# ---- FUNZIONE DI INIZIALIZZAZIONE (cerca adb.exe) ----
function Initialize-ADB {
    $possiblePaths = @(
        (Get-Command adb -ErrorAction SilentlyContinue).Source,
        "$env:ProgramFiles\Android\platform-tools\adb.exe",
        "$env:LOCALAPPDATA\Android\platform-tools\adb.exe",
        "$env:USERPROFILE\AppData\Local\Android\platform-tools\adb.exe"
    )
    foreach ($p in $possiblePaths) {
        if ($p -and (Test-Path $p)) {
            $script:adbPath = $p
            return $true
        }
    }
    return $false
}

# ---- INSTALLAZIONE DRIVER E ADB ----
function Install-ADBDrivers {
    if (Test-Cancel) { return }
    Log ""; Log "==============================================================================================="
    Log "[>] INSTALLAZIONE DRIVER ADB E PLATFORM TOOLS"
    Log "==============================================================================================="
    Update-Status "[...] Installazione ADB..." $global:infoColor
    Flush-LogBuffer; Pump-UI

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Log "[OK] winget trovato. Installazione tramite winget..."
        & winget install Google.AndroidSDKPlatformTools --silent --accept-package-agreements --accept-source-agreements 2>&1 | ForEach-Object { Log $_ }
        & winget install Google.AndroidUSBDriver --silent --accept-package-agreements --accept-source-agreements 2>&1 | ForEach-Object { Log $_ }
        if (Initialize-ADB) {
            Log "[OK] ADB installato correttamente tramite winget!"
            Update-Status "[OK] ADB installato" $global:successColor
            Flush-LogBuffer; Pump-UI
            return
        } else {
            Log "[!] winget non ha installato adb.exe. Passo al metodo manuale..."
        }
    } else {
        Log "[!] winget non trovato. Utilizzo metodo manuale..."
    }

    # Metodo manuale
    try {
        $tempDir = Join-Path $env:TEMP "adb_install_$(Get-Date -Format 'yyyyMMddHHmmss')"
        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
        Log "[DL] Download da Google..."
        $url = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
        $zipPath = Join-Path $tempDir "platform-tools.zip"
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        $destDir = "$env:ProgramFiles\Android\platform-tools"
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        Copy-Item -Path "$tempDir\platform-tools\*" -Destination $destDir -Recurse -Force
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$destDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$destDir", "Machine")
            Log "[OK] Aggiunto $destDir al PATH di sistema."
        }
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        if (Initialize-ADB) {
            Log "[OK] ADB installato manualmente con successo!"
            Update-Status "[OK] ADB installato" $global:successColor
            Flush-LogBuffer; Pump-UI
            return
        }
        # Driver USB
        Log "[DL] Download driver USB Google..."
        $driverUrl = "https://dl.google.com/android/repository/usb_driver_r13-windows.zip"
        $driverZip = Join-Path $tempDir "usb_driver.zip"
        Invoke-WebRequest -Uri $driverUrl -OutFile $driverZip -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
        Expand-Archive -Path $driverZip -DestinationPath $tempDir -Force
        $infPath = Get-ChildItem -Path $tempDir -Filter "*.inf" -Recurse | Select-Object -First 1 -ExpandProperty FullName
        if ($infPath) {
            Log "[>] Installazione driver con pnputil..."
            & pnputil /add-driver $infPath /install 2>&1 | ForEach-Object { Log $_ }
            Log "[OK] Driver USB installati."
        }
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        if (Initialize-ADB) {
            Log "[OK] ADB e driver installati con successo!"
            Update-Status "[OK] ADB installato" $global:successColor
        } else {
            Log "[X] Installazione fallita. Scarica manualmente da: https://developer.android.com/studio/releases/platform-tools"
            Update-Status "[X] Installazione fallita" $global:exitColor
        }
    } catch {
        Log "[X] Errore installazione: $($_.Exception.Message)"
        Update-Status "[X] Errore" $global:exitColor
    }
    Flush-LogBuffer; Pump-UI
    Log "==============================================================================================="
}

# ---- VERIFICA CONNESSIONE DISPOSITIVI ----
function Get-ADBDevices {
    if (Test-Cancel) { return }
    if (-not (Initialize-ADB)) {
        Log "[X] adb.exe non trovato. Esegui prima 'Installa Driver ADB'."
        Update-Status "[X] ADB non trovato" $global:exitColor
        return
    }
    Log ""; Log "==============================================================================================="
    Log "[>] DISPOSITIVI ADB CONNESSI"
    Log "==============================================================================================="
    Update-Status "[...] Ricerca dispositivi..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    try {
        & $script:adbPath start-server 2>&1 | Out-Null
        $output = & $script:adbPath devices -l 2>&1
        $devices = @()
        $lines = $output -split "`n"
        foreach ($line in $lines) {
            if ($line -match "^(?<serial>[a-zA-Z0-9_]+)\s+device\s+(?<info>.+)$") {
                $devices += @{ Serial = $matches['serial']; Info = $matches['info'] }
            } elseif ($line -match "^(?<serial>[a-zA-Z0-9_]+)\s+unauthorized$") {
                $devices += @{ Serial = $matches['serial']; Info = "Unauthorized (autorizza il dispositivo)" }
            } elseif ($line -match "^(?<serial>[a-zA-Z0-9_]+)\s+offline$") {
                $devices += @{ Serial = $matches['serial']; Info = "Offline" }
            }
        }
        if ($devices.Count -eq 0) {
            Log "[i] Nessun dispositivo trovato. Assicurati che:"
            Log "  1. Il dispositivo sia connesso via USB"
            Log "  2. Il debug USB sia attivato (Impostazioni > Opzioni sviluppatore)"
            Log "  3. I driver siano installati correttamente"
            Update-Status "[!] Nessun dispositivo" $global:warningColor
        } else {
            Log "[OK] Trovati $($devices.Count) dispositivo(i):"
            foreach ($d in $devices) { Log "  📱 $($d.Serial) - $($d.Info)" }
            if ($devices.Count -eq 1) {
                $script:deviceSerial = $devices[0].Serial
                Log "[i] Dispositivo default: $($script:deviceSerial)"
                Update-Status "[OK] $($script:deviceSerial)" $global:successColor
            } else {
                $script:deviceSerial = Select-ADBDevice -DeviceList $devices
            }
        }
    } catch {
        Log "[X] Errore: $($_.Exception.Message)"
        Update-Status "[X] Errore" $global:exitColor
    }
    Log "==============================================================================================="
    Flush-LogBuffer; Pump-UI
}

function Select-ADBDevice {
    param($DeviceList)
    if ($DeviceList.Count -eq 0) { return $null }
    if ($DeviceList.Count -eq 1) { return $DeviceList[0].Serial }
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Seleziona dispositivo ADB"
    $form.Size = New-Object System.Drawing.Size(400, 250)
    $form.StartPosition = "CenterParent"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.TopMost = $true
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Seleziona il dispositivo da utilizzare:"
    $label.Location = New-Object System.Drawing.Point(20, 20)
    $label.Size = New-Object System.Drawing.Size(350, 25)
    $label.ForeColor = [System.Drawing.Color]::White
    $form.Controls.Add($label)
    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(20, 55)
    $listBox.Size = New-Object System.Drawing.Size(350, 120)
    $listBox.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 42)
    $listBox.ForeColor = [System.Drawing.Color]::White
    $listBox.Font = New-Object System.Drawing.Font("Consolas", 10)
    foreach ($d in $DeviceList) { $listBox.Items.Add("$($d.Serial) - $($d.Info)") }
    $listBox.SelectedIndex = 0
    $form.Controls.Add($listBox)
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "OK"
    $btnOK.Location = New-Object System.Drawing.Point(190, 185)
    $btnOK.Size = New-Object System.Drawing.Size(80, 28)
    $btnOK.BackColor = [System.Drawing.Color]::FromArgb(0, 160, 0)
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($btnOK)
    $form.AcceptButton = $btnOK
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(280, 185)
    $btnCancel.Size = New-Object System.Drawing.Size(80, 28)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(220, 60, 60)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnCancel)
    $form.CancelButton = $btnCancel
    $result = $form.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $listBox.SelectedIndex -ge 0) {
        $selected = $listBox.SelectedItem
        return $selected -split ' - ' | Select-Object -First 1
    }
    return $null
}

# ---- COMANDI ADB (wrapper) ----
function Invoke-ADBCommand {
    param(
        [string]$Command,
        [string]$Description = $Command,
        [bool]$ShowOutput = $true,
        [string]$DeviceSerial = $null
    )
    if (-not (Initialize-ADB)) {
        Log "[X] adb.exe non trovato. Installa prima ADB."
        return $null
    }
    if (-not $DeviceSerial) { $DeviceSerial = $script:deviceSerial }
    
    $fullCmd = if ($DeviceSerial) { "-s $DeviceSerial $Command" } else { $Command }
    
    if ($ShowOutput) {
        Log ""; Log "[>] ADB $Description"
        Log "[CMD] adb $fullCmd"
    }
    
    try {
        $output = & cmd /c "`"$script:adbPath`" $fullCmd" 2>&1
        if ($ShowOutput) { foreach ($line in $output) { Log " $line" } }
        return $output
    } catch {
        Log "[X] Errore comando ADB: $($_.Exception.Message)"
        return $null
    }
}

# ============================================================
# 0. GESTIONE PACCHETTI (FUNZIONI PRINCIPALI)
# ============================================================

# ---- LISTA PACCHETTI ----
function Get-ADBPackages {
    param(
        [ValidateSet('All', 'System', 'ThirdParty')]
        [string]$Filter = 'All'
    )
    if (Test-Cancel) { return }
    if (-not (Initialize-ADB) -or -not $script:deviceSerial) {
        Log "[X] Nessun dispositivo connesso o ADB non trovato. Esegui prima 'Controlla Dispositivi'."
        return $null
    }
    Log ""; Log "==============================================================================================="
    Log "[>] LISTA PACCHETTI ($Filter)"
    Log "==============================================================================================="
    Update-Status "[...] Elenco pacchetti..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    $cmd = "shell pm list packages"
    if ($Filter -eq 'ThirdParty') { $cmd += " -3" }
    if ($Filter -eq 'System') { $cmd += " -s" }
    
    $output = Invoke-ADBCommand -Command $cmd -Description "Lista pacchetti" -ShowOutput $false
    $packages = @()
    foreach ($line in $output) {
        if ($line -match '^package:(.+)$') {
            $packages += $matches[1]
        }
    }
    Log "[OK] Trovati $($packages.Count) pacchetti."
    Update-Status "[OK] $($packages.Count) pacchetti" $global:successColor
    Flush-LogBuffer; Pump-UI
    return $packages
}

function Export-ADBPackages {
    param(
        [ValidateSet('All', 'System', 'ThirdParty')]
        [string]$Filter = 'All',
        [string]$OutputPath = $null
    )
    if (Test-Cancel) { return }
    if (-not $OutputPath) {
        $desktop = [Environment]::GetFolderPath("Desktop")
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $OutputPath = Join-Path $desktop "packages_$timestamp.txt"
    }
    $packages = Get-ADBPackages -Filter $Filter
    if (-not $packages) {
        Log "[X] Nessun pacchetto da esportare."
        return
    }
    $packages | Sort-Object | Out-File -FilePath $OutputPath -Encoding UTF8
    Log "[OK] Esportati $($packages.Count) pacchetti in: $OutputPath"
    Update-Status "[OK] Esportazione completata" $global:successColor
    Start-Process "explorer.exe" "/select,`"$OutputPath`""
}

# ---- DISABILITA / ABILITA / DISINSTALLA / CACHE ----
function Disable-ADBPackage {
    param([string]$PackageName)
    if (Test-Cancel) { return }
    if (-not $PackageName) {
        $PackageName = Prompt-ADBPackageName -Action "disabilitare"
        if (-not $PackageName) { return }
    }
    $response = [System.Windows.Forms.MessageBox]::Show("Disabilitare il pacchetto '$PackageName'?", "Conferma", "YesNo", "Warning")
    if ($response -ne "Yes") { return }
    Log ""; Log "==============================================================================================="
    Log "[>] DISABILITA PACCHETTO: $PackageName"
    Log "==============================================================================================="
    Update-Status "[...] Disabilitazione..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Invoke-ADBCommand -Command "shell pm disable-user --user 0 $PackageName" -Description "Disabilita pacchetto"
    Update-Status "[OK] Disabilitato" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Enable-ADBPackage {
    param([string]$PackageName)
    if (Test-Cancel) { return }
    if (-not $PackageName) {
        $PackageName = Prompt-ADBPackageName -Action "riabilitare"
        if (-not $PackageName) { return }
    }
    Log ""; Log "==============================================================================================="
    Log "[>] RIABILITA PACCHETTO: $PackageName"
    Log "==============================================================================================="
    Update-Status "[...] Riabilitazione..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Invoke-ADBCommand -Command "shell pm enable $PackageName" -Description "Riabilita pacchetto"
    Update-Status "[OK] Riabilitato" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Uninstall-ADBPackage {
    param([string]$PackageName)
    if (Test-Cancel) { return }
    if (-not $PackageName) {
        $PackageName = Prompt-ADBPackageName -Action "disinstallare"
        if (-not $PackageName) { return }
    }
    $response = [System.Windows.Forms.MessageBox]::Show("Disinstallare il pacchetto '$PackageName'?", "Conferma", "YesNo", "Warning")
    if ($response -ne "Yes") { return }
    Log ""; Log "==============================================================================================="
    Log "[>] DISINSTALLA PACCHETTO: $PackageName"
    Log "==============================================================================================="
    Update-Status "[...] Disinstallazione..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Invoke-ADBCommand -Command "shell pm uninstall -k --user 0 $PackageName" -Description "Disinstalla pacchetto"
    Update-Status "[OK] Disinstallazione" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Clear-ADBPackageCache {
    param([string]$PackageName)
    if (Test-Cancel) { return }
    if (-not $PackageName) {
        $PackageName = Prompt-ADBPackageName -Action "pulire la cache di"
        if (-not $PackageName) { return }
    }
    Log ""; Log "==============================================================================================="
    Log "[>] PULIZIA CACHE: $PackageName"
    Log "==============================================================================================="
    Update-Status "[...] Pulizia cache..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Invoke-ADBCommand -Command "shell pm clear --cache-only $PackageName" -Description "Pulizia cache"
    Update-Status "[OK] Cache pulita" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Clear-ADBAllCache {
    param(
        [ValidateSet('All', 'ThirdParty')]
        [string]$Filter = 'ThirdParty'
    )
    if (Test-Cancel) { return }
    $filterText = if ($Filter -eq 'ThirdParty') { 'di terze parti' } else { '' }
    $response = [System.Windows.Forms.MessageBox]::Show("Pulire la cache di TUTTI i pacchetti $filterText?`nQuesta operazione potrebbe richiedere diversi minuti.", "Conferma", "YesNo", "Warning")
    if ($response -ne "Yes") { return }
    Log ""; Log "==============================================================================================="
    Log "[>] PULIZIA CACHE COMPLETA ($Filter)"
    Log "==============================================================================================="
    Update-Status "[...] Pulizia cache in corso..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    $packages = Get-ADBPackages -Filter $Filter
    if (-not $packages) {
        Log "[X] Nessun pacchetto trovato."
        return
    }
    $count = $packages.Count
    $i = 0
    foreach ($pkg in $packages) {
        $i++
        Update-Status "[$i/$count] Pulizia cache: $pkg" $global:infoColor
        Invoke-ADBCommand -Command "shell pm clear --cache-only $pkg" -Description "Pulizia cache $pkg" -ShowOutput $false
        Flush-LogBuffer; Pump-UI
    }
    Log "[OK] Cache pulita per $count pacchetti."
    Update-Status "[OK] Cache completa pulita" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Trim-ADBCache {
    param([string]$Size = "128G")
    if (Test-Cancel) { return }
    Log ""; Log "==============================================================================================="
    Log "[>] TRIM CACHE (limite: $Size)"
    Log "==============================================================================================="
    Update-Status "[...] Trim cache..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Invoke-ADBCommand -Command "shell pm trim-caches $Size" -Description "Trim cache"
    Update-Status "[OK] Trim completato" $global:successColor
    Flush-LogBuffer; Pump-UI
}

# ---- FUNZIONE DI INPUT PER PACKAGE NAME ----
function Prompt-ADBPackageName {
    param([string]$Action = "gestire")
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Inserisci Package Name"
    $form.Size = New-Object System.Drawing.Size(450, 160)
    $form.StartPosition = "CenterParent"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inserisci il package name da ${Action}:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(390, 25)
    $lbl.ForeColor = [System.Drawing.Color]::White
    $form.Controls.Add($lbl)
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(20, 55)
    $txt.Size = New-Object System.Drawing.Size(390, 26)
    $txt.Font = New-Object System.Drawing.Font("Consolas", 11)
    $txt.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 42)
    $txt.ForeColor = [System.Drawing.Color]::White
    $form.Controls.Add($txt)
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "OK"
    $btnOK.Location = New-Object System.Drawing.Point(230, 95)
    $btnOK.Size = New-Object System.Drawing.Size(85, 28)
    $btnOK.BackColor = [System.Drawing.Color]::FromArgb(0, 160, 0)
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($btnOK)
    $form.AcceptButton = $btnOK
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(325, 95)
    $btnCancel.Size = New-Object System.Drawing.Size(85, 28)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btnCancel)
    $form.CancelButton = $btnCancel
    if ($form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $pkg = $txt.Text.Trim()
        if (-not $pkg) { Log "[X] Package name non inserito."; return $null }
        return $pkg
    }
    return $null
}

# ---- INTERFACCIA GESTIONE PACCHETTI ----
function Show-ADBPackageManager {
    if (Test-Cancel) { return }
    Get-ADBDevices
    if (-not $script:deviceSerial) {
        Log "[X] Nessun dispositivo selezionato. Collega il dispositivo e riprova."
        return
    }
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "📱 Gestione Pacchetti ADB"
    $form.Size = New-Object System.Drawing.Size(700, 600)
    $form.StartPosition = "CenterParent"
    $form.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.TopMost = $true
    $form.MinimumSize = New-Object System.Drawing.Size(600, 400)
    
    $flowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $flowPanel.FlowDirection = "LeftToRight"
    $flowPanel.Location = New-Object System.Drawing.Point(20, 20)
    $flowPanel.Size = New-Object System.Drawing.Size(660, 30)
    $flowPanel.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $form.Controls.Add($flowPanel)
    
    $lblFilter = New-Object System.Windows.Forms.Label
    $lblFilter.Text = "Filtro:"
    $lblFilter.Size = New-Object System.Drawing.Size(40, 25)
    $lblFilter.ForeColor = [System.Drawing.Color]::White
    $flowPanel.Controls.Add($lblFilter)
    
    $cmbFilter = New-Object System.Windows.Forms.ComboBox
    $cmbFilter.Size = New-Object System.Drawing.Size(120, 25)
    $cmbFilter.DropDownStyle = "DropDownList"
    $cmbFilter.Items.AddRange(@("All", "System", "ThirdParty"))
    $cmbFilter.SelectedIndex = 0
    $flowPanel.Controls.Add($cmbFilter)
    
    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = "🔄 Carica Lista"
    $btnRefresh.Size = New-Object System.Drawing.Size(110, 25)
    $btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(56, 132, 244)
    $btnRefresh.ForeColor = [System.Drawing.Color]::White
    $btnRefresh.FlatStyle = "Flat"
    $btnRefresh.Cursor = [System.Windows.Forms.Cursors]::Hand
    $flowPanel.Controls.Add($btnRefresh)
    
    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Text = "📤 Esporta"
    $btnExport.Size = New-Object System.Drawing.Size(80, 25)
    $btnExport.BackColor = [System.Drawing.Color]::FromArgb(0, 160, 0)
    $btnExport.ForeColor = [System.Drawing.Color]::White
    $btnExport.FlatStyle = "Flat"
    $btnExport.Cursor = [System.Windows.Forms.Cursors]::Hand
    $flowPanel.Controls.Add($btnExport)
    
    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(20, 60)
    $listBox.Size = New-Object System.Drawing.Size(660, 350)
    $listBox.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 24)
    $listBox.ForeColor = [System.Drawing.Color]::White
    $listBox.Font = New-Object System.Drawing.Font("Consolas", 10)
    $listBox.SelectionMode = "MultiExtended"
    $form.Controls.Add($listBox)
    
    $btnPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $btnPanel.FlowDirection = "LeftToRight"
    $btnPanel.Location = New-Object System.Drawing.Point(20, 420)
    $btnPanel.Size = New-Object System.Drawing.Size(660, 35)
    $btnPanel.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $form.Controls.Add($btnPanel)
    
    $btnDisable = New-Object System.Windows.Forms.Button
    $btnDisable.Text = "⛔ Disabilita"
    $btnDisable.Size = New-Object System.Drawing.Size(100, 30)
    $btnDisable.BackColor = [System.Drawing.Color]::FromArgb(220, 60, 60)
    $btnDisable.ForeColor = [System.Drawing.Color]::White
    $btnDisable.FlatStyle = "Flat"
    $btnDisable.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnPanel.Controls.Add($btnDisable)
    
    $btnEnable = New-Object System.Windows.Forms.Button
    $btnEnable.Text = "✅ Abilita"
    $btnEnable.Size = New-Object System.Drawing.Size(100, 30)
    $btnEnable.BackColor = [System.Drawing.Color]::FromArgb(0, 160, 0)
    $btnEnable.ForeColor = [System.Drawing.Color]::White
    $btnEnable.FlatStyle = "Flat"
    $btnEnable.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnPanel.Controls.Add($btnEnable)
    
    $btnUninstall = New-Object System.Windows.Forms.Button
    $btnUninstall.Text = "🗑️ Disinstalla"
    $btnUninstall.Size = New-Object System.Drawing.Size(100, 30)
    $btnUninstall.BackColor = [System.Drawing.Color]::FromArgb(200, 50, 50)
    $btnUninstall.ForeColor = [System.Drawing.Color]::White
    $btnUninstall.FlatStyle = "Flat"
    $btnUninstall.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnPanel.Controls.Add($btnUninstall)
    
    $btnClearCache = New-Object System.Windows.Forms.Button
    $btnClearCache.Text = "🧹 Pulizia Cache"
    $btnClearCache.Size = New-Object System.Drawing.Size(110, 30)
    $btnClearCache.BackColor = [System.Drawing.Color]::FromArgb(255, 180, 50)
    $btnClearCache.ForeColor = [System.Drawing.Color]::White
    $btnClearCache.FlatStyle = "Flat"
    $btnClearCache.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnPanel.Controls.Add($btnClearCache)
    
    $btnClearAll = New-Object System.Windows.Forms.Button
    $btnClearAll.Text = "🧹 Pulisci Tutto (cache)"
    $btnClearAll.Size = New-Object System.Drawing.Size(140, 30)
    $btnClearAll.BackColor = [System.Drawing.Color]::FromArgb(200, 140, 40)
    $btnClearAll.ForeColor = [System.Drawing.Color]::White
    $btnClearAll.FlatStyle = "Flat"
    $btnClearAll.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnPanel.Controls.Add($btnClearAll)
    
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(20, 465)
    $statusLabel.Size = New-Object System.Drawing.Size(660, 20)
    $statusLabel.ForeColor = [System.Drawing.Color]::Gray
    $statusLabel.Text = "Pronto"
    $form.Controls.Add($statusLabel)
    
    $script:currentPackages = @()
    function Load-PackageList {
        $filter = $cmbFilter.SelectedItem
        $statusLabel.Text = "Caricamento in corso..."
        $statusLabel.ForeColor = [System.Drawing.Color]::Yellow
        [System.Windows.Forms.Application]::DoEvents()
        
        $listBox.Items.Clear()
        $packages = Get-ADBPackages -Filter $filter
        if ($packages) {
            $script:currentPackages = $packages
            foreach ($pkg in $packages | Sort-Object) {
                $listBox.Items.Add($pkg)
            }
            $statusLabel.Text = "$($packages.Count) pacchetti caricati"
            $statusLabel.ForeColor = [System.Drawing.Color]::Green
        } else {
            $statusLabel.Text = "Nessun pacchetto trovato"
            $statusLabel.ForeColor = [System.Drawing.Color]::Red
        }
    }
    
    $btnRefresh.Add_Click({ Load-PackageList })
    $btnExport.Add_Click({
        $filter = $cmbFilter.SelectedItem
        Export-ADBPackages -Filter $filter
    })
    
    $btnDisable.Add_Click({
        $selected = $listBox.SelectedItems
        if ($selected.Count -eq 0) { Log "[i] Seleziona almeno un pacchetto."; return }
        $pkgList = $selected -join "`n"
        $msg = "Disabilitare questi $($selected.Count) pacchetti?`n`n$pkgList"
        if ([System.Windows.Forms.MessageBox]::Show($msg, "Conferma", "YesNo", "Warning") -eq "Yes") {
            foreach ($pkg in $selected) { Disable-ADBPackage -PackageName $pkg }
            Load-PackageList
        }
    })
    
    $btnEnable.Add_Click({
        $selected = $listBox.SelectedItems
        if ($selected.Count -eq 0) { Log "[i] Seleziona almeno un pacchetto."; return }
        $pkgList = $selected -join "`n"
        $msg = "Riabilitare questi $($selected.Count) pacchetti?`n`n$pkgList"
        if ([System.Windows.Forms.MessageBox]::Show($msg, "Conferma", "YesNo", "Question") -eq "Yes") {
            foreach ($pkg in $selected) { Enable-ADBPackage -PackageName $pkg }
            Load-PackageList
        }
    })
    
    $btnUninstall.Add_Click({
        $selected = $listBox.SelectedItems
        if ($selected.Count -eq 0) { Log "[i] Seleziona almeno un pacchetto."; return }
        $pkgList = $selected -join "`n"
        $msg = "Disinstallare PERMANENTEMENTE questi $($selected.Count) pacchetti?`n`n$pkgList"
        if ([System.Windows.Forms.MessageBox]::Show($msg, "Conferma", "YesNo", "Warning") -eq "Yes") {
            foreach ($pkg in $selected) { Uninstall-ADBPackage -PackageName $pkg }
            Load-PackageList
        }
    })
    
    $btnClearCache.Add_Click({
        $selected = $listBox.SelectedItems
        if ($selected.Count -eq 0) { Log "[i] Seleziona almeno un pacchetto."; return }
        $pkgList = $selected -join "`n"
        $msg = "Pulire la cache di questi $($selected.Count) pacchetti?`n`n$pkgList"
        if ([System.Windows.Forms.MessageBox]::Show($msg, "Conferma", "YesNo", "Question") -eq "Yes") {
            foreach ($pkg in $selected) { Clear-ADBPackageCache -PackageName $pkg }
            Load-PackageList
        }
    })
    
    $btnClearAll.Add_Click({
        $filter = $cmbFilter.SelectedItem
        Clear-ADBAllCache -Filter $filter
        Load-PackageList
    })
    
    Load-PackageList
    $form.ShowDialog() | Out-Null
}

# ============================================================
# 1. BACKUP E RIPRISTINO
# ============================================================

# ---- BACKUP COMPLETO DISPOSITIVO ----
function Backup-ADBFull {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Title = "Salva backup completo"
    $saveDialog.Filter = "Backup file (*.ab)|*.ab|All Files (*.*)|*.*"
    $saveDialog.FileName = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').ab"
    $saveDialog.RestoreDirectory = $true
    
    if ($saveDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Backup annullato."
        return
    }
    
    $backupFile = $saveDialog.FileName
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Il backup completo include: APK, dati condivisi, sistema e tutte le app.`n`nIl dispositivo chiederà conferma per il backup.`n`nProcedere?",
        "Backup Completo",
        "YesNo",
        "Question"
    )
    if ($response -ne "Yes") { return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] BACKUP COMPLETO DISPOSITIVO"
    Log "==============================================================================================="
    Update-Status "[...] Backup in corso..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    Log "[i] ATTENZIONE: Conferma il backup sul dispositivo quando richiesto."
    Log "[i] Il backup potrebbe richiedere alcuni minuti."
    Log ""
    
    $output = Invoke-ADBCommand -Command "backup -apk -shared -all -system -f `"$backupFile`"" -Description "Backup completo" -ShowOutput $true
    $script:lastBackupFile = $backupFile
    
    if (Test-Path $backupFile) {
        $size = [Math]::Round((Get-Item $backupFile).Length / 1MB, 2)
        Log "[OK] Backup completato! File: $backupFile ($size MB)"
        Update-Status "[OK] Backup completato" $global:successColor
    } else {
        Log "[X] Backup fallito o annullato."
        Update-Status "[X] Backup fallito" $global:exitColor
    }
    Flush-LogBuffer; Pump-UI
}

# ---- BACKUP DATI APP SPECIFICA ----
function Backup-ADBAppData {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $package = Prompt-ADBPackageName -Action "eseguire il backup dei dati di"
    if (-not $package) { return }
    
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Title = "Salva backup dati app"
    $saveDialog.Filter = "Backup file (*.ab)|*.ab|All Files (*.*)|*.*"
    $saveDialog.FileName = "${package}_$(Get-Date -Format 'yyyyMMdd_HHmmss').ab"
    $saveDialog.RestoreDirectory = $true
    
    if ($saveDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Backup annullato."
        return
    }
    
    $backupFile = $saveDialog.FileName
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Backup dei dati dell'app '$package'?`n`nIl dispositivo chiederà conferma.",
        "Backup Dati App",
        "YesNo",
        "Question"
    )
    if ($response -ne "Yes") { return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] BACKUP DATI APP: $package"
    Log "==============================================================================================="
    Update-Status "[...] Backup dati app..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    Log "[i] Conferma il backup sul dispositivo."
    Invoke-ADBCommand -Command "backup -f `"$backupFile`" $package" -Description "Backup dati app" -ShowOutput $true
    
    if (Test-Path $backupFile) {
        $size = [Math]::Round((Get-Item $backupFile).Length / 1MB, 2)
        Log "[OK] Backup dati completato! File: $backupFile ($size MB)"
        Update-Status "[OK] Backup dati" $global:successColor
    } else {
        Log "[X] Backup dati fallito o annullato."
        Update-Status "[X] Backup fallito" $global:exitColor
    }
    Flush-LogBuffer; Pump-UI
}

# ---- RIPRISTINO BACKUP ----
function Restore-ADBBackup {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $openDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openDialog.Title = "Seleziona file di backup da ripristinare"
    $openDialog.Filter = "Backup file (*.ab)|*.ab|All Files (*.*)|*.*"
    $openDialog.RestoreDirectory = $true
    
    if ($openDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Ripristino annullato."
        return
    }
    
    $backupFile = $openDialog.FileName
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Ripristinare il backup da '$backupFile'?`n`nATTENZIONE: Il ripristino sovrascriverà i dati esistenti.`n`nIl dispositivo chiederà conferma.",
        "Ripristino Backup",
        "YesNo",
        "Warning"
    )
    if ($response -ne "Yes") { return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] RIPRISTINO BACKUP"
    Log "==============================================================================================="
    Update-Status "[...] Ripristino in corso..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    Log "[i] Conferma il ripristino sul dispositivo."
    Invoke-ADBCommand -Command "restore `"$backupFile`"" -Description "Ripristino backup" -ShowOutput $true
    
    Log "[OK] Ripristino completato (se confermato sul dispositivo)."
    Update-Status "[OK] Ripristino" $global:successColor
    Flush-LogBuffer; Pump-UI
}

# ---- BACKUP APK (estrai APK) ----
function Backup-ADBAPKs {
    param(
        [ValidateSet('All', 'ThirdParty')]
        [string]$Filter = 'All'
    )
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $filterText = if ($Filter -eq 'ThirdParty') { 'di terze parti' } else { '' }
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Estrarre TUTTI gli APK delle app installate $filterText?`n`nI file verranno salvati in una cartella sul desktop.`nQuesta operazione potrebbe richiedere del tempo.",
        "Backup APK",
        "YesNo",
        "Question"
    )
    if ($response -ne "Yes") { return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] BACKUP APK"
    Log "==============================================================================================="
    Update-Status "[...] Estrazione APK..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    $desktop = [Environment]::GetFolderPath("Desktop")
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $outputDir = Join-Path $desktop "APK_Backup_$timestamp"
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    
    $packages = Get-ADBPackages -Filter 'All'
    if (-not $packages) {
        Log "[X] Nessun pacchetto trovato."
        return
    }
    
    $count = $packages.Count
    $i = 0
    $extracted = 0
    $failed = 0
    
    Log "[OK] Trovati $count pacchetti. Inizio estrazione..."
    
    foreach ($pkg in $packages | Sort-Object) {
        $i++
        Update-Status "[$i/$count] Estrazione: $pkg" $global:infoColor
        Flush-LogBuffer; Pump-UI
        
        $pathOutput = Invoke-ADBCommand -Command "shell pm path $pkg" -Description "Percorso APK" -ShowOutput $false
        if ($pathOutput -match '^package:(.+)$') {
            $apkPath = $matches[1]
            $apkName = ($pkg -replace '[^a-zA-Z0-9]', '_') + ".apk"
            $destFile = Join-Path $outputDir $apkName
            
            $pullResult = Invoke-ADBCommand -Command "pull `"$apkPath`" `"$destFile`"" -Description "Download APK" -ShowOutput $false
            if (Test-Path $destFile) {
                $extracted++
            } else {
                $failed++
            }
        } else {
            $failed++
        }
    }
    
    Log ""
    Log "[OK] Estrazione completata!"
    Log "    - APK estratti: $extracted"
    Log "    - Falliti: $failed"
    Log "    - Cartella: $outputDir"
    Update-Status "[OK] $extracted APK estratti" $global:successColor
    Start-Process "explorer.exe" $outputDir
    Flush-LogBuffer; Pump-UI
}

# ---- RIAVVIO IN FASTBOOT ----
function Reboot-ADBFastboot {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Riavviare il dispositivo in modalità FASTBOOT?`n`nQuesta modalità è utilizzata per operazioni avanzate (sblocco bootloader, flashing, ecc.).",
        "Riavvio Fastboot",
        "YesNo",
        "Warning"
    )
    if ($response -ne "Yes") { return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] RIAVVIO IN FASTBOOT"
    Log "==============================================================================================="
    Update-Status "[...] Riavvio in Fastboot..." $global:warningColor
    Flush-LogBuffer; Pump-UI
    
    Invoke-ADBCommand -Command "reboot bootloader" -Description "Riavvio Fastboot"
    Log "[OK] Riavvio in Fastboot inviato. Il dispositivo si riavvierà."
    Update-Status "[OK] Fastboot" $global:successColor
    Flush-LogBuffer; Pump-UI
}

# ---- RIAVVIO IN RECOVERY ----
function Reboot-ADBRecovery {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Riavviare il dispositivo in modalità RECOVERY?`n`nQuesta modalità permette di fare wipe cache, factory reset, installare update, ecc.",
        "Riavvio Recovery",
        "YesNo",
        "Warning"
    )
    if ($response -ne "Yes") { return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] RIAVVIO IN RECOVERY"
    Log "==============================================================================================="
    Update-Status "[...] Riavvio in Recovery..." $global:warningColor
    Flush-LogBuffer; Pump-UI
    
    Invoke-ADBCommand -Command "reboot recovery" -Description "Riavvio Recovery"
    Log "[OK] Riavvio in Recovery inviato. Il dispositivo si riavvierà."
    Update-Status "[OK] Recovery" $global:successColor
    Flush-LogBuffer; Pump-UI
}

# ---- RESET APP (CLEAR DATA) ----
function Clear-ADBAppData {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $package = Prompt-ADBPackageName -Action "cancellare i dati di"
    if (-not $package) { return }
    
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Cancellare TUTTI i dati dell'app '$package'?`n`nQuesto equivale a un 'Clear Data' / 'Cancella Dati' dell'app.`nI dati saranno definitivamente persi!",
        "Reset Dati App",
        "YesNo",
        "Warning"
    )
    if ($response -ne "Yes") { return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] RESET DATI APP: $package"
    Log "==============================================================================================="
    Update-Status "[...] Reset dati app..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    Invoke-ADBCommand -Command "shell pm clear $package" -Description "Reset dati app"
    Update-Status "[OK] Dati cancellati" $global:successColor
    Flush-LogBuffer; Pump-UI
}

# ---- RESET IMPOSTAZIONI DI RETE ----
function Reset-ADBNetworkSettings {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Resettare le impostazioni di rete?`n`nVerranno resettate: WiFi, Bluetooth, Dati mobili, VPN.`nLe reti salvate verranno cancellate.",
        "Reset Impostazioni Rete",
        "YesNo",
        "Warning"
    )
    if ($response -ne "Yes") { return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] RESET IMPOSTAZIONI RETE"
    Log "==============================================================================================="
    Update-Status "[...] Reset rete..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    Invoke-ADBCommand -Command "shell settings delete global airplane_mode_on" -Description "Reset Airplane Mode" -ShowOutput $false
    Invoke-ADBCommand -Command "shell settings delete global wifi_on" -Description "Reset WiFi" -ShowOutput $false
    Invoke-ADBCommand -Command "shell settings delete global bluetooth_on" -Description "Reset Bluetooth" -ShowOutput $false
    
    Log "[OK] Impostazioni di rete resettate. Il dispositivo potrebbe richiedere un riavvio per applicare completamente."
    Update-Status "[OK] Reset rete" $global:successColor
    Flush-LogBuffer; Pump-UI
}

# ============================================================
# 2. GESTIONE FILE
# ============================================================

# ---- COPIA FILE DAL TELEFONO AL PC (PULL) ----
function Pull-ADBFile {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Copia Phone to PC"
    $inputForm.Size = New-Object System.Drawing.Size(450, 160)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $inputForm.ForeColor = [System.Drawing.Color]::White
    $inputForm.TopMost = $true
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Percorso file sul telefono (es. /sdcard/file.txt):"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(390, 25)
    $lbl.ForeColor = [System.Drawing.Color]::White
    $inputForm.Controls.Add($lbl)
    
    $txtPath = New-Object System.Windows.Forms.TextBox
    $txtPath.Location = New-Object System.Drawing.Point(20, 55)
    $txtPath.Size = New-Object System.Drawing.Size(390, 26)
    $txtPath.Font = New-Object System.Drawing.Font("Consolas", 11)
    $txtPath.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 42)
    $txtPath.ForeColor = [System.Drawing.Color]::White
    $txtPath.Text = "/sdcard/"
    $inputForm.Controls.Add($txtPath)
    
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Seleziona destinazione"
    $btnOK.Location = New-Object System.Drawing.Point(230, 95)
    $btnOK.Size = New-Object System.Drawing.Size(180, 28)
    $btnOK.BackColor = [System.Drawing.Color]::FromArgb(56, 132, 244)
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK
    
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140, 95)
    $btnCancel.Size = New-Object System.Drawing.Size(80, 28)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($btnCancel)
    $inputForm.CancelButton = $btnCancel
    
    if ($inputForm.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Copia annullata."
        return
    }
    
    $remotePath = $txtPath.Text.Trim()
    if (-not $remotePath) { Log "[X] Percorso non inserito."; return }
    
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Title = "Salva file sul PC"
    $saveDialog.RestoreDirectory = $true
    $fileName = Split-Path $remotePath -Leaf
    if ($fileName) { $saveDialog.FileName = $fileName }
    
    if ($saveDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Copia annullata."
        return
    }
    
    $localPath = $saveDialog.FileName
    
    Log ""; Log "==============================================================================================="
    Log "[>] COPIA FILE: $remotePath -> $localPath"
    Log "==============================================================================================="
    Update-Status "[...] Copia in corso..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    Invoke-ADBCommand -Command "pull `"$remotePath`" `"$localPath`"" -Description "Pull file" -ShowOutput $true
    
    if (Test-Path $localPath) {
        $size = [Math]::Round((Get-Item $localPath).Length / 1KB, 2)
        Log "[OK] File copiato con successo! ($size KB)"
        Update-Status "[OK] File copiato" $global:successColor
        explorer.exe "/select,`"$localPath`""
    } else {
        Log "[X] Errore nella copia del file. Verifica il percorso sul dispositivo."
        Update-Status "[X] Errore" $global:exitColor
    }
    Flush-LogBuffer; Pump-UI
}

# ---- COPIA FILE DAL PC AL TELEFONO (PUSH) ----
function Push-ADBFile {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $openDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openDialog.Title = "Seleziona file da copiare sul telefono"
    $openDialog.RestoreDirectory = $true
    
    if ($openDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Copia annullata."
        return
    }
    
    $localPath = $openDialog.FileName
    $fileName = Split-Path $localPath -Leaf
    
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Destinazione sul telefono"
    $inputForm.Size = New-Object System.Drawing.Size(450, 160)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $inputForm.ForeColor = [System.Drawing.Color]::White
    $inputForm.TopMost = $true
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Percorso destinazione (es. /sdcard/Download/):"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(390, 25)
    $lbl.ForeColor = [System.Drawing.Color]::White
    $inputForm.Controls.Add($lbl)
    
    $txtPath = New-Object System.Windows.Forms.TextBox
    $txtPath.Location = New-Object System.Drawing.Point(20, 55)
    $txtPath.Size = New-Object System.Drawing.Size(390, 26)
    $txtPath.Font = New-Object System.Drawing.Font("Consolas", 11)
    $txtPath.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 42)
    $txtPath.ForeColor = [System.Drawing.Color]::White
    $txtPath.Text = "/sdcard/Download/"
    $inputForm.Controls.Add($txtPath)
    
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Copia"
    $btnOK.Location = New-Object System.Drawing.Point(230, 95)
    $btnOK.Size = New-Object System.Drawing.Size(180, 28)
    $btnOK.BackColor = [System.Drawing.Color]::FromArgb(0, 160, 0)
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK
    
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140, 95)
    $btnCancel.Size = New-Object System.Drawing.Size(80, 28)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($btnCancel)
    $inputForm.CancelButton = $btnCancel
    
    if ($inputForm.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Copia annullata."
        return
    }
    
    $remotePath = $txtPath.Text.Trim()
    if (-not $remotePath) { $remotePath = "/sdcard/" }
    if (-not $remotePath.EndsWith("/")) { $remotePath += "/" }
    $remotePath += $fileName
    
    Log ""; Log "==============================================================================================="
    Log "[>] COPIA FILE: $localPath -> $remotePath"
    Log "==============================================================================================="
    Update-Status "[...] Copia in corso..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    Invoke-ADBCommand -Command "push `"$localPath`" `"$remotePath`"" -Description "Push file" -ShowOutput $true
    Log "[OK] File copiato sul telefono."
    Update-Status "[OK] File copiato" $global:successColor
    Flush-LogBuffer; Pump-UI
}

# ============================================================
# 3. DIAGNOSTICA E MONITORAGGIO
# ============================================================

# ---- INFO DETTAGLIATE DISPOSITIVO ----
function Get-ADBDeviceInfo {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] INFO DETTAGLIATE DISPOSITIVO"
    Log "==============================================================================================="
    Update-Status "[...] Recupero info..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    $props = @{
        "ro.product.manufacturer" = "Produttore"
        "ro.product.model" = "Modello"
        "ro.product.name" = "Nome prodotto"
        "ro.build.version.release" = "Versione Android"
        "ro.build.version.sdk" = "SDK"
        "ro.build.fingerprint" = "Build"
        "ro.build.date" = "Data build"
        "ro.build.type" = "Tipo build"
        "ro.kernel.version" = "Versione kernel"
        "ro.bootloader" = "Bootloader"
        "ro.hardware" = "Hardware"
        "ro.product.cpu.abi" = "CPU ABI"
        "ro.serialno" = "Numero seriale"
        "ro.product.board" = "Board"
        "ro.product.device" = "Device"
        "ro.build.host" = "Host build"
        "ro.build.user" = "User build"
        "ro.build.tags" = "Tags"
        "ro.build.description" = "Descrizione build"
        "ro.build.display.id" = "Display ID"
        "ro.product.locale" = "Locale"
        "ro.product.brand" = "Brand"
        "ro.sf.lcd_density" = "Densità display"
        "ro.secure" = "Secure"
    }
    
    Log "  [INFORMAZIONI HARDWARE E SOFTWARE]"
    Log "  ---------------------------------------------"
    foreach ($key in $props.Keys | Sort-Object) {
        $value = Invoke-ADBCommand -Command "shell getprop $key" -Description "Get prop" -ShowOutput $false
        $value = $value -replace "`n|`r", "" -replace "\[|\]", ""
        if ($value) {
            Log "  $($props[$key]): $value"
        }
    }
    
    Log ""
    Log "  [STATO BATTERIA]"
    Log "  ---------------------------------------------"
    $battery = Invoke-ADBCommand -Command "shell dumpsys battery" -Description "Stato batteria" -ShowOutput $false
    $lines = $battery -split "`n"
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -match "^(level|scale|temperature|voltage|status|health|present|AC powered|USB powered|Wireless powered): (.+)$") {
            $key = $matches[1]
            $val = $matches[2]
            if ($key -eq "level") { Log "  🔋 Livello: $val%" }
            elseif ($key -eq "scale") { Log "  📏 Scala: $val" }
            elseif ($key -eq "temperature") { 
                $tempC = [Math]::Round([int]$val / 10, 1)
                Log "  🌡️ Temperatura: $tempC °C"
            }
            elseif ($key -eq "voltage") {
                $volt = [Math]::Round([int]$val / 1000, 2)
                Log "  ⚡ Voltaggio: $volt V"
            }
            elseif ($key -eq "status") { 
                $status = @{1="Carica"; 2="In carica"; 3="Scarica"; 4="Non in carica"; 5="Piena"}[[int]$val] -replace $null, "Sconosciuto"
                Log "  📊 Stato: $status"
            }
            elseif ($key -eq "health") {
                $health = @{1="Buona"; 2="Ottima"; 3="Surriscaldata"; 4="Difettosa"; 5="Overvoltage"; 6="Non specificata"}[[int]$val] -replace $null, "Sconosciuta"
                Log "  ❤️ Salute: $health"
            }
            elseif ($key -eq "present") { Log "  ✅ Presente: $val" }
            elseif ($key -match "powered") { Log ("  🔌 {0}: {1}" -f $key, $val) }
        }
    }
    
    Log ""
    Log "  [MEMORIA E STORAGE]"
    Log "  ---------------------------------------------"
    $memInfo = Invoke-ADBCommand -Command "shell dumpsys meminfo" -Description "Memoria" -ShowOutput $false
    $memLines = $memInfo -split "`n"
    $foundMem = $false
    foreach ($line in $memLines) {
        if ($line -match "^\s*Total RAM: (\d+)\s*KB") {
            $ram = [Math]::Round([int]$matches[1] / 1MB, 2)
            Log "  💾 RAM totale: $ram GB"
            $foundMem = $true
        }
        if ($line -match "^\s*Free RAM: (\d+)\s*KB") {
            $ram = [Math]::Round([int]$matches[1] / 1MB, 2)
            Log "  💾 RAM libera: $ram GB"
            $foundMem = $true
        }
        if ($line -match "^\s*Used RAM: (\d+)\s*KB") {
            $ram = [Math]::Round([int]$matches[1] / 1MB, 2)
            Log "  💾 RAM usata: $ram GB"
            $foundMem = $true
        }
    }
    
    $storage = Invoke-ADBCommand -Command "shell df -h" -Description "Spazio" -ShowOutput $false
    Log ""
    $storageLines = $storage -split "`n"
    foreach ($line in $storageLines) {
        if ($line -match "/data$|/sdcard$") {
            Log "  📂 $line"
        }
    }
    
    Update-Status "[OK] Info recuperate" $global:successColor
    Flush-LogBuffer; Pump-UI
    Log "==============================================================================================="
}

# ---- STATO BATTERIA IN TEMPO REALE ----
function Get-ADBBatteryStatus {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] STATO BATTERIA"
    Log "==============================================================================================="
    Update-Status "[...] Lettura batteria..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    $battery = Invoke-ADBCommand -Command "shell dumpsys battery" -Description "Batteria" -ShowOutput $false
    
    Log "  [DATI BATTERIA]"
    Log "  ---------------------------------------------"
    $lines = $battery -split "`n"
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -match "^(level|scale|temperature|voltage|status|health|present|AC powered|USB powered|Wireless powered|batteryPresent): (.+)$") {
            $key = $matches[1]
            $val = $matches[2]
            if ($key -eq "level") { Log "  🔋 Livello: $val%" }
            elseif ($key -eq "scale") { Log "  📏 Scala massima: $val" }
            elseif ($key -eq "temperature") { 
                $tempC = [Math]::Round([int]$val / 10, 1)
                $tempF = [Math]::Round(($tempC * 9/5) + 32, 1)
                Log "  🌡️ Temperatura: $tempC °C / $tempF °F"
            }
            elseif ($key -eq "voltage") {
                $volt = [Math]::Round([int]$val / 1000, 2)
                Log "  ⚡ Voltaggio: $volt V"
            }
            elseif ($key -eq "status") { 
                $status = @{1="Sconosciuto"; 2="In carica"; 3="Scarica"; 4="Non in carica"; 5="Piena"}[[int]$val] -replace $null, "Sconosciuto"
                Log "  📊 Stato: $status"
            }
            elseif ($key -eq "health") {
                $health = @{1="Buona"; 2="Ottima"; 3="Surriscaldata"; 4="Difettosa"; 5="Overvoltage"; 6="Non specificata"}[[int]$val] -replace $null, "Sconosciuta"
                Log "  ❤️ Salute: $health"
            }
            elseif ($key -eq "present" -or $key -eq "batteryPresent") { 
                $present = if ([int]$val -eq 1) { "Sì" } else { "No" }
                Log "  ✅ Batteria presente: $present"
            }
            elseif ($key -match "powered") { 
                $powered = if ([int]$val -eq 1) { "Sì" } else { "No" }
                Log ("  🔌 {0}: {1}" -f $key, $powered)
            }
            else { Log ("  {0}: {1}" -f $key, $val) }
        }
    }
    
    Update-Status "[OK] Batteria letta" $global:successColor
    Flush-LogBuffer; Pump-UI
    Log "==============================================================================================="
}

# ---- UTILIZZO CPU/MEMORIA ----
function Get-ADBTopProcesses {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Processi in esecuzione"
    $inputForm.Size = New-Object System.Drawing.Size(400, 130)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $inputForm.ForeColor = [System.Drawing.Color]::White
    $inputForm.TopMost = $true
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Numero di processi da mostrare:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(350, 25)
    $lbl.ForeColor = [System.Drawing.Color]::White
    $inputForm.Controls.Add($lbl)
    
    $txtCount = New-Object System.Windows.Forms.TextBox
    $txtCount.Location = New-Object System.Drawing.Point(20, 50)
    $txtCount.Size = New-Object System.Drawing.Size(80, 26)
    $txtCount.Font = New-Object System.Drawing.Font("Consolas", 11)
    $txtCount.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 42)
    $txtCount.ForeColor = [System.Drawing.Color]::White
    $txtCount.Text = "20"
    $inputForm.Controls.Add($txtCount)
    $inputForm.AcceptButton = $txtCount
    
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Mostra"
    $btnOK.Location = New-Object System.Drawing.Point(120, 50)
    $btnOK.Size = New-Object System.Drawing.Size(80, 28)
    $btnOK.BackColor = [System.Drawing.Color]::FromArgb(56, 132, 244)
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK
    
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(210, 50)
    $btnCancel.Size = New-Object System.Drawing.Size(80, 28)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($btnCancel)
    $inputForm.CancelButton = $btnCancel
    
    if ($inputForm.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Annullato."
        return
    }
    
    $count = [int]$txtCount.Text
    if ($count -lt 1) { $count = 20 }
    if ($count -gt 50) { $count = 50 }
    
    Log ""; Log "==============================================================================================="
    Log "[>] TOP $count PROCESSI"
    Log "==============================================================================================="
    Update-Status "[...] Lettura processi..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    $top = Invoke-ADBCommand -Command "shell top -n 1 -m $count" -Description "Top processi" -ShowOutput $false
    
    Log ""
    Log "  [PROCESSI PIÙ PESANTI]"
    Log "  ---------------------------------------------"
    Log "  %CPU  %MEM  PID   Nome processo"
    Log "  ---------------------------------------------"
    
    $lines = $top -split "`n"
    $found = $false
    foreach ($line in $lines) {
        if ($line -match "^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)$") {
            $cpu = $matches[1]
            $mem = $matches[7]
            $pid = $matches[3]
            $name = $matches[8]
            Log "  $cpu%    $mem%    $pid    $name"
            $found = $true
        }
    }
    
    if (-not $found) {
        Log "  [Nessun processo rilevato o formato non riconosciuto]"
        Log "  [Output raw per debug:]"
        foreach ($line in $lines) {
            Log "  $line"
        }
    }
    
    Update-Status "[OK] Processi mostrati" $global:successColor
    Flush-LogBuffer; Pump-UI
    Log "==============================================================================================="
}

# ---- REGISTRAZIONE SCHERMO ----
function Record-ADBScreen {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Registrazione Schermo"
    $inputForm.Size = New-Object System.Drawing.Size(450, 200)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $inputForm.ForeColor = [System.Drawing.Color]::White
    $inputForm.TopMost = $true
    
    $lblDuration = New-Object System.Windows.Forms.Label
    $lblDuration.Text = "Durata (secondi, 0=illimitato):"
    $lblDuration.Location = New-Object System.Drawing.Point(20, 20)
    $lblDuration.Size = New-Object System.Drawing.Size(200, 25)
    $lblDuration.ForeColor = [System.Drawing.Color]::White
    $inputForm.Controls.Add($lblDuration)
    
    $txtDuration = New-Object System.Windows.Forms.TextBox
    $txtDuration.Location = New-Object System.Drawing.Point(220, 20)
    $txtDuration.Size = New-Object System.Drawing.Size(60, 26)
    $txtDuration.Font = New-Object System.Drawing.Font("Consolas", 11)
    $txtDuration.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 42)
    $txtDuration.ForeColor = [System.Drawing.Color]::White
    $txtDuration.Text = "30"
    $inputForm.Controls.Add($txtDuration)
    
    $lblSize = New-Object System.Windows.Forms.Label
    $lblSize.Text = "Risoluzione (default=auto):"
    $lblSize.Location = New-Object System.Drawing.Point(20, 60)
    $lblSize.Size = New-Object System.Drawing.Size(200, 25)
    $lblSize.ForeColor = [System.Drawing.Color]::White
    $inputForm.Controls.Add($lblSize)
    
    $txtSize = New-Object System.Windows.Forms.TextBox
    $txtSize.Location = New-Object System.Drawing.Point(220, 60)
    $txtSize.Size = New-Object System.Drawing.Size(150, 26)
    $txtSize.Font = New-Object System.Drawing.Font("Consolas", 11)
    $txtSize.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 42)
    $txtSize.ForeColor = [System.Drawing.Color]::White
    $txtSize.Text = ""
    $inputForm.Controls.Add($txtSize)
    
    $lblBitrate = New-Object System.Windows.Forms.Label
    $lblBitrate.Text = "Bitrate (Mbps, default=4):"
    $lblBitrate.Location = New-Object System.Drawing.Point(20, 100)
    $lblBitrate.Size = New-Object System.Drawing.Size(200, 25)
    $lblBitrate.ForeColor = [System.Drawing.Color]::White
    $inputForm.Controls.Add($lblBitrate)
    
    $txtBitrate = New-Object System.Windows.Forms.TextBox
    $txtBitrate.Location = New-Object System.Drawing.Point(220, 100)
    $txtBitrate.Size = New-Object System.Drawing.Size(60, 26)
    $txtBitrate.Font = New-Object System.Drawing.Font("Consolas", 11)
    $txtBitrate.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 42)
    $txtBitrate.ForeColor = [System.Drawing.Color]::White
    $txtBitrate.Text = "4"
    $inputForm.Controls.Add($txtBitrate)
    
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Avvia Registrazione"
    $btnOK.Location = New-Object System.Drawing.Point(230, 135)
    $btnOK.Size = New-Object System.Drawing.Size(180, 28)
    $btnOK.BackColor = [System.Drawing.Color]::FromArgb(220, 60, 60)
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK
    
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140, 135)
    $btnCancel.Size = New-Object System.Drawing.Size(80, 28)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($btnCancel)
    $inputForm.CancelButton = $btnCancel
    
    if ($inputForm.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Registrazione annullata."
        return
    }
    
    $duration = [int]$txtDuration.Text
    $size = $txtSize.Text.Trim()
    $bitrate = [int]$txtBitrate.Text
    
    if ($duration -lt 0) { $duration = 0 }
    if ($bitrate -lt 1) { $bitrate = 4 }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $remoteFile = "/sdcard/screenrecord_$timestamp.mp4"
    $desktop = [Environment]::GetFolderPath("Desktop")
    $localFile = Join-Path $desktop "screenrecord_$timestamp.mp4"
    
    $durationText = if ($duration -gt 0) { "$duration secondi" } else { 'Illimitata' }
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Avviare la registrazione schermo?`n`nDurata: $durationText`nBitrate: $bitrate Mbps`n`nPer interrompere una registrazione illimitata, usa Ctrl+C nel terminale.",
        "Registrazione Schermo",
        "YesNo",
        "Question"
    )
    if ($response -ne "Yes") { return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] REGISTRAZIONE SCHERMO"
    Log "==============================================================================================="
    Update-Status "[...] Registrazione in corso..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    $cmd = "shell screenrecord"
    if ($duration -gt 0) { $cmd += " --time-limit $duration" }
    if ($size) { $cmd += " --size $size" }
    if ($bitrate -gt 0) { $cmd += " --bit-rate $($bitrate * 1000000)" }
    $cmd += " $remoteFile"
    
    Log "[i] Registrazione in corso..."
    if ($duration -gt 0) {
        Log "[i] Durata: $duration secondi"
    } else {
        Log "[i] Registrazione illimitata. Premi Ctrl+C per interrompere."
    }
    
    Invoke-ADBCommand -Command $cmd -Description "Registrazione schermo" -ShowOutput $true
    
    Start-Sleep -Milliseconds 1000
    
    Log "[>] Download del video..."
    Invoke-ADBCommand -Command "pull $remoteFile `"$localFile`"" -Description "Download video" -ShowOutput $false
    Invoke-ADBCommand -Command "shell rm $remoteFile" -Description "Pulizia" -ShowOutput $false
    
    if (Test-Path $localFile) {
        $sizeMB = [Math]::Round((Get-Item $localFile).Length / 1MB, 2)
        Log "[OK] Video salvato: $localFile ($sizeMB MB)"
        Update-Status "[OK] Video salvato" $global:successColor
        explorer.exe "/select,`"$localFile`""
    } else {
        Log "[X] Video non salvato correttamente."
        Update-Status "[X] Errore" $global:exitColor
    }
    Flush-LogBuffer; Pump-UI
}

# ============================================================
# 4. SICUREZZA E PRIVACY
# ============================================================

# ---- BLOCCO/SBLOCCO SCHERMO ----
function Lock-ADBScreen {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] BLOCCO SCHERMO"
    Log "==============================================================================================="
    Update-Status "[...] Blocco schermo..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    Invoke-ADBCommand -Command "shell input keyevent KEYCODE_POWER" -Description "Blocco schermo" -ShowOutput $true
    Log "[OK] Schermo bloccato."
    Update-Status "[OK] Schermo bloccato" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Unlock-ADBScreen {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] SBLOCCO SCHERMO"
    Log "==============================================================================================="
    Update-Status "[...] Sblocco schermo..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    Invoke-ADBCommand -Command "shell input keyevent 82" -Description "Sblocco schermo (MENU)" -ShowOutput $false
    Invoke-ADBCommand -Command "shell input keyevent KEYCODE_MENU" -Description "Sblocco schermo (MENU)" -ShowOutput $false
    
    Log "[!] Se lo schermo è protetto da PIN/pattern, sbloccalo manualmente."
    Log "[OK] Tentativo di sblocco inviato."
    Update-Status "[OK] Sblocco tentato" $global:successColor
    Flush-LogBuffer; Pump-UI
}

# ---- INSERISCI TESTO ----
function Send-ADBText {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Inserisci testo sul dispositivo"
    $inputForm.Size = New-Object System.Drawing.Size(500, 170)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $inputForm.ForeColor = [System.Drawing.Color]::White
    $inputForm.TopMost = $true
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Testo da inviare (deve essere selezionato un campo di input):"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(440, 25)
    $lbl.ForeColor = [System.Drawing.Color]::White
    $inputForm.Controls.Add($lbl)
    
    $txtText = New-Object System.Windows.Forms.TextBox
    $txtText.Location = New-Object System.Drawing.Point(20, 55)
    $txtText.Size = New-Object System.Drawing.Size(440, 26)
    $txtText.Font = New-Object System.Drawing.Font("Consolas", 11)
    $txtText.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 42)
    $txtText.ForeColor = [System.Drawing.Color]::White
    $inputForm.Controls.Add($txtText)
    
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Invia"
    $btnOK.Location = New-Object System.Drawing.Point(300, 100)
    $btnOK.Size = New-Object System.Drawing.Size(80, 28)
    $btnOK.BackColor = [System.Drawing.Color]::FromArgb(0, 160, 0)
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK
    
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(390, 100)
    $btnCancel.Size = New-Object System.Drawing.Size(80, 28)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($btnCancel)
    $inputForm.CancelButton = $btnCancel
    
    if ($inputForm.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Invio testo annullato."
        return
    }
    
    $text = $txtText.Text
    if (-not $text) { Log "[X] Nessun testo inserito."; return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] INVIO TESTO"
    Log "==============================================================================================="
    Update-Status "[...] Invio testo..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    $escapedText = $text -replace "'", "'\''" -replace "`"", '\"'
    Invoke-ADBCommand -Command "shell input text `"$escapedText`"" -Description "Invio testo" -ShowOutput $true
    
    Log "[OK] Testo inviato."
    Update-Status "[OK] Testo inviato" $global:successColor
    Flush-LogBuffer; Pump-UI
}

# ---- SCATTA FOTO (Camera Remota) ----
function Camera-ADBPhoto {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Scattare una foto con la fotocamera del dispositivo?`n`nLa foto verrà salvata nella galleria.",
        "Scatta Foto",
        "YesNo",
        "Question"
    )
    if ($response -ne "Yes") { return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] SCATTA FOTO"
    Log "==============================================================================================="
    Update-Status "[...] Apertura fotocamera..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    Invoke-ADBCommand -Command "shell am start -a android.media.action.IMAGE_CAPTURE" -Description "Apertura fotocamera" -ShowOutput $true
    Start-Sleep -Milliseconds 500
    
    Log "[i] Scatto in corso..."
    Invoke-ADBCommand -Command "shell input keyevent KEYCODE_CAMERA" -Description "Scatto" -ShowOutput $true
    
    Log "[OK] Foto scattata! Dovresti vederla nella galleria."
    Update-Status "[OK] Foto scattata" $global:successColor
    Flush-LogBuffer; Pump-UI
}

# ---- LEGGI SMS ----
function Get-ADBSMS {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] LEGGI SMS"
    Log "==============================================================================================="
    Update-Status "[...] Lettura SMS..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    $sms = Invoke-ADBCommand -Command "shell content query --uri content://sms/inbox --projection address:body:date" -Description "Lettura SMS" -ShowOutput $false
    
    Log ""
    Log "  [SMS RICEVUTI (ultimi 20)]"
    Log "  ---------------------------------------------"
    $lines = $sms -split "`n"
    $count = 0
    foreach ($line in $lines) {
        if ($line -match "address=([^,]+), body=([^,]+), date=(\d+)") {
            $address = $matches[1]
            $body = $matches[2]
            $date = [datetime]::FromFileTime([int64]$matches[3]).ToString("yyyy-MM-dd HH:mm")
            Log ("  📩 [{0}] {1}: {2}" -f $date, $address, $body)
            $count++
            if ($count -ge 20) { break }
        }
    }
    
    if ($count -eq 0) {
        Log "  [Nessun SMS trovato o permessi insufficienti]"
        Log "[i] Assicurati che il dispositivo abbia i permessi di lettura SMS."
    } else {
        Log ""
        Log "  [Mostrati $count SMS]"
    }
    
    Update-Status "[OK] Lettura SMS completata" $global:successColor
    Flush-LogBuffer; Pump-UI
    Log "==============================================================================================="
}

# ---- EFFETTUA CHIAMATA ----
function Call-ADBPhone {
    if (Test-Cancel) { return }
    if (-not $script:deviceSerial) { Log "[X] Nessun dispositivo selezionato."; return }
    
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Effettua Chiamata"
    $inputForm.Size = New-Object System.Drawing.Size(450, 160)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $inputForm.ForeColor = [System.Drawing.Color]::White
    $inputForm.TopMost = $true
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Numero di telefono (es. 123456789):"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(390, 25)
    $lbl.ForeColor = [System.Drawing.Color]::White
    $inputForm.Controls.Add($lbl)
    
    $txtNumber = New-Object System.Windows.Forms.TextBox
    $txtNumber.Location = New-Object System.Drawing.Point(20, 55)
    $txtNumber.Size = New-Object System.Drawing.Size(390, 26)
    $txtNumber.Font = New-Object System.Drawing.Font("Consolas", 11)
    $txtNumber.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 42)
    $txtNumber.ForeColor = [System.Drawing.Color]::White
    $inputForm.Controls.Add($txtNumber)
    
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Chiama"
    $btnOK.Location = New-Object System.Drawing.Point(230, 95)
    $btnOK.Size = New-Object System.Drawing.Size(180, 28)
    $btnOK.BackColor = [System.Drawing.Color]::FromArgb(0, 160, 0)
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK
    
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140, 95)
    $btnCancel.Size = New-Object System.Drawing.Size(80, 28)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($btnCancel)
    $inputForm.CancelButton = $btnCancel
    
    if ($inputForm.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Chiamata annullata."
        return
    }
    
    $number = $txtNumber.Text.Trim()
    if (-not $number) { Log "[X] Numero non inserito."; return }
    
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Effettuare chiamata a $number?",
        "Conferma Chiamata",
        "YesNo",
        "Warning"
    )
    if ($response -ne "Yes") { return }
    
    Log ""; Log "==============================================================================================="
    Log "[>] CHIAMATA: $number"
    Log "==============================================================================================="
    Update-Status "[...] Chiamata..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    
    Invoke-ADBCommand -Command "shell am start -a android.intent.action.CALL -d tel:$number" -Description "Chiamata"
    
    Log "[OK] Chiamata avviata."
    Update-Status "[OK] Chiamata avviata" $global:successColor
    Flush-LogBuffer; Pump-UI
}

# ---- FUNZIONI WRAPPER PER LA GUI ----
function Do-ADBDevices { Get-ADBDevices }
function Do-ADBReboot { 
    if (Test-Cancel) { return }
    $response = [System.Windows.Forms.MessageBox]::Show("Riavviare il dispositivo?", "Conferma", "YesNo", "Question")
    if ($response -ne "Yes") { return }
    Log ""; Log "==============================================================================================="
    Log "[>] RIAVVIO DISPOSITIVO"
    Log "==============================================================================================="
    Update-Status "[...] Riavvio..." $global:warningColor
    Flush-LogBuffer; Pump-UI
    Invoke-ADBCommand -Command "reboot" -Description "Riavvio dispositivo"
    Log "[OK] Comando reboot inviato."
    Update-Status "[OK] Riavvio" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-ADBScreenshot {
    if (Test-Cancel) { return }
    Log ""; Log "==============================================================================================="
    Log "[>] SCREENSHOT"
    Log "==============================================================================================="
    Update-Status "[...] Screenshot..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $tempFile = "/sdcard/screenshot_$timestamp.png"
    $desktop = [Environment]::GetFolderPath("Desktop")
    $localFile = Join-Path $desktop "screenshot_$timestamp.png"
    Invoke-ADBCommand -Command "shell screencap -p $tempFile" -Description "Acquisizione schermata" -ShowOutput $false
    if ($LASTEXITCODE -ne 0) { Log "[X] Errore acquisizione screenshot."; Update-Status "[X] Errore" $global:exitColor; return }
    Invoke-ADBCommand -Command "pull $tempFile `"$localFile`"" -Description "Download screenshot" -ShowOutput $false
    Invoke-ADBCommand -Command "shell rm $tempFile" -Description "Pulizia" -ShowOutput $false
    if (Test-Path $localFile) {
        Log "[OK] Screenshot salvato: $localFile"
        Update-Status "[OK] Screenshot salvato" $global:successColor
        explorer.exe "/select,$localFile"
    } else {
        Log "[X] Screenshot non salvato."
        Update-Status "[X] Errore" $global:exitColor
    }
    Flush-LogBuffer; Pump-UI
}

function Do-ADBInstallAPK {
    if (Test-Cancel) { return }
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = "Seleziona il file APK da installare"
    $openFileDialog.Filter = "APK File (*.apk)|*.apk|All Files (*.*)|*.*"
    $openFileDialog.FilterIndex = 1
    $openFileDialog.RestoreDirectory = $true
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $apkPath = $openFileDialog.FileName
        Log ""; Log "==============================================================================================="
        Log "[>] INSTALLAZIONE APK"
        Log "==============================================================================================="
        Update-Status "[...] Installazione APK..." $global:infoColor
        Flush-LogBuffer; Pump-UI
        Invoke-ADBCommand -Command "install -r `"$apkPath`"" -Description "Installazione APK"
        Update-Status "[OK] Installazione" $global:successColor
        Flush-LogBuffer; Pump-UI
    }
}

function Do-ADBUninstallAPK {
    if (Test-Cancel) { return }
    $pkg = Prompt-ADBPackageName -Action "disinstallare"
    if (-not $pkg) { return }
    $response = [System.Windows.Forms.MessageBox]::Show("Disinstallare $pkg?", "Conferma", "YesNo", "Warning")
    if ($response -ne "Yes") { return }
    Log ""; Log "==============================================================================================="
    Log "[>] DISINSTALLAZIONE APK: $pkg"
    Log "==============================================================================================="
    Update-Status "[...] Disinstallazione..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    Invoke-ADBCommand -Command "uninstall $pkg" -Description "Disinstallazione APK"
    Update-Status "[OK] Disinstallazione" $global:successColor
    Flush-LogBuffer; Pump-UI
}

function Do-ADBLogcat {
    if (Test-Cancel) { return }
    Log ""; Log "==============================================================================================="
    Log "[>] LOGCAT"
    Log "==============================================================================================="
    Update-Status "[...] Logcat..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    $output = Invoke-ADBCommand -Command "logcat -v brief -t 100" -Description "Logcat ultime 100 righe"
    Update-Status "[OK] Logcat completato" $global:successColor
    Flush-LogBuffer; Pump-UI
    if ($output) {
        $tempLog = Join-Path $env:TEMP "logcat_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $output | Out-File -FilePath $tempLog -Encoding UTF8
        Log "[OK] Log salvato in: $tempLog"
        notepad.exe $tempLog
    }
}

function Do-ADBCustomCommand {
    if (Test-Cancel) { return }
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Comando ADB Personalizzato"
    $inputForm.Size = New-Object System.Drawing.Size(500, 170)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $inputForm.ForeColor = [System.Drawing.Color]::White
    $inputForm.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inserisci il comando ADB (es. shell ls /sdcard):"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(440, 25)
    $lbl.ForeColor = [System.Drawing.Color]::White
    $inputForm.Controls.Add($lbl)
    $txtCmd = New-Object System.Windows.Forms.TextBox
    $txtCmd.Location = New-Object System.Drawing.Point(20, 55)
    $txtCmd.Size = New-Object System.Drawing.Size(440, 26)
    $txtCmd.Font = New-Object System.Drawing.Font("Consolas", 11)
    $txtCmd.BackColor = [System.Drawing.Color]::FromArgb(36, 36, 42)
    $txtCmd.ForeColor = [System.Drawing.Color]::White
    $txtCmd.Text = "shell ls"
    $inputForm.Controls.Add($txtCmd)
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Esegui"
    $btnOK.Location = New-Object System.Drawing.Point(300, 100)
    $btnOK.Size = New-Object System.Drawing.Size(80, 28)
    $btnOK.BackColor = [System.Drawing.Color]::FromArgb(56, 132, 244)
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(390, 100)
    $btnCancel.Size = New-Object System.Drawing.Size(80, 28)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($btnCancel)
    $inputForm.CancelButton = $btnCancel
    if ($inputForm.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $cmd = $txtCmd.Text.Trim()
        if (-not $cmd) { Log "[X] Comando non inserito."; return }
        Log ""; Log "==============================================================================================="
        Log "[>] COMANDO ADB: $cmd"
        Log "==============================================================================================="
        Update-Status "[...] Esecuzione..." $global:infoColor
        Flush-LogBuffer; Pump-UI
        Invoke-ADBCommand -Command $cmd -Description $cmd
        Update-Status "[OK] Comando eseguito" $global:successColor
        Flush-LogBuffer; Pump-UI
    }
}

# ---- ESPORTAZIONE ----
Export-ModuleMember -Function @(
    'Install-ADBDrivers',
    'Get-ADBDevices',
    'Do-ADBDevices',
    'Do-ADBReboot',
    'Do-ADBScreenshot',
    'Do-ADBInstallAPK',
    'Do-ADBUninstallAPK',
    'Do-ADBLogcat',
    'Do-ADBCustomCommand',
    'Get-ADBPackages',
    'Export-ADBPackages',
    'Disable-ADBPackage',
    'Enable-ADBPackage',
    'Uninstall-ADBPackage',
    'Clear-ADBPackageCache',
    'Clear-ADBAllCache',
    'Trim-ADBCache',
    'Show-ADBPackageManager',
    'Backup-ADBFull',
    'Backup-ADBAppData',
    'Backup-ADBAPKs',
    'Restore-ADBBackup',
    'Pull-ADBFile',
    'Push-ADBFile',
    'Get-ADBDeviceInfo',
    'Get-ADBBatteryStatus',
    'Get-ADBTopProcesses',
    'Record-ADBScreen',
    'Reboot-ADBFastboot',
    'Reboot-ADBRecovery',
    'Clear-ADBAppData',
    'Reset-ADBNetworkSettings',
    'Lock-ADBScreen',
    'Unlock-ADBScreen',
    'Send-ADBText',
    'Camera-ADBPhoto',
    'Get-ADBSMS',
    'Call-ADBPhone'
)