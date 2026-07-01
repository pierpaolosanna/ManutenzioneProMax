# ============================================================
# Search.ps1 - Modulo Ricerca per Manutenzione PRO MAX
# Versione: 1.0.0
# Data: 2026-07-01
# Descrizione: Fornisce funzionalità di ricerca rapida file e contenuti
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------- FUNZIONI DI RICERCA ----------
function Search-Files {
    param(
        [string]$Path = $env:USERPROFILE,
        [string]$Pattern = "*",
        [string]$Content = "",
        [int]$MaxResults = 50,
        [switch]$Recurse
    )
    
    $results = @()
    $searchPath = if ($Recurse) { $Path } else { $Path }
    
    try {
        # Ricerca per pattern nome file
        $items = Get-ChildItem -Path $searchPath -Filter $Pattern -File -ErrorAction SilentlyContinue
        if ($Recurse) {
            $items = Get-ChildItem -Path $searchPath -Filter $Pattern -File -Recurse -ErrorAction SilentlyContinue
        }
        
        # Filtra per contenuto se specificato
        if ($Content -and $Content -ne "") {
            $items = $items | Where-Object {
                try {
                    $text = Get-Content -Path $_.FullName -Raw -ErrorAction SilentlyContinue
                    $text -match $Content
                } catch { $false }
            }
        }
        
        $results = $items | Select-Object -First $MaxResults | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                Path = $_.FullName
                Size = $_.Length
                Modified = $_.LastWriteTime
                Folder = $_.DirectoryName
            }
        }
    } catch {
        Write-Error "Errore durante la ricerca: $($_.Exception.Message)"
    }
    
    return $results
}

function Search-Duplicates {
    param(
        [string]$Path = $env:USERPROFILE,
        [switch]$Recurse,
        [int]$MaxResults = 20
    )
    
    $groups = @{}
    $searchPath = if ($Recurse) { $Path } else { $Path }
    
    try {
        $files = Get-ChildItem -Path $searchPath -File -Recurse:$Recurse -ErrorAction SilentlyContinue
        
        foreach ($file in $files) {
            try {
                $hash = Get-FileHash -Path $file.FullName -Algorithm MD5 -ErrorAction SilentlyContinue
                if ($hash) {
                    $key = "$($file.Length)_$($hash.Hash)"
                    if (-not $groups.ContainsKey($key)) {
                        $groups[$key] = @()
                    }
                    $groups[$key] += $file.FullName
                }
            } catch {}
        }
        
        $duplicates = $groups.Values | Where-Object { $_.Count -gt 1 } | Select-Object -First $MaxResults
        return $duplicates
    } catch {
        Write-Error "Errore durante la ricerca duplicati: $($_.Exception.Message)"
        return @()
    }
}

function Search-LargeFiles {
    param(
        [string]$Path = $env:USERPROFILE,
        [int]$MinSizeMB = 100,
        [int]$MaxResults = 20,
        [switch]$Recurse
    )
    
    $minBytes = $MinSizeMB * 1MB
    $searchPath = if ($Recurse) { $Path } else { $Path }
    
    try {
        $files = Get-ChildItem -Path $searchPath -File -Recurse:$Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -gt $minBytes } |
            Sort-Object Length -Descending |
            Select-Object -First $MaxResults
        
        return $files | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                Path = $_.FullName
                SizeMB = [Math]::Round($_.Length / 1MB, 2)
                Modified = $_.LastWriteTime
            }
        }
    } catch {
        Write-Error "Errore durante la ricerca file grandi: $($_.Exception.Message)"
        return @()
    }
}

# ---------- FUNZIONE PRINCIPALE ----------
function Show-SearchDialog {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "🔍 Ricerca Rapida"
    $form.Size = New-Object System.Drawing.Size(900, 600)
    $form.MinimumSize = New-Object System.Drawing.Size(800, 500)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $form.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 24)
    $form.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $form.MaximizeBox = $true
    $form.MinimizeBox = $true
    
    # Layout principale
    $mainPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $mainPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainPanel.RowCount = 2
    $mainPanel.ColumnCount = 1
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 120)))
    $mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $mainPanel.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 24)
    $form.Controls.Add($mainPanel)
    
    # Pannello superiore (filtri)
    $topPanel = New-Object System.Windows.Forms.Panel
    $topPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $topPanel.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $topPanel.Padding = New-Object System.Windows.Forms.Padding(15)
    $mainPanel.Controls.Add($topPanel, 0, 0)
    
    # Percorso
    $lblPath = New-Object System.Windows.Forms.Label
    $lblPath.Text = "📁 Percorso:"
    $lblPath.Location = New-Object System.Drawing.Point(15, 15)
    $lblPath.Size = New-Object System.Drawing.Size(80, 25)
    $lblPath.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblPath.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $topPanel.Controls.Add($lblPath)
    
    $txtPath = New-Object System.Windows.Forms.TextBox
    $txtPath.Location = New-Object System.Drawing.Point(100, 12)
    $txtPath.Size = New-Object System.Drawing.Size(500, 28)
    $txtPath.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $txtPath.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
    $txtPath.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $txtPath.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $txtPath.Text = $env:USERPROFILE
    $topPanel.Controls.Add($txtPath)
    
    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = "📂 Sfoglia"
    $btnBrowse.Location = New-Object System.Drawing.Point(610, 10)
    $btnBrowse.Size = New-Object System.Drawing.Size(100, 32)
    $btnBrowse.BackColor = [System.Drawing.Color]::FromArgb(56, 132, 244)
    $btnBrowse.ForeColor = [System.Drawing.Color]::White
    $btnBrowse.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnBrowse.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnBrowse.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnBrowse.Add_Click({
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fbd.Description = "Seleziona la cartella da cercare"
        $fbd.SelectedPath = $txtPath.Text
        if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $txtPath.Text = $fbd.SelectedPath
        }
    })
    $topPanel.Controls.Add($btnBrowse)
    
    # Pattern e Contenuto
    $lblPattern = New-Object System.Windows.Forms.Label
    $lblPattern.Text = "🔎 Nome:"
    $lblPattern.Location = New-Object System.Drawing.Point(15, 50)
    $lblPattern.Size = New-Object System.Drawing.Size(80, 25)
    $lblPattern.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblPattern.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $topPanel.Controls.Add($lblPattern)
    
    $txtPattern = New-Object System.Windows.Forms.TextBox
    $txtPattern.Location = New-Object System.Drawing.Point(100, 47)
    $txtPattern.Size = New-Object System.Drawing.Size(200, 28)
    $txtPattern.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $txtPattern.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
    $txtPattern.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $txtPattern.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $txtPattern.Text = "*"
    $topPanel.Controls.Add($txtPattern)
    
    $lblContent = New-Object System.Windows.Forms.Label
    $lblContent.Text = "📄 Contenuto:"
    $lblContent.Location = New-Object System.Drawing.Point(320, 50)
    $lblContent.Size = New-Object System.Drawing.Size(80, 25)
    $lblContent.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblContent.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $topPanel.Controls.Add($lblContent)
    
    $txtContent = New-Object System.Windows.Forms.TextBox
    $txtContent.Location = New-Object System.Drawing.Point(410, 47)
    $txtContent.Size = New-Object System.Drawing.Size(300, 28)
    $txtContent.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $txtContent.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
    $txtContent.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $txtContent.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $topPanel.Controls.Add($txtContent)
    
    # Opzioni
    $chkRecurse = New-Object System.Windows.Forms.CheckBox
    $chkRecurse.Text = "🔁 Ricorsivo"
    $chkRecurse.Location = New-Object System.Drawing.Point(15, 85)
    $chkRecurse.Size = New-Object System.Drawing.Size(100, 25)
    $chkRecurse.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $chkRecurse.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $chkRecurse.Checked = $true
    $topPanel.Controls.Add($chkRecurse)
    
    $lblMax = New-Object System.Windows.Forms.Label
    $lblMax.Text = "Max risultati:"
    $lblMax.Location = New-Object System.Drawing.Point(130, 85)
    $lblMax.Size = New-Object System.Drawing.Size(90, 25)
    $lblMax.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblMax.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $topPanel.Controls.Add($lblMax)
    
    $numMax = New-Object System.Windows.Forms.NumericUpDown
    $numMax.Location = New-Object System.Drawing.Point(225, 82)
    $numMax.Size = New-Object System.Drawing.Size(80, 28)
    $numMax.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $numMax.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
    $numMax.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $numMax.Minimum = 1
    $numMax.Maximum = 500
    $numMax.Value = 50
    $numMax.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $topPanel.Controls.Add($numMax)
    
    $btnSearch = New-Object System.Windows.Forms.Button
    $btnSearch.Text = "🔍 Cerca"
    $btnSearch.Location = New-Object System.Drawing.Point(330, 80)
    $btnSearch.Size = New-Object System.Drawing.Size(100, 32)
    $btnSearch.BackColor = [System.Drawing.Color]::FromArgb(60, 210, 120)
    $btnSearch.ForeColor = [System.Drawing.Color]::White
    $btnSearch.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSearch.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnSearch.Cursor = [System.Windows.Forms.Cursors]::Hand
    $topPanel.Controls.Add($btnSearch)
    
    $btnDuplicates = New-Object System.Windows.Forms.Button
    $btnDuplicates.Text = "🔁 Duplicati"
    $btnDuplicates.Location = New-Object System.Drawing.Point(440, 80)
    $btnDuplicates.Size = New-Object System.Drawing.Size(100, 32)
    $btnDuplicates.BackColor = [System.Drawing.Color]::FromArgb(160, 80, 220)
    $btnDuplicates.ForeColor = [System.Drawing.Color]::White
    $btnDuplicates.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnDuplicates.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnDuplicates.Cursor = [System.Windows.Forms.Cursors]::Hand
    $topPanel.Controls.Add($btnDuplicates)
    
    $btnLarge = New-Object System.Windows.Forms.Button
    $btnLarge.Text = "📦 File Grandi"
    $btnLarge.Location = New-Object System.Drawing.Point(550, 80)
    $btnLarge.Size = New-Object System.Drawing.Size(100, 32)
    $btnLarge.BackColor = [System.Drawing.Color]::FromArgb(240, 180, 40)
    $btnLarge.ForeColor = [System.Drawing.Color]::White
    $btnLarge.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnLarge.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnLarge.Cursor = [System.Windows.Forms.Cursors]::Hand
    $topPanel.Controls.Add($btnLarge)
    
    # Pannello risultati
    $resultPanel = New-Object System.Windows.Forms.Panel
    $resultPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $resultPanel.BackColor = [System.Drawing.Color]::FromArgb(14, 14, 18)
    $mainPanel.Controls.Add($resultPanel, 0, 1)
    
    $dgvResults = New-Object System.Windows.Forms.DataGridView
    $dgvResults.Dock = [System.Windows.Forms.DockStyle]::Fill
    $dgvResults.BackgroundColor = [System.Drawing.Color]::FromArgb(14, 14, 18)
    $dgvResults.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $dgvResults.AllowUserToAddRows = $false
    $dgvResults.AllowUserToDeleteRows = $false
    $dgvResults.ReadOnly = $true
    $dgvResults.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $dgvResults.RowHeadersVisible = $false
    $dgvResults.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $dgvResults.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 24)
    $dgvResults.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 210)
    $dgvResults.DefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $dgvResults.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $dgvResults.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $dgvResults.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $dgvResults.GridColor = [System.Drawing.Color]::FromArgb(50, 50, 58)
    
	$colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
	$colName.Name = "Nome"; $colName.HeaderText = "Nome"; $colName.FillWeight = 30
	$dgvResults.Columns.Add($colName)

	$colPath = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
	$colPath.Name = "Percorso"; $colPath.HeaderText = "Percorso"; $colPath.FillWeight = 50
	$dgvResults.Columns.Add($colPath)

	$colSize = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
	$colSize.Name = "Dimensione"; $colSize.HeaderText = "Dimensione"; $colSize.FillWeight = 10
	$dgvResults.Columns.Add($colSize)

	$colDate = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
	$colDate.Name = "Modificato"; $colDate.HeaderText = "Modificato"; $colDate.FillWeight = 10
	$dgvResults.Columns.Add($colDate)
    $resultPanel.Controls.Add($dgvResults)
    
    # Barra inferiore
    $bottomPanel = New-Object System.Windows.Forms.Panel
    $bottomPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $bottomPanel.Height = 40
    $bottomPanel.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 34)
    $resultPanel.Controls.Add($bottomPanel)
    
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "Pronto"
    $lblStatus.Location = New-Object System.Drawing.Point(10, 10)
    $lblStatus.AutoSize = $true
    $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $bottomPanel.Controls.Add($lblStatus)
    
    $btnOpenFolder = New-Object System.Windows.Forms.Button
    $btnOpenFolder.Text = "📂 Apri Cartella"
    $btnOpenFolder.Location = New-Object System.Drawing.Point(650, 5)
    $btnOpenFolder.Size = New-Object System.Drawing.Size(110, 30)
    $btnOpenFolder.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $btnOpenFolder.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
    $btnOpenFolder.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnOpenFolder.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $btnOpenFolder.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnOpenFolder.Add_Click({
        if ($dgvResults.SelectedRows.Count -gt 0) {
            $path = $dgvResults.SelectedRows[0].Cells["Percorso"].Value
            if ($path -and (Test-Path $path)) {
                Start-Process "explorer.exe" -ArgumentList "/select,`"$path`""
            }
        }
    })
    $bottomPanel.Controls.Add($btnOpenFolder)
    
    $btnCopyPath = New-Object System.Windows.Forms.Button
    $btnCopyPath.Text = "📋 Copia Percorso"
    $btnCopyPath.Location = New-Object System.Drawing.Point(770, 5)
    $btnCopyPath.Size = New-Object System.Drawing.Size(110, 30)
    $btnCopyPath.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $btnCopyPath.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
    $btnCopyPath.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCopyPath.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $btnCopyPath.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnCopyPath.Add_Click({
        if ($dgvResults.SelectedRows.Count -gt 0) {
            $path = $dgvResults.SelectedRows[0].Cells["Percorso"].Value
            if ($path) {
                [System.Windows.Forms.Clipboard]::SetText($path)
                $lblStatus.Text = "✅ Percorso copiato!"
            }
        }
    })
    $bottomPanel.Controls.Add($btnCopyPath)
    
    # Funzioni di ricerca
    function Update-Results($results, $statusMsg) {
        $dgvResults.Rows.Clear()
        foreach ($item in $results) {
            $sizeStr = if ($item.Size -gt 1GB) { "$([Math]::Round($item.Size/1GB, 2)) GB" } 
                       elseif ($item.Size -gt 1MB) { "$([Math]::Round($item.Size/1MB, 2)) MB" }
                       else { "$([Math]::Round($item.Size/1KB, 2)) KB" }
            $dgvResults.Rows.Add($item.Name, $item.Path, $sizeStr, $item.Modified)
        }
        $lblStatus.Text = "$statusMsg - Trovati $($dgvResults.Rows.Count) risultati"
        $dgvResults.ClearSelection()
    }
    
    $btnSearch.Add_Click({
        $lblStatus.Text = "⏳ Ricerca in corso..."
        [System.Windows.Forms.Application]::DoEvents()
        
        $results = Search-Files -Path $txtPath.Text -Pattern $txtPattern.Text -Content $txtContent.Text -MaxResults ([int]$numMax.Value) -Recurse:$chkRecurse.Checked
        Update-Results $results "✅ Ricerca completata"
    })
    
    $btnDuplicates.Add_Click({
        $lblStatus.Text = "⏳ Ricerca duplicati in corso..."
        [System.Windows.Forms.Application]::DoEvents()
        
        $duplicates = Search-Duplicates -Path $txtPath.Text -Recurse:$chkRecurse.Checked -MaxResults ([int]$numMax.Value)
        $results = @()
        foreach ($group in $duplicates) {
            foreach ($file in $group) {
                $info = Get-Item $file -ErrorAction SilentlyContinue
                if ($info) {
                    $results += [PSCustomObject]@{
                        Name = $info.Name
                        Path = $file
                        Size = $info.Length
                        Modified = $info.LastWriteTime
                    }
                }
            }
        }
        Update-Results $results "🔁 Duplicati trovati"
    })
    
    $btnLarge.Add_Click({
        $lblStatus.Text = "⏳ Ricerca file grandi in corso..."
        [System.Windows.Forms.Application]::DoEvents()
        
        $results = Search-LargeFiles -Path $txtPath.Text -MinSizeMB 100 -MaxResults ([int]$numMax.Value) -Recurse:$chkRecurse.Checked
        Update-Results $results "📦 File grandi trovati"
    })
    
    $form.Add_KeyDown({
        if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $form.Close()
        }
        if ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::F) {
            $txtPattern.Focus()
            $txtPattern.SelectAll()
        }
    })
    
    $form.Add_Shown({
        $txtPattern.Focus()
        $txtPattern.SelectAll()
    })
    
    $form.ShowDialog()
    $form.Dispose()
}

# ============================================================
# FINE DEL MODULO - Le funzioni sono disponibili tramite dot-sourcing
# ============================================================