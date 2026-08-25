# ==========================================================
# Startup Manager UNIFIED v3.0 - Completo e Corretto
# Supporto: Registry + Cartella Startup + UWP + Task + Servizi
# UWP tramite AppModel (Teams, Copilot, Terminal, ecc.)
# ==========================================================

#requires -Version 5.1
#requires -RunAsAdministrator

[CmdletBinding()]
param()

# ==============================================================================
# CONFIGURAZIONE GLOBALE
# ==============================================================================
 $ErrorActionPreference = "SilentlyContinue"
 $ProgressPreference = "SilentlyContinue"

 $script:ConfigPath = Join-Path $env:APPDATA "StartupManagerPro"
 $script:BackupPath = Join-Path $script:ConfigPath "Backups"
 $script:LogPath = Join-Path $script:ConfigPath "Logs"
 $script:DisabledDBPath = Join-Path $script:ConfigPath "disabled_items.json"

foreach ($dir in @($script:ConfigPath, $script:BackupPath, $script:LogPath)) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

 $script:CurrentLogFile = Join-Path $script:LogPath "startup_$(Get-Date -Format 'yyyyMMdd').log"
 $script:CurrentMode = "ESSENTIAL"

# ==============================================================================
# LOGGING
# ==============================================================================
function Write-SMLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $logLine = "[$timestamp] [$Level] [$($script:CurrentMode)] $Message"
    try {
        Add-Content -Path $script:CurrentLogFile -Value $logLine -Encoding UTF8
    } catch {}
}

# ==============================================================================
# DATABASE BACKUP
# ==============================================================================
 $script:DisabledItemsDB = @{}

function Initialize-DisabledDB {
    if (Test-Path $script:DisabledDBPath) {
        try {
            $json = Get-Content -Path $script:DisabledDBPath -Raw -Encoding UTF8
            $script:DisabledItemsDB = $json | ConvertFrom-Json -AsHashtable
        } catch {}
    }
}

function Save-DisabledDB {
    try {
        $script:DisabledItemsDB | ConvertTo-Json -Depth 10 | Out-File -Path $script:DisabledDBPath -Encoding UTF8
    } catch {}
}

function Add-ToDisabledDB {
    param([string]$Source, [string]$Key, [hashtable]$OriginalData)
    $id = "$($Source):$($Key)"
    $script:DisabledItemsDB[$id] = @{
        Source = $Source
        Key = $Key
        OriginalData = $OriginalData
        DisabledAt = (Get-Date).ToString("o")
    }
    Save-DisabledDB
}

function Remove-FromDisabledDB {
    param([string]$Source, [string]$Key)
    $id = "$($Source):$($Key)"
    if ($script:DisabledItemsDB.ContainsKey($id)) {
        $script:DisabledItemsDB.Remove($id)
        Save-DisabledDB
        return $true
    }
    return $false
}

Initialize-DisabledDB

# ==============================================================================
# ASSEMBLY
# ==============================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ==============================================================================
# SELETTORE MODALITA INIZIALE
# ==============================================================================
 $selectorForm = New-Object System.Windows.Forms.Form
 $selectorForm.Text = "Startup Manager - Selezione Modalita"
 $selectorForm.Size = New-Object System.Drawing.Size(500, 320)
 $selectorForm.StartPosition = "CenterScreen"
 $selectorForm.FormBorderStyle = "FixedDialog"
 $selectorForm.MaximizeBox = $false
 $selectorForm.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
 $selectorForm.Font = New-Object System.Drawing.Font("Segoe UI", 10)
 $selectorForm.Icon = [System.Drawing.SystemIcons]::Shield

 $selTitle = New-Object System.Windows.Forms.Label
 $selTitle.Text = "SCEGLI LA MODALITA"
 $selTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
 $selTitle.ForeColor = [System.Drawing.Color]::White
 $selTitle.Size = New-Object System.Drawing.Size(480, 35)
 $selTitle.Location = New-Object System.Drawing.Point(10, 15)
 $selTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
 $selectorForm.Controls.Add($selTitle)

 $selDesc = New-Object System.Windows.Forms.Label
 $selDesc.Text = "Seleziona la modalita di visualizzazione:"
 $selDesc.ForeColor = [System.Drawing.Color]::LightGray
 $selDesc.Size = New-Object System.Drawing.Size(480, 20)
 $selDesc.Location = New-Object System.Drawing.Point(10, 55)
 $selDesc.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
 $selectorForm.Controls.Add($selDesc)

 $btnEssential = New-Object System.Windows.Forms.Button
 $btnEssential.Text = "ESSENTIAL`n`nSolo elementi essenziali`nRegistry + Cartella Startup + UWP`nInterfaccia pulita"
 $btnEssential.Size = New-Object System.Drawing.Size(220, 130)
 $btnEssential.Location = New-Object System.Drawing.Point(15, 85)
 $btnEssential.BackColor = [System.Drawing.Color]::FromArgb(46, 125, 50)
 $btnEssential.ForeColor = [System.Drawing.Color]::White
 $btnEssential.FlatStyle = "Flat"
 $btnEssential.Font = New-Object System.Drawing.Font("Segoe UI", 9)
 $selectorForm.Controls.Add($btnEssential)

 $btnPro = New-Object System.Windows.Forms.Button
 $btnPro.Text = "PRO`n`nTUTTI gli elementi`nRegistry + Task + Servizi + UWP`nInterfaccia completa"
 $btnPro.Size = New-Object System.Drawing.Size(220, 130)
 $btnPro.Location = New-Object System.Drawing.Point(250, 85)
 $btnPro.BackColor = [System.Drawing.Color]::FromArgb(25, 118, 210)
 $btnPro.ForeColor = [System.Drawing.Color]::White
 $btnPro.FlatStyle = "Flat"
 $btnPro.Font = New-Object System.Drawing.Font("Segoe UI", 9)
 $selectorForm.Controls.Add($btnPro)

 $selNote = New-Object System.Windows.Forms.Label
 $selNote.Text = "Puoi cambiare modalita con il pulsante [SWITCH]"
 $selNote.ForeColor = [System.Drawing.Color]::Gray
 $selNote.Size = New-Object System.Drawing.Size(480, 20)
 $selNote.Location = New-Object System.Drawing.Point(10, 230)
 $selNote.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
 $selectorForm.Controls.Add($selNote)

 $script:ModeSelected = $false

 $btnEssential.Add_Click({
    $script:CurrentMode = "ESSENTIAL"
    $script:ModeSelected = $true
    $selectorForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $selectorForm.Close()
})

 $btnPro.Add_Click({
    $script:CurrentMode = "PRO"
    $script:ModeSelected = $true
    $selectorForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $selectorForm.Close()
})

 $selectorForm.Add_FormClosing({
    if (-not $script:ModeSelected) {
        $selectorForm.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    }
})

 $result = $selectorForm.ShowDialog()
if ($result -ne "OK") { exit 0 }

Write-SMLog "========================================" "INFO"
Write-SMLog "Startup Manager avviato in modalita: $($script:CurrentMode)" "INFO"
Write-SMLog "Utente: $env:USERNAME | Computer: $env:COMPUTERNAME" "INFO"
Write-SMLog "========================================" "INFO"

# ==============================================================================
# RACCOLTA DATI
# ==============================================================================
 $script:AllStartupItems = [System.Collections.Generic.List[PSCustomObject]]::new()

function Get-StartupStatusFromApproved {
    param([string]$Name, [string]$Location)
    $approvedKey = $null
    if ($Location -match "^HKCU") {
        $approvedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
    } elseif ($Location -match "^HKLM") {
        $approvedKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
    } elseif ($Location -match "StartupFolder") {
        $approvedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"
    }
    if ($approvedKey -and (Test-Path $approvedKey)) {
        $item = Get-ItemProperty -Path $approvedKey -Name $Name -ErrorAction SilentlyContinue
        if ($item -and $item.$Name) {
            $bytes = $item.$Name
            if ($bytes.Length -ge 1) {
                if ($bytes[0] -eq 1 -or $bytes[0] -eq 3) { return "Disattivato" }
            }
        }
    }
    return "Attivo"
}

function Get-RegistryItems {
    Write-SMLog "Scansione registro..." "INFO"
    $paths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"
    )
    foreach ($regPath in $paths) {
        if (Test-Path $regPath) {
            try {
                $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
                foreach ($p in $props.PSObject.Properties) {
                    if ($p.Name -notmatch "PSPath|PSParentPath|PSChildName|PSDrive|PSProvider") {
                        $scope = "User"
                        if ($regPath -match "^HKLM") { $scope = "Machine" }
                        $status = Get-StartupStatusFromApproved -Name $p.Name -Location $regPath
                        $script:AllStartupItems.Add([PSCustomObject]@{
                            Name = $p.Name
                            Command = $p.Value
                            Location = $regPath
                            Scope = $scope
                            Type = "Registry"
                            Status = $status
                            PackageFamilyName = $null
                            TaskId = $null
                            RawData = @{ RegistryPath = $regPath; ValueName = $p.Name }
                        })
                    }
                }
            } catch {
                Write-SMLog "Errore $regPath" "WARN"
            }
        }
    }
}

function Get-StartupFolderItems {
    Write-SMLog "Scansione cartella Startup..." "INFO"
    $userFolder = [Environment]::GetFolderPath("Startup")
    $machineFolder = "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Startup"
    
    $folderList = @(
        @{ Path = $userFolder; Scope = "User" },
        @{ Path = $machineFolder; Scope = "Machine" }
    )
    
    foreach ($f in $folderList) {
        if (Test-Path $f.Path) {
            $lnkFiles = Get-ChildItem -Path $f.Path -Filter "*.lnk" -ErrorAction SilentlyContinue
            foreach ($file in $lnkFiles) {
                $status = Get-StartupStatusFromApproved -Name $file.BaseName -Location $f.Path
                $script:AllStartupItems.Add([PSCustomObject]@{
                    Name = $file.BaseName
                    Command = $file.FullName
                    Location = $f.Path
                    Scope = $f.Scope
                    Type = "Shortcut"
                    Status = $status
                    PackageFamilyName = $null
                    TaskId = $null
                    RawData = @{ FilePath = $file.FullName; Folder = $f.Path }
                })
            }
        }
    }
}

function Get-UWPItems {
    Write-SMLog "Scansione app UWP (AppModel)..." "INFO"
    $uwpCandidates = @(
        "MicrosoftTeams",
        "MSTeams",
        "Microsoft.WindowsTerminal",
        "Microsoft.Copilot",
        "Microsoft.Outlook",
        "Microsoft.SkypeApp",
        "Microsoft.OneDriveSync",
        "SpotifyAB.SpotifyMusic",
        "WhatsAppInc.WhatsAppDesktop"
    )
    
    foreach ($candidate in $uwpCandidates) {
        $app = Get-AppxPackage -Name "$candidate*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($app) {
            try {
                $manifest = Get-AppxPackageManifest -Package $app
                $extensions = $manifest.package.Applications.Application.Extensions.Extension
                foreach ($ext in $extensions) {
                    if ($ext.StartupTask) {
                        $taskId = $ext.StartupTask.TaskId
                        $regPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\$($app.PackageFamilyName)\$taskId"
                        $status = "Attivo"
                        if (Test-Path $regPath) {
                            $state = (Get-ItemProperty -Path $regPath -Name "State" -ErrorAction SilentlyContinue).State
                            if ($state -eq 1) { $status = "Disattivato" }
                        }
                        $script:AllStartupItems.Add([PSCustomObject]@{
                            Name = "$candidate (UWP)"
                            Command = "(App Store: $($app.Name))"
                            Location = "UWP AppModel"
                            Scope = "User"
                            Type = "UWP"
                            Status = $status
                            PackageFamilyName = $app.PackageFamilyName
                            TaskId = $taskId
                            RawData = @{ PackageFamilyName = $app.PackageFamilyName; TaskId = $taskId }
                        })
                        Write-SMLog "UWP trovato: $candidate - Stato: $status" "INFO"
                    }
                }
            } catch {
                Write-SMLog "Errore UWP $candidate" "WARN"
            }
        }
    }
}

function Get-TaskSchedulerItems {
    Write-SMLog "Scansione Task Scheduler..." "INFO"
    try {
        $scheduler = New-Object -ComObject Schedule.Service
        $scheduler.Connect($env:COMPUTERNAME)
        
        function Scan-Tasks {
            param($folder, $path = "\")
            try {
                $tasks = $folder.GetTasks(1)
                foreach ($task in $tasks) {
                    $hasStartupTrigger = $false
                    foreach ($trigger in $task.Triggers) {
                        if ($trigger.Type -eq 8 -or $trigger.Type -eq 9) {
                            $hasStartupTrigger = $true
                            break
                        }
                    }
                    if ($hasStartupTrigger) {
                        $taskPath = $task.Path
                        if (-not $taskPath) { $taskPath = "$path$($task.Name)" }
                        $cmd = "(impossibile leggere)"
                        try {
                            $action = $task.Definition.Actions.Item(1)
                            $cmd = "$($action.Path) $($action.Arguments)".Trim()
                        } catch {}
                        $script:AllStartupItems.Add([PSCustomObject]@{
                            Name = $task.Name
                            Command = $cmd
                            Location = "Task: $taskPath"
                            Scope = "Machine"
                            Type = "TaskScheduler"
                            Status = "Attivo"
                            PackageFamilyName = $null
                            TaskId = $null
                            RawData = @{ TaskPath = $taskPath; TaskName = $task.Name }
                        })
                        if (-not $task.Enabled) {
                            $script:AllStartupItems[-1].Status = "Disattivato"
                        }
                    }
                }
                $subFolders = $folder.GetFolders(0)
                foreach ($sub in $subFolders) {
                    Scan-Tasks -folder $sub -path "$path$($sub.Name)\"
                }
            } catch {}
        }
        
        Scan-Tasks -folder $scheduler.GetFolder("\")
    } catch {
        Write-SMLog "Errore Task Scheduler" "ERROR"
    }
}

function Get-ServiceItems {
    Write-SMLog "Scansione servizi..." "INFO"
    try {
        $services = Get-CimInstance -ClassName Win32_Service -ErrorAction SilentlyContinue | Where-Object {
            $_.StartMode -eq "Auto" -or $_.StartMode -eq "Delayed Auto"
        }
        
        foreach ($svc in $services) {
            if ($svc.Name -match "^(RPCSS|PlugPlay|Power|DcomLaunch)$") {
                continue
            }
            
            $cleanPath = $svc.PathName
            if ($cleanPath) {
                $cleanPath = $cleanPath -replace [char]34, ""
            } else {
                $cleanPath = "(percorso non disponibile)"
            }
            
            $itemStatus = "Attivo"
            if ($svc.StartMode -eq "Disabled") { $itemStatus = "Disattivato" }
            
            $script:AllStartupItems.Add([PSCustomObject]@{
                Name = $svc.DisplayName
                Command = $cleanPath
                Location = "Servizio: $($svc.Name)"
                Scope = "Machine"
                Type = "Service"
                Status = $itemStatus
                PackageFamilyName = $null
                TaskId = $null
                RawData = @{ ServiceName = $svc.Name; StartMode = $svc.StartMode }
            })
        }
    } catch {
        Write-SMLog "Errore servizi" "ERROR"
    }
}

function Get-AllStartupItems {
    $script:AllStartupItems.Clear()
    Get-RegistryItems
    Get-StartupFolderItems
    Get-UWPItems
    
    if ($script:CurrentMode -eq "PRO") {
        Get-TaskSchedulerItems
        Get-ServiceItems
    }
    
    Write-SMLog "TOTALE: $($script:AllStartupItems.Count) voci" "INFO"
    return $script:AllStartupItems
}

# ==============================================================================
# OPERAZIONI DI ATTIVAZIONE
# ==============================================================================
function Set-ClassicStartupState {
    param([string]$Name, [string]$Location, [bool]$Enabled)
    $approvedKey = $null
    if ($Location -match "^HKCU") {
        $approvedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
    } elseif ($Location -match "^HKLM") {
        $approvedKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
    } elseif ($Location -match "StartupFolder") {
        $approvedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder"
    }
    if (-not $approvedKey) { return $false }
    if (-not (Test-Path $approvedKey)) {
        New-Item -Path $approvedKey -Force | Out-Null
    }
    $timestamp = [BitConverter]::GetBytes([DateTime]::Now.ToFileTime())
    $stateByte = 0x02
    if (-not $Enabled) { $stateByte = 0x03 }
    $newValue = [byte[]]@($stateByte, 0, 0, 0) + $timestamp
    try {
        Set-ItemProperty -Path $approvedKey -Name $Name -Value $newValue -Type Binary -Force
        return $true
    } catch {
        return $false
    }
}

function Set-UWPStartupState {
    param([string]$PackageFamilyName, [string]$TaskId, [bool]$Enabled)
    $regPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\$PackageFamilyName\$TaskId"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    $stateValue = 2
    if (-not $Enabled) { $stateValue = 1 }
    try {
        Set-ItemProperty -Path $regPath -Name "State" -Value $stateValue -Type DWord -Force
        Set-ItemProperty -Path $regPath -Name "UserEnabledStartupOnce" -Value 1 -Type DWord -Force
        return $true
    } catch {
        return $false
    }
}

function Disable-StartupEntry {
    param([PSCustomObject]$Item)
    Write-SMLog "Disattivazione: $($Item.Name) ($($Item.Type))" "INFO"
    
    if ($Item.Type -eq "UWP") {
        return Set-UWPStartupState -PackageFamilyName $Item.PackageFamilyName -TaskId $Item.TaskId -Enabled $false
    }
    elseif ($Item.Type -eq "Shortcut") {
        if (Test-Path $Item.Command) {
            Rename-Item -Path $Item.Command -NewName "$($Item.Name).lnk.disabled" -Force
            return $true
        }
        return $false
    }
    elseif ($Item.Type -eq "TaskScheduler") {
        try {
            $scheduler = New-Object -ComObject Schedule.Service
            $scheduler.Connect($env:COMPUTERNAME)
            $taskPath = $Item.RawData.TaskPath
            $folderPath = Split-Path $taskPath -Parent
            $taskName = Split-Path $taskPath -Leaf
            if (-not $folderPath) { $folderPath = "\" }
            $task = $scheduler.GetFolder($folderPath).GetTask($taskName)
            if ($task) {
                $task.Enabled = $false
                $task.Save()
                return $true
            }
        } catch {}
        return $false
    }
    elseif ($Item.Type -eq "Service") {
        try {
            Set-Service -Name $Item.RawData.ServiceName -StartupType Disabled -ErrorAction Stop
            return $true
        } catch {}
        return $false
    }
    else {
        return Set-ClassicStartupState -Name $Item.Name -Location $Item.Location -Enabled $false
    }
}

function Enable-StartupEntry {
    param([PSCustomObject]$Item)
    Write-SMLog "Riattivazione: $($Item.Name) ($($Item.Type))" "INFO"
    
    if ($Item.Type -eq "UWP") {
        return Set-UWPStartupState -PackageFamilyName $Item.PackageFamilyName -TaskId $Item.TaskId -Enabled $true
    }
    elseif ($Item.Type -eq "Shortcut") {
        $disabledPath = "$($Item.Command).disabled"
        if (Test-Path $disabledPath) {
            Rename-Item -Path $disabledPath -NewName "$($Item.Name).lnk" -Force
            return $true
        }
        return $false
    }
    elseif ($Item.Type -eq "TaskScheduler") {
        try {
            $scheduler = New-Object -ComObject Schedule.Service
            $scheduler.Connect($env:COMPUTERNAME)
            $taskPath = $Item.RawData.TaskPath
            $folderPath = Split-Path $taskPath -Parent
            $taskName = Split-Path $taskPath -Leaf
            if (-not $folderPath) { $folderPath = "\" }
            $task = $scheduler.GetFolder($folderPath).GetTask($taskName)
            if ($task) {
                $task.Enabled = $true
                $task.Save()
                return $true
            }
        } catch {}
        return $false
    }
    elseif ($Item.Type -eq "Service") {
        try {
            Set-Service -Name $Item.RawData.ServiceName -StartupType Automatic -ErrorAction Stop
            return $true
        } catch {}
        return $false
    }
    else {
        return Set-ClassicStartupState -Name $Item.Name -Location $Item.Location -Enabled $true
    }
}

# ==============================================================================
# INTERFACCIA GRAFICA
# ==============================================================================
 $form = New-Object System.Windows.Forms.Form
 $modeText = "ESSENTIAL (Semplificata)"
if ($script:CurrentMode -eq "PRO") { $modeText = "PRO (Completa)" }
 $form.Text = "Startup Manager - Modalita: $modeText"
 $form.Size = New-Object System.Drawing.Size(1300, 750)
 $form.MinimumSize = New-Object System.Drawing.Size(900, 550)
 $form.StartPosition = "CenterScreen"
 $form.BackColor = [System.Drawing.Color]::FromArgb(34, 34, 34)
 $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
 $form.Icon = [System.Drawing.SystemIcons]::Shield

# Header
 $header = New-Object System.Windows.Forms.Panel
 $header.Dock = [System.Windows.Forms.DockStyle]::Top
 $header.Height = 50
 $header.BackColor = [System.Drawing.Color]::FromArgb(25, 118, 210)
 $form.Controls.Add($header)

 $headerTitle = New-Object System.Windows.Forms.Label
 $headerTitle.Text = "STARTUP MANAGER [$modeText]"
 $headerTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
 $headerTitle.ForeColor = [System.Drawing.Color]::White
 $headerTitle.Location = New-Object System.Drawing.Point(15, 12)
 $header.Controls.Add($headerTitle)

 $headerInfo = New-Object System.Windows.Forms.Label
 $infoText = "Registry + Startup + UWP"
if ($script:CurrentMode -eq "PRO") { $infoText = $infoText + " + Task Scheduler + Servizi" }
 $headerInfo.Text = $infoText
 $headerInfo.Font = New-Object System.Drawing.Font("Segoe UI", 9)
 $headerInfo.ForeColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
 $headerInfo.Dock = [System.Windows.Forms.DockStyle]::Right
 $headerInfo.Padding = New-Object System.Windows.Forms.Padding(0, 0, 15, 0)
 $headerInfo.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
 $headerInfo.Height = 50
 $header.Controls.Add($headerInfo)

# Layout principale
 $mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
 $mainLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
 $mainLayout.ColumnCount = 2
 $mainLayout.RowCount = 1
 $colStyle1 = New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)
 $colStyle2 = New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 260)
 $mainLayout.ColumnStyles.Add($colStyle1)
 $mainLayout.ColumnStyles.Add($colStyle2)
 $form.Controls.Add($mainLayout)

# Griglia
 $gridPanel = New-Object System.Windows.Forms.GroupBox
 $gridPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
 $gridPanel.Text = "Elenco programmi all'avvio"
 $gridPanel.ForeColor = [System.Drawing.Color]::White
 $gridPanel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
 $gridPanel.Padding = New-Object System.Windows.Forms.Padding(8, 18, 8, 8)
 $mainLayout.Controls.Add($gridPanel, 0, 0)

 $grid = New-Object System.Windows.Forms.DataGridView
 $grid.Dock = [System.Windows.Forms.DockStyle]::Fill
 $grid.BackgroundColor = [System.Drawing.Color]::White
 $grid.GridColor = [System.Drawing.Color]::Gray
 $grid.RowHeadersVisible = $false
 $grid.AllowUserToAddRows = $false
 $grid.SelectionMode = "FullRowSelect"
 $grid.MultiSelect = $true
 $grid.EnableHeadersVisualStyles = $false
 $grid.Font = New-Object System.Drawing.Font("Segoe UI", 9)
 $grid.AutoSizeColumnsMode = "Fill"
 $grid.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
 $grid.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
 $grid.RowTemplate.Height = 24
 $grid.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Black

# Colonne
 $colSel = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
 $colSel.HeaderText = ""
 $colSel.FillWeight = 5
 $grid.Columns.Add($colSel) | Out-Null

 $colName = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
 $colName.HeaderText = "Nome"
 $colName.Name = "Name"
 $colName.FillWeight = 25
 $colName.ReadOnly = $true
 $grid.Columns.Add($colName) | Out-Null

 $colCmd = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
 $colCmd.HeaderText = "Comando/Percorso"
 $colCmd.Name = "Command"
 $colCmd.FillWeight = 40
 $colCmd.ReadOnly = $true
 $grid.Columns.Add($colCmd) | Out-Null

 $colType = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
 $colType.HeaderText = "Tipo"
 $colType.Name = "Type"
 $colType.FillWeight = 10
 $colType.ReadOnly = $true
 $grid.Columns.Add($colType) | Out-Null

 $colScope = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
 $colScope.HeaderText = "Ambito"
 $colScope.Name = "Scope"
 $colScope.FillWeight = 8
 $colScope.ReadOnly = $true
 $grid.Columns.Add($colScope) | Out-Null

 $colStatus = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
 $colStatus.HeaderText = "Stato"
 $colStatus.Name = "Status"
 $colStatus.FillWeight = 10
 $colStatus.ReadOnly = $true
 $grid.Columns.Add($colStatus) | Out-Null

 $gridPanel.Controls.Add($grid)

# Pannello destro
 $rightPanel = New-Object System.Windows.Forms.Panel
 $rightPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
 $rightPanel.AutoScroll = $true
 $mainLayout.Controls.Add($rightPanel, 1, 0)

# Ricerca
 $lblSearch = New-Object System.Windows.Forms.Label
 $lblSearch.Text = "Ricerca:"
 $lblSearch.ForeColor = [System.Drawing.Color]::LightGray
 $lblSearch.Size = New-Object System.Drawing.Size(240, 18)
 $lblSearch.Location = New-Object System.Drawing.Point(5, 5)
 $rightPanel.Controls.Add($lblSearch)

 $txtSearch = New-Object System.Windows.Forms.TextBox
 $txtSearch.Size = New-Object System.Drawing.Size(240, 22)
 $txtSearch.Location = New-Object System.Drawing.Point(5, 23)
 $rightPanel.Controls.Add($txtSearch)

 $searchTimer = New-Object System.Windows.Forms.Timer
 $searchTimer.Interval = 400
 $searchTimer.Add_Tick({
    $searchTimer.Stop()
    Populate-Grid -search $txtSearch.Text
})

# Pulsante SWITCH
 $btnSwitch = New-Object System.Windows.Forms.Button
 $btnSwitch.Text = "[SWITCH] Cambia Modalita"
 $btnSwitch.Size = New-Object System.Drawing.Size(240, 30)
 $btnSwitch.Location = New-Object System.Drawing.Point(5, 55)
 $btnSwitch.BackColor = [System.Drawing.Color]::FromArgb(156, 39, 176)
 $btnSwitch.ForeColor = [System.Drawing.Color]::White
 $btnSwitch.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
 $rightPanel.Controls.Add($btnSwitch)

# Seleziona tutto
 $btnSelectAll = New-Object System.Windows.Forms.Button
 $btnSelectAll.Text = "Seleziona tutto"
 $btnSelectAll.Size = New-Object System.Drawing.Size(240, 24)
 $btnSelectAll.Location = New-Object System.Drawing.Point(5, 92)
 $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
 $btnSelectAll.ForeColor = [System.Drawing.Color]::White
 $rightPanel.Controls.Add($btnSelectAll)

# Deseleziona
 $btnClear = New-Object System.Windows.Forms.Button
 $btnClear.Text = "Deseleziona"
 $btnClear.Size = New-Object System.Drawing.Size(240, 24)
 $btnClear.Location = New-Object System.Drawing.Point(5, 120)
 $btnClear.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
 $btnClear.ForeColor = [System.Drawing.Color]::White
 $rightPanel.Controls.Add($btnClear)

# Disattiva
 $btnDisable = New-Object System.Windows.Forms.Button
 $btnDisable.Text = "Disattiva selezionati"
 $btnDisable.Size = New-Object System.Drawing.Size(240, 28)
 $btnDisable.Location = New-Object System.Drawing.Point(5, 155)
 $btnDisable.BackColor = [System.Drawing.Color]::FromArgb(198, 40, 40)
 $btnDisable.ForeColor = [System.Drawing.Color]::White
 $btnDisable.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
 $rightPanel.Controls.Add($btnDisable)

# Riattiva
 $btnEnable = New-Object System.Windows.Forms.Button
 $btnEnable.Text = "Riattiva selezionati"
 $btnEnable.Size = New-Object System.Drawing.Size(240, 28)
 $btnEnable.Location = New-Object System.Drawing.Point(5, 187)
 $btnEnable.BackColor = [System.Drawing.Color]::FromArgb(46, 125, 50)
 $btnEnable.ForeColor = [System.Drawing.Color]::White
 $btnEnable.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
 $rightPanel.Controls.Add($btnEnable)

# Aggiorna
 $btnRefresh = New-Object System.Windows.Forms.Button
 $btnRefresh.Text = "Aggiorna elenco"
 $btnRefresh.Size = New-Object System.Drawing.Size(240, 24)
 $btnRefresh.Location = New-Object System.Drawing.Point(5, 225)
 $btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(25, 118, 210)
 $btnRefresh.ForeColor = [System.Drawing.Color]::White
 $rightPanel.Controls.Add($btnRefresh)

# Esporta
 $btnExport = New-Object System.Windows.Forms.Button
 $btnExport.Text = "Esporta CSV"
 $btnExport.Size = New-Object System.Drawing.Size(240, 24)
 $btnExport.Location = New-Object System.Drawing.Point(5, 253)
 $btnExport.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
 $btnExport.ForeColor = [System.Drawing.Color]::White
 $rightPanel.Controls.Add($btnExport)

# Log
 $btnLog = New-Object System.Windows.Forms.Button
 $btnLog.Text = "Visualizza Log"
 $btnLog.Size = New-Object System.Drawing.Size(240, 24)
 $btnLog.Location = New-Object System.Drawing.Point(5, 281)
 $btnLog.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
 $btnLog.ForeColor = [System.Drawing.Color]::White
 $rightPanel.Controls.Add($btnLog)

# ==============================================================================
# FUNZIONI UI
# ==============================================================================
function Populate-Grid {
    param([string]$search = "")
    $grid.Rows.Clear()
    $global:AllStartupCommands = Get-AllStartupItems
    
    $filtered = $global:AllStartupCommands | Where-Object {
        $search -eq "" -or $_.Name -match [regex]::Escape($search)
    }
    
    foreach ($item in $filtered) {
        $idx = $grid.Rows.Add()
        $grid.Rows[$idx].Cells[0].Value = $false
        $grid.Rows[$idx].Cells[1].Value = $item.Name
        $grid.Rows[$idx].Cells[2].Value = $item.Command
        $grid.Rows[$idx].Cells[3].Value = $item.Type
        $grid.Rows[$idx].Cells[4].Value = $item.Scope
        $grid.Rows[$idx].Cells[5].Value = $item.Status
        
        if ($item.Status -eq "Attivo") {
            $grid.Rows[$idx].Cells[5].Style.ForeColor = [System.Drawing.Color]::Green
            $grid.Rows[$idx].Cells[5].Style.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        } else {
            $grid.Rows[$idx].Cells[5].Style.ForeColor = [System.Drawing.Color]::Red
            $grid.Rows[$idx].Cells[5].Style.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        }
        
        $typeColors = @{
            "Registry" = "Black"
            "Shortcut" = "DarkGreen"
            "UWP" = "DarkMagenta"
            "TaskScheduler" = "DarkOrange"
            "Service" = "DarkBlue"
        }
        if ($typeColors.ContainsKey($item.Type)) {
            $grid.Rows[$idx].Cells[3].Style.ForeColor = $typeColors[$item.Type]
            $grid.Rows[$idx].Cells[3].Style.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        }
        
        if ($idx % 2 -eq 0) {
            $grid.Rows[$idx].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
        } else {
            $grid.Rows[$idx].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
        }
    }
    
    $form.Text = "Startup Manager [$modeText] - $($filtered.Count) elementi"
    Write-SMLog "Griglia aggiornata: $($filtered.Count) elementi" "INFO"
}

function Switch-Mode {
    Write-SMLog "Cambio modalita da $($script:CurrentMode)" "INFO"
    
    $newMode = "ESSENTIAL"
    if ($script:CurrentMode -eq "ESSENTIAL") { $newMode = "PRO" }
    
    $msg = "Vuoi passare alla modalita $newMode?`n`n"
    $msg = $msg + "ESSENTIAL: Registry + Startup + UWP (Teams, Copilot)`n"
    $msg = $msg + "PRO: TUTTO (Task Scheduler + Servizi + ...)`n`n"
    $msg = $msg + "La griglia verra ricaricata."
    
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        $msg,
        "Cambia Modalita",
        "YesNo",
        "Question"
    )
    
    if ($confirm -eq "Yes") {
        $script:CurrentMode = $newMode
        $modeText = "ESSENTIAL (Semplificata)"
        if ($newMode -eq "PRO") { $modeText = "PRO (Completa)" }
        
        $headerTitle.Text = "STARTUP MANAGER [$modeText]"
        
        $infoText = "Registry + Startup + UWP"
        if ($newMode -eq "PRO") { $infoText = $infoText + " + Task Scheduler + Servizi" }
        $headerInfo.Text = $infoText
        
        $form.Text = "Startup Manager [$modeText]"
        
        Write-SMLog "Modalita cambiata a: $newMode" "INFO"
        Populate-Grid -search $txtSearch.Text
    }
}

# ==============================================================================
# EVENTI
# ==============================================================================
 $txtSearch.Add_TextChanged({
    $searchTimer.Stop()
    $searchTimer.Start()
})

 $btnSelectAll.Add_Click({
    for ($i = 0; $i -lt $grid.Rows.Count; $i++) {
        $grid.Rows[$i].Cells[0].Value = $true
    }
})

 $btnClear.Add_Click({
    for ($i = 0; $i -lt $grid.Rows.Count; $i++) {
        $grid.Rows[$i].Cells[0].Value = $false
    }
})

 $btnRefresh.Add_Click({
    Populate-Grid -search $txtSearch.Text
})

 $btnSwitch.Add_Click({
    Switch-Mode
})

 $grid.Add_CellDoubleClick({
    param($sender, $e)
    if ($e.RowIndex -ge 0) {
        $current = $grid.Rows[$e.RowIndex].Cells[0].Value
        $grid.Rows[$e.RowIndex].Cells[0].Value = -not $current
    }
})

 $btnDisable.Add_Click({
    $selected = @()
    for ($i = 0; $i -lt $grid.Rows.Count; $i++) {
        if ($grid.Rows[$i].Cells[0].Value -eq $true) {
            $name = $grid.Rows[$i].Cells[1].Value
            $found = $global:AllStartupCommands | Where-Object { $_.Name -eq $name } | Select-Object -First 1
            if ($found) { $selected += $found }
        }
    }
    
    if ($selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Seleziona almeno un elemento.", "Info", "OK", "Information")
        return
    }
    
    $confirm = [System.Windows.Forms.MessageBox]::Show("Disattivare $($selected.Count) elementi?", "Conferma", "YesNo", "Question")
    if ($confirm -ne "Yes") { return }
    
    $success = 0
    $fail = 0
    foreach ($item in $selected) {
        if (Disable-StartupEntry -Item $item) {
            $success++
        } else {
            $fail++
        }
    }
    
    Populate-Grid -search $txtSearch.Text
    [System.Windows.Forms.MessageBox]::Show("Disattivati: $success`nErrori: $fail", "Risultato", "OK", "Information")
})

 $btnEnable.Add_Click({
    $selected = @()
    for ($i = 0; $i -lt $grid.Rows.Count; $i++) {
        if ($grid.Rows[$i].Cells[0].Value -eq $true) {
            $name = $grid.Rows[$i].Cells[1].Value
            $found = $global:AllStartupCommands | Where-Object { $_.Name -eq $name } | Select-Object -First 1
            if ($found) { $selected += $found }
        }
    }
    
    if ($selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Seleziona almeno un elemento.", "Info", "OK", "Information")
        return
    }
    
    $success = 0
    $fail = 0
    foreach ($item in $selected) {
        if (Enable-StartupEntry -Item $item) {
            $success++
        } else {
            $fail++
        }
    }
    
    Populate-Grid -search $txtSearch.Text
    [System.Windows.Forms.MessageBox]::Show("Riattivati: $success`nErrori: $fail", "Risultato", "OK", "Information")
})

 $btnExport.Add_Click({
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $csvPath = Join-Path $env:USERPROFILE "startup_$timestamp.csv"
    $rows = @()
    for ($i = 0; $i -lt $grid.Rows.Count; $i++) {
        $rows += [PSCustomObject]@{
            Nome = $grid.Rows[$i].Cells[1].Value
            Comando = $grid.Rows[$i].Cells[2].Value
            Tipo = $grid.Rows[$i].Cells[3].Value
            Ambito = $grid.Rows[$i].Cells[4].Value
            Stato = $grid.Rows[$i].Cells[5].Value
        }
    }
    $rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    [System.Windows.Forms.MessageBox]::Show("Esportato: $csvPath", "CSV", "OK", "Information")
})

 $btnLog.Add_Click({
    if (Test-Path $script:CurrentLogFile) {
        Start-Process notepad.exe $script:CurrentLogFile
    } else {
        [System.Windows.Forms.MessageBox]::Show("Log non trovato.", "Info", "OK", "Information")
    }
})

# ==============================================================================
# AVVIO
# ==============================================================================
Populate-Grid
 $form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()