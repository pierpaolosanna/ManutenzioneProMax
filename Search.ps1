# ============================================================
# Search.ps1 - Modulo Ricerca File v3.0.3
# Con Cache, Log e Apertura File (FINAL)
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================================
# VARIABILI GLOBALI
# ============================================================
$script:Job = $null
$script:Timer = $null
$script:IsSearching = $false
$script:Results = $null
$script:StartTime = $null
$script:CacheFile = "$env:APPDATA\SearchCache.json"
$script:LogFile = "$env:APPDATA\SearchLog.txt"

# ============================================================
# FUNZIONI DI LOG E CACHE
# ============================================================

function Write-SearchLog {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $script:LogFile -Append -Encoding UTF8 -ErrorAction SilentlyContinue
}

function ConvertTo-Hashtable {
    param($obj)
    if ($obj -eq $null) { return @{} }
    if ($obj -is [PSCustomObject]) {
        $hash = @{}
        foreach ($prop in $obj.PSObject.Properties) {
            $value = $prop.Value
            if ($value -is [PSCustomObject] -or $value -is [System.Management.Automation.PSObject]) {
                $hash[$prop.Name] = ConvertTo-Hashtable $value
            } elseif ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) {
                $list = @()
                foreach ($item in $value) {
                    if ($item -is [PSCustomObject]) {
                        $list += ConvertTo-Hashtable $item
                    } else {
                        $list += $item
                    }
                }
                $hash[$prop.Name] = $list
            } else {
                $hash[$prop.Name] = $value
            }
        }
        return $hash
    }
    return $obj
}

function Get-SearchCache {
    if (Test-Path $script:CacheFile) {
        try {
            $json = Get-Content -Path $script:CacheFile -Raw -ErrorAction SilentlyContinue
            if ([string]::IsNullOrWhiteSpace($json)) { return @{} }
            $obj = $json | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($obj -eq $null) { return @{} }
            return ConvertTo-Hashtable $obj
        } catch {
            Write-SearchLog "ERRORE lettura cache: $($_.Exception.Message)"
            return @{}
        }
    }
    return @{}
}

function Save-SearchCache {
    param($Cache)
    try {
        if ($Cache -eq $null -or $Cache.Count -eq 0) {
            if (Test-Path $script:CacheFile) {
                Remove-Item -Path $script:CacheFile -Force -ErrorAction SilentlyContinue
            }
            return
        }
        $json = $Cache | ConvertTo-Json -Depth 10 -ErrorAction SilentlyContinue
        $json | Out-File -FilePath $script:CacheFile -Encoding UTF8 -Force -ErrorAction SilentlyContinue
    } catch {
        Write-SearchLog "ERRORE salvataggio cache: $($_.Exception.Message)"
    }
}

function Get-SearchKey {
    param($SearchType, $Path, $Pattern, $Content, $Recurse, $MinSizeMB = 0)
    $key = "$SearchType|$Path|$Pattern|$Content|$Recurse|$MinSizeMB"
    return [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($key))
}

# ============================================================
# FUNZIONI DI RICERCA
# ============================================================

function Search-FilesPure {
    param($Path, $Pattern, $Content, $Recurse, $MaxResults = 500)
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $getParams = @{
        Path = $Path
        Filter = $Pattern
        File = $true
        ErrorAction = 'SilentlyContinue'
    }
    if ($Recurse) { $getParams.Recurse = $true }
    $files = Get-ChildItem @getParams
    $total = $files.Count
    $processed = 0
    foreach ($file in $files) {
        $processed++
        $percent = if ($total -gt 0) { [int](($processed / $total) * 100) } else { 0 }
        Write-Progress -Activity "Ricerca file..." -Status "$processed di $total" -PercentComplete $percent
        if ($Content -and $Content -ne "") {
            try {
                if (Select-String -Path $file.FullName -Pattern $Content -Quiet -ErrorAction SilentlyContinue) {
                    $results.Add([PSCustomObject]@{
                        Nome = $file.Name
                        Percorso = $file.FullName
                        Dimensione = $file.Length
                        Modificato = $file.LastWriteTime
                    })
                }
            } catch {}
        } else {
            $results.Add([PSCustomObject]@{
                Nome = $file.Name
                Percorso = $file.FullName
                Dimensione = $file.Length
                Modificato = $file.LastWriteTime
            })
        }
        if ($results.Count -ge $MaxResults) { break }
    }
    Write-Progress -Activity "Ricerca file..." -Completed
    return $results
}

function Search-DuplicatesPure {
    param($Path, $Recurse, $MaxResults = 100)
    $results = @()
    $getParams = @{
        Path = $Path
        File = $true
        ErrorAction = 'SilentlyContinue'
    }
    if ($Recurse) { $getParams.Recurse = $true }
    $files = Get-ChildItem @getParams
    $total = $files.Count
    $processed = 0
    $groups = @{}
    foreach ($file in $files) {
        $processed++
        $percent = if ($total -gt 0) { [int](($processed / $total) * 100) } else { 0 }
        Write-Progress -Activity "Analisi duplicati..." -Status "$processed di $total" -PercentComplete $percent
        try {
            $hash = Get-FileHash -Path $file.FullName -Algorithm MD5 -ErrorAction SilentlyContinue
            if ($hash) {
                $key = "$($file.Length)_$($hash.Hash)"
                if (-not $groups.ContainsKey($key)) { $groups[$key] = @() }
                $groups[$key] += $file.FullName
            }
        } catch {}
    }
    Write-Progress -Activity "Analisi duplicati..." -Completed
    foreach ($group in $groups.Values | Where-Object { $_.Count -gt 1 }) {
        $results += ,$group
        if ($results.Count -ge $MaxResults) { break }
    }
    return $results
}

function Search-LargePure {
    param($Path, $Recurse, $MinSizeMB = 100, $MaxResults = 50)
    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $minBytes = $MinSizeMB * 1MB
    $getParams = @{
        Path = $Path
        File = $true
        ErrorAction = 'SilentlyContinue'
    }
    if ($Recurse) { $getParams.Recurse = $true }
    $files = Get-ChildItem @getParams | Where-Object { $_.Length -gt $minBytes } | Sort-Object Length -Descending
    $total = $files.Count
    $processed = 0
    foreach ($file in $files) {
        $processed++
        $percent = if ($total -gt 0) { [int](($processed / $total) * 100) } else { 0 }
        Write-Progress -Activity "Ricerca file grandi..." -Status "$processed di $total" -PercentComplete $percent
        $results.Add([PSCustomObject]@{
            Nome = $file.Name
            Percorso = $file.FullName
            Dimensione = $file.Length
            Modificato = $file.LastWriteTime
        })
        if ($results.Count -ge $MaxResults) { break }
    }
    Write-Progress -Activity "Ricerca file grandi..." -Completed
    return $results
}

# ============================================================
# FUNZIONE PRINCIPALE UI
# ============================================================

function Show-SearchDialog {
    # ---- Creazione Finestra ----
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "🔍 Ricerca File v6.1"
    $form.Size = New-Object System.Drawing.Size(920, 680)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 40)
    $form.ForeColor = [System.Drawing.Color]::White
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $form.KeyPreview = $true

    # ---- Layout ----
    $table = New-Object System.Windows.Forms.TableLayoutPanel
    $table.Dock = [System.Windows.Forms.DockStyle]::Fill
    $table.ColumnCount = 1
    $table.RowCount = 5
    $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 65)))
    $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $table.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 25)))
    $form.Controls.Add($table)

    # ---- RIGA 1: PERCORSO ----
    $panelPath = New-Object System.Windows.Forms.Panel
    $panelPath.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panelPath.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)
    $table.Controls.Add($panelPath, 0, 0)

    $lblPath = New-Object System.Windows.Forms.Label
    $lblPath.Text = "Percorso:"
    $lblPath.Location = New-Object System.Drawing.Point(10, 10)
    $lblPath.Size = New-Object System.Drawing.Size(70, 25)
    $lblPath.ForeColor = [System.Drawing.Color]::White
    $panelPath.Controls.Add($lblPath)

    $txtPath = New-Object System.Windows.Forms.TextBox
    $txtPath.Location = New-Object System.Drawing.Point(85, 8)
    $txtPath.Size = New-Object System.Drawing.Size(550, 25)
    $txtPath.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 60)
    $txtPath.ForeColor = [System.Drawing.Color]::White
    $txtPath.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $txtPath.Text = "F:\DOWNLOAD\EASY"
    $panelPath.Controls.Add($txtPath)

    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = "Sfoglia..."
    $btnBrowse.Location = New-Object System.Drawing.Point(645, 8)
    $btnBrowse.Size = New-Object System.Drawing.Size(80, 25)
    $btnBrowse.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 80)
    $btnBrowse.ForeColor = [System.Drawing.Color]::White
    $btnBrowse.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnBrowse.Add_Click({
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fbd.SelectedPath = $txtPath.Text
        if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtPath.Text = $fbd.SelectedPath
        }
    })
    $panelPath.Controls.Add($btnBrowse)

    # ---- RIGA 2: OPZIONI ----
    $panelOptions = New-Object System.Windows.Forms.Panel
    $panelOptions.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panelOptions.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)
    $table.Controls.Add($panelOptions, 0, 1)

    $chkRecurse = New-Object System.Windows.Forms.CheckBox
    $chkRecurse.Text = "Ricorsivo"
    $chkRecurse.Location = New-Object System.Drawing.Point(10, 10)
    $chkRecurse.Size = New-Object System.Drawing.Size(100, 25)
    $chkRecurse.Checked = $true
    $chkRecurse.ForeColor = [System.Drawing.Color]::White
    $panelOptions.Controls.Add($chkRecurse)

    $lblPattern = New-Object System.Windows.Forms.Label
    $lblPattern.Text = "Filtro nome:"
    $lblPattern.Location = New-Object System.Drawing.Point(120, 12)
    $lblPattern.Size = New-Object System.Drawing.Size(80, 20)
    $lblPattern.ForeColor = [System.Drawing.Color]::White
    $panelOptions.Controls.Add($lblPattern)

    $txtPattern = New-Object System.Windows.Forms.TextBox
    $txtPattern.Location = New-Object System.Drawing.Point(205, 10)
    $txtPattern.Size = New-Object System.Drawing.Size(150, 25)
    $txtPattern.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 60)
    $txtPattern.ForeColor = [System.Drawing.Color]::White
    $txtPattern.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $txtPattern.Text = "*"
    $panelOptions.Controls.Add($txtPattern)

    $lblContent = New-Object System.Windows.Forms.Label
    $lblContent.Text = "Contenuto:"
    $lblContent.Location = New-Object System.Drawing.Point(370, 12)
    $lblContent.Size = New-Object System.Drawing.Size(70, 20)
    $lblContent.ForeColor = [System.Drawing.Color]::White
    $panelOptions.Controls.Add($lblContent)

    $txtContent = New-Object System.Windows.Forms.TextBox
    $txtContent.Location = New-Object System.Drawing.Point(445, 10)
    $txtContent.Size = New-Object System.Drawing.Size(280, 25)
    $txtContent.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 60)
    $txtContent.ForeColor = [System.Drawing.Color]::White
    $txtContent.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $panelOptions.Controls.Add($txtContent)

    # ---- RIGA 3: PULSANTI ----
    $panelButtons = New-Object System.Windows.Forms.Panel
    $panelButtons.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panelButtons.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)
    $table.Controls.Add($panelButtons, 0, 2)

    # Pulsanti (altezza 35)
    $btnSearch = New-Object System.Windows.Forms.Button
    $btnSearch.Text = "🔍 Cerca"
    $btnSearch.Location = New-Object System.Drawing.Point(10, 8)
    $btnSearch.Size = New-Object System.Drawing.Size(85, 35)
    $btnSearch.BackColor = [System.Drawing.Color]::FromArgb(60, 180, 100)
    $btnSearch.ForeColor = [System.Drawing.Color]::White
    $btnSearch.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSearch.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $panelButtons.Controls.Add($btnSearch)

    $btnDuplicates = New-Object System.Windows.Forms.Button
    $btnDuplicates.Text = "🔁 Duplicati"
    $btnDuplicates.Location = New-Object System.Drawing.Point(105, 8)
    $btnDuplicates.Size = New-Object System.Drawing.Size(85, 35)
    $btnDuplicates.BackColor = [System.Drawing.Color]::FromArgb(140, 80, 200)
    $btnDuplicates.ForeColor = [System.Drawing.Color]::White
    $btnDuplicates.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnDuplicates.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $panelButtons.Controls.Add($btnDuplicates)

    $btnLarge = New-Object System.Windows.Forms.Button
    $btnLarge.Text = "📦 File Grandi"
    $btnLarge.Location = New-Object System.Drawing.Point(200, 8)
    $btnLarge.Size = New-Object System.Drawing.Size(85, 35)
    $btnLarge.BackColor = [System.Drawing.Color]::FromArgb(220, 160, 40)
    $btnLarge.ForeColor = [System.Drawing.Color]::White
    $btnLarge.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnLarge.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $panelButtons.Controls.Add($btnLarge)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "⛔ Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(295, 8)
    $btnCancel.Size = New-Object System.Drawing.Size(75, 35)
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(200, 60, 60)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCancel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnCancel.Enabled = $false
    $panelButtons.Controls.Add($btnCancel)

    $btnClearCache = New-Object System.Windows.Forms.Button
    $btnClearCache.Text = "🗑️ Cache"
    $btnClearCache.Location = New-Object System.Drawing.Point(380, 8)
    $btnClearCache.Size = New-Object System.Drawing.Size(70, 35)
    $btnClearCache.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 120)
    $btnClearCache.ForeColor = [System.Drawing.Color]::White
    $btnClearCache.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClearCache.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
    $btnClearCache.Add_Click({
        if (Test-Path $script:CacheFile) {
            Remove-Item -Path $script:CacheFile -Force -ErrorAction SilentlyContinue
            $lblStatus.Text = "✅ Cache svuotata!"
            Write-SearchLog "Cache svuotata manualmente"
        } else {
            $lblStatus.Text = "ℹ️ Nessuna cache trovata"
        }
    })
    $panelButtons.Controls.Add($btnClearCache)

    $btnViewLog = New-Object System.Windows.Forms.Button
    $btnViewLog.Text = "📋 Log"
    $btnViewLog.Location = New-Object System.Drawing.Point(460, 8)
    $btnViewLog.Size = New-Object System.Drawing.Size(60, 35)
    $btnViewLog.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 120)
    $btnViewLog.ForeColor = [System.Drawing.Color]::White
    $btnViewLog.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnViewLog.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
    $btnViewLog.Add_Click({
        if (Test-Path $script:LogFile) {
            Start-Process notepad.exe $script:LogFile
        } else {
            $lblStatus.Text = "ℹ️ Nessun log trovato"
        }
    })
    $panelButtons.Controls.Add($btnViewLog)

    # Progress Bar e Status
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(530, 14)
    $progressBar.Size = New-Object System.Drawing.Size(240, 22)
    $progressBar.Minimum = 0
    $progressBar.Maximum = 100
    $progressBar.Value = 0
    $panelButtons.Controls.Add($progressBar)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Pronto"
    $lblStatus.Location = New-Object System.Drawing.Point(780, 16)
    $lblStatus.Size = New-Object System.Drawing.Size(100, 20)
    $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 200)
    $panelButtons.Controls.Add($lblStatus)

    # ---- RIGA 4: RISULTATI ----
    $dgvResults = New-Object System.Windows.Forms.DataGridView
    $dgvResults.Dock = [System.Windows.Forms.DockStyle]::Fill
    $dgvResults.BackgroundColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
    $dgvResults.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $dgvResults.AllowUserToAddRows = $false
    $dgvResults.AllowUserToDeleteRows = $false
    $dgvResults.ReadOnly = $true
    $dgvResults.RowHeadersVisible = $false
    $dgvResults.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $dgvResults.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $dgvResults.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
    $dgvResults.DefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    $dgvResults.DefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $dgvResults.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 50)
    $dgvResults.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    $dgvResults.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $dgvResults.GridColor = [System.Drawing.Color]::FromArgb(50, 50, 60)
    
    # Colonne
    $dgvResults.Columns.Add("Nome", "Nome")
    $dgvResults.Columns.Add("Percorso", "Percorso")
    $dgvResults.Columns.Add("Dimensione", "Dimensione")
    $dgvResults.Columns.Add("Modificato", "Modificato")
    $dgvResults.Columns[0].FillWeight = 25
    $dgvResults.Columns[1].FillWeight = 50
    $dgvResults.Columns[2].FillWeight = 12
    $dgvResults.Columns[3].FillWeight = 13
    
    $table.Controls.Add($dgvResults, 0, 3)

    # ---- RIGA 5: STATUS BAR INFERIORE ----
    $panelBottom = New-Object System.Windows.Forms.Panel
    $panelBottom.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panelBottom.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 30)
    $panelBottom.Padding = New-Object System.Windows.Forms.Padding(10, 0, 10, 0)
    $table.Controls.Add($panelBottom, 0, 4)

    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = "💡 Doppio click su un file per aprirlo"
    $lblInfo.Location = New-Object System.Drawing.Point(10, 4)
    $lblInfo.Size = New-Object System.Drawing.Size(400, 20)
    $lblInfo.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 170)
    $panelBottom.Controls.Add($lblInfo)

    $lblCacheStatus = New-Object System.Windows.Forms.Label
    $lblCacheStatus.Text = ""
    $lblCacheStatus.Location = New-Object System.Drawing.Point(700, 4)
    $lblCacheStatus.Size = New-Object System.Drawing.Size(180, 20)
    $lblCacheStatus.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $lblCacheStatus.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 170)
    $lblCacheStatus.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $panelBottom.Controls.Add($lblCacheStatus)

    # ============================================================
    # FUNZIONI UI
    # ============================================================

    function Update-Results {
        param($results, $status, $fromCache = $false)
        $dgvResults.Rows.Clear()
        if ($results -and $results.Count -gt 0) {
            foreach ($item in $results) {
                $sizeStr = if ($item.Dimensione -gt 1GB) { "{0:N2} GB" -f ($item.Dimensione / 1GB) }
                           elseif ($item.Dimensione -gt 1MB) { "{0:N2} MB" -f ($item.Dimensione / 1MB) }
                           else { "{0:N0} KB" -f ($item.Dimensione / 1KB) }
                $dgvResults.Rows.Add($item.Nome, $item.Percorso, $sizeStr, $item.Modificato)
            }
            $lblStatus.Text = "$status - Trovati $($dgvResults.Rows.Count)"
        } else {
            $lblStatus.Text = "$status - Nessun risultato"
        }
        if ($fromCache) {
            $lblCacheStatus.Text = "📦 Da cache"
            $lblCacheStatus.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 100)
        } else {
            $lblCacheStatus.Text = "🔍 Ricerca live"
            $lblCacheStatus.ForeColor = [System.Drawing.Color]::FromArgb(100, 200, 255)
        }
        $dgvResults.ClearSelection()
        $progressBar.Value = 100
        $btnSearch.Enabled = $true
        $btnDuplicates.Enabled = $true
        $btnLarge.Enabled = $true
        $btnCancel.Enabled = $false
    }

    # ---- DOPPIO CLICK PER APRIRE ----
    $dgvResults.Add_CellDoubleClick({
        if ($dgvResults.SelectedRows.Count -eq 0) { return }
        $row = $dgvResults.SelectedRows[0]
        $path = $row.Cells["Percorso"].Value
        if (-not $path) { return }
        try {
            if (Test-Path -Path $path) {
                Start-Process -FilePath $path
                $lblStatus.Text = "📄 Aperto: $(Split-Path $path -Leaf)"
            } else {
                $lblStatus.Text = "⚠️ Percorso non trovato: $path"
            }
        } catch {
            $lblStatus.Text = "❌ Errore: $($_.Exception.Message)"
        }
    })

    # ============================================================
    # AVVIO RICERCA IN BACKGROUND
    # ============================================================

    function Start-BackgroundSearch {
        param($SearchType)
        
        if ($script:IsSearching) { return }
        
        $path = $txtPath.Text
        $recurse = $chkRecurse.Checked
        $pattern = $txtPattern.Text
        $content = $txtContent.Text
        $minSizeMB = 100
        
        # Controlla cache
        $cacheKey = Get-SearchKey -SearchType $SearchType -Path $path -Pattern $pattern -Content $content -Recurse $recurse -MinSizeMB $minSizeMB
        $cache = Get-SearchCache
        
        # Usa Hashtable per la cache
        if ($cache -is [hashtable] -and $cache.ContainsKey($cacheKey)) {
            $cachedItem = $cache[$cacheKey]
            $cachedTime = [datetime]$cachedItem.Timestamp
            $age = (Get-Date) - $cachedTime
            
            if ($age.TotalHours -lt 24) {
                Write-SearchLog "USO CACHE $SearchType su $path ($($cachedItem.Results.Count) risultati, $([math]::Round($age.TotalHours,1)) ore)"
                $lblStatus.Text = "📦 Cache ($([math]::Round($age.TotalHours,1)) ore)"
                Update-Results -results $cachedItem.Results -status "✅ Da cache" -fromCache $true
                return
            }
        }
        
        # Avvia ricerca
        $script:IsSearching = $true
        $btnSearch.Enabled = $false
        $btnDuplicates.Enabled = $false
        $btnLarge.Enabled = $false
        $btnCancel.Enabled = $true
        $progressBar.Value = 0
        $lblStatus.Text = "Ricerca in corso..."
        $lblCacheStatus.Text = "🔍 Ricerca live"
        $lblCacheStatus.ForeColor = [System.Drawing.Color]::FromArgb(100, 200, 255)
        $dgvResults.Rows.Clear()
        
        # ScriptBlock per il Job (self-contained)
        $scriptBlock = {
            param($Type, $Path, $Pattern, $Content, $Recurse, $MinSizeMB)
            
            # Funzioni di ricerca (inline)
            function Search-Files {
                param($Path, $Pattern, $Content, $Recurse, $MaxResults = 500)
                $results = [System.Collections.Generic.List[PSCustomObject]]::new()
                $getParams = @{ Path = $Path; Filter = $Pattern; File = $true; ErrorAction = 'SilentlyContinue' }
                if ($Recurse) { $getParams.Recurse = $true }
                $files = Get-ChildItem @getParams
                foreach ($file in $files) {
                    if ($Content -and $Content -ne "") {
                        try {
                            if (Select-String -Path $file.FullName -Pattern $Content -Quiet -ErrorAction SilentlyContinue) {
                                $results.Add([PSCustomObject]@{ Nome = $file.Name; Percorso = $file.FullName; Dimensione = $file.Length; Modificato = $file.LastWriteTime })
                            }
                        } catch {}
                    } else {
                        $results.Add([PSCustomObject]@{ Nome = $file.Name; Percorso = $file.FullName; Dimensione = $file.Length; Modificato = $file.LastWriteTime })
                    }
                    if ($results.Count -ge $MaxResults) { break }
                }
                return $results
            }
            
            function Search-Duplicates {
                param($Path, $Recurse, $MaxResults = 100)
                $results = @()
                $getParams = @{ Path = $Path; File = $true; ErrorAction = 'SilentlyContinue' }
                if ($Recurse) { $getParams.Recurse = $true }
                $files = Get-ChildItem @getParams
                $groups = @{}
                foreach ($file in $files) {
                    try {
                        $hash = Get-FileHash -Path $file.FullName -Algorithm MD5 -ErrorAction SilentlyContinue
                        if ($hash) {
                            $key = "$($file.Length)_$($hash.Hash)"
                            if (-not $groups.ContainsKey($key)) { $groups[$key] = @() }
                            $groups[$key] += $file.FullName
                        }
                    } catch {}
                }
                foreach ($group in $groups.Values | Where-Object { $_.Count -gt 1 }) {
                    $results += ,$group
                    if ($results.Count -ge $MaxResults) { break }
                }
                return $results
            }
            
            function Search-Large {
                param($Path, $Recurse, $MinSizeMB, $MaxResults = 50)
                $results = [System.Collections.Generic.List[PSCustomObject]]::new()
                $minBytes = $MinSizeMB * 1MB
                $getParams = @{ Path = $Path; File = $true; ErrorAction = 'SilentlyContinue' }
                if ($Recurse) { $getParams.Recurse = $true }
                $files = Get-ChildItem @getParams | Where-Object { $_.Length -gt $minBytes } | Sort-Object Length -Descending
                foreach ($file in $files) {
                    $results.Add([PSCustomObject]@{ Nome = $file.Name; Percorso = $file.FullName; Dimensione = $file.Length; Modificato = $file.LastWriteTime })
                    if ($results.Count -ge $MaxResults) { break }
                }
                return $results
            }
            
            # Esegui la ricerca richiesta
            switch ($Type) {
                "Files" { return Search-Files -Path $Path -Pattern $Pattern -Content $Content -Recurse $Recurse }
                "Duplicates" { return Search-Duplicates -Path $Path -Recurse $Recurse }
                "Large" { return Search-Large -Path $Path -Recurse $Recurse -MinSizeMB $MinSizeMB }
            }
        }
        
        # SALVA IL TEMPO DI INIZIO NELLO SCRIPT SCOPE
        $script:StartTime = Get-Date
        
        $script:Job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $SearchType, $path, $pattern, $content, $recurse, $minSizeMB
        
        # Timer per controllare il job
        $script:Timer = New-Object System.Windows.Forms.Timer
        $script:Timer.Interval = 300
        $script:Timer.Add_Tick({
            $job = $script:Job
            if ($job -eq $null) { $this.Stop(); return }
            
            if ($job.State -eq 'Running') {
                $val = ($progressBar.Value + 3) % 90
                if ($val -lt 10) { $val = 10 }
                $progressBar.Value = $val
                $lblStatus.Text = "Ricerca in corso... ($val%)"
            } elseif ($job.State -eq 'Completed') {
                $this.Stop()
                $results = Receive-Job -Job $job
                Remove-Job -Job $job
                $script:Job = $null
                $script:IsSearching = $false
                
                # USO $script:StartTime (ora disponibile)
                $endTime = Get-Date
                if ($script:StartTime) {
                    $duration = (New-TimeSpan -Start $script:StartTime -End $endTime).TotalSeconds
                } else {
                    $duration = 0
                }
                $script:StartTime = $null
                
                # Salva in cache
                if ($results -and $results.Count -gt 0) {
                    try {
                        $cache = Get-SearchCache
                        if ($cache -isnot [hashtable]) { $cache = @{} }
                        $cacheKey = Get-SearchKey -SearchType $SearchType -Path $path -Pattern $pattern -Content $content -Recurse $recurse -MinSizeMB $minSizeMB
                        $cache[$cacheKey] = @{
                            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                            Type = $SearchType
                            Path = $path
                            Pattern = $pattern
                            Content = $content
                            Recurse = $recurse
                            Results = $results
                            Count = $results.Count
                        }
                        Save-SearchCache -Cache $cache
                        Write-SearchLog "RICERCA $SearchType su $path - $($results.Count) risultati in $([math]::Round($duration,2)) sec - SALVATO IN CACHE"
                    } catch {
                        Write-SearchLog "ERRORE salvataggio cache: $($_.Exception.Message)"
                    }
                } else {
                    Write-SearchLog "RICERCA $SearchType su $path - 0 risultati in $([math]::Round($duration,2)) sec"
                }
                
                Update-Results -results $results -status "✅ Completato" -fromCache $false
            } elseif ($job.State -eq 'Failed' -or $job.State -eq 'Stopped') {
                $this.Stop()
                Remove-Job -Job $job -Force
                $script:Job = $null
                $script:IsSearching = $false
                $script:StartTime = $null
                $lblStatus.Text = "❌ Errore o annullato"
                $progressBar.Value = 0
                $lblCacheStatus.Text = ""
                $btnSearch.Enabled = $true
                $btnDuplicates.Enabled = $true
                $btnLarge.Enabled = $true
                $btnCancel.Enabled = $false
            }
        })
        $script:Timer.Start()
    }

    # ============================================================
    # EVENTI PULSANTI
    # ============================================================

    $btnSearch.Add_Click({ Start-BackgroundSearch -SearchType "Files" })
    $btnDuplicates.Add_Click({ Start-BackgroundSearch -SearchType "Duplicates" })
    $btnLarge.Add_Click({ Start-BackgroundSearch -SearchType "Large" })

    $btnCancel.Add_Click({
        if ($script:Job) {
            # Stop-Job NON ha -Force
            Stop-Job -Job $script:Job
            Remove-Job -Job $script:Job -Force
            $script:Job = $null
            $script:IsSearching = $false
            $script:StartTime = $null
            $lblStatus.Text = "⛔ Annullato"
            $progressBar.Value = 0
            $lblCacheStatus.Text = ""
            $btnSearch.Enabled = $true
            $btnDuplicates.Enabled = $true
            $btnLarge.Enabled = $true
            $btnCancel.Enabled = $false
            Write-SearchLog "RICERCA ANNULLATA"
        }
    })

    # ---- SCORCIATOIE ----
    $form.Add_KeyDown({
        if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $form.Close() }
        if ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::F) {
            $txtPattern.Focus(); $txtPattern.SelectAll()
        }
    })

    # ---- MOSTRA ----
    $form.ShowDialog() | Out-Null
}

# ============================================================
# FINE MODULO
# ============================================================
