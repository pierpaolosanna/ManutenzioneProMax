# ============================================================
# MANUTENZIONE PRO MAX v3.1.0 - ARCHITETTURA MODULARE
# ============================================================
# Auto-install PS7 + Rilancio (silenzioso)
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshPath = $null
    $possiblePaths = @("$env:ProgramFiles\PowerShell\7\pwsh.exe", "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe")
    foreach ($pp in $possiblePaths) { if (Test-Path $pp) { $pwshPath = $pp; break } }
    if (-not $pwshPath) { try { $found = (Get-Command pwsh -ErrorAction Stop).Source; if ($found -and (Test-Path $found)) { $pwshPath = $found } } catch {} }
    if (-not $pwshPath) {
        try { $null = Get-Command winget -ErrorAction Stop; Start-Process "winget" -ArgumentList "install Microsoft.PowerShell --force --silent --accept-package-agreements --accept-source-agreements" -Wait -NoNewWindow; Start-Sleep -Seconds 3; foreach ($pp in $possiblePaths) { if (Test-Path $pp) { $pwshPath = $pp; break } }; if (-not $pwshPath) { try { $found = (Get-Command pwsh -ErrorAction Stop).Source; if ($found -and (Test-Path $found)) { $pwshPath = $found } } catch {} } } catch { }
    }
    if ($pwshPath -and (Test-Path $pwshPath)) {
        $scriptPath = $PSCommandPath; if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }; if (-not $scriptPath) { $scriptPath = $MyInvocation.ScriptName }
        if ($scriptPath -and (Test-Path $scriptPath)) { Start-Process $pwshPath -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs; exit }
    }
}

# ---- CARICA I MODULI ----
$scriptRoot = Split-Path -Parent $PSCommandPath
if (-not $scriptRoot) { $scriptRoot = $PWD.Path }

# Modulo Core (deve essere caricato per primo)
$corePath = Join-Path $scriptRoot "Modules\Core.psm1"
if (Test-Path $corePath) { Import-Module $corePath -Force -ErrorAction Stop -WarningAction SilentlyContinue } else { throw "Core.psm1 non trovato!" }
Write-Host "[OK] Caricato Core.psm1" -ForegroundColor Green

# Carica gli altri moduli
$modules = @("Upgrade", "Pulizia", "Rete", "Riparazione", "Sicurezza", "Diagnostica", "Sistema", "Dominio", "Backup", "Privacy", "Utility")
Write-Host "[...] Caricamento moduli secondari..." -ForegroundColor Yellow
foreach ($mod in $modules) {
    $modPath = Join-Path $scriptRoot "Modules\$mod.psm1"
    if (Test-Path $modPath) {
        try {
            Import-Module $modPath -Force -ErrorAction Stop -WarningAction SilentlyContinue
            Write-Host "[OK] Caricato $mod.psm1" -ForegroundColor Green
        } catch {
            Write-Host "[X] ERRORE caricamento $mod.psm1 : $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "[X] Dettaglio: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "[!] Modulo $mod.psm1 non trovato in $modPath" -ForegroundColor Yellow
    }
}
Write-Host "[OK] Caricati tutti i moduli" -ForegroundColor Green

# Carica AICHAT e Search (invariati)
$aiChatPath = Join-Path $scriptRoot "Modules\AICHAT.ps1"
if (Test-Path $aiChatPath) { . $aiChatPath; Write-Host "[OK] Caricato AICHAT.ps1" -ForegroundColor Green }
$searchPath = Join-Path $scriptRoot "Modules\Search.ps1"
if (Test-Path $searchPath) { . $searchPath; Write-Host "[OK] Caricato Search.ps1" -ForegroundColor Green }

# ---- VARIABILI GLOBALI ----
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$currUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Colori (esportati come globali per i moduli)
$global:bgColor = [System.Drawing.Color]::FromArgb(20, 20, 24)
$global:bgPanel = [System.Drawing.Color]::FromArgb(28, 28, 34)
$global:bgCard = [System.Drawing.Color]::FromArgb(36, 36, 42)
$global:fgColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
$global:fgDim = [System.Drawing.Color]::FromArgb(120, 120, 130)
$global:accentColor = [System.Drawing.Color]::FromArgb(56, 132, 244)
$global:successColor = [System.Drawing.Color]::FromArgb(50, 220, 1)
$global:warningColor = [System.Drawing.Color]::FromArgb(240, 180, 40)
$global:exitColor = [System.Drawing.Color]::FromArgb(220, 60, 60)
$global:infoColor = [System.Drawing.Color]::FromArgb(40, 170, 220)
$global:securityColor = [System.Drawing.Color]::FromArgb(220, 70, 70)
$global:repairColor = [System.Drawing.Color]::FromArgb(160, 80, 220)
$global:networkColor = [System.Drawing.Color]::FromArgb(40, 200, 200)
$global:cpuColor = [System.Drawing.Color]::FromArgb(140, 0, 240)
$global:remoteColor = [System.Drawing.Color]::FromArgb(255, 0, 50)
$global:maintColor = [System.Drawing.Color]::FromArgb(200, 140, 30)
$global:separatorColor = [System.Drawing.Color]::FromArgb(50, 50, 58)
$global:logBg = [System.Drawing.Color]::FromArgb(14, 14, 18)
$global:isAdmin = $isAdmin
$global:scriptRoot = $scriptRoot
$global:tempDir = [System.IO.Path]::GetTempPath()

$script:updateAvailable = $false
$script:pendingUpdates = $null
$script:uiTimer = $null
$tempDir = [System.IO.Path]::GetTempPath()
$logFile = Join-Path $tempDir "Manutenzione_PRO_MAX_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$isPwsh7 = ($PSVersionTable.PSVersion.Major -ge 7)

# ---- VARIABILI GLOBALI ----
$global:currentVersion = "3.1.0"   # aggiorna con la tua versione
$global:repoOwner = "pierpaolosanna"
$global:repoName = "ManutenzioneProMax"
$global:scriptFileName = "Manutenzione_PRO_MAX.ps1"
$global:versionFileName = "version.txt"
$global:githubRawUrl = "https://raw.githubusercontent.com/$($global:repoOwner)/$($global:repoName)/main/"

# Aggiungi anche queste per la funzione Restart-AsAdmin e per i moduli
$global:isAdmin = $isAdmin          # già calcolato prima
$global:isPwsh7 = ($PSVersionTable.PSVersion.Major -ge 7)
$global:isClosing = $false
# $global:form verrà assegnato in Build-GUI (dopo la creazione)

function Restart-AsAdmin {
    if ($global:isAdmin) { 
        Log "[i] Già amministratore!" 
        return 
    }
    try {
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
        if (-not $scriptPath) { $scriptPath = $MyInvocation.ScriptName }
        if ($scriptPath -and (Test-Path $scriptPath)) {
            $exe = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
            if (-not (Test-Path $exe)) { 
                $exe = if ($global:isPwsh7) { "pwsh.exe" } else { "powershell.exe" } 
            }
            Start-Process $exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
            $global:isClosing = $true
            $global:form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Salva lo script come .ps1 e rieseguilo.", "Info", "OK", "Information") | Out-Null
        }
    } catch { 
        if ($_.Exception.Message -notmatch "canceled|annullat|cancelled") { 
            Log "[X] $($_.Exception.Message)" 
        } 
    }
}

# ---------- BUILD-GUI ----------
function Build-GUI {
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2)
    $script:form = New-Object System.Windows.Forms.Form
    $script:form.Text = "Manutenzione PRO MAX v$($global:currentVersion) Peters"
    $script:form.Size = New-Object System.Drawing.Size(1050, 580)
    $script:form.MinimumSize = New-Object System.Drawing.Size(1050, 580)
    $script:form.StartPosition = "CenterScreen"
    $script:form.BackColor = $global:bgColor
    $script:form.ForeColor = $global:fgColor
    $script:form.FormBorderStyle = "Sizable"
    $script:form.MaximizeBox = $true
    $script:form.WindowState = "Maximized"
    $script:form.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 11)
    $script:form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $dbProp = $script:form.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]"Instance,NonPublic")
    if ($dbProp) { $dbProp.SetValue($script:form, $true) }

    # DEFINIZIONE CATEGORIE
    $categories = @{
        "Upgrade" = @{
            Color = [System.Drawing.Color]::FromArgb(0, 220, 255)
            Items = @(
                @{Text="🔑 Eleva Admin"; Action={Restart-AsAdmin}; Tooltip="Riavvia lo script con privilegi amministrativi."}
                @{Text="💾 Crea Ripristino"; Action={Do-RestorePoint}; Tooltip="Crea un punto di ripristino del sistema."}
                @{Text="🔄 Winget"; Action={Do-Winget}; Tooltip="Aggiorna tutti i programmi con Winget."}
                @{Text="📦 Store"; Action={Do-StoreUpdate}; Tooltip="Aggiorna le app del Microsoft Store."}
                @{Text="🔍 Cerca WU"; Action={Do-SearchWU}; Tooltip="Cerca aggiornamenti Windows."}
                @{Text="⬇️ Installa WU"; Action={Do-InstallWU}; Tooltip="Installa aggiornamenti Windows."}
                @{Text="🔧 Driver"; Action={Do-DriverUpdate}; Tooltip="Aggiorna driver via Windows Update."}
                @{Text="📦 Full Update Script"; Action={Do-FullUpdate -Force}; Tooltip="Aggiorna TUTTI i file del repository."}
                @{Text="▶️ UPGRADE TOTAL"; Action={Do-RunAll}; Tooltip="Esegue la sequenza completa di aggiornamento."}
            )
        }
        "Pulizia" = @{
            Color = [System.Drawing.Color]::FromArgb(255, 180, 100)
            Items = @(
                @{Text="🧹 Temp"; Action={Do-CleanTemp}; Tooltip="Pulisce le cartelle temporanee."}
                @{Text="💾 Disk Cleanup"; Action={Do-DiskCleanup}; Tooltip="Avvia lo strumento di pulizia disco."}
                @{Text="📝 Pulisci Log"; Action={Do-CleanLogs}; Tooltip="Pulisce file di log e dump."}
                @{Text="📊 Analisi Disco"; Action={Do-DiskAnalysis}; Tooltip="Analisi dettagliata spazio disco."}
            )
        }
        "Rete" = @{
            Color = [System.Drawing.Color]::FromArgb(255, 50, 200)
            Items = @(
                @{Text="🌐 Flush DNS"; Action={Do-FlushDNS}; Tooltip="Svuota la cache DNS."}
                @{Text="📶 Renew IP"; Action={Do-RenewIP}; Tooltip="Rinnova l'indirizzo IP."}
                @{Text="ℹ️ Info IP"; Action={Do-InfoIP}; Tooltip="Mostra info di rete."}
                @{Text="🔧 Winsock"; Action={Do-ResetWinsock}; Tooltip="Resetta lo stack Winsock."}
                @{Text="🔄 Reset Rete"; Action={Do-NetworkReset}; Tooltip="Reset completo stack di rete."}
                @{Text="🔑 Wi-Fi Pass"; Action={Do-WifiPasswords}; Tooltip="Visualizza password Wi-Fi salvate."}
                @{Text="📡 Ping Test"; Action={Do-SpeedTest}; Tooltip="Test di latenza verso server DNS."}
                @{Text="🚀 Speed Internet"; Action={Do-SpeedInternet}; Tooltip="Test velocità Cloudflare."}
                @{Text="📊 Speed Ookla"; Action={Do-SpeedOokla}; Tooltip="Test approfondito Ookla."}
                @{Text="🗺️ Traceroute"; Action={Do-Traceroute}; Tooltip="Traccia il percorso verso un IP/dominio."}
                @{Text="🔄 Cambia DNS"; Action={Do-ChangeDNS}; Tooltip="Modifica i server DNS."}
                @{Text="🔍 Whois"; Action={Do-Whois}; Tooltip="Informazioni su IP/dominio."}
                @{Text="🚫 Blacklist Check"; Action={Do-BlacklistCheck}; Tooltip="Verifica blacklist."}
                @{Text="📡 Scansione Rete Pro"; Action={
                    $retePath = Join-Path $scriptRoot "Modules\rete.ps1"
                    if (Test-Path $retePath) { Start-Process "pwsh.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$retePath`"" } else { Log "[X] rete.ps1 non trovato!" }
                }; Tooltip="Avvia lo strumento di scansione rete avanzato."}
            )
        }
        "Riparazione" = @{
            Color = [System.Drawing.Color]::FromArgb(210, 150, 255)
            Items = @(
                @{Text="🔨 SFC + DISM"; Action={Do-RepairSystem}; Tooltip="Esegue SFC /scannow e DISM."}
                @{Text="⏱️ Pt. Ripristino"; Action={Do-RestorePoint}; Tooltip="Crea un punto di ripristino (limite 24 ore)."}
            )
        }
        "Sicurezza" = @{
            Color = [System.Drawing.Color]::FromArgb(155, 120, 200)
            Items = @(
                @{Text="🛡️ Scan Defender"; Action={Do-SecurityScan}; Tooltip="Avvia scansione rapida con Defender."}
                @{Text="📋 Event Log"; Action={Do-EventLogErrors}; Tooltip="Mostra errori critici (7gg)."}
                @{Text="🏥 Health Check"; Action={Do-SystemHealth}; Tooltip="Verifica integrità del sistema."}
                @{Text="🚫 Blacklist Check"; Action={Do-BlacklistCheck}; Tooltip="Verifica blacklist IP/dominio."}
            )
        }
        "Diagnostica" = @{
            Color = [System.Drawing.Color]::FromArgb(80, 255, 200)
            Items = @(
                @{Text="💻 Info Sistema"; Action={Do-SystemInfo}; Tooltip="Informazioni hardware e OS."}
                @{Text="🔋 Batteria"; Action={Do-BatteryReport}; Tooltip="Report sulla salute della batteria."}
                @{Text="⏰ Uptime"; Action={Do-Uptime}; Tooltip="Tempo di attività del sistema."}
                @{Text="📈 Top Processi"; Action={Do-TopProcesses}; Tooltip="Processi che consumano più CPU."}
                @{Text="🚀 Startup"; Action={Do-StartupPrograms}; Tooltip="Programmi avviati all'avvio."}
                @{Text="💿 Spazio Disco"; Action={Do-DiskSpace}; Tooltip="Spazio occupato dalle cartelle principali."}
                @{Text="⚙️ Servizi"; Action={Do-ServiceStatus}; Tooltip="Stato dei servizi di sistema principali."}
            )
        }
        "Sistema" = @{
            Color = [System.Drawing.Color]::FromArgb(255, 220, 0)
            Items = @(
                @{Text="🎨 Ottimizza Visivi"; Action={Do-OptimizeVisual}; Tooltip="Ottimizza effetti visivi."}
                @{Text="⚡ Ottimizza Avvio"; Action={Do-BootOptimization}; Tooltip="Ottimizza servizi e avvio."}
                @{Text="🔓 CPU Unlock"; Action={Do-UnlockCPU}; Tooltip="Sblocca opzioni avanzate energia CPU."}
                @{Text="🖥️ TPM CPU RAM"; Action={Do-TpmCpuRamUnlock}; Tooltip="Rimuove limiti per Windows 11."}
                @{Text="🔄 Riavvia PC"; Action={$r=[System.Windows.Forms.MessageBox]::Show("Riavviare?","Conferma","YesNo","Warning");if($r -eq "Yes"){shutdown /r /t 5 /c "Riavvio"}}; Tooltip="Riavvia il sistema."}
            )
        }
        "Dominio" = @{
            Color = [System.Drawing.Color]::FromArgb(100, 200, 255)
            Items = @(
                @{Text="🏢 Info Dominio"; Action={Do-DomainInfo}; Tooltip="Info su dominio e PC."}
                @{Text="🖥️ Test DC"; Action={Do-DCTest}; Tooltip="Ping ai Domain Controller."}
                @{Text="🕐 Sincronizza Ora"; Action={Do-SyncTime}; Tooltip="Sincronizza orario con DC."}
                @{Text="🗑️ Flush Kerberos"; Action={Do-FlushKerberos}; Tooltip="Svuota cache ticket Kerberos."}
                @{Text="📋 Info GPO"; Action={Do-GPOInfo}; Tooltip="Mostra le GPO applicate."}
                @{Text="🔄 Reset Profilo"; Action={Do-ResetNetworkProfile}; Tooltip="Reimposta profilo di rete."}
                @{Text="🌐 Test DNS"; Action={Do-DNSTest}; Tooltip="Verifica risoluzione DNS dominio."}
                @{Text="📍 Info Sito AD"; Action={Do-ADSiteInfo}; Tooltip="Mostra sito AD corrente."}
                @{Text="🔗 Test LDAP"; Action={Do-LDAPTest}; Tooltip="Verifica connettività LDAP."}
                @{Text="🔑 Cambia Password"; Action={Do-DomainPassword}; Tooltip="Cambia password dominio."}
                @{Text="📅 Ultimo Login"; Action={Do-LastLogin}; Tooltip="Mostra ultimo login dominio."}
                @{Text="👥 Gruppi Utente"; Action={Do-GroupMembership}; Tooltip="Mostra gruppi dominio dell'utente."}
            )
        }
        "Backup" = @{
            Color = [System.Drawing.Color]::FromArgb(200, 255, 100)
            Items = @(
                @{Text="💾 Backup Files"; Action={Do-BackupFiles}; Tooltip="Backup .zip (esclude cartelle backup*)."}
                @{Text="📦 Backup Avanzato (7z)"; Action={Do-BackupAdvanced}; Tooltip="Backup 7-Zip massimo (esclude backup*)."}
                @{Text="💾 Crea Ripristino"; Action={Do-RestorePoint}; Tooltip="Crea un punto di ripristino."}
            )
        }
        "Privacy" = @{
            Color = [System.Drawing.Color]::FromArgb(255, 100, 0)
            Items = @(
                @{Text="🔒 Privacy Windows"; Action={Do-PrivacyWindows}; Tooltip="Disabilita telemetria Windows."}
                @{Text="📁 Privacy Office"; Action={Do-PrivacyOffice}; Tooltip="Disabilita telemetria Office."}
                @{Text="🌐 Privacy Edge"; Action={Do-PrivacyEdge}; Tooltip="Disabilita telemetria Edge."}
                @{Text="⏰ Privacy Task"; Action={Do-PrivacyTasks}; Tooltip="Disabilita attività telemetria."}
                @{Text="🚀 DISABILITA TUTTO"; Action={Do-PrivacyAll}; Tooltip="Esegue TUTTE le privacy in sequenza."}
            )
        }
        "Utility" = @{
            Color = [System.Drawing.Color]::FromArgb(155, 220, 0)
            Items = @(
                @{Text="⚙️ Riavvia su BIOS"; Action={Start-Process "shutdown.exe" -ArgumentList "/r /fw /f /t 0"}; Tooltip="Riavvia nel BIOS/UEFI."}
                @{Text="🔄 Riavvia PC"; Action={Start-Process "shutdown.exe" -ArgumentList "-r -t 00"}; Tooltip="Riavvia il computer."}
                @{Text="👤 Disconnetti Utente"; Action={Start-Process "shutdown.exe" -ArgumentList "/l"}; Tooltip="Disconnette l'utente."}
                @{Text="⏻ Arresta PC"; Action={Start-Process "shutdown.exe" -ArgumentList "-s -f -t 00"}; Tooltip="Spegne il computer."}
                @{Text="⏰ Shutdown Sched."; Action={Do-ScheduleShutdown}; Tooltip="Programma spegnimento forzato."}
                @{Text="❌ Rimuovi Shutdown"; Action={Do-RemoveShutdown}; Tooltip="Rimuove lo spegnimento programmato."}
                @{Text="💬 AI Chat"; Action={Show-AIChatDialog}; Tooltip="Apre AI Chat."}
                @{Text="🔍 Ricerca File"; Action={Show-SearchDialog}; Tooltip="Apre ricerca file."}
                @{Text="⏹️ Annulla"; Action={$script:cancelRequested=$true}; Tooltip="Annulla l'operazione in corso."}
                @{Text="🖥️ Assist. Remota"; Action={Do-RemoteAssist}; Tooltip="Avvia RustDesk."}
                @{Text="🌐 Assist. LAN"; Action={Do-VNCViewer}; Tooltip="Avvia TightVNC Viewer."}
                @{Text="🖥️ RDP LAN"; Action={Do-RDPManager}; Tooltip="Gestore sessioni RDP."}
            )
        }
    }

    # ---- HEADER (invariato) ----
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Dock = "Top"
    $headerPanel.BackColor = $global:bgPanel
    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
    $headerTable = New-Object System.Windows.Forms.TableLayoutPanel
    $headerTable.Dock = "Fill"
    $headerTable.ColumnCount = 2
    $headerTable.RowCount = 1
    $headerTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $headerTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $headerTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $headerTable.BackColor = $global:bgPanel
    $headerPanel.Controls.Add($headerTable)
    $titleContainer = New-Object System.Windows.Forms.FlowLayoutPanel
    $titleContainer.Dock = "Fill"
    $titleContainer.FlowDirection = "LeftToRight"
    $titleContainer.BackColor = $global:bgPanel
    $titleContainer.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
    $titleLabel = New-Object System.Windows.Forms.LinkLabel
    $titleLabel.Text = "⚡ MANUTENZIONE PRO MAX"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = $global:fgColor
    $titleLabel.AutoSize = $true
    $titleLabel.TextAlign = "MiddleLeft"
    $titleLabel.LinkColor = $global:fgColor
    $titleLabel.ActiveLinkColor = $global:accentColor
    $titleLabel.VisitedLinkColor = $global:fgDim
    $titleLabel.LinkBehavior = "AlwaysUnderline"
    $titleLabel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $titleLabel.Add_LinkClicked({ param($sender, $e) Start-Process "https://github.com/pierpaolosanna/ManutenzioneProMax/archive/refs/heads/main.zip" })
    $titleContainer.Controls.Add($titleLabel)
    $adminBadge = New-Object System.Windows.Forms.Label
    $adminBadge.Font = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
    $adminBadge.AutoSize = $true
    $adminBadge.Margin = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
    if ($isAdmin) { $adminBadge.Text = "ADMIN"; $adminBadge.ForeColor = $global:successColor } else { $adminBadge.Text = "UTENTE"; $adminBadge.ForeColor = $global:warningColor }
    $titleContainer.Controls.Add($adminBadge)
    $psVer = "PS$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
    $verLabel = New-Object System.Windows.Forms.Label
    $verLabel.Text = "v$($global:currentVersion) | $psVer"
    $verLabel.Font = New-Object System.Drawing.Font("Segoe UI", 7)
    $verLabel.ForeColor = $global:fgDim
    $verLabel.AutoSize = $true
    $verLabel.TextAlign = "MiddleLeft"
    $verLabel.Margin = New-Object System.Windows.Forms.Padding(15, 0, 0, 0)
    $titleContainer.Controls.Add($verLabel)
    $headerTable.Controls.Add($titleContainer, 0, 0)

    # ---- CATEGORIE (invariato) ----
    $categoryGrid = New-Object System.Windows.Forms.TableLayoutPanel
    $categoryGrid.Dock = "Fill"
    $categoryGrid.RowCount = 2
    $categoryGrid.ColumnCount = 0
    $categoryGrid.BackColor = $global:bgPanel
    $categoryGrid.Padding = New-Object System.Windows.Forms.Padding(4, 2, 4, 2)
    $categoryGrid.AutoSize = $false
    $categoryGrid.GrowStyle = "AddColumns"
    $categoryGrid.RowStyles.Clear()
    $categoryGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $categoryGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $headerTable.Controls.Add($categoryGrid, 1, 0)
    $script:selectedCategory = $null
    $categoryButtons = @{}
    $catList = $categories.Keys | Sort-Object
    $numCols = [Math]::Ceiling($catList.Count / 2)
    $colWidth = 155
    $catIcons = @{ "Upgrade" = "⬆️"; "Pulizia" = "🧹"; "Rete" = "🌐"; "Riparazione" = "🔧"; "Sicurezza" = "🛡️"; "Diagnostica" = "📊"; "Sistema" = "⚙️"; "Dominio" = "🏢"; "Backup" = "💾"; "Privacy" = "🔒"; "Utility" = "🧰" }
    for ($col = 0; $col -lt $numCols; $col++) {
        $categoryGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, $colWidth)))
        for ($row = 0; $row -lt 2; $row++) {
            $idx = $row * $numCols + $col
            if ($idx -ge $catList.Count) { break }
            $catName = $catList[$idx]
            $catColor = $categories[$catName].Color
            $btn = New-Object System.Windows.Forms.Button
            $btn.Text = "$($catIcons[$catName]) $catName"
            $btn.FlatStyle = "Flat"
            $btn.FlatAppearance.BorderSize = 2
            $btn.FlatAppearance.BorderColor = $catColor
            $btn.BackColor = $global:bgCard
            $btn.ForeColor = [System.Drawing.Color]::White
            $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(60, 60, 80)
            $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(80, 80, 100)
            $btn.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 8, [System.Drawing.FontStyle]::Bold)
            $btn.AutoSize = $false
            $btn.Width = $colWidth - 8
            $btn.Height = 30
            $btn.Margin = New-Object System.Windows.Forms.Padding(4, 2, 4, 2)
            $btn.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
            $btn.TextAlign = "MiddleLeft"
            $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
            $btn.Tag = $catName
            $tooltip = New-Object System.Windows.Forms.ToolTip
            $tooltip.SetToolTip($btn, "Seleziona categoria: $catName")
            $btn.Add_Click({
                param($sender, $e)
                $script:selectedCategory = $sender.Tag
                $catColor = $categories[$sender.Tag].Color
                foreach ($b in $categoryButtons.Values) {
                    $b.BackColor = $global:bgCard
                    $b.ForeColor = [System.Drawing.Color]::White
                    $b.FlatAppearance.BorderColor = $categories[$b.Tag].Color
                }
                $sender.BackColor = $catColor
                $sender.FlatAppearance.BorderSize = 4
                $sender.ForeColor = [System.Drawing.Color]::White
                $sender.FlatAppearance.BorderColor = $catColor
                Update-Buttons
            })
            $categoryGrid.Controls.Add($btn, $col, $row)
            $categoryButtons[$catName] = $btn
        }
    }
    $defaultCat = "Upgrade"
    if ($categoryButtons.ContainsKey($defaultCat)) {
        $script:selectedCategory = $defaultCat
        $catColor = $categories[$defaultCat].Color
        $categoryButtons[$defaultCat].BackColor = $catColor
        $categoryButtons[$defaultCat].ForeColor = [System.Drawing.Color]::White
        $categoryButtons[$defaultCat].FlatAppearance.BorderColor = $catColor
    }
    $headerPanel.Height = 40 + 2 * 22
    $script:form.Controls.Add($headerPanel)

    # ---- SEPARATORE ----
    $separator = New-Object System.Windows.Forms.Panel
    $separator.Dock = "Top"
    $separator.Height = 2
    $separator.BackColor = $global:separatorColor
    $script:form.Controls.Add($separator)

    # ---- PANNELLO PRINCIPALE ----
    $mainPanel = New-Object System.Windows.Forms.Panel
    $mainPanel.Dock = "Fill"
    $mainPanel.BackColor = $global:bgColor
    $mainPanel.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
    $script:form.Controls.Add($mainPanel)
    $tableLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $tableLayout.Dock = "Fill"
    $tableLayout.ColumnCount = 2
    $tableLayout.RowCount = 1
    $tableLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 15)))
    $tableLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 85)))
    $tableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $tableLayout.BackColor = $global:bgColor
    $mainPanel.Controls.Add($tableLayout)

    # ---- BOTTONI ----
    $buttonGrid = New-Object System.Windows.Forms.TableLayoutPanel
    $buttonGrid.Dock = "Fill"
    $buttonGrid.ColumnCount = 1
    $buttonGrid.RowCount = 0
    $buttonGrid.AutoScroll = $true
    $buttonGrid.BackColor = $global:bgPanel
    $buttonGrid.Padding = New-Object System.Windows.Forms.Padding(6, 120, 6, 6)
    $tableLayout.Controls.Add($buttonGrid, 0, 0)

    # ---- LOG ----
    $logPanel = New-Object System.Windows.Forms.Panel
    $logPanel.Dock = "Fill"
    $logPanel.BackColor = $global:bgColor
    $logPanel.Padding = New-Object System.Windows.Forms.Padding(15, 5, 15, 5)
    $tableLayout.Controls.Add($logPanel, 1, 0)
    $logBoxPanel = New-Object System.Windows.Forms.Panel
    $logBoxPanel.Dock = "Fill"
    $logBoxPanel.BackColor = $global:logBg
    $logBoxPanel.Padding = New-Object System.Windows.Forms.Padding(2, 25, 2, 2)
    $logBoxPanel.BorderStyle = "FixedSingle"
    $logPanel.Controls.Add($logBoxPanel)
    $script:logBox = New-Object System.Windows.Forms.RichTextBox
    $script:logBox.Dock = "Fill"
    $script:logBox.BackColor = $global:logBg
    $script:logBox.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 210)
    $script:logBox.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Regular)
    $script:logBox.ReadOnly = $true
    $script:logBox.BorderStyle = "None"
    $script:logBox.ScrollBars = "ForcedVertical"
    $script:logBox.WordWrap = $false
    $script:logBox.DetectUrls = $false
    $script:logBox.ShortcutsEnabled = $true
    $logBoxPanel.Controls.Add($script:logBox)

    # ---- STATUS ----
    $statusPanel = New-Object System.Windows.Forms.Panel
    $statusPanel.Dock = "Bottom"
    $statusPanel.Height = 58
    $statusPanel.BackColor = $global:bgPanel
    $statusPanel.Padding = New-Object System.Windows.Forms.Padding(5, 2, 5, 2)
    $statusPanel.BorderStyle = "FixedSingle"
    $script:statusLabel = New-Object System.Windows.Forms.Label
    $script:statusLabel.Text = "🛡️ Pronto"
    $script:statusLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8)
    $script:statusLabel.ForeColor = $global:fgDim
    $script:statusLabel.Location = New-Object System.Drawing.Point(8, 1)
    $script:statusLabel.Size = New-Object System.Drawing.Size(250, 16)
    $statusPanel.Controls.Add($script:statusLabel)
    $script:progressLabel = New-Object System.Windows.Forms.Label
    $script:progressLabel.Text = "0%"
    $script:progressLabel.Font = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
    $script:progressLabel.ForeColor = $global:accentColor
    $script:progressLabel.Location = New-Object System.Drawing.Point(270, 1)
    $script:progressLabel.Size = New-Object System.Drawing.Size(40, 16)
    $script:progressLabel.TextAlign = "MiddleLeft"
    $statusPanel.Controls.Add($script:progressLabel)
    $script:progressBar = New-Object System.Windows.Forms.ProgressBar
    $script:progressBar.Location = New-Object System.Drawing.Point(8, 22)
    $script:progressBar.Size = New-Object System.Drawing.Size(1020, 20)
    $script:progressBar.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $script:progressBar.Style = "Continuous"
    $script:progressBar.Value = 0
    $script:progressBar.Minimum = 0
    $script:progressBar.Maximum = 100
    $script:progressBar.ForeColor = $global:accentColor
    $script:progressBar.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 48)
    $statusPanel.Controls.Add($script:progressBar)
    $statusPanel.Add_Resize({ $script:progressBar.Width = $statusPanel.Width - 16 })
    $mainPanel.Controls.Add($statusPanel)

    # ---- INIZIALIZZA CORE UI ----
    Set-CoreUI -LogBox $script:logBox -ProgressBar $script:progressBar -ProgressLabel $script:progressLabel -StatusLabel $script:statusLabel -Form $script:form -LogFile $logFile
	# Rendi disponibili le variabili UI a tutti i moduli
		$global:logBox = $script:logBox
		$global:progressBar = $script:progressBar
		$global:progressLabel = $script:progressLabel
		$global:statusLabel = $script:statusLabel
		$global:form = $script:form

    # ---- FUNZIONE UPDATE-BUTTONS ----
    function Update-Buttons {
        $buttonGrid.Controls.Clear()
        $buttonGrid.RowCount = 0
        if ([string]::IsNullOrEmpty($script:selectedCategory)) { return }
        if (-not $categories.ContainsKey($script:selectedCategory)) { return }
        $catData = $categories[$script:selectedCategory]
        $categoryColor = $catData.Color
        $items = $catData.Items
        $rowIndex = 0
        foreach ($btnData in $items) {
            $btn = New-Object System.Windows.Forms.Button
            $btn.Text = $btnData.Text
            $btn.FlatStyle = "Flat"
            $btn.FlatAppearance.BorderSize = 3
            $btn.FlatAppearance.BorderColor = $categoryColor
            $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(80, 80, 100)
            $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(100, 100, 120)
            $btn.BackColor = $global:bgCard
            $btn.ForeColor = [System.Drawing.Color]::White
            $btn.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 9, [System.Drawing.FontStyle]::Bold)
            if ($btnData.Text -match "Eleva Admin") {
                $btn.BackColor = [System.Drawing.Color]::FromArgb(0, 160, 0)
                $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::Lime
                $btn.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 10, [System.Drawing.FontStyle]::Bold)
                $btn.ForeColor = [System.Drawing.Color]::White
            }
            $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
            $btn.TextAlign = "MiddleLeft"
            $btn.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
            $btn.Height = 34
            $btn.Margin = New-Object System.Windows.Forms.Padding(5, 4, 5, 4)
            $btn.Dock = [System.Windows.Forms.DockStyle]::Fill
            $btn.Add_Click($btnData.Action)
            if ($btnData.Tooltip) { $tt = New-Object System.Windows.Forms.ToolTip; $tt.SetToolTip($btn, $btnData.Tooltip) }
            $buttonGrid.RowCount++
            $buttonGrid.Controls.Add($btn, 0, $rowIndex)
            $buttonGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
            $rowIndex++
        }
        $buttonGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    }

    Update-Buttons

    # ---- TIMER ----
    $script:uiTimer = New-Object System.Windows.Forms.Timer
    $script:uiTimer.Interval = 100
    $script:uiTimer.Add_Tick({ Flush-LogBuffer })
    $script:uiTimer.Start()

    # ---- EVENTI FORM ----
    $script:form.Add_Shown({
        Log "  Manutenzione PRO MAX v$($global:currentVersion) Peters"
        Log " $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $psVer"
        Log " Log: $logFile"
        Log ""; Flush-LogBuffer
        $script:logBox.SuspendLayout()
        $script:logBox.SelectionStart = $script:logBox.TextLength
        $script:logBox.SelectionLength = 0
        $script:logBox.SelectionColor = $global:successColor
        $script:logBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
        if ($isAdmin) {
            $msg = " Sei già amministratore. Tutte le funzionalità sono disponibili.`nCrea sempre un punto di ripristino con Crea Ripristino prima di ogni modifica."
        } else {
            $msg = "🔧 Esegui 'Eleva Admin' per ottenere le complete potenzialità.`nCrea sempre un punto di ripristino con Crea Ripristino prima di ogni modifica."
        }
        $script:logBox.AppendText("`r`n$msg`r`n")
        $script:logBox.SelectionColor = $script:logBox.ForeColor
        $script:logBox.ResumeLayout()
        $script:logBox.ScrollToCaret()
    })
    $script:form.Add_FormClosing({
        $script:isClosing = $true
        $script:cancelRequested = $true
        Stop-ProgressPulse
        if ($script:uiTimer) { $script:uiTimer.Stop(); $script:uiTimer.Dispose() }
    })
    $script:form.Add_Shown({
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        try {
            $remoteVersionUrl = $global:githubRawUrl + $global:versionFileName
            $remoteVersion = (Invoke-WebRequest -Uri $remoteVersionUrl -UseBasicParsing -TimeoutSec 20).Content.Trim()
            if ($remoteVersion -ne $global:currentVersion) {
                Log "[!] Nuova versione disponibile: $remoteVersion (locale: $($global:currentVersion))"
                $response = [System.Windows.Forms.MessageBox]::Show("Versione $remoteVersion disponibile (hai la $($global:currentVersion)).`nEseguire Full Update?", "Aggiornamento Disponibile", "YesNo", "Question")
                if ($response -eq "Yes") { Do-FullUpdate }
            } else {
                Log "[OK] Script aggiornato da PeterS (v$($global:currentVersion))"
            }
        } catch {
            Log "[!] Impossibile verificare aggiornamenti: $($_.Exception.Message)"
        }
        Flush-LogBuffer; Pump-UI
    })

    [System.Windows.Forms.Application]::Run($script:form)
}

# ============================================================
# AVVIO
# ============================================================
Build-GUI
