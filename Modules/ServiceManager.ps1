# ==========================================================
# Gestione Servizi - Compatto e funzionante
# PowerShell 7.6.5 - WinForms
# Eseguire come Amministratore
# ==========================================================

# Verifica dei permessi di amministratore
$currentPrincipal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    [System.Windows.Forms.MessageBox]::Show(
        "Questo script deve essere eseguito come Amministratore.`nRiavvia PowerShell come Admin e riprova.",
        "Permessi insufficienti",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# -----------------------
# Configurazioni iniziali
# -----------------------
$knownDisable = @(
    "DiagTrack","dmwappushservice","WSearch","Fax","MapsBroker","RetailDemo",
    "XblAuthManager","XblGameSave","XboxNetApiSvc","XboxGipSvc",
    "RemoteRegistry","PhoneSvc"
)

$profilePrivacy = @("DiagTrack","dmwappushservice","WSearch","MapsBroker","RetailDemo")
$profileGaming  = @("XblAuthManager","XblGameSave","XboxNetApiSvc","XboxGipSvc")
$profileWorkstation = @("WSearch","WMPNetworkSvc","OneSyncSvc")

$backupFolder = Join-Path $env:USERPROFILE "ServiceBackups"
if (-not (Test-Path $backupFolder)) {
    New-Item -Path $backupFolder -ItemType Directory | Out-Null
}

$global:InitialStates = @{}
$global:AllServicesCache = @()

# -----------------------
# Funzioni utili
# -----------------------
function Get-AllServices {
    Get-CimInstance -ClassName Win32_Service |
        Select-Object @{Name='ServiceName';Expression={$_.Name}},
                      @{Name='DisplayName';Expression={$_.DisplayName}},
                      @{Name='State';Expression={$_.State}},
                      @{Name='StartMode';Expression={$_.StartMode}},
                      @{Name='StartName';Expression={$_.StartName}},
                      @{Name='Description';Expression={$_.Description}} |
        Sort-Object -Property DisplayName
}

function Get-Recommendation {
    param([string]$ServiceName, [string]$State, [string]$StartMode)
    if ($knownDisable -contains $ServiceName) { return "Disattivare" }
    $critical = @("WinDefend","Dhcp","Dnscache","Lanman","W32Time","EventLog","Rpc","TrustedInstaller","BITS","Spooler","Wuauserv")
    foreach ($p in $critical) {
        if ($ServiceName.StartsWith($p, [System.StringComparison]::InvariantCultureIgnoreCase)) { return "Lasciare" }
    }
    if ($StartMode -eq "Disabled") { return "Lasciare" }
    if ($StartMode -eq "Auto" -and $State -eq "Running") { return "Lasciare" }
    if ($StartMode -eq "Manual" -and $State -eq "Stopped") { return "Valutare" }
    return "Valutare"
}

# -----------------------
# Form principale
# -----------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Gestione Servizi - Compatto"
$form.Size = New-Object System.Drawing.Size(1400,760)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(34,34,34)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Header
$header = New-Object System.Windows.Forms.Panel
$header.Size = New-Object System.Drawing.Size(1360,36)
$header.Location = New-Object System.Drawing.Point(10,8)
$header.BackColor = [System.Drawing.Color]::FromArgb(45,45,45)
$form.Controls.Add($header)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Gestione Servizi - Visualizza tutti i servizi e consigli"
$title.AutoSize = $false
$title.Size = New-Object System.Drawing.Size(1100,26)
$title.Location = New-Object System.Drawing.Point(10,5)
$title.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::White
$header.Controls.Add($title)

# Left: griglia
$leftGroup = New-Object System.Windows.Forms.GroupBox
$leftGroup.Text = "Elenco servizi"
$leftGroup.Size = New-Object System.Drawing.Size(1120,660)
$leftGroup.Location = New-Object System.Drawing.Point(10,50)
$leftGroup.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$leftGroup.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($leftGroup)

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Size = New-Object System.Drawing.Size(1100,620)
$grid.Location = New-Object System.Drawing.Point(10,22)
$grid.BackgroundColor = [System.Drawing.Color]::FromArgb(250,250,250)
$grid.GridColor = [System.Drawing.Color]::Gray
$grid.RowHeadersVisible = $false
$grid.AllowUserToAddRows = $false
$grid.AllowUserToResizeRows = $false
$grid.SelectionMode = "FullRowSelect"
$grid.MultiSelect = $false
$grid.EnableHeadersVisualStyles = $false
$grid.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$grid.AutoSizeRowsMode = "None"
$grid.AutoSizeColumnsMode = "None"
$grid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(220,220,220)
$grid.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::Black
$grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$grid.RowTemplate.Height = 24

# Columns
$colSelect = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$colSelect.HeaderText = "Seleziona"
$colSelect.Width = 60
$grid.Columns.Add($colSelect) | Out-Null

$colDisplay = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colDisplay.HeaderText = "Nome visualizzato"
$colDisplay.Name = "DisplayName"
$colDisplay.Width = 320
$colDisplay.ReadOnly = $true
$grid.Columns.Add($colDisplay) | Out-Null

$colService = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colService.HeaderText = "ServiceName"
$colService.Name = "ServiceName"
$colService.Width = 300
$colService.ReadOnly = $true
$grid.Columns.Add($colService) | Out-Null

$colState = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colState.HeaderText = "Stato"
$colState.Name = "State"
$colState.Width = 90
$colState.ReadOnly = $true
$grid.Columns.Add($colState) | Out-Null

$colStart = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colStart.HeaderText = "StartupType"
$colStart.Name = "StartMode"
$colStart.Width = 110
$colStart.ReadOnly = $true
$grid.Columns.Add($colStart) | Out-Null

$colRec = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colRec.HeaderText = "Consiglio"
$colRec.Name = "Recommendation"
$colRec.Width = 110
$colRec.ReadOnly = $true
$grid.Columns.Add($colRec) | Out-Null

$colDesc = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$colDesc.HeaderText = "Description"
$colDesc.Name = "Description"
$colDesc.Visible = $false
$grid.Columns.Add($colDesc) | Out-Null

$leftGroup.Controls.Add($grid)

# Right: controls
$rightGroup = New-Object System.Windows.Forms.GroupBox
$rightGroup.Text = "Azioni e filtri"
$rightGroup.Size = New-Object System.Drawing.Size(250,660)
$rightGroup.Location = New-Object System.Drawing.Point(1140,50)
$rightGroup.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$rightGroup.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($rightGroup)

# Search + debounce
$lblSearch = New-Object System.Windows.Forms.Label
$lblSearch.Text = "Ricerca"
$lblSearch.Size = New-Object System.Drawing.Size(220,16)
$lblSearch.Location = New-Object System.Drawing.Point(12,16)
$lblSearch.ForeColor = [System.Drawing.Color]::LightGray
$rightGroup.Controls.Add($lblSearch)

$txtSearch = New-Object System.Windows.Forms.TextBox
$txtSearch.Size = New-Object System.Drawing.Size(220,22)
$txtSearch.Location = New-Object System.Drawing.Point(12,34)
$txtSearch.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$rightGroup.Controls.Add($txtSearch)

$searchTimer = New-Object System.Windows.Forms.Timer
$searchTimer.Interval = 400
$searchTimer.Add_Tick({
    $searchTimer.Stop()
    Populate-Grid -search $txtSearch.Text -filterRec $cmbRec.SelectedItem -filterStart $cmbStart.SelectedItem -filterState $cmbState.SelectedItem
})

# Filters
$lblFilterRec = New-Object System.Windows.Forms.Label
$lblFilterRec.Text = "Consiglio"
$lblFilterRec.Size = New-Object System.Drawing.Size(220,16)
$lblFilterRec.Location = New-Object System.Drawing.Point(12,60)
$lblFilterRec.ForeColor = [System.Drawing.Color]::LightGray
$rightGroup.Controls.Add($lblFilterRec)

$cmbRec = New-Object System.Windows.Forms.ComboBox
$cmbRec.Size = New-Object System.Drawing.Size(220,22)
$cmbRec.Location = New-Object System.Drawing.Point(12,76)
$cmbRec.DropDownStyle = "DropDownList"
$cmbRec.Items.AddRange(@("Tutti","Disattivare","Lasciare","Valutare"))
$cmbRec.SelectedIndex = 0
$rightGroup.Controls.Add($cmbRec)

$lblFilterStart = New-Object System.Windows.Forms.Label
$lblFilterStart.Text = "StartupType"
$lblFilterStart.Size = New-Object System.Drawing.Size(220,16)
$lblFilterStart.Location = New-Object System.Drawing.Point(12,102)
$lblFilterStart.ForeColor = [System.Drawing.Color]::LightGray
$rightGroup.Controls.Add($lblFilterStart)

$cmbStart = New-Object System.Windows.Forms.ComboBox
$cmbStart.Size = New-Object System.Drawing.Size(220,22)
$cmbStart.Location = New-Object System.Drawing.Point(12,118)
$cmbStart.DropDownStyle = "DropDownList"
$cmbStart.Items.AddRange(@("Tutti","Auto","Manual","Disabled"))
$cmbStart.SelectedIndex = 0
$rightGroup.Controls.Add($cmbStart)

$lblFilterState = New-Object System.Windows.Forms.Label
$lblFilterState.Text = "Stato"
$lblFilterState.Size = New-Object System.Drawing.Size(220,16)
$lblFilterState.Location = New-Object System.Drawing.Point(12,144)
$lblFilterState.ForeColor = [System.Drawing.Color]::LightGray
$rightGroup.Controls.Add($lblFilterState)

$cmbState = New-Object System.Windows.Forms.ComboBox
$cmbState.Size = New-Object System.Drawing.Size(220,22)
$cmbState.Location = New-Object System.Drawing.Point(12,160)
$cmbState.DropDownStyle = "DropDownList"
$cmbState.Items.AddRange(@("Tutti","Running","Stopped","Disabled"))
$cmbState.SelectedIndex = 0
$rightGroup.Controls.Add($cmbState)

# Buttons (compact)
$btnApplyFilters = New-Object System.Windows.Forms.Button
$btnApplyFilters.Text = "Applica"
$btnApplyFilters.Size = New-Object System.Drawing.Size(96,24)
$btnApplyFilters.Location = New-Object System.Drawing.Point(12,188)
$btnApplyFilters.BackColor = [System.Drawing.Color]::FromArgb(70,130,180)
$btnApplyFilters.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnApplyFilters)

$btnClearFilters = New-Object System.Windows.Forms.Button
$btnClearFilters.Text = "Reset"
$btnClearFilters.Size = New-Object System.Drawing.Size(96,24)
$btnClearFilters.Location = New-Object System.Drawing.Point(136,188)
$btnClearFilters.BackColor = [System.Drawing.Color]::FromArgb(100,100,100)
$btnClearFilters.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnClearFilters)

$btnSelectRecommended = New-Object System.Windows.Forms.Button
$btnSelectRecommended.Text = "Seleziona consigliati"
$btnSelectRecommended.Size = New-Object System.Drawing.Size(220,24)
$btnSelectRecommended.Location = New-Object System.Drawing.Point(12,216)
$btnSelectRecommended.BackColor = [System.Drawing.Color]::FromArgb(200,120,60)
$btnSelectRecommended.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnSelectRecommended)

$btnSelectAll = New-Object System.Windows.Forms.Button
$btnSelectAll.Text = "Seleziona tutto"
$btnSelectAll.Size = New-Object System.Drawing.Size(96,24)
$btnSelectAll.Location = New-Object System.Drawing.Point(12,244)
$btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(100,100,100)
$btnSelectAll.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnSelectAll)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Deseleziona"
$btnClear.Size = New-Object System.Drawing.Size(96,24)
$btnClear.Location = New-Object System.Drawing.Point(136,244)
$btnClear.BackColor = [System.Drawing.Color]::FromArgb(100,100,100)
$btnClear.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnClear)

$btnDisable = New-Object System.Windows.Forms.Button
$btnDisable.Text = "Disattiva"
$btnDisable.Size = New-Object System.Drawing.Size(220,26)
$btnDisable.Location = New-Object System.Drawing.Point(12,274)
$btnDisable.BackColor = [System.Drawing.Color]::FromArgb(200,60,60)
$btnDisable.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnDisable)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "Stop"
$btnStop.Size = New-Object System.Drawing.Size(220,26)
$btnStop.Location = New-Object System.Drawing.Point(12,304)
$btnStop.BackColor = [System.Drawing.Color]::FromArgb(180,90,20)
$btnStop.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnStop)

$btnEnable = New-Object System.Windows.Forms.Button
$btnEnable.Text = "Riattiva"
$btnEnable.Size = New-Object System.Drawing.Size(220,26)
$btnEnable.Location = New-Object System.Drawing.Point(12,334)
$btnEnable.BackColor = [System.Drawing.Color]::FromArgb(60,160,80)
$btnEnable.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnEnable)

# Profiles (filter-only)
$lblProfiles = New-Object System.Windows.Forms.Label
$lblProfiles.Text = "Profili rapidi"
$lblProfiles.Size = New-Object System.Drawing.Size(220,16)
$lblProfiles.Location = New-Object System.Drawing.Point(12,364)
$lblProfiles.ForeColor = [System.Drawing.Color]::LightGray
$rightGroup.Controls.Add($lblProfiles)

$btnProfilePrivacy = New-Object System.Windows.Forms.Button
$btnProfilePrivacy.Text = "Privacy"
$btnProfilePrivacy.Size = New-Object System.Drawing.Size(64,24)
$btnProfilePrivacy.Location = New-Object System.Drawing.Point(12,382)
$btnProfilePrivacy.BackColor = [System.Drawing.Color]::FromArgb(120,120,200)
$btnProfilePrivacy.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnProfilePrivacy)

$btnProfileGaming = New-Object System.Windows.Forms.Button
$btnProfileGaming.Text = "Gaming"
$btnProfileGaming.Size = New-Object System.Drawing.Size(64,24)
$btnProfileGaming.Location = New-Object System.Drawing.Point(86,382)
$btnProfileGaming.BackColor = [System.Drawing.Color]::FromArgb(120,120,200)
$btnProfileGaming.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnProfileGaming)

$btnProfileWork = New-Object System.Windows.Forms.Button
$btnProfileWork.Text = "Work"
$btnProfileWork.Size = New-Object System.Drawing.Size(64,24)
$btnProfileWork.Location = New-Object System.Drawing.Point(160,382)
$btnProfileWork.BackColor = [System.Drawing.Color]::FromArgb(120,120,200)
$btnProfileWork.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnProfileWork)

# Backup / Restore / Export
$btnBackup = New-Object System.Windows.Forms.Button
$btnBackup.Text = "Crea backup"
$btnBackup.Size = New-Object System.Drawing.Size(220,24)
$btnBackup.Location = New-Object System.Drawing.Point(12,412)
$btnBackup.BackColor = [System.Drawing.Color]::FromArgb(90,90,200)
$btnBackup.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnBackup)

$btnLoadBackup = New-Object System.Windows.Forms.Button
$btnLoadBackup.Text = "Carica backup"
$btnLoadBackup.Size = New-Object System.Drawing.Size(220,24)
$btnLoadBackup.Location = New-Object System.Drawing.Point(12,440)
$btnLoadBackup.BackColor = [System.Drawing.Color]::FromArgb(90,90,200)
$btnLoadBackup.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnLoadBackup)

$btnExport = New-Object System.Windows.Forms.Button
$btnExport.Text = "Esporta CSV"
$btnExport.Size = New-Object System.Drawing.Size(220,24)
$btnExport.Location = New-Object System.Drawing.Point(12,468)
$btnExport.BackColor = [System.Drawing.Color]::FromArgb(120,120,120)
$btnExport.ForeColor = [System.Drawing.Color]::White
$rightGroup.Controls.Add($btnExport)

# Description area
$infoLabel = New-Object System.Windows.Forms.Label
$infoLabel.Text = "Seleziona una riga per vedere la descrizione."
$infoLabel.Size = New-Object System.Drawing.Size(220,20)
$infoLabel.Location = New-Object System.Drawing.Point(12,498)
$infoLabel.ForeColor = [System.Drawing.Color]::LightGray
$rightGroup.Controls.Add($infoLabel)

$descBox = New-Object System.Windows.Forms.TextBox
$descBox.Multiline = $true
$descBox.ReadOnly = $true
$descBox.ScrollBars = "Vertical"
$descBox.Size = New-Object System.Drawing.Size(220,140)
$descBox.Location = New-Object System.Drawing.Point(12,520)
$descBox.BackColor = [System.Drawing.Color]::FromArgb(250,250,250)
$descBox.ForeColor = [System.Drawing.Color]::Black
$descBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$rightGroup.Controls.Add($descBox)

# -----------------------
# Populate-Grid (with optional profileFilter)
# -----------------------
function Populate-Grid {
    param(
        [string]$search = "",
        [string]$filterRec = "Tutti",
        [string]$filterStart = "Tutti",
        [string]$filterState = "Tutti",
        [string[]]$profileFilter = $null
    )

    $grid.Rows.Clear()
    $global:AllServicesCache = Get-AllServices

    if ($global:InitialStates.Count -eq 0) {
        foreach ($s in $global:AllServicesCache) {
            $global:InitialStates[$s.ServiceName] = [PSCustomObject]@{ StartMode = $s.StartMode; State = $s.State }
        }
    }

    $filtered = $global:AllServicesCache | Where-Object {
        ($profileFilter -eq $null -or $profileFilter -contains $_.ServiceName) -and
        ($search -eq "" -or ($_.DisplayName -match [regex]::Escape($search) -or $_.ServiceName -match [regex]::Escape($search))) -and
        ($filterRec -eq "Tutti" -or (Get-Recommendation -ServiceName $_.ServiceName -State $_.State -StartMode $_.StartMode) -eq $filterRec) -and
        ($filterStart -eq "Tutti" -or $_.StartMode -eq $filterStart) -and
        ($filterState -eq "Tutti" -or $_.State -eq $filterState)
    }

    foreach ($svc in $filtered) {
        $rec = Get-Recommendation -ServiceName $svc.ServiceName -State $svc.State -StartMode $svc.StartMode
        $idx = $grid.Rows.Add()
        $grid.Rows[$idx].Cells[0].Value = $false
        $grid.Rows[$idx].Cells[1].Value = $svc.DisplayName
        $grid.Rows[$idx].Cells[2].Value = $svc.ServiceName
        $grid.Rows[$idx].Cells[3].Value = $svc.State
        $grid.Rows[$idx].Cells[4].Value = $svc.StartMode
        $grid.Rows[$idx].Cells[5].Value = $rec
        $grid.Rows[$idx].Cells[6].Value = $svc.Description

        # Colors
        switch ($svc.State) {
            "Running"   { $grid.Rows[$idx].Cells[3].Style.ForeColor = [System.Drawing.Color]::FromArgb(0,128,0) }
            "Stopped"   { $grid.Rows[$idx].Cells[3].Style.ForeColor = [System.Drawing.Color]::FromArgb(255,140,0) }
            "Disabled"  { $grid.Rows[$idx].Cells[3].Style.ForeColor = [System.Drawing.Color]::FromArgb(200,60,60) }
            default     { $grid.Rows[$idx].Cells[3].Style.ForeColor = [System.Drawing.Color]::FromArgb(80,80,80) }
        }
        switch ($rec) {
            "Disattivare" { $grid.Rows[$idx].Cells[5].Style.ForeColor = [System.Drawing.Color]::FromArgb(200,60,60) }
            "Lasciare"    { $grid.Rows[$idx].Cells[5].Style.ForeColor = [System.Drawing.Color]::FromArgb(0,120,0) }
            "Valutare"    { $grid.Rows[$idx].Cells[5].Style.ForeColor = [System.Drawing.Color]::FromArgb(200,160,60) }
            default       { $grid.Rows[$idx].Cells[5].Style.ForeColor = [System.Drawing.Color]::FromArgb(120,120,120) }
        }

        $boldFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        if ($svc.State -eq "Running") { $nameColor = [System.Drawing.Color]::FromArgb(0,128,0) }
        elseif ($svc.State -eq "Disabled") { $nameColor = [System.Drawing.Color]::FromArgb(200,60,60) }
        else { $nameColor = [System.Drawing.Color]::Black }

        $grid.Rows[$idx].Cells[1].Style.ForeColor = $nameColor
        $grid.Rows[$idx].Cells[1].Style.Font = $boldFont
        $grid.Rows[$idx].Cells[1].Style.BackColor = [System.Drawing.Color]::FromArgb(245,245,245)

        $grid.Rows[$idx].Cells[2].Style.ForeColor = $nameColor
        $grid.Rows[$idx].Cells[2].Style.Font = $boldFont
        $grid.Rows[$idx].Cells[2].Style.BackColor = [System.Drawing.Color]::FromArgb(245,245,245)

        $grid.Rows[$idx].Cells[4].Style.ForeColor = [System.Drawing.Color]::Black
        $grid.Rows[$idx].Cells[4].Style.Font = $boldFont
        $grid.Rows[$idx].Cells[4].Style.BackColor = [System.Drawing.Color]::FromArgb(245,245,245)
    }

    # Fixed widths
    $grid.Columns["DisplayName"].AutoSizeMode = "None"
    $grid.Columns["DisplayName"].Width = 320
    $grid.Columns["ServiceName"].Width = 300
    $grid.Columns["State"].Width = 90
    $grid.Columns["StartMode"].Width = 110
    $grid.Columns["Recommendation"].Width = 110
}

# -----------------------
# Debounce wiring
# -----------------------
$txtSearch.Add_TextChanged({
    $searchTimer.Stop()
    $searchTimer.Start()
})

# -----------------------
# Button events
# -----------------------
$btnApplyFilters.Add_Click({
    Populate-Grid -search $txtSearch.Text -filterRec $cmbRec.SelectedItem -filterStart $cmbStart.SelectedItem -filterState $cmbState.SelectedItem
})

$btnClearFilters.Add_Click({
    $txtSearch.Text = ""
    $cmbRec.SelectedIndex = 0
    $cmbStart.SelectedIndex = 0
    $cmbState.SelectedIndex = 0
    Populate-Grid
})

$btnSelectRecommended.Add_Click({
    for ($i=0; $i -lt $grid.Rows.Count; $i++) {
        $grid.Rows[$i].Cells[0].Value = ($grid.Rows[$i].Cells[5].Value -eq "Disattivare")
    }
})

$btnSelectAll.Add_Click({
    for ($i=0; $i -lt $grid.Rows.Count; $i++) { $grid.Rows[$i].Cells[0].Value = $true }
})

$btnClear.Add_Click({
    for ($i=0; $i -lt $grid.Rows.Count; $i++) { $grid.Rows[$i].Cells[0].Value = $false }
})

# Preview + apply function (robust)
function Show-Preview-And-Apply {
    param([string]$Action)

    # Raccogli i servizi selezionati
    $actions = @()
    for ($i=0; $i -lt $grid.Rows.Count; $i++) {
        $cell = $grid.Rows[$i].Cells[0]
        if ($cell.Value -eq $true) {
            $svcName = $grid.Rows[$i].Cells["ServiceName"].Value
            $display  = $grid.Rows[$i].Cells["DisplayName"].Value
            $current  = $grid.Rows[$i].Cells["State"].Value
            $actions += [PSCustomObject]@{ ServiceName=$svcName; DisplayName=$display; CurrentState=$current; Action=$Action }
        }
    }

    if ($actions.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Nessun servizio selezionato.",
            "Anteprima",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }

    # Form di anteprima
    $previewForm = New-Object System.Windows.Forms.Form
    $previewForm.Text = "Anteprima modifiche"
    $previewForm.Size = New-Object System.Drawing.Size(700,420)
    $previewForm.StartPosition = "CenterParent"
    $previewForm.Font = New-Object System.Drawing.Font("Segoe UI", 9)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = ("Azioni: {0} servizi selezionati" -f $actions.Count)
    $lbl.Size = New-Object System.Drawing.Size(660,20)
    $lbl.Location = New-Object System.Drawing.Point(10,10)
    $previewForm.Controls.Add($lbl)

    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Multiline = $true
    $txt.ScrollBars = "Vertical"
    $txt.ReadOnly = $true
    $txt.Size = New-Object System.Drawing.Size(660,300)
    $txt.Location = New-Object System.Drawing.Point(10,36)
    $previewForm.Controls.Add($txt)

    foreach ($a in $actions) {
        $txt.AppendText(("{0} ({1}) -> {2}`r`n" -f $a.DisplayName, $a.ServiceName, $a.Action))
    }

    $btnYes = New-Object System.Windows.Forms.Button
    $btnYes.Text = "Conferma"
    $btnYes.Size = New-Object System.Drawing.Size(120,30)
    $btnYes.Location = New-Object System.Drawing.Point(380,350)
    $btnYes.BackColor = [System.Drawing.Color]::FromArgb(60,160,80)
    $btnYes.ForeColor = [System.Drawing.Color]::White
    $btnYes.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $previewForm.Controls.Add($btnYes)

    $btnNo = New-Object System.Windows.Forms.Button
    $btnNo.Text = "Annulla"
    $btnNo.Size = New-Object System.Drawing.Size(120,30)
    $btnNo.Location = New-Object System.Drawing.Point(520,350)
    $btnNo.BackColor = [System.Drawing.Color]::FromArgb(200,60,60)
    $btnNo.ForeColor = [System.Drawing.Color]::White
    $btnNo.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $previewForm.Controls.Add($btnNo)

    $previewForm.AcceptButton = $btnYes
    $previewForm.CancelButton = $btnNo

    $result = $previewForm.ShowDialog()

    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        return
    }

    # Applica le modifiche con gestione errori
    $errors = @()
    $successCount = 0

    foreach ($a in $actions) {
        try {
            switch ($a.Action) {
                "Disable" {
                    Stop-Service -Name $a.ServiceName -Force -ErrorAction Stop
                    Set-Service -Name $a.ServiceName -StartupType Disabled -ErrorAction Stop
                }
                "Enable" {
                    Set-Service -Name $a.ServiceName -StartupType Manual -ErrorAction Stop
                    Start-Service -Name $a.ServiceName -ErrorAction Stop
                }
                "Stop" {
                    Stop-Service -Name $a.ServiceName -Force -ErrorAction Stop
                }
            }
            $successCount++
        } catch {
            $errors += "$($a.DisplayName) ($($a.ServiceName)): $($_.Exception.Message)"
        }
    }

    # Aggiorna la griglia dopo un breve ritardo per permettere al sistema di aggiornare lo stato
    Start-Sleep -Milliseconds 500
    Populate-Grid -search $txtSearch.Text -filterRec $cmbRec.SelectedItem -filterStart $cmbStart.SelectedItem -filterState $cmbState.SelectedItem

    # Mostra il riepilogo finale
    $msg = "Operazione completata.`n`n"
    $msg += "Servizi elaborati: $($actions.Count)`n"
    $msg += "Riusciti: $successCount`n"
    if ($errors.Count -gt 0) {
        $msg += "Errori: $($errors.Count)`n`n"
        $msg += "Dettagli errori:`n" + ($errors -join "`n")
    } else {
        $msg += "Nessun errore."
    }

    [System.Windows.Forms.MessageBox]::Show(
        $msg,
        "Risultato operazione",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}

$btnDisable.Add_Click({ Show-Preview-And-Apply -Action "Disable" })
$btnStop.Add_Click({ Show-Preview-And-Apply -Action "Stop" })
$btnEnable.Add_Click({ Show-Preview-And-Apply -Action "Enable" })

# Profiles: filter-only
$btnProfilePrivacy.Add_Click({ Populate-Grid -profileFilter $profilePrivacy })
$btnProfileGaming.Add_Click({ Populate-Grid -profileFilter $profileGaming })
$btnProfileWork.Add_Click({ Populate-Grid -profileFilter $profileWorkstation })

# Backup / Load / Export
$btnBackup.Add_Click({
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $path = Join-Path $backupFolder "services_backup_$timestamp.json"
    $obj = @{}
    foreach ($k in $global:InitialStates.Keys) { $obj[$k] = $global:InitialStates[$k] }
    $obj | ConvertTo-Json -Depth 5 | Out-File -FilePath $path -Encoding UTF8
    [System.Windows.Forms.MessageBox]::Show(
        ("Backup creato:`n{0}" -f $path),
        "Backup",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
})

$btnLoadBackup.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.InitialDirectory = $backupFolder
    $ofd.Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
    if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    try {
        $json = Get-Content -Path $ofd.FileName -Raw | ConvertFrom-Json
        $errors = @()
        foreach ($prop in $json.PSObject.Properties) {
            $svcName = $prop.Name
            $orig = $prop.Value
            try {
                Set-Service -Name $svcName -StartupType $orig.StartMode -ErrorAction Stop
                if ($orig.State -eq "Running") {
                    Start-Service -Name $svcName -ErrorAction Stop
                } else {
                    Stop-Service -Name $svcName -Force -ErrorAction Stop
                }
            } catch {
                $errors += "$svcName : $($_.Exception.Message)"
            }
        }
        Populate-Grid
        if ($errors.Count -gt 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Restore completato con alcuni errori:`n`n" + ($errors -join "`n"),
                "Restore",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "Restore dal backup completato con successo.",
                "Restore",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Impossibile leggere il backup selezionato.`n`n$($_.Exception.Message)",
            "Errore",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

$btnExport.Add_Click({
    $csvPath = Join-Path -Path $env:USERPROFILE -ChildPath "services_export_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
    $rows = @()
    for ($i=0; $i -lt $grid.Rows.Count; $i++) {
        $rows += [PSCustomObject]@{
            DisplayName = $grid.Rows[$i].Cells[1].Value
            ServiceName = $grid.Rows[$i].Cells[2].Value
            State       = $grid.Rows[$i].Cells[3].Value
            StartMode   = $grid.Rows[$i].Cells[4].Value
            Recommendation = $grid.Rows[$i].Cells[5].Value
            Description = $grid.Rows[$i].Cells[6].Value
        }
    }
    $rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    [System.Windows.Forms.MessageBox]::Show(
        ("Esportato CSV:`n{0}" -f $csvPath),
        "Esporta",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
})

# Selection -> description
$grid.Add_SelectionChanged({
    if ($grid.SelectedRows.Count -gt 0) {
        $r = $grid.SelectedRows[0]
        $desc = $r.Cells["Description"].Value
        if ([string]::IsNullOrWhiteSpace($desc)) { $desc = "Nessuna descrizione disponibile." }
        $descBox.Text = $desc
    }
})

# Double-click toggles checkbox
$grid.Add_CellDoubleClick({
    param($sender,$e)
    if ($e.RowIndex -ge 0) {
        $current = $grid.Rows[$e.RowIndex].Cells[0].Value
        $grid.Rows[$e.RowIndex].Cells[0].Value = -not $current
    }
})

# Initial population
Populate-Grid

$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()