# rete.ps1 - Scansione rete professionale con supporto SNMP (tema scuro)
#Requires -Version 7
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------- DEFINIZIONE COLORI (allineati a Manutenzione_PRO_MAX) ----------
$bgColor = [System.Drawing.Color]::FromArgb(20, 20, 24)
$bgPanel = [System.Drawing.Color]::FromArgb(28, 28, 34)
$bgCard = [System.Drawing.Color]::FromArgb(36, 36, 42)
$fgColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
$fgDim = [System.Drawing.Color]::FromArgb(120, 120, 130)
$sectionColor = [System.Drawing.Color]::FromArgb(50, 220, 1)
$accentColor = [System.Drawing.Color]::FromArgb(56, 132, 244)
$warningColor = [System.Drawing.Color]::FromArgb(240, 180, 40)
$successColor = [System.Drawing.Color]::FromArgb(50, 220, 1)
$exitColor = [System.Drawing.Color]::FromArgb(220, 60, 60)
$restartColor = [System.Drawing.Color]::FromArgb(230, 120, 30)
$infoColor = [System.Drawing.Color]::FromArgb(40, 170, 220)
$repairColor = [System.Drawing.Color]::FromArgb(160, 80, 220)
$networkColor = [System.Drawing.Color]::FromArgb(40, 200, 200)
$runAllColor = [System.Drawing.Color]::FromArgb(40, 200, 0)
$elevateColor = [System.Drawing.Color]::FromArgb(240, 200, 40)
$securityColor = [System.Drawing.Color]::FromArgb(220, 70, 70)
$maintColor = [System.Drawing.Color]::FromArgb(200, 140, 30)
$cpuColor = [System.Drawing.Color]::FromArgb(140, 0, 240)
$remoteColor = [System.Drawing.Color]::FromArgb(255, 0, 50)
$searchColor = [System.Drawing.Color]::FromArgb(60, 2, 180)
$logBg = [System.Drawing.Color]::FromArgb(14, 14, 18)
$btnHover = [System.Drawing.Color]::FromArgb(48, 48, 56)
$runAllBg = [System.Drawing.Color]::FromArgb(25, 60, 40)
$separatorColor = [System.Drawing.Color]::FromArgb(50, 50, 58)

# ---------- FUNZIONI ----------
function Get-IPInfo {
    $adapter = Get-NetIPAddress -AddressFamily IPv4 | 
        Where-Object { $_.InterfaceAlias -notmatch "Loopback|vEthernet|Bluetooth" -and $_.PrefixOrigin -ne "WellKnown" } |
        Select-Object -First 1
    if (-not $adapter) { throw "Nessun adattatore IP valido trovato." }
    $ip = $adapter.IPAddress
    $network = $ip -replace '\.[^.]+$', '.'
    return $network
}

function Get-ARPFromGateway {
    param(
        [string]$GatewayIP,
        [string]$Community = "public"
    )
    $arpTable = @{}
    try {
        $snmpwalk = Get-Command "snmpwalk" -ErrorAction SilentlyContinue
        if ($snmpwalk) {
            Write-Progress -Activity "Gateway SNMP" -Status "Interrogazione $GatewayIP con snmpwalk..." -PercentComplete 0
            $output = & snmpwalk -v2c -c $Community $GatewayIP 1.3.6.1.2.1.4.22.1.2 2>$null
            foreach ($line in $output) {
                if ($line -match '\.(\d+\.\d+\.\d+\.\d+)\s*=\s*Hex-STRING:\s*([0-9A-Fa-f]{2}\s+[0-9A-Fa-f]{2}\s+[0-9A-Fa-f]{2}\s+[0-9A-Fa-f]{2}\s+[0-9A-Fa-f]{2}\s+[0-9A-Fa-f]{2})') {
                    $ip = $Matches[1]
                    $mac = ($Matches[2] -split '\s+') -join '-'
                    $arpTable[$ip] = $mac
                }
            }
            Write-Progress -Activity "Gateway SNMP" -Completed
            return $arpTable
        }

        $module = Get-Module -Name SNMP -ListAvailable -ErrorAction SilentlyContinue
        if ($module) {
            Import-Module SNMP -ErrorAction SilentlyContinue
            Write-Progress -Activity "Gateway SNMP" -Status "Interrogazione $GatewayIP con modulo SNMP..." -PercentComplete 0
            $oids = @("1.3.6.1.2.1.4.22.1.2")
            $result = Get-SnmpOid -IP $GatewayIP -Community $Community -Oid $oids -ErrorAction SilentlyContinue
            foreach ($entry in $result) {
                if ($entry.Oid -match '\.(\d+\.\d+\.\d+\.\d+)$' -and $entry.Data) {
                    $ip = $Matches[1]
                    $mac = $entry.Data -replace ':', '-' -replace '\s+', ''
                    $arpTable[$ip] = $mac
                }
            }
            Write-Progress -Activity "Gateway SNMP" -Completed
            return $arpTable
        }

        Write-Progress -Activity "Gateway SNMP" -Completed
        return $arpTable
    } catch {
        Write-Progress -Activity "Gateway SNMP" -Completed
        return $arpTable
    }
}

function Scan-Network {
    param(
        [string]$Network,
        [int]$Start,
        [int]$End,
        [int[]]$Ports,
        [int]$Timeout = 1000,
        [string]$GatewayIP = $null,
        [string]$Community = "public"
    )
    $ipList = for ($i = $Start; $i -le $End; $i++) { "$Network$i" }
    $total = $ipList.Count

    $gatewayARP = @{}
    if ($GatewayIP) {
        $gatewayARP = Get-ARPFromGateway -GatewayIP $GatewayIP -Community $Community
        if ($gatewayARP.Count -gt 0) {
            Write-Progress -Activity "Scansione rete" -Status "Tabella ARP gateway: $($gatewayARP.Count) voci" -PercentComplete 0
        }
    }

    Write-Progress -Activity "Scansione rete" -Status "Avvio scan su $total IP..." -PercentComplete 0

    $results = $ipList | ForEach-Object -Parallel {
        $ip = $_
        $ports = $using:Ports
        $timeout = $using:Timeout
        $gatewayARP = $using:gatewayARP
        $timeMs = 0
        $alive = $false

        $ping = Test-Connection -ComputerName $ip -Count 2 -ErrorAction SilentlyContinue
        if ($ping -and $ping.StatusCode -eq 0) {
            $alive = $true
            $timeMs = [Math]::Round(($ping | Measure-Object -Property ResponseTime -Average).Average, 0)
        } else {
            foreach ($port in $ports) {
                try {
                    $tcp = New-Object System.Net.Sockets.TcpClient
                    $sw = [System.Diagnostics.Stopwatch]::StartNew()
                    $async = $tcp.BeginConnect($ip, $port, $null, $null)
                    $wait = $async.AsyncWaitHandle.WaitOne($timeout, $false)
                    $sw.Stop()
                    if ($wait -and $tcp.Connected) {
                        $alive = $true
                        $timeMs = [Math]::Round($sw.Elapsed.TotalMilliseconds, 0)
                        if ($timeMs -lt 1) { $timeMs = 1 }
                        $tcp.EndConnect($async)
                        $tcp.Close()
                        break
                    }
                    $tcp.Close()
                } catch { }
            }
        }

        if ($alive) {
            $hostname = $null
            try {
                $nbtOutput = nbtstat -A $ip 2>$null
                if ($nbtOutput -match "Nome NetBIOS\s+=\s+([^\s<]+)") {
                    $hostname = $Matches[1]
                }
            } catch { }
            if (-not $hostname) {
                try {
                    $pingOutput = ping -a $ip -n 1 2>$null
                    if ($pingOutput -match "Ping\s+([^\s]+)\s+\[$ip\]") {
                        $hostname = $Matches[1]
                    }
                } catch { }
            }
            if (-not $hostname) {
                try {
                    $nsOutput = nslookup $ip 2>$null
                    if ($nsOutput -match "Name:\s+(.+?)$") {
                        $hostname = $Matches[1].Trim()
                    }
                } catch { }
            }
            if (-not $hostname) {
                try {
                    $hostname = [System.Net.Dns]::GetHostEntry($ip).HostName
                } catch { }
            }

            $mac = $null
            try {
                $mac = (Get-NetNeighbor -IPAddress $ip -ErrorAction SilentlyContinue).LinkLayerAddress
            } catch { }
            if (-not $mac -or $mac -eq "00-00-00-00-00-00") {
                try {
                    $arpOutput = arp -a $ip 2>$null
                    if ($arpOutput -match '([0-9A-Fa-f]{2}-[0-9A-Fa-f]{2}-[0-9A-Fa-f]{2}-[0-9A-Fa-f]{2}-[0-9A-Fa-f]{2}-[0-9A-Fa-f]{2})') {
                        $mac = $Matches[1]
                    }
                } catch { }
            }
            if (-not $mac -or $mac -eq "00-00-00-00-00-00") {
                if ($gatewayARP.ContainsKey($ip)) {
                    $mac = $gatewayARP[$ip]
                }
            }

            $vendor = $null
            if ($mac -and $mac -ne "00-00-00-00-00-00") {
                try {
                    $macClean = $mac -replace '[:-]', ''
                    $vendor = (Invoke-RestMethod -Uri "https://api.macvendors.com/$macClean" -TimeoutSec 2 -ErrorAction Stop) -replace "`n", ""
                    if ($vendor -match "Not Found") { $vendor = $null }
                } catch { }
            }

            if ($mac -and $mac -ne "00-00-00-00-00-00") {
                [PSCustomObject]@{
                    IP       = $ip
                    Hostname = $hostname
                    MAC      = $mac
                    Vendor   = $vendor
                    Time_ms  = $timeMs
                    Status   = "Online"
                }
            } elseif ($timeMs -gt 0) {
                [PSCustomObject]@{
                    IP       = $ip
                    Hostname = $hostname
                    MAC      = $null
                    Vendor   = $null
                    Time_ms  = $timeMs
                    Status   = "Online (no MAC)"
                }
            }
        }
    } -ThrottleLimit 50

    Write-Progress -Activity "Scansione rete" -Completed
    return $results
}

# ---------- GUI CON TEMA SCURO ----------
function Show-GUI {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Scansione Rete Pro v6.1 (SNMP)"

    # --- DIMENSIONE ADATTIVA (80% larghezza, 75% altezza) ---
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $larghezza = [Math]::Round($screen.Width * 0.8)
    $altezza   = [Math]::Round($screen.Height * 0.75)
    if ($larghezza -lt 800) { $larghezza = 800 }
    if ($altezza -lt 600)   { $altezza = 600 }
    $form.Size = New-Object System.Drawing.Size($larghezza, $altezza)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = $bgColor
    $form.ForeColor = $fgColor
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $form.MinimumSize = New-Object System.Drawing.Size(800, 600)

    # ---- TABLE LAYOUT PRINCIPALE (2 righe) ----
    $mainTable = New-Object System.Windows.Forms.TableLayoutPanel
    $mainTable.Dock = "Fill"
    $mainTable.ColumnCount = 1
    $mainTable.RowCount = 2
    $mainTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 230)))
    $mainTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $mainTable.BackColor = $bgColor
    $form.Controls.Add($mainTable)

    # ---- RIGA 1: Pannello superiore ----
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = "Fill"
    $panel.BackColor = $bgPanel
    $panel.Padding = New-Object System.Windows.Forms.Padding(20, 15, 20, 15)
    $panel.BorderStyle = "FixedSingle"
    $mainTable.Controls.Add($panel, 0, 0)

    $y = 10
    $spacing = 38

    # Riga 1: IP rete, Subnet, Start, End
    $lblIP = New-Object System.Windows.Forms.Label
    $lblIP.Text = "🌐 IP rete:"
    $lblIP.Location = New-Object System.Drawing.Point(10, $y)
    $lblIP.Size = New-Object System.Drawing.Size(80, 28)
    $lblIP.ForeColor = $infoColor
    $lblIP.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($lblIP)

    $txtIP = New-Object System.Windows.Forms.TextBox
    $txtIP.Text = (Get-IPInfo -ErrorAction SilentlyContinue)
    if ([string]::IsNullOrEmpty($txtIP.Text)) { $txtIP.Text = "192.168.1." }
    $txtIP.Location = New-Object System.Drawing.Point(95, $y)
    $txtIP.Size = New-Object System.Drawing.Size(130, 28)
    $txtIP.Font = New-Object System.Drawing.Font("Consolas", 11)
    $txtIP.BackColor = $bgCard
    $txtIP.ForeColor = $fgColor
    $txtIP.BorderStyle = "FixedSingle"
    $panel.Controls.Add($txtIP)

    $lblSubnet = New-Object System.Windows.Forms.Label
    $lblSubnet.Text = "Subnet:"
    $lblSubnet.Location = New-Object System.Drawing.Point(240, $y)
    $lblSubnet.Size = New-Object System.Drawing.Size(60, 28)
    $lblSubnet.ForeColor = $infoColor
    $lblSubnet.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($lblSubnet)

    $cmbSubnet = New-Object System.Windows.Forms.ComboBox
    $cmbSubnet.Location = New-Object System.Drawing.Point(305, $y)
    $cmbSubnet.Size = New-Object System.Drawing.Size(120, 28)
    $cmbSubnet.DropDownStyle = "DropDownList"
    $cmbSubnet.Font = New-Object System.Drawing.Font("Consolas", 10)
    $cmbSubnet.BackColor = $bgCard
    $cmbSubnet.ForeColor = $fgColor
    $cmbSubnet.Items.Add("/24 (1-254)")
    $cmbSubnet.Items.Add("/23 (0-255)")
    $cmbSubnet.Items.Add("/16 (0-255)")
    $cmbSubnet.SelectedIndex = 0
    $panel.Controls.Add($cmbSubnet)

    $lblStart = New-Object System.Windows.Forms.Label
    $lblStart.Text = "Start:"
    $lblStart.Location = New-Object System.Drawing.Point(440, $y)
    $lblStart.Size = New-Object System.Drawing.Size(45, 28)
    $lblStart.ForeColor = $infoColor
    $lblStart.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($lblStart)

    $txtStart = New-Object System.Windows.Forms.TextBox
    $txtStart.Text = "1"
    $txtStart.Location = New-Object System.Drawing.Point(490, $y)
    $txtStart.Size = New-Object System.Drawing.Size(55, 28)
    $txtStart.Font = New-Object System.Drawing.Font("Consolas", 11)
    $txtStart.BackColor = $bgCard
    $txtStart.ForeColor = $fgColor
    $txtStart.BorderStyle = "FixedSingle"
    $panel.Controls.Add($txtStart)

    $lblEnd = New-Object System.Windows.Forms.Label
    $lblEnd.Text = "End:"
    $lblEnd.Location = New-Object System.Drawing.Point(560, $y)
    $lblEnd.Size = New-Object System.Drawing.Size(40, 28)
    $lblEnd.ForeColor = $infoColor
    $lblEnd.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($lblEnd)

    $txtEnd = New-Object System.Windows.Forms.TextBox
    $txtEnd.Text = "254"
    $txtEnd.Location = New-Object System.Drawing.Point(605, $y)
    $txtEnd.Size = New-Object System.Drawing.Size(55, 28)
    $txtEnd.Font = New-Object System.Drawing.Font("Consolas", 11)
    $txtEnd.BackColor = $bgCard
    $txtEnd.ForeColor = $fgColor
    $txtEnd.BorderStyle = "FixedSingle"
    $panel.Controls.Add($txtEnd)

    # Riga 2: Porte
    $y += $spacing
    $lblPorts = New-Object System.Windows.Forms.Label
    $lblPorts.Text = "🔌 Porte:"
    $lblPorts.Location = New-Object System.Drawing.Point(10, $y)
    $lblPorts.Size = New-Object System.Drawing.Size(70, 28)
    $lblPorts.ForeColor = $infoColor
    $lblPorts.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($lblPorts)

    $txtPorts = New-Object System.Windows.Forms.TextBox
    $txtPorts.Text = "445,139,22,80,443,3389,8080"
    $txtPorts.Location = New-Object System.Drawing.Point(85, $y)
    $txtPorts.Size = New-Object System.Drawing.Size(400, 28)
    $txtPorts.Font = New-Object System.Drawing.Font("Consolas", 10)
    $txtPorts.BackColor = $bgCard
    $txtPorts.ForeColor = $fgColor
    $txtPorts.BorderStyle = "FixedSingle"
    $panel.Controls.Add($txtPorts)

    # Riga 3: Gateway SNMP
    $y += $spacing
    $lblGateway = New-Object System.Windows.Forms.Label
    $lblGateway.Text = "🌐 Gateway SNMP:"
    $lblGateway.Location = New-Object System.Drawing.Point(10, $y)
    $lblGateway.Size = New-Object System.Drawing.Size(130, 28)
    $lblGateway.ForeColor = $infoColor
    $lblGateway.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($lblGateway)

    $txtGateway = New-Object System.Windows.Forms.TextBox
    $txtGateway.Text = ""
    $txtGateway.Location = New-Object System.Drawing.Point(145, $y)
    $txtGateway.Size = New-Object System.Drawing.Size(150, 28)
    $txtGateway.Font = New-Object System.Drawing.Font("Consolas", 10)
    $txtGateway.BackColor = $bgCard
    $txtGateway.ForeColor = $fgColor
    $txtGateway.BorderStyle = "FixedSingle"
    $tooltipGateway = New-Object System.Windows.Forms.ToolTip
    $tooltipGateway.SetToolTip($txtGateway, "Inserisci IP del gateway (es. 192.168.31.1) per ottenere MAC via SNMP")
    $panel.Controls.Add($txtGateway)

    $lblCommunity = New-Object System.Windows.Forms.Label
    $lblCommunity.Text = "Community:"
    $lblCommunity.Location = New-Object System.Drawing.Point(310, $y)
    $lblCommunity.Size = New-Object System.Drawing.Size(80, 28)
    $lblCommunity.ForeColor = $infoColor
    $lblCommunity.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($lblCommunity)

    $txtCommunity = New-Object System.Windows.Forms.TextBox
    $txtCommunity.Text = "public"
    $txtCommunity.Location = New-Object System.Drawing.Point(395, $y)
    $txtCommunity.Size = New-Object System.Drawing.Size(100, 28)
    $txtCommunity.Font = New-Object System.Drawing.Font("Consolas", 10)
    $txtCommunity.BackColor = $bgCard
    $txtCommunity.ForeColor = $fgColor
    $txtCommunity.BorderStyle = "FixedSingle"
    $tooltipCommunity = New-Object System.Windows.Forms.ToolTip
    $tooltipCommunity.SetToolTip($txtCommunity, "Community SNMP (default 'public')")
    $panel.Controls.Add($txtCommunity)

    # Riga 4: Bottoni
    $y += $spacing + 5
    $btnScan = New-Object System.Windows.Forms.Button
    $btnScan.Text = "🚀 Avvia Scansione"
    $btnScan.Location = New-Object System.Drawing.Point(10, $y)
    $btnScan.Size = New-Object System.Drawing.Size(160, 40)
    $btnScan.BackColor = $accentColor
    $btnScan.ForeColor = [System.Drawing.Color]::White
    $btnScan.FlatStyle = "Flat"
    $btnScan.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $btnScan.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnScan.FlatAppearance.BorderSize = 0
    $panel.Controls.Add($btnScan)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "✅ Pronto"
    $lblStatus.Location = New-Object System.Drawing.Point(190, ($y + 5))
    $lblStatus.Size = New-Object System.Drawing.Size(350, 30)
    $lblStatus.ForeColor = $successColor
    $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $panel.Controls.Add($lblStatus)

    $btnExport = New-Object System.Windows.Forms.Button
    $btnExport.Text = "💾 Esporta CSV"
    $btnExport.Location = New-Object System.Drawing.Point(560, $y)
    $btnExport.Size = New-Object System.Drawing.Size(150, 40)
    $btnExport.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 0)
    $btnExport.ForeColor = [System.Drawing.Color]::White
    $btnExport.FlatStyle = "Flat"
    $btnExport.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $btnExport.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnExport.FlatAppearance.BorderSize = 0
    $btnExport.Visible = $false
    $panel.Controls.Add($btnExport)

    # ---- RIGA 2: DataGridView (compatto) ----
    $dgv = New-Object System.Windows.Forms.DataGridView
    $dgv.Dock = "Fill"
    $dgv.BackgroundColor = $logBg
    $dgv.ForeColor = $fgColor
    $dgv.GridColor = $separatorColor
    $dgv.Font = New-Object System.Drawing.Font("Consolas", 9)
    $dgv.AutoSizeColumnsMode = "AllCells"
    $dgv.AllowUserToAddRows = $false
    $dgv.ReadOnly = $true
    $dgv.RowHeadersVisible = $false
    $dgv.ColumnHeadersVisible = $true
    $dgv.ColumnHeadersHeight = 30
    $dgv.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
    $dgv.ColumnHeadersDefaultCellStyle.BackColor = $accentColor
    $dgv.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    $dgv.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $dgv.ColumnHeadersDefaultCellStyle.Alignment = "MiddleCenter"
    $dgv.ColumnHeadersDefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(4)
    $dgv.DefaultCellStyle.BackColor = $bgCard
    $dgv.DefaultCellStyle.ForeColor = $fgColor
    $dgv.DefaultCellStyle.SelectionBackColor = $accentColor
    $dgv.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::White
    $dgv.AlternatingRowsDefaultCellStyle.BackColor = $bgPanel
    $dgv.AlternatingRowsDefaultCellStyle.ForeColor = $fgColor
    $dgv.RowsDefaultCellStyle.BackColor = $bgCard
    $dgv.RowsDefaultCellStyle.ForeColor = $fgColor
    $dgv.BorderStyle = "None"
    $dgv.CellBorderStyle = "SingleHorizontal"
    $dgv.EnableHeadersVisualStyles = $false
    $mainTable.Controls.Add($dgv, 0, 1)

    # ---- Eventi ----
    $cmbSubnet.Add_SelectedIndexChanged({
        $selected = $cmbSubnet.SelectedItem
        if ($selected -like "*24*") {
            $txtStart.Text = "1"
            $txtEnd.Text = "254"
        } elseif ($selected -like "*23*") {
            $txtStart.Text = "0"
            $txtEnd.Text = "255"
        } elseif ($selected -like "*16*") {
            $txtStart.Text = "0"
            $txtEnd.Text = "255"
        }
    })

    $btnScan.Add_Click({
        $btnScan.Enabled = $false
        $btnExport.Visible = $false
        $lblStatus.Text = "⏳ Scansione in corso..."
        $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
        $dgv.Rows.Clear()
        $dgv.Columns.Clear()

        $cols = @("IP", "Hostname", "MAC", "Vendor", "Time (ms)", "Status")
        foreach ($col in $cols) {
            $dgv.Columns.Add($col, $col) | Out-Null
            $dgv.Columns[$col].HeaderCell.Style.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            $dgv.Columns[$col].HeaderCell.Style.ForeColor = [System.Drawing.Color]::White
            $dgv.Columns[$col].HeaderCell.Style.BackColor = $accentColor
            $dgv.Columns[$col].HeaderCell.Style.Alignment = "MiddleCenter"
        }

        $network = $txtIP.Text.Trim()
        if (-not $network.EndsWith('.')) { $network += '.' }
        $start = [int]$txtStart.Text
        $end   = [int]$txtEnd.Text
        $ports = $txtPorts.Text -split ',' | ForEach-Object { [int]$_ }

        $gatewayIP = $txtGateway.Text.Trim()
        if ([string]::IsNullOrEmpty($gatewayIP)) { $gatewayIP = $null }
        $community = $txtCommunity.Text.Trim()
        if ([string]::IsNullOrEmpty($community)) { $community = "public" }

        $results = Scan-Network -Network $network -Start $start -End $end -Ports $ports -Timeout 1000 -GatewayIP $gatewayIP -Community $community

        foreach ($r in $results) {
            $idx = $dgv.Rows.Add($r.IP, $r.Hostname, $r.MAC, $r.Vendor, $r.Time_ms, $r.Status)
            if ($r.Time_ms -gt 0 -and $r.Time_ms -lt 50) {
                $dgv.Rows[$idx].DefaultCellStyle.ForeColor = $successColor
            } elseif ($r.Time_ms -ge 50 -and $r.Time_ms -lt 100) {
                $dgv.Rows[$idx].DefaultCellStyle.ForeColor = $warningColor
            } elseif ($r.Time_ms -ge 100) {
                $dgv.Rows[$idx].DefaultCellStyle.ForeColor = $exitColor
            }
        }

        foreach ($col in $dgv.Columns) {
            $col.AutoSizeMode = "AllCells"
        }
        $dgv.AutoResizeColumns()

        $larghezzaColonne = 0
        foreach ($col in $dgv.Columns) {
            $larghezzaColonne += $col.Width
        }
        if ($dgv.RowHeadersVisible) {
            $larghezzaColonne += $dgv.RowHeadersWidth
        }
        $margineTotale = 40
        $nuovaLarghezza = $larghezzaColonne + $margineTotale + 10
        if ($nuovaLarghezza -gt $form.MinimumSize.Width) {
            $form.Width = $nuovaLarghezza
        } else {
            $form.Width = $form.MinimumSize.Width
        }

        $lblStatus.Text = "✅ Scansione completata! Trovati $($results.Count) dispositivi."
        $lblStatus.ForeColor = $successColor
        $btnScan.Enabled = $true
        $btnExport.Visible = $true
    })

    $btnExport.Add_Click({
        if ($dgv.Rows.Count -eq 0) { return }
        $desktop = [Environment]::GetFolderPath("Desktop")
        $file = Join-Path $desktop "ScanRete_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $header = "IP,Hostname,MAC,Vendor,Time_ms,Status"
        $header | Out-File $file -Encoding UTF8
        foreach ($row in $dgv.Rows) {
            $ip = $row.Cells[0].Value
            $hostname = $row.Cells[1].Value
            $mac = $row.Cells[2].Value
            $vendor = $row.Cells[3].Value
            $time = $row.Cells[4].Value
            $status = $row.Cells[5].Value
            "$ip,$hostname,$mac,$vendor,$time,$status" | Out-File $file -Append -Encoding UTF8
        }
        [System.Windows.Forms.MessageBox]::Show("✅ File CSV salvato sul desktop:`n$file", "Esportazione completata", "OK", "Information")
    })

    $form.ShowDialog() | Out-Null
}

# ---------- AVVIO ----------
Show-GUI