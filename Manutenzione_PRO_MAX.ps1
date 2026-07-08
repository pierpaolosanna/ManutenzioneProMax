# ============================================================
# BLOCCO 1 - VERSIONE E CONFIGURAZIONE REPO
# ============================================================
# Versione: 3.0.4
# Data: 2026-07-01
# Descrizione: Tool di manutenzione Windows con GUI dark e menu a tendina
#              Moduli: AICHAT.ps1, Search.ps1
# ============================================================

# ============================
# AUTO-INSTALL PS7 + RILANCIO (silenzioso)
# ============================
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwshPath = $null
    $possiblePaths = @("$env:ProgramFiles\PowerShell\7\pwsh.exe","${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe")
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

# ============================
# CARICAMENTO MODULI (Dot-Sourcing)
# ============================
$scriptRoot = Split-Path -Parent $PSCommandPath
if (-not $scriptRoot) { $scriptRoot = $PWD.Path }

# Carica AICHAT.ps1 se esiste
$aiChatPath = Join-Path $scriptRoot "AICHAT.ps1"
if (Test-Path $aiChatPath) {
    . $aiChatPath
    Write-Host "[OK] Caricato AICHAT.ps1" -ForegroundColor Green
} else {
    Write-Host "[WARN] AICHAT.ps1 non trovato. La chat AI non sarà disponibile." -ForegroundColor Yellow
}

# Carica Search.ps1 se esiste
$searchPath = Join-Path $scriptRoot "Search.ps1"
if (Test-Path $searchPath) {
    . $searchPath
    Write-Host "[OK] Caricato Search.ps1" -ForegroundColor Green
} else {
    Write-Host "[WARN] Search.ps1 non trovato. La ricerca non sarà disponibile." -ForegroundColor Yellow
}

# ============================
# AUTO-INSTALLA CERTIFICATO
# ============================
$script:certThumbprint = "1D51CF0E33DB5E1F124FE14CC49DBF4294F03F"
try {
    $installed = Get-ChildItem Cert:\LocalMachine\TrustedPublisher -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $script:certThumbprint }
    if (-not $installed) {
        $myDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
        $certFile = Join-Path $myDir "PetersIT.cer"
        if (-not (Test-Path $certFile)) { $scriptDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { $null }; if ($scriptDir) { $certFile = Join-Path $scriptDir "PetersIT.cer" } }
        if (Test-Path $certFile) { & certutil -addstore TrustedPublisher "$certFile" 2>$null | Out-Null; & certutil -addstore Root "$certFile" 2>$null | Out-Null }
    }
} catch { }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$currUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ============================================================
# BLOCCO 2 - UI COLORI E VARIABILI GLOBALI (MIGLIORATI)
# ============================================================
$bgColor = [System.Drawing.Color]::FromArgb(20, 20, 24)
$bgPanel = [System.Drawing.Color]::FromArgb(28, 28, 34)
$bgCard = [System.Drawing.Color]::FromArgb(36, 36, 42)
$fgColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
$fgDim = [System.Drawing.Color]::FromArgb(120, 120, 130)

# Colori categorie (con gradienti simulati)
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

$script:updateAvailable = $false
$script:logBox = $null
$script:progressBar = $null
$script:progressLabel = $null
$script:statusLabel = $null
$script:form = $null
$script:isClosing = $false
$script:cancelRequested = $false
$script:pendingUpdates = $null
$script:logBuffer = [System.Text.StringBuilder]::new()
$script:lastFlush = [DateTime]::Now
$script:uiTimer = $null
$tempDir = [System.IO.Path]::GetTempPath()
$logFile = Join-Path $tempDir "Manutenzione_PRO_MAX_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$isPwsh7 = ($PSVersionTable.PSVersion.Major -ge 7)
$script:pingProperty = if ($isPwsh7) { "Latency" } else { "ResponseTime" }

$script:currentVersion = "3.0.4"
$script:repoOwner = "pierpaolosanna"
$script:repoName = "ManutenzioneProMax"
$script:scriptFileName = "Manutenzione_PRO_MAX.ps1"
$script:versionFileName = "version.txt"
$script:githubRawUrl = "https://raw.githubusercontent.com/$($script:repoOwner)/$($script:repoName)/main/"

# ============================================================
# BLOCCO 3 - FUNZIONI UTILITY DI BASE (MIGLIORATE)
# ============================================================
function Restart-AsAdmin {
    if ($isAdmin) { Log "[i] Gia amministratore!"; return }
    try {
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }
        if (-not $scriptPath) { $scriptPath = $MyInvocation.ScriptName }
        if ($scriptPath -and (Test-Path $scriptPath)) {
            $exe = "$env:ProgramFiles\PowerShell\7\pwsh.exe"
            if (-not (Test-Path $exe)) { $exe = if ($isPwsh7) { "pwsh.exe" } else { "powershell.exe" } }
            Start-Process $exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
            $script:isClosing = $true
            $script:form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Salva lo script come .ps1 e rieseguilo.", "Info", "OK", "Information") | Out-Null
        }
    } catch {
        if ($_.Exception.Message -notmatch "canceled|annullat|cancelled") { Log "[X] $($_.Exception.Message)" }
    }
}

function Is-SpinnerLine($line) {
    if (-not $line) { return $false }
    $s = "$line".Trim()
    if (-not $s) { return $false }
    return ($s -match '^(?:[-\\|/])$' -or $s -match '^(?:[-\\|/]\s*)+$')
}

function Get-PercentFromLine($line) {
    if (-not $line) { return $null }
    $m = [regex]::Match("$line", '(?<!\d)(0|[1-9]?\d)%')
    if ($m.Success) { return [int]$m.Groups[1].Value }
    return $null
}

function Set-StepProgress($stepPercent, $stepStart, $stepEnd) {
    # Prevenzione NaN
    if ([double]::IsNaN($stepPercent)) { $stepPercent = 0 }
    if ([double]::IsNaN($stepStart)) { $stepStart = 0 }
    if ([double]::IsNaN($stepEnd)) { $stepEnd = 0 }

    # Corretto il limite massimo da 0 a 100
    $p = [Math]::Max(0, [Math]::Min($stepPercent, 100))
    $start = [Math]::Max(0, [Math]::Min($stepStart, 100))
    $end = [Math]::Max(0, [Math]::Min($stepEnd, 100))
    
    # Corretto il divisore da 0.0 a 100.0 per calcolare la percentuale corretta
    $overall = [Math]::Round($start + (($end - $start) * ($p / 100.0)))
    
    Update-Progress $overall
    if ($script:progressLabel) { $script:progressLabel.Text = "$p%" }
}

function Format-LogLine($line) {
    if (-not $line) { return $null }
    if (Is-SpinnerLine $line) { return $null }
    $s = "$line".TrimEnd()
    if (-not $s) { return $null }
    if ($s -match "ERRORE|ERROR|failed|fallito|denied|Impossibile|non riesce|Accesso negato") { return " [X] $s" }
    elseif ($s -match "WARNING|AVVISO|warning") { return " [!] $s" }
    elseif ($s -match "success|completato|done|OK|trovato|installato|aggiornato|completata") { return " [OK] $s" }
    elseif ($s -match "Download|Downloading|Scaricamento|Scarico") { return " [DL] $s" }
    elseif ($s -match "Install|Installing|Installazione|Aggiornamento|Updating") { return " [PKG] $s" }
    elseif ($s -match "Found|Trovato|Rilevato") { return " [>>] $s" }
    elseif ($s -match "(?<!\d)(0|[1-9]?\d)%") { return " [%] $s" }
    else { return " $s" }
}

function Flush-LogBuffer {
    if ($script:logBuffer.Length -gt 0 -and $script:logBox -and -not $script:isClosing) {
        $text = $script:logBuffer.ToString()
        $script:logBuffer.Clear()
        $script:logBox.SuspendLayout()
        $script:logBox.AppendText($text)
        $script:logBox.SelectionStart = $script:logBox.Text.Length
        $script:logBox.ScrollToCaret()
        $script:logBox.ResumeLayout()
        $script:lastFlush = [DateTime]::Now
    }
}

function Log($msg) {
    if ($script:isClosing) { return }
    [void]$script:logBuffer.AppendLine($msg)
    if (([DateTime]::Now - $script:lastFlush).TotalMilliseconds -gt 80 -or $script:logBuffer.Length -gt 2000) {
        Flush-LogBuffer
    }
    try { "$msg" | Out-File -FilePath $logFile -Append -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}

function Log-Output($output, [int]$stepStart = -1, [int]$stepEnd = -1) {
    if (-not $output -or $script:isClosing) { return }
    foreach ($line in $output) {
        if (Is-SpinnerLine $line) { continue }
        $linePercent = Get-PercentFromLine $line
        if ($null -ne $linePercent -and $stepStart -ge 0 -and $stepEnd -ge 0) {
            Set-StepProgress $linePercent $stepStart $stepEnd
        }
        $f = Format-LogLine $line
        if ($f) { Log $f }
    }
}

function Update-Progress($value) {
    if ($script:progressBar -and -not $script:isClosing) {
        # Se il valore è NaN, vuoto o nullo, lo forziamo a 0 per evitare il crash
        if ([double]::IsNaN($value) -or [string]::IsNullOrWhiteSpace($value) -or $null -eq $value) {
            $value = 0
        }
        # Corretto il limite massimo da 0 a 100
        $v = [Math]::Max(0, [Math]::Min($value, 100))
        $script:progressBar.Value = $v
        if ($script:progressLabel) { $script:progressLabel.Text = "$v%" }
    }
}

function Update-Status($msg, $color) {
    if ($script:statusLabel -and -not $script:isClosing) {
        $script:statusLabel.Text = $msg
        if ($color) { $script:statusLabel.ForeColor = $color }
    }
}

function Pump-UI { if (-not $script:isClosing) { [System.Windows.Forms.Application]::DoEvents() } }

function Test-Cancel {
    Pump-UI
    if ($script:cancelRequested) {
        Log "[STOP] Annullato."
        $script:cancelRequested = $false
        return $true
    }
    return $false
}

function Test-WingetAvailable {
    try { $null = Get-Command winget -ErrorAction Stop; return $true }
    catch { Log "[X] Winget non trovato!"; return $false }
}

# ============================================================
# BLOCCO 4 - FUNZIONI DI AGGIORNAMENTO + DOMINIO + BACKUP + PRIVACY
# ============================================================

# ---------- FUNZIONI DI AGGIORNAMENTO ----------
function Do-ScriptUpdate {
    if($script:isClosing -or (Test-Cancel)){return}
    Log "";Log "==============================================================================================="
    Log "[>] VERIFICA AGGIORNAMENTO SCRIPT"
    Log "==============================================================================================="
    Update-Status "[...] Controllo versione..." $infoColor
    Flush-LogBuffer;Pump-UI

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $remoteVersionUrl = $script:githubRawUrl + $script:versionFileName
        $remoteVersion = (Invoke-WebRequest -Uri $remoteVersionUrl -UseBasicParsing -TimeoutSec 20).Content.Trim()
        
        Log "[OK] Versione locale: $($script:currentVersion)"
        Log "[OK] Versione remota: $remoteVersion"

        if ($remoteVersion -eq $script:currentVersion) {
            Log "[OK] Script già aggiornato."
            Update-Status "[OK] Aggiornato" $successColor
            $script:updateAvailable = $false
        } else {
            Log "[!] Nuova versione disponibile!"
            $script:updateAvailable = $true
            Update-Status "[!] Aggiornamento disponibile v$remoteVersion" $warningColor
            
            $response = [System.Windows.Forms.MessageBox]::Show(
                "Versione $remoteVersion disponibile.`nAggiornare lo script?",
                "Aggiornamento Disponibile",
                "YesNo",
                "Question"
            )
            if ($response -eq "Yes") {
                Update-Status "[...] Aggiornamento..." $warningColor
                Flush-LogBuffer;Pump-UI
                
                $remoteScriptUrl = $script:githubRawUrl + $script:scriptFileName
                $localScriptPath = $PSCommandPath
                
                if (-not $localScriptPath) {
                    Log "[X] Impossibile determinare il percorso dello script."
                    Update-Status "[X] Errore percorso" $exitColor
                    return
                }

                $backupPath = $localScriptPath + ".backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Copy-Item -Path $localScriptPath -Destination $backupPath -Force
                Log "[OK] Backup creato: $backupPath"

                Log "[DL] Download nuovo script..."
                Invoke-WebRequest -Uri $remoteScriptUrl -OutFile $localScriptPath -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
                Log "[OK] Download completato."

                Log "[i] Riavvio dello script aggiornato..."
                Update-Status "[OK] Aggiornato, riavvio..." $successColor
                Flush-LogBuffer;Pump-UI
                Start-Sleep -Seconds 2

                $exe = if ($isPwsh7) { "pwsh.exe" } else { "powershell.exe" }
                Start-Process $exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$localScriptPath`""
                $script:isClosing = $true
                $script:form.Close()
            } else {
                Log "[i] Aggiornamento saltato."
                Update-Status "[i] Aggiornamento saltato" $fgDim
            }
        }
    } catch {
        Log "[X] Errore controllo aggiornamenti: $($_.Exception.Message)"
        Update-Status "[X] Errore aggiornamento" $exitColor
    }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Flush-LogBuffer;Pump-UI
}

function Invoke-GitHubDownloadRecursive {
    param(
        [string]$ApiUrl,
        [string]$LocalPath,
        [string]$BasePath = ""
    )

    $items = Invoke-RestMethod -Uri $ApiUrl -Method Get -UseBasicParsing -TimeoutSec 15
    foreach ($item in $items) {
        if ($item.type -eq "dir") {
            # Escludi cartelle indesiderate
            if ($item.name -in @("Prompt", "Docs")) { continue }
            # Crea la cartella locale
            $newLocalPath = Join-Path $LocalPath $item.name
            New-Item -ItemType Directory -Force -Path $newLocalPath | Out-Null
            # Ricorsione
            Invoke-GitHubDownloadRecursive -ApiUrl $item.url -LocalPath $newLocalPath -BasePath "$BasePath/$($item.name)"
        } elseif ($item.type -eq "file") {
            # Scarica il file
            $localFile = Join-Path $LocalPath $item.name
            try {
                Log "[DL] Download: $BasePath/$($item.name)..."
                Invoke-WebRequest -Uri $item.download_url -OutFile $localFile -UseBasicParsing -ErrorAction Stop
                Log "[OK] Scaricato: $BasePath/$($item.name)"
            } catch {
                Log "[X] Errore download $BasePath/$($item.name): $($_.Exception.Message)"
            }
        }
    }
}


function Do-FullUpdate {
    param([switch]$Force)
    
    if ($script:isClosing -or (Test-Cancel)) { return }
    
    Log ""; Log "==============================================================================================="
    if ($Force) { Log "[>] FULL UPDATE FORZATO" } else { Log "[>] FULL UPDATE - AGGIORNAMENTO COMPLETO" }
    Log "==============================================================================================="
    Update-Status "[...] Verifica aggiornamento completo..." $infoColor
    Flush-LogBuffer; Pump-UI

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # --- Solo se NON è forzato, controlla la versione ---
        if (-not $Force) {
            $remoteVersionUrl = $script:githubRawUrl + $script:versionFileName
            $remoteVersion = (Invoke-WebRequest -Uri $remoteVersionUrl -UseBasicParsing -TimeoutSec 10).Content.Trim()
            Log "[OK] Versione locale: $($script:currentVersion)"
            Log "[OK] Versione remota: $remoteVersion"

            if ($remoteVersion -eq $script:currentVersion) {
                Log "[OK] Tutti i file sono già aggiornati."
                Update-Status "[OK] Già aggiornato" $successColor
                Update-Progress 100
                Flush-LogBuffer; Pump-UI
                return
            }
            Log "[!] Nuova versione completa disponibile!"
        } else {
            Log "[i] Modalità forzata: download di tutti i file indipendentemente dalla versione."
        }

        # --- Conferma (solo se non forzato) ---
        if (-not $Force) {
            $response = [System.Windows.Forms.MessageBox]::Show(
                "Versione $remoteVersion disponibile.`n`nQuesta operazione aggiornerà TUTTI i file nella repository (escluse Prompt e Docs).`n`nProcedere?",
                "Full Update Disponibile",
                "YesNo",
                "Question"
            )
            if ($response -ne "Yes") { 
                Log "[i] Full Update annullato."; Update-Progress 100; return 
            }
        }

        # --- Determina percorso locale ---
        $localDir = Split-Path -Parent $PSCommandPath
        if (-not $localDir) { 
            Log "[X] Impossibile determinare la cartella di esecuzione."
            Update-Status "[X] Errore percorso" $exitColor
            Update-Progress 100
            return
        }

        # --- Crea backup della cartella corrente ---
        $backupDir = Join-Path $localDir "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        Log "[OK] Backup creato in: $backupDir"

        # --- Backup di tutti i file esistenti (esclusa la cartella di backup stessa) ---
        Get-ChildItem -Path $localDir -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.FullName -match [regex]::Escape($backupDir)) { return }
            $relativePath = $_.FullName.Substring($localDir.Length + 1)
            $backupFile = Join-Path $backupDir $relativePath
            if ($_.PSIsContainer) {
                New-Item -ItemType Directory -Force -Path $backupFile -ErrorAction SilentlyContinue | Out-Null
            } else {
                $backupParent = Split-Path $backupFile -Parent
                if (-not (Test-Path $backupParent)) { New-Item -ItemType Directory -Force -Path $backupParent | Out-Null }
                Copy-Item -Path $_.FullName -Destination $backupFile -Force -ErrorAction SilentlyContinue
            }
        }
        Log "[OK] Backup di tutti i file completato."

        # --- Scarica ricorsivamente TUTTI i file dalla repository (escluso Prompt e Docs) ---
        $apiUrl = "https://api.github.com/repos/$($script:repoOwner)/$($script:repoName)/contents/"
        Log "[>] Download ricorsivo della repository..."
        Invoke-GitHubDownloadRecursive -ApiUrl $apiUrl -LocalPath $localDir

        # --- Report finale ---
        Log ""
        Log "==============================================================================================="
        Log "[OK] FULL UPDATE COMPLETATO!"
        Log "     Backup salvato in: $backupDir"
        Log "==============================================================================================="
        
        Update-Progress 100
        Update-Status "[OK] Full Update completato!" $successColor
        Flush-LogBuffer; Pump-UI

        # --- Riavvio automatico ---
        $response = [System.Windows.Forms.MessageBox]::Show(
            "Aggiornamento completato!`nRiavviare lo script con la nuova versione?",
            "Riavvio necessario",
            "YesNo",
            "Question"
        )
        if ($response -eq "Yes") {
            $exe = if ($isPwsh7) { "pwsh.exe" } else { "powershell.exe" }
            $localScriptPath = $PSCommandPath
            if ($localScriptPath -and (Test-Path $localScriptPath)) {
                Start-Process $exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$localScriptPath`""
                $script:isClosing = $true
                $script:form.Close()
            }
        }

    } catch {
        Log "[X] Errore Full Update: $($_.Exception.Message)"
        Update-Status "[X] Errore" $exitColor
        Update-Progress 100
        Flush-LogBuffer; Pump-UI
    }
}

function Do-Winget { if($script:isClosing -or(Test-Cancel)){return};if(-not(Test-WingetAvailable)){return};Update-Progress 10;Update-Status "[...] Winget..." $fgColor;Flush-LogBuffer;Pump-UI;Run-ProcessRealtime "winget" "upgrade --all --force --accept-package-agreements --accept-source-agreements --include-unknown" "Winget Upgrade" 10 25;Set-StepProgress 100 10 25;Update-Progress 100;Update-Status "[OK] Winget" $successColor;Flush-LogBuffer;Pump-UI }
function Do-StoreUpdate {
    if($script:isClosing -or(Test-Cancel)){return}
    if(-not(Test-WingetAvailable)){return}
    Update-Progress 30
    Update-Status "[...] Store..." $fgColor
    Flush-LogBuffer;Pump-UI
    Run-ProcessRealtime "winget" "upgrade --source msstore --all --accept-package-agreements --accept-source-agreements --include-unknown" "Store Update" 30 40
    
    # Controlla se il comando non ha trovato aggiornamenti
    if ($script:logBox.Text -match "Non è stato trovato alcun pacchetto installato corrispondente ai criteri di input") {
        $script:logBox.SuspendLayout()
        $script:logBox.SelectionStart = $script:logBox.TextLength
        $script:logBox.SelectionLength = 0
        $script:logBox.SelectionColor = $successColor   # Verde (definito nel BLOCCO 2)
        $script:logBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
        $script:logBox.AppendText("`r`n[SUGGERIMENTO] CLICCA 'CONTROLLA AGGIORNAMENTI DISPONIBILI' NELLO STORE PER VERIFICARE MANUALMENTE.`r`n")
        $script:logBox.SelectionColor = $script:logBox.ForeColor
        $script:logBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Regular)
        $script:logBox.ResumeLayout()
        $script:logBox.ScrollToCaret()
    }
    
    try{Start-Process "ms-windows-store://downloadsandupdates" -WindowStyle Hidden -ErrorAction SilentlyContinue}catch{}
    Log " [OK] Store in background."
    Set-StepProgress 100 30 40
    Update-Progress 100
    Update-Status "[OK] Store" $successColor
    Flush-LogBuffer;Pump-UI
}
function Do-SearchWU { if($script:isClosing -or(Test-Cancel)){return};Log "";Log "===============================================================================================";Log "[>] RICERCA: Windows Update";Log "===============================================================================================";Update-Progress 50;Update-Status "[...] Ricerca WU..." $fgColor;Flush-LogBuffer;Pump-UI;if(-not $isAdmin){Log "[!] Servono privilegi admin.";Update-Status "[!] Privilegi insufficienti" $warningColor;Flush-LogBuffer;Update-Progress 100;return};try{$session=New-Object -ComObject Microsoft.Update.Session;$searcher=$session.CreateUpdateSearcher();Pump-UI;$result=$searcher.Search("IsInstalled=0 and Type='Software'");Pump-UI;if($result.Updates.Count -gt 0){Log "[OK] Trovati $($result.Updates.Count):";for($i=0;$i -lt $result.Updates.Count;$i++){$u=$result.Updates.Item($i);$kb="";if($u.KBArticleIDs.Count -gt 0){$kb="KB$($u.KBArticleIDs.Item(0)) - "};Log " $($i+1). $kb$($u.Title)"};$script:pendingUpdates=$result}else{Log "[OK] Nessun aggiornamento.";$script:pendingUpdates=$null}}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] Ricerca completata" $successColor;Flush-LogBuffer;Pump-UI }
function Do-InstallWU { if($script:isClosing -or(Test-Cancel)){return};Log "";Log "===============================================================================================";Log "[>] INSTALLAZIONE: Windows Update";Log "===============================================================================================";Update-Progress 70;Update-Status "[...] Installazione WU..." $fgColor;Flush-LogBuffer;Pump-UI;if(-not $isAdmin){Log "[X] Servono privilegi admin.";Update-Status "[!] Privilegi insufficienti" $warningColor;Flush-LogBuffer;Update-Progress 100;return};try{if(-not $script:pendingUpdates){$session=New-Object -ComObject Microsoft.Update.Session;$script:pendingUpdates=$session.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Software'");Pump-UI};$sr=$script:pendingUpdates;if($sr.Updates.Count -eq 0){Log "[OK] Nessun aggiornamento."}else{Set-StepProgress 10 70 85;$dlC=New-Object -ComObject Microsoft.Update.UpdateColl;for($i=0;$i -lt $sr.Updates.Count;$i++){$u=$sr.Updates.Item($i);if(-not $u.EulaAccepted){$u.AcceptEula()};if(-not $u.IsDownloaded){$dlC.Add($u)|Out-Null}};if($dlC.Count -gt 0){Log " [DL] Download...";Flush-LogBuffer;Pump-UI;$session=New-Object -ComObject Microsoft.Update.Session;$dl=$session.CreateUpdateDownloader();$dl.Updates=$dlC;$dl.Download()|Out-Null;Pump-UI;Set-StepProgress 50 70 85};$iC=New-Object -ComObject Microsoft.Update.UpdateColl;for($i=0;$i -lt $sr.Updates.Count;$i++){$u=$sr.Updates.Item($i);if($u.IsDownloaded){$iC.Add($u)|Out-Null}};if($iC.Count -gt 0){Log " [PKG] Installazione...";Flush-LogBuffer;Pump-UI;$session=New-Object -ComObject Microsoft.Update.Session;$inst=$session.CreateUpdateInstaller();$inst.Updates=$iC;Pump-UI;$ir=$inst.Install();Pump-UI;for($i=0;$i -lt $iC.Count;$i++){$rc=$ir.GetUpdateResult($i).ResultCode;$st=switch($rc){2{"[OK]"}3{"[OK*]"}4{"[X]"}5{"[!]"}default{"[?]"}};Log " $st $($iC.Item($i).Title)";Set-StepProgress([Math]::Round((($i+1)/$iC.Count)*100)) 70 85;Pump-UI};if($ir.RebootRequired){Log "";Log "[!] RIAVVIO NECESSARIO."}}};$script:pendingUpdates=$null}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Set-StepProgress 100 70 85;Update-Progress 100;Update-Status "[OK] Installazione completata" $successColor;Flush-LogBuffer;Pump-UI }
function Do-DriverUpdate {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Driver..." $accentColor
    Flush-LogBuffer;Pump-UI
    
    Log "";Log "==============================================================================================="
    Log "[>] AGGIORNAMENTO DRIVER"
    Log "==============================================================================================="
    
    if(-not $isAdmin){ 
        Log "[X] Richiesti privilegi admin per driver"
        Update-Status "[!] Admin richiesto" $warningColor
        Flush-LogBuffer
        Update-Progress 100
        return 
    }
    
    try {
        Log "[>] Ricerca driver via Windows Update..."
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $driverResult = $searcher.Search("IsInstalled=0 and Type='Driver'")
        
        if($driverResult.Updates.Count -gt 0) {
            Log "[OK] Trovati $($driverResult.Updates.Count) aggiornamenti driver:"
            foreach($d in $driverResult.Updates) { 
                Log "   - $($d.Title)" 
            }
            
            $response = [System.Windows.Forms.MessageBox]::Show(
                "Installare $($driverResult.Updates.Count) aggiornamenti driver?",
                "Driver Update",
                "YesNo",
                "Question"
            )
            if($response -eq "Yes") {
                Log "[DL] Download driver in corso..."
                $downloader = $session.CreateUpdateDownloader()
                $downloader.Updates = $driverResult.Updates
                $downloadResult = $downloader.Download()
                
                if($downloadResult -ne $null -and $downloadResult.ResultCode -eq 2) {
                    Log "[OK] Download completato. Installazione in corso..."
                    $installer = $session.CreateUpdateInstaller()
                    $installer.Updates = $driverResult.Updates
                    $installResult = $installer.Install()
                    
                    if($installResult -ne $null) {
                        Log "[OK] Installazione driver completata."
                        if($installResult.RebootRequired) { 
                            Log "[!] RIAVVIO NECESSARIO." 
                        }
                    } else {
                        Log "[X] Errore durante l'installazione dei driver."
                    }
                } else {
                    $resultCode = if($downloadResult) { $downloadResult.ResultCode } else { "N/A" }
                    Log "[X] Errore download driver (codice: $resultCode)"
                    Log "[!] Il driver potrebbe non essere compatibile o richiedere approvazione manuale."
                }
            }
        } else { 
            Log "[OK] Nessun aggiornamento driver disponibile" 
        }
    } catch {
        Log "[X] Errore aggiornamento driver: $($_.Exception.Message)"
        if($_.Exception.Message -match "Index was outside the bounds") {
            Log "[!] Errore durante l'elaborazione del driver. Riprova o installa manualmente."
        }
    }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Driver" $successColor
    Flush-LogBuffer;Pump-UI
}

# ---------- FUNZIONI DOMINIO ----------
function Do-DomainInfo {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Info Dominio..." $infoColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] INFORMAZIONI DOMINIO"
    Log "==============================================================================================="
    try {
        $computer = Get-CimInstance Win32_ComputerSystem
        Log " Nome PC      : $($computer.Name)"
        Log " Dominio      : $($computer.Domain)"
        if($computer.PartOfDomain) {
            Log " Stato        : MEMBRO DEL DOMINIO"
            try {
                Import-Module ActiveDirectory -ErrorAction Stop
                $domain = Get-ADDomain -ErrorAction Stop
                Log " Nome Dominio : $($domain.Name)"
                Log " DC Primario  : $($domain.PDCEmulator)"
                Log " Foresta      : $($domain.Forest)"
            } catch { Log "[!] Modulo AD non disponibile. Installare RSAT-AD-PowerShell." }
        } else {
            Log " Stato        : WORKGROUP"
        }
        $user = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        Log " Utente       : $($user.Name)"
    } catch { Log "[X] $($_.Exception.Message)" }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Info Dominio" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-DCTest {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Test DC..." $networkColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] TEST DOMAIN CONTROLLER"
    Log "==============================================================================================="
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        $domain = Get-ADDomain -ErrorAction Stop
        $dcs = $domain.ReplicaDirectoryServers
        if(-not $dcs) { $dcs = @($domain.PDCEmulator) }
        foreach($dc in $dcs) {
            Log "[>] Test $dc..."
            try {
                $ping = Test-Connection -ComputerName $dc -Count 2 -ErrorAction Stop
                $avg = [Math]::Round(($ping | Measure-Object -Property ResponseTime -Average).Average, 1)
                Log "[OK] $dc - ${avg}ms"
            } catch { Log "[X] $dc - NON RAGGIUNGIBILE" }
            Pump-UI
        }
    } catch { Log "[X] $($_.Exception.Message)" }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Test DC" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-SyncTime {
    if($script:isClosing -or(Test-Cancel)){return}
    if(-not $isAdmin){Log "[X] Admin richiesto";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;Update-Progress 100;return}
    Update-Status "[...] Sincronizzazione Ora..." $infoColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] SINCRONIZZA ORA CON DC"
    Log "==============================================================================================="
    try {
        $result = w32tm /resync /nowait 2>&1
        Log-Output $result
        Log "[OK] Sincronizzazione orario avviata."
    } catch { Log "[X] $($_.Exception.Message)" }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Ora sincronizzata" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-FlushKerberos {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Flush Kerberos..." $securityColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] FLUSH KERBEROS TICKET"
    Log "==============================================================================================="
    try {
        $result = klist purge 2>&1
        Log-Output $result
        Log "[OK] Cache Kerberos svuotata."
    } catch { Log "[X] $($_.Exception.Message)" }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Kerberos" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-GPOInfo {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] GPO..." $infoColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] INFORMAZIONI GPO"
    Log "==============================================================================================="
    try {
        $result = gpresult /r /scope computer 2>&1 | Select-String -Pattern "Nome|Ultima|OU|GPO"
        foreach($line in $result) { Log " $line" }
        Log ""
        $userResult = gpresult /r /scope user 2>&1 | Select-String -Pattern "Nome|GPO"
        foreach($line in $userResult) { Log " $line" }
    } catch { Log "[X] $($_.Exception.Message)" }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] GPO" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-ResetNetworkProfile {
    if($script:isClosing -or(Test-Cancel)){return}
    if(-not $isAdmin){Log "[X] Admin richiesto";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;Update-Progress 100;return}
    Update-Status "[...] Reset Profilo Rete..." $networkColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] RESET PROFILO RETE (ATTENZIONE: DISCONNETTE LA RETE)"
    Log "==============================================================================================="
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Questa operazione riavvierà la scheda di rete causando una breve disconnessione (1-2 secondi). Continuare?",
        "Reset Profilo Rete",
        "YesNo",
        "Warning"
    )
    if($confirm -ne "Yes") { Log "[i] Annullato."; Update-Progress 100; return }
    
    try {
        Log "[>] Reset Winsock..."
        netsh winsock reset | Out-Null
        Log "[>] Reset TCP/IP..."
        netsh int ip reset | Out-Null
        Log "[>] Rilascio IP..."
        ipconfig /release | Out-Null
        Start-Sleep 2
        Log "[>] Rinnovo IP..."
        ipconfig /renew | Out-Null
        Log "[OK] Profilo rete reimpostato. Riavvio consigliato."
    } catch { Log "[X] $($_.Exception.Message)" }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Reset Rete" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-DNSTest {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Test DNS..." $networkColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] TEST DNS DOMINIO"
    Log "==============================================================================================="
    try {
        $domain = (Get-CimInstance Win32_ComputerSystem).Domain
        if($domain -and $domain -ne "WORKGROUP") {
            Log "[>] Risoluzione $domain..."
            $result = nslookup $domain 2>&1
            Log-Output $result
            Log "[OK] Test DNS completato."
        } else {
            Log "[!] PC non in dominio."
        }
    } catch { Log "[X] $($_.Exception.Message)" }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] DNS" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-ADSiteInfo {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Sito AD..." $infoColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] INFORMAZIONI SITO AD"
    Log "==============================================================================================="
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        $site = Get-ADReplicationSubnet -Filter * -ErrorAction Stop | Select-Object -First 5
        if($site) {
            foreach($s in $site) {
                Log " Sito: $($s.Name) - Subnet: $($s.Location)"
            }
        } else {
            Log "[!] Nessun sito AD trovato."
        }
    } catch { Log "[X] $($_.Exception.Message)" }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Sito AD" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-LDAPTest {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Test LDAP..." $infoColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] TEST CONNETTIVITÀ LDAP"
    Log "==============================================================================================="
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        $domain = Get-ADDomain -ErrorAction Stop
        Log "[OK] Connessione LDAP riuscita!"
        Log " DN: $($domain.DistinguishedName)"
    } catch { Log "[X] Errore LDAP: $($_.Exception.Message)" }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] LDAP" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-DomainPassword {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Cambio Password..." $securityColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] CAMBIO PASSWORD DOMINIO"
    Log "==============================================================================================="
    try {
        $user = $env:USERNAME
        Log "[i] Cambio password per: $user"
        $result = net user $user * /domain 2>&1
        Log-Output $result
        Log "[OK] Operazione completata."
    } catch { Log "[X] $($_.Exception.Message)" }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Password" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-LastLogin {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Ultimo Login..." $infoColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] ULTIMO LOGIN DOMINIO"
    Log "==============================================================================================="
    try {
        $user = $env:USERNAME
        Import-Module ActiveDirectory -ErrorAction Stop
        $adUser = Get-ADUser -Identity $user -Properties LastLogonDate, PasswordLastSet, AccountExpirationDate -ErrorAction Stop
        if($adUser) {
            Log " Utente       : $($adUser.Name)"
            Log " Ultimo Login : $($adUser.LastLogonDate)"
            Log " Password Set : $($adUser.PasswordLastSet)"
            Log " Scadenza     : $($adUser.AccountExpirationDate)"
        } else {
            Log "[!] Utente non trovato in AD."
        }
    } catch { Log "[X] $($_.Exception.Message)" }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Last Login" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-GroupMembership {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Gruppi..." $infoColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] GRUPPI DOMINIO UTENTE"
    Log "==============================================================================================="
    try {
        $user = $env:USERNAME
        Import-Module ActiveDirectory -ErrorAction Stop
        $groups = Get-ADPrincipalGroupMembership -Identity $user -ErrorAction Stop
        if($groups) {
            Log " Utente: $user"
            Log " Gruppi:"
            foreach($g in $groups | Sort-Object Name) {
                Log "   - $($g.Name)"
            }
        } else {
            Log "[!] Nessun gruppo trovato."
        }
    } catch { Log "[X] $($_.Exception.Message)" }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Gruppi" $successColor
    Flush-LogBuffer;Pump-UI
}

# ---------- FUNZIONE BACKUP FILES ----------
function Do-BackupFiles {
    if($script:isClosing -or(Test-Cancel)){return}
    
    $folderDialog1 = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog1.Description = "Seleziona la cartella da BACKUP (origine)"
    $folderDialog1.ShowNewFolderButton = $false
    $folderDialog1.RootFolder = "MyComputer"
    
    if($folderDialog1.ShowDialog() -ne "OK") { 
        Log "[i] Backup annullato."; Update-Progress 100; return 
    }
    $sourcePath = $folderDialog1.SelectedPath
    
    $folderDialog2 = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog2.Description = "Seleziona la cartella dove SALVARE il backup (destinazione)"
    $folderDialog2.ShowNewFolderButton = $true
    $folderDialog2.RootFolder = "MyComputer"
    
    if($folderDialog2.ShowDialog() -ne "OK") { 
        Log "[i] Backup annullato."; Update-Progress 100; return 
    }
    $destPath = $folderDialog2.SelectedPath
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $folderName = Split-Path $sourcePath -Leaf
    $zipName = "Backup_${folderName}_${timestamp}.zip"
    $zipPath = Join-Path $destPath $zipName
    
    Log "";Log "==============================================================================================="
    Log "[>] BACKUP COMPRESSO FILES"
    Log "==============================================================================================="
    Log "[i] Origine    : $sourcePath"
    Log "[i] Destinazione: $zipPath"
    Log ""
    
    if(-not (Test-Path $sourcePath)) {
        Log "[X] Cartella origine non trovata!"
        Update-Status "[X] Origine non trovata" $exitColor
        Update-Progress 100
        return
    }
    
    Update-Status "[...] Calcolo dimensione..." $infoColor
    Flush-LogBuffer;Pump-UI
    
    try {
        $items = Get-ChildItem -Path $sourcePath -Recurse -Force -ErrorAction SilentlyContinue
        $totalSize = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $totalCount = $items.Count
        Log "[OK] Elementi: $totalCount, Dimensione: $([Math]::Round($totalSize/1MB, 2)) MB"
    } catch {
        Log "[X] Errore calcolo dimensione: $($_.Exception.Message)"
        Update-Progress 100
        return
    }
    
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Avviare backup di $totalCount elementi ($([Math]::Round($totalSize/1MB, 2)) MB)?",
        "Conferma Backup",
        "YesNo",
        "Question"
    )
    if($response -ne "Yes") { 
        Log "[i] Backup annullato."; Update-Progress 100; return 
    }
    
    Update-Status "[...] Compressione in corso..." $warningColor
    Flush-LogBuffer;Pump-UI
    
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $compressParams = @{
            Path = $sourcePath
            DestinationPath = $zipPath
            CompressionLevel = "Optimal"
            Force = $true
        }
        Compress-Archive @compressParams -ErrorAction Stop
        $sw.Stop()
        $elapsed = $sw.Elapsed
        
        if(Test-Path $zipPath) {
            $zipSize = (Get-Item $zipPath).Length
            $ratio = [Math]::Round((1 - ($zipSize / $totalSize)) * 100, 1)
            Log ""
            Log "[OK] BACKUP COMPLETATO!"
            Log "     File: $zipPath"
            Log "     Dimensione: $([Math]::Round($zipSize/1MB, 2)) MB"
            Log "     Compressione: $ratio%"
            Log "     Tempo: $($elapsed.ToString('hh\:mm\:ss'))"
            Update-Status "[OK] Backup completato ($([Math]::Round($zipSize/1MB, 1)) MB)" $successColor
            
            $openFolder = [System.Windows.Forms.MessageBox]::Show(
                "Backup completato!`nAprire la cartella di destinazione?",
                "Backup Completato",
                "YesNo",
                "Information"
            )
            if($openFolder -eq "Yes") { Start-Process $destPath }
        } else {
            Log "[X] File backup non trovato dopo la compressione!"
            Update-Status "[X] Errore backup" $exitColor
        }
    } catch {
        Log "[X] Errore compressione: $($_.Exception.Message)"
        Update-Status "[X] Errore backup" $exitColor
    }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Flush-LogBuffer;Pump-UI
}

# ---------- FUNZIONI PRIVACY ----------
function Do-PrivacyWindows {
    if($script:isClosing -or(Test-Cancel)){return}
    if(-not $isAdmin){Log "[X] Admin richiesto";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;Update-Progress 100;return}
    
    Update-Status "[...] Privacy Windows..." $securityColor
    Flush-LogBuffer;Pump-UI
    
    Log "";Log "==============================================================================================="
    Log "[>] DISABILITA TELEMETRIA WINDOWS"
    Log "==============================================================================================="
    
    $count = 0; $errors = 0
    
    $paths = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"; Name="DisabledByGroupPolicy"; Value=1},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name="DisableSoftLanding"; Value=1},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name="DisableWindowsConsumerFeatures"; Value=1},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name="AllowTelemetry"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name="DoNotShowFeedbackNotifications"; Value=1},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name="AllowTelemetry"; Value=0},
        @{Path="HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name="AllowTelemetry"; Value=0},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"; Name="TailoredExperiencesWithDiagnosticDataEnabled"; Value=0},
        @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"; Name="TailoredExperiencesWithDiagnosticDataEnabled"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name="AllowCortana"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name="AllowSearchToUseLocation"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name="DisableWebSearch"; Value=1},
        @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; Name="CortanaEnabled"; Value=0},
        @{Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; Name="AllowSearchToUseLocation"; Value=0},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"; Name="Disabled"; Value=1},
        @{Path="HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Consent"; Name="DefaultConsent"; Value=0},
        @{Path="HKCU:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"; Name="Disabled"; Value=1},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name="DisableInventory"; Value=1},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"; Name="AITEnable"; Value=0}
    )
    
    foreach($p in $paths) {
        try {
            if(-not (Test-Path $p.Path)) { New-Item -Path $p.Path -Force | Out-Null }
            Set-ItemProperty -Path $p.Path -Name $p.Name -Value $p.Value -Force -ErrorAction Stop
            $count++
            Log "[OK] $($p.Name) = $($p.Value)"
        } catch {
            $errors++
            Log "[!] $($p.Name): $($_.Exception.Message)"
        }
        Pump-UI
    }
    
    Log ""
    Log "[OK] Impostazioni Windows: $count OK, $errors errori"
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Privacy Windows ($count modifiche)" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-PrivacyOffice {
    if($script:isClosing -or(Test-Cancel)){return}
    if(-not $isAdmin){Log "[X] Admin richiesto";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;Update-Progress 100;return}
    
    Update-Status "[...] Privacy Office..." $securityColor
    Flush-LogBuffer;Pump-UI
    
    Log "";Log "==============================================================================================="
    Log "[>] DISABILITA TELEMETRIA OFFICE"
    Log "==============================================================================================="
    
    $count = 0; $errors = 0
    
    $officePaths = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Instrumentation"; Name="Enable"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Telemetry"; Name="Enable"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Telemetry\Instrumentation"; Name="Enable"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\Common\Telemetry\Debug"; Name="Enable"; Value=0}
    )
    
    foreach($p in $officePaths) {
        try {
            if(-not (Test-Path $p.Path)) { New-Item -Path $p.Path -Force | Out-Null }
            Set-ItemProperty -Path $p.Path -Name $p.Name -Value $p.Value -Force -ErrorAction Stop
            $count++
            Log "[OK] $($p.Name) = $($p.Value)"
        } catch {
            $errors++
            Log "[!] $($p.Name): $($_.Exception.Message)"
        }
        Pump-UI
    }
    
    Log ""
    Log "[OK] Impostazioni Office: $count OK, $errors errori"
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Privacy Office ($count modifiche)" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-PrivacyEdge {
    if($script:isClosing -or(Test-Cancel)){return}
    if(-not $isAdmin){Log "[X] Admin richiesto";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;Update-Progress 100;return}
    
    Update-Status "[...] Privacy Edge..." $securityColor
    Flush-LogBuffer;Pump-UI
    
    Log "";Log "==============================================================================================="
    Log "[>] DISABILITA TELEMETRIA EDGE"
    Log "==============================================================================================="
    
    $count = 0; $errors = 0
    
    $edgePaths = @(
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name="SearchSuggestEnabled"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name="AutofillAddressEnabled"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name="AutofillCreditCardEnabled"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name="PersonalizationReportingEnabled"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name="UrlDiagnosticDataEnabled"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name="MicrosoftSearchInBingProviderEnabled"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name="AlternateErrorPagesEnabled"; Value=0},
        @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; Name="ShowRecommendationsEnabled"; Value=0}
    )
    
    foreach($p in $edgePaths) {
        try {
            if(-not (Test-Path $p.Path)) { New-Item -Path $p.Path -Force | Out-Null }
            Set-ItemProperty -Path $p.Path -Name $p.Name -Value $p.Value -Force -ErrorAction Stop
            $count++
            Log "[OK] $($p.Name) = $($p.Value)"
        } catch {
            $errors++
            Log "[!] $($p.Name): $($_.Exception.Message)"
        }
        Pump-UI
    }
    
    Log ""
    Log "[OK] Impostazioni Edge: $count OK, $errors errori"
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Privacy Edge ($count modifiche)" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-PrivacyTasks {
    if($script:isClosing -or(Test-Cancel)){return}
    if(-not $isAdmin){Log "[X] Admin richiesto";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;Update-Progress 100;return}
    
    Update-Status "[...] Privacy Task Scheduler..." $securityColor
    Flush-LogBuffer;Pump-UI
    
    Log "";Log "==============================================================================================="
    Log "[>] DISABILITA ATTIVITÀ TELEMETRIA"
    Log "==============================================================================================="
    
    $tasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\StartupAppTask",
        "\Microsoft\Windows\Application Experience\Device Census",
        "\Microsoft\Windows\Application Experience\DiskDiagnosticDataCollector",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\Customer Experience Improvement Program\Sqm-Tasks",
        "\Microsoft\Windows\Customer Experience Improvement Program\Proxy",
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
        "\Microsoft\Windows\Feedback\Siuf\DmClient",
        "\Microsoft\Windows\Feedback\Siuf\Siuf",
        "\Microsoft\Windows\NetTrace\GatherNetworkInfo",
        "\Microsoft\Windows\AppID\SmartScreenSpecific"
    )
    
    $count = 0; $errors = 0
    
    foreach($taskPath in $tasks) {
        try {
            $task = Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue
            if($task) {
                Disable-ScheduledTask -TaskPath $taskPath -ErrorAction Stop
                $count++
                $taskName = Split-Path $taskPath -Leaf
                Log "[OK] Disabilitato: $taskName"
            } else {
                Log "[i] $taskPath - Non trovato"
            }
        } catch {
            $errors++
            Log "[!] ${taskPath}: $($_.Exception.Message)"
        }
        Pump-UI
    }
    
    Log ""
    Log "[OK] Attività disabilitate: $count, errori: $errors"
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Privacy Tasks ($count disabilitate)" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-PrivacyAll {
    if($script:isClosing -or(Test-Cancel)){return}
    if(-not $isAdmin){Log "[X] Admin richiesto";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;Update-Progress 100;return}
    
    Log "";Log "##################################################################################################"
    Log "# PRIVACY - DISABILITA TUTTO #"
    Log "##################################################################################################";Log ""
    
    Update-Status "[...] Privacy Completa..." $securityColor
    Flush-LogBuffer;Pump-UI
    
    Do-PrivacyWindows
    if(Test-Cancel){return}
    Do-PrivacyOffice
    if(Test-Cancel){return}
    Do-PrivacyEdge
    if(Test-Cancel){return}
    Do-PrivacyTasks
    if(Test-Cancel){return}
    
    Log ""
    Log "##################################################################################################"
    Log "# PRIVACY COMPLETATA - RIAVVIO CONSIGLIATO #"
    Log "##################################################################################################";Log ""
    
    Update-Progress 100
    Update-Status "[OK] Privacy Completata!" $successColor
    Flush-LogBuffer;Pump-UI
    
    $response = [System.Windows.Forms.MessageBox]::Show(
        "Privacy configurata!`nRiavviare il PC per applicare tutte le modifiche?",
        "Riavvio Consigliato",
        "YesNo",
        "Question"
    )
    if($response -eq "Yes") {
        shutdown /r /t 10 /c "Riavvio per applicare modifiche privacy"
        Log "[i] Riavvio in 10 secondi..."
    }
}


# ---------- FUNZIONE ASSISTENZA REMOTA VNC ----------
function Do-VNCViewer {
    if($script:isClosing -or (Test-Cancel)){return}

    # --- Popup per inserire IP ---
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Assistenza LAN - TightVNC"
    $inputForm.Size = New-Object System.Drawing.Size(400, 180)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = $bgColor
    $inputForm.ForeColor = $fgColor
    $inputForm.TopMost = $true

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inserisci l'IP del PC remoto:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(360, 22)
    $lbl.ForeColor = $fgColor
    $inputForm.Controls.Add($lbl)

    $txtIP = New-Object System.Windows.Forms.TextBox
    $txtIP.Text = "192.168.1."
    $txtIP.Location = New-Object System.Drawing.Point(20, 50)
    $txtIP.Size = New-Object System.Drawing.Size(340, 26)
    $txtIP.Font = New-Object System.Drawing.Font("Consolas", 12)
    $txtIP.BackColor = $bgCard
    $txtIP.ForeColor = $fgColor
    $inputForm.Controls.Add($txtIP)

    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Connetti"
    $btnOK.Location = New-Object System.Drawing.Point(20, 90)
    $btnOK.Size = New-Object System.Drawing.Size(100, 32)
    $btnOK.BackColor = $remoteColor # Rosso che hai nel Blocco 2
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140, 90)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 32)
    $btnCancel.BackColor = $exitColor
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($btnCancel)
    $inputForm.CancelButton = $btnCancel

    $result = $inputForm.ShowDialog($script:form)
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Log "[i] Assistenza remota annullata."
        return
    }

    $targetIP = $txtIP.Text.Trim()
    if ([string]::IsNullOrEmpty($targetIP)) {
        Log "[X] Nessun IP inserito."
        return
    }

    # --- Verifica ed Esecuzione ---
    $vncPath = Join-Path $scriptRoot "lib\tvnviewer.exe"

    if (-not (Test-Path $vncPath)) {
        Log "[X] Impossibile trovare lib\tvnviewer.exe. Assicurati che il file sia nella cartella."
        Update-Status "[X] tvnviewer.exe mancante" $exitColor
        return
    }

    Log ""; Log "==============================================================================================="
    Log "[>] AVVIO ASSISTENZA REMOTA (TightVNC Viewer)"
    Log "==============================================================================================="
    Log "[OK] Connessione a: $targetIP"
    Log "[OK] Avvio eseguibile portatile..."
    Update-Status "[...] Connessione a $targetIP..." $remoteColor
    Flush-LogBuffer; Pump-UI

    try {
        # Lancia il viewer passandogli l'IP come argomento
        Start-Process -FilePath $vncPath -ArgumentList "$targetIP"
        Log "[OK] Viewer avviato con successo."
        Update-Status "[OK] VNC in esecuzione" $successColor
    } catch {
        Log "[X] Errore durante l'avvio di TightVNC: $($_.Exception.Message)"
        Update-Status "[X] Errore avvio VNC" $exitColor
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}


# ---------- FUNZIONI GESTIONE RDP ----------

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
        # 1. Salva temporaneamente le credenziali in Windows Credential Manager
        $null = cmdkey /generic:"TERMSRV/$IP" /user:"$User" /pass:"$Pass"
        
        # 2. Lancia mstsc.exe
        Start-Process "mstsc.exe" -ArgumentList "`"$RDPFile`""
        
        Log "[OK] Sessione RDP avviata per $IP"
        Update-Status "[OK] RDP Connesso a $IP" $successColor
        
        # 3. Opzionale: Rimuove la credenziale dopo 30 secondi per sicurezza
        # (Lo lascio commentato, se vuoi che si cancelli da sola decommentalo)
        # Start-Sleep -Seconds 30
        # $null = cmdkey /delete:"TERMSRV/$IP"
    } catch {
        Log "[X] Errore avvio RDP: $($_.Exception.Message)"
    }
}


function Do-RDPManager {
    if($script:isClosing -or (Test-Cancel)){return}

    $promptDir = Join-Path $scriptRoot "Prompt"
    if (-not (Test-Path $promptDir)) { New-Item -ItemType Directory -Force -Path $promptDir | Out-Null }

    # --- Creazione Form Dark ---
    $rdpForm = New-Object System.Windows.Forms.Form
    $rdpForm.Text = "Gestore Sessioni RDP"
    $rdpForm.Size = New-Object System.Drawing.Size(500, 450)
    $rdpForm.StartPosition = "CenterParent"
    $rdpForm.FormBorderStyle = "FixedDialog"
    $rdpForm.MaximizeBox = $false
    $rdpForm.MinimizeBox = $false
    $rdpForm.BackColor = $bgColor
    $rdpForm.ForeColor = $fgColor
    $rdpForm.TopMost = $true

    # --- Label Lista Sessioni ---
    $lblList = New-Object System.Windows.Forms.Label
    $lblList.Text = "Sessioni Salvate (cartella Prompt):"
    $lblList.Location = New-Object System.Drawing.Point(15, 15)
    $lblList.Size = New-Object System.Drawing.Size(300, 20)
    $lblList.ForeColor = $fgColor
    $rdpForm.Controls.Add($lblList)

    # --- ComboBox Sessioni ---
    $cmbSessions = New-Object System.Windows.Forms.ComboBox
    $cmbSessions.Location = New-Object System.Drawing.Point(15, 40)
    $cmbSessions.Size = New-Object System.Drawing.Size(350, 25)
    $cmbSessions.BackColor = $bgCard
    $cmbSessions.ForeColor = $fgColor
    $cmbSessions.DropDownStyle = "DropDownList"
    # Popola la lista
    Get-ChildItem -Path $promptDir -Filter "*.rdp" | ForEach-Object { $cmbSessions.Items.Add($_.BaseName) | Out-Null }
    if ($cmbSessions.Items.Count -gt 0) { $cmbSessions.SelectedIndex = 0 }
    $rdpForm.Controls.Add($cmbSessions)

    # --- Pulsanti Lista ---
    $btnConnect = New-Object System.Windows.Forms.Button
    $btnConnect.Text = "Connetti"
    $btnConnect.Location = New-Object System.Drawing.Point(375, 38)
    $btnConnect.Size = New-Object System.Drawing.Size(100, 28)
    $btnConnect.BackColor = $successColor
    $btnConnect.ForeColor = [System.Drawing.Color]::White
    $btnConnect.FlatStyle = "Flat"
    $rdpForm.Controls.Add($btnConnect)

    $btnDelete = New-Object System.Windows.Forms.Button
    $btnDelete.Text = "Elimina"
    $btnDelete.Location = New-Object System.Drawing.Point(375, 72)
    $btnDelete.Size = New-Object System.Drawing.Size(100, 25)
    $btnDelete.BackColor = $exitColor
    $btnDelete.ForeColor = [System.Drawing.Color]::White
    $btnDelete.FlatStyle = "Flat"
    $rdpForm.Controls.Add($btnDelete)

    # --- Separatore ---
    $sep = New-Object System.Windows.Forms.Label
    $sep.Text = "─" * 60
    $sep.Location = New-Object System.Drawing.Point(15, 105)
    $sep.ForeColor = $separatorColor
    $rdpForm.Controls.Add($sep)

    # --- Campi Nuova Connessione ---
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
    $txtName.BackColor = $bgCard
    $txtName.ForeColor = $fgDim
    $rdpForm.Controls.Add($txtName)

    $txtIP = New-Object System.Windows.Forms.TextBox
    $txtIP.Text = "192.168.1."
    $txtIP.Location = New-Object System.Drawing.Point(15, 180)
    $txtIP.Size = New-Object System.Drawing.Size(220, 25)
    $txtIP.Font = New-Object System.Drawing.Font("Consolas", 10)
    $txtIP.BackColor = $bgCard
    $txtIP.ForeColor = $fgColor
    $rdpForm.Controls.Add($txtIP)

    $txtUser = New-Object System.Windows.Forms.TextBox
    $txtUser.Text = "Administrator"
    $txtUser.Location = New-Object System.Drawing.Point(250, 180)
    $txtUser.Size = New-Object System.Drawing.Size(225, 25)
    $txtUser.BackColor = $bgCard
    $txtUser.ForeColor = $fgColor
    $rdpForm.Controls.Add($txtUser)

    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Text = "Password"
    $txtPass.Location = New-Object System.Drawing.Point(15, 210)
    $txtPass.Size = New-Object System.Drawing.Size(460, 25)
    $txtPass.PasswordChar = "*"
    $txtPass.BackColor = $bgCard
    $txtPass.ForeColor = $fgColor
    $rdpForm.Controls.Add($txtPass)

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "💾 Salva e Connetti"
    $btnSave.Location = New-Object System.Drawing.Point(15, 250)
    $btnSave.Size = New-Object System.Drawing.Size(460, 35)
    $btnSave.BackColor = $accentColor
    $btnSave.ForeColor = [System.Drawing.Color]::White
    $btnSave.FlatStyle = "Flat"
    $btnSave.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $rdpForm.Controls.Add($btnSave)

    # --- Log Area nel Form ---
    $lblLogTitle = New-Object System.Windows.Forms.Label
    $lblLogTitle.Text = "Stato:"
    $lblLogTitle.Location = New-Object System.Drawing.Point(15, 300)
    $lblLogTitle.ForeColor = $fgDim
    $rdpForm.Controls.Add($lblLogTitle)

    $txtFormLog = New-Object System.Windows.Forms.TextBox
    $txtFormLog.Multiline = $true
    $txtFormLog.ReadOnly = $true
    $txtFormLog.Location = New-Object System.Drawing.Point(15, 320)
    $txtFormLog.Size = New-Object System.Drawing.Size(460, 80)
    $txtFormLog.BackColor = $logBg
    $txtFormLog.ForeColor = $fgDim
    $txtFormLog.Font = New-Object System.Drawing.Font("Consolas", 8)
    $rdpForm.Controls.Add($txtFormLog)

    # --- LOGICA EVENTI ---

    # Connetti a sessione esistente
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

    # Elimina sessione
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

    # Salva e Connetti Nuova
    $btnSave.Add_Click({
        $nome = $txtName.Text.Trim()
        $ip = $txtIP.Text.Trim()
        $user = $txtUser.Text.Trim()
        $pass = $txtPass.Text.Trim()

        if ([string]::IsNullOrEmpty($nome) -or [string]::IsNullOrEmpty($ip) -or $ip -eq "192.168.1.") {
            $txtFormLog.Text = "[X] Inserisci un Nome valido e un IP."
            return
        }

        # Rimuovi caratteri non validi per i nomi dei file
        $safeName = ($nome -replace '[\\/:*?"<>|]', '_')
        $rdpPath = Join-Path $promptDir "$safeName.rdp"
        $jsonPath = Join-Path $promptDir "$safeName.json"

        try {
            # Crea file RDP
            New-RDPFile -FilePath $rdpPath -IP $ip -User $user
            
            # Crea file JSON con le credenziali
            $credObj = @{ IP = $ip; User = $user; Pass = $pass } | ConvertTo-Json
            Set-Content -Path $jsonPath -Value $credObj -Force

            $txtFormLog.Text = "[OK] Salvataggio completato in Prompt\. Avvio..."

            # Aggiorna combobox se non c'è
            if (-not $cmbSessions.Items.Contains($safeName)) { $cmbSessions.Items.Add($safeName) }
            $cmbSessions.SelectedItem = $safeName

            # Avvia
            Start-RDPWithCred -IP $ip -User $user -Pass $pass -RDPFile $rdpPath
            
        } catch {
            $txtFormLog.Text = "[X] Errore durante il salvataggio: $($_.Exception.Message)"
        }
    })

    # Mostra il form
    $rdpForm.ShowDialog($script:form) | Out-Null

    Log "[i] Gestore RDP chiuso."
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}




# ============================================================
# BLOCCO 5 - FUNZIONI DI PULIZIA
# ============================================================
function Do-CleanTemp { if($script:isClosing -or(Test-Cancel)){return};Log "";Log "===============================================================================================";Log "[>] PULIZIA Temp";Log "===============================================================================================";Update-Progress 90;Update-Status "[...] Pulizia..." $fgColor;Flush-LogBuffer;Pump-UI;$paths=@(@{Path=$env:TEMP;Name="Temp"},@{Path="$env:LOCALAPPDATA\Temp";Name="Local"},@{Path="$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache";Name="INet"},@{Path="$env:USERPROFILE\AppData\Local\CrashDumps";Name="Crash"});if($isAdmin){$paths+=@{Path="$env:WINDIR\Temp";Name="WinTemp"}};$tot=[long]0;foreach($p in $paths){if(Test-Cancel){return};if(Test-Path $p.Path){try{$items=Get-ChildItem -Path $p.Path -Force -Recurse -ErrorAction SilentlyContinue;$sz=($items|Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum;if(-not $sz){$sz=0};$cnt=($items|Measure-Object).Count;if($cnt -gt 0){Remove-Item "$($p.Path)\*" -Recurse -Force -ErrorAction SilentlyContinue;$tot+=$sz};Log " [$($p.Name)] $cnt, $([Math]::Round($sz/1MB,1))MB"}catch{}};Pump-UI};$mb=[Math]::Round($tot/1MB,1);Log "";Log "[OK] Liberati: ${mb}MB";Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] Pulizia (${mb}MB)" $successColor;Flush-LogBuffer;Pump-UI }
function Do-DiskCleanup { if($script:isClosing -or(Test-Cancel)){return};if(-not $isAdmin){Log "[X] Admin.";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;Update-Progress 100;return};Update-Status "[...] Cleanup..." $maintColor;Flush-LogBuffer;Pump-UI;try{$cp="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches";if(Test-Path $cp){Get-ChildItem $cp -ErrorAction SilentlyContinue|ForEach-Object{Set-ItemProperty -Path $_.PSPath -Name "StateFlags0100" -Value 2 -ErrorAction SilentlyContinue}};Run-ProcessRealtime "cleanmgr" "/sagerun:100" "Disk Cleanup" 80 95}catch{Log "[X] $($_.Exception.Message)"};Update-Progress 100;Update-Status "[OK] Cleanup" $successColor;Flush-LogBuffer;Pump-UI }
function Do-DiskAnalysis {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Analisi Disco..." $maintColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] ANALISI SPAZIO DISCO DETTAGLIATA"
    Log "==============================================================================================="
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    $totalSize = 0; $totalFree = 0
    foreach($drive in $drives) {
        $size = [Math]::Round($drive.Size/1GB, 2)
        $free = [Math]::Round($drive.FreeSpace/1GB, 2)
        $used = $size - $free
        $percent = [Math]::Round(($used/$size)*100, 1)
        Log " [$($drive.DeviceID)] $used GB / $size GB ($percent% usato)"
        if($percent -gt 85) { Log "   [!] ATTENZIONE: Spazio critico!" }
        $totalSize += $size; $totalFree += $free
        Pump-UI
    }
    Log "";Log " TOTALE: $([Math]::Round($totalSize-$totalFree, 2)) / $([Math]::Round($totalSize, 2)) GB"
    Log " LIBERO: $([Math]::Round($totalFree, 2)) GB"
    if($totalFree/$totalSize -lt 0.2) {
        Log "";Log " [!] SUGGERIMENTI:"
        Log "    - Esegui 'Pulizia temp' e 'Disk Cleanup'"
        $downloadsSize = [Math]::Round((Get-ChildItem ~/Downloads -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum/1GB, 2)
        Log "    - Controlla Downloads: ${downloadsSize}GB"
        Log "    - Usa 'Spazio Disco' per identificare cartelle grandi"
    }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Analisi disco" $successColor
    Flush-LogBuffer;Pump-UI
}
function Do-CleanLogs {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Log pulizia..." $maintColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] PULIZIA FILE DI LOG E DUMP"
    Log "==============================================================================================="
    $logPaths = @(
        "$env:WINDIR\Logs\*",
        "$env:WINDIR\System32\LogFiles\*",
        "$env:PROGRAMDATA\Microsoft\Windows\WER\*"
    )
    $totalFreed = 0
    foreach($path in $logPaths) {
        if(Test-Path $path) {
            try {
                $items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                $size = ($items | Measure-Object Length -Sum -ErrorAction SilentlyContinue).Sum
                if($size -gt 0) {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    $totalFreed += $size
                    Log "[OK] Pulito: $path ($([Math]::Round($size/1MB,1)) MB)"
                }
            } catch { Log "[!] Accesso negato a $path" }
        }
        Pump-UI
    }
    Log "";Log "[OK] Liberati $([Math]::Round($totalFreed/1MB,1)) MB"
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Log puliti" $successColor
    Flush-LogBuffer;Pump-UI
}

# ============================================================
# BLOCCO 6 - FUNZIONI DI RETE
# ============================================================
function Do-FlushDNS { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] DNS..." $networkColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Flush DNS";Log "===============================================================================================";try{$o=& ipconfig /flushdns 2>&1;Log-Output $o;Log "[OK] DNS svuotata."}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] DNS" $successColor;Flush-LogBuffer;Pump-UI }
function Do-RenewIP { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] IP..." $networkColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Rinnovo IP";Log "===============================================================================================";try{& ipconfig /release 2>&1|Out-Null;Pump-UI;Start-Sleep 2;Pump-UI;$o=& ipconfig /renew 2>&1;Log-Output $o;Log "[OK] IP rinnovato."}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] IP" $successColor;Flush-LogBuffer;Pump-UI }

function Do-InfoIP {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Info..." $infoColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] Info Rete"
    Log "==============================================================================================="

    # --- Ottieni IP pubblico ---
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5 -ErrorAction Stop
        Log " [🌐] IP Pubblico : $publicIP"
    } catch {
        Log " [🌐] IP Pubblico : non rilevato (verifica connessione)"
    }
    Log ""

    try {
        $o = & ipconfig /all 2>&1
        foreach($l in $o) { Log " $l" }
    } catch {
        Log "[X] $($_.Exception.Message)"
    }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Info" $successColor
    Flush-LogBuffer;Pump-UI
}

function Do-ResetWinsock { if($script:isClosing -or(Test-Cancel)){return};if(-not $isAdmin){Log "[X] Admin.";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;Update-Progress 100;return};Update-Status "[...] Winsock..." $networkColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Winsock Reset";Log "===============================================================================================";try{& netsh winsock reset 2>&1|Out-Null;& netsh int ip reset 2>&1|Out-Null;Log "[OK] Reset. Riavvio consigliato."}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] Winsock" $successColor;Flush-LogBuffer;Pump-UI }
function Do-NetworkReset {
    if($script:isClosing -or(Test-Cancel)){return}
    if(-not $isAdmin){Log "[X] Admin richiesto";Update-Progress 100;return}
    Update-Status "[...] Reset Rete..." $networkColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] RESET COMPLETO RETE"
    Log "==============================================================================================="
    $backupDir = Join-Path $env:TEMP "network_backup_$(Get-Date -Format 'yyyyMMdd')"
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    netsh interface show interface > "$backupDir\interfaces.txt"
    ipconfig /all > "$backupDir\ipconfig.txt"
    Log "[OK] Backup salvato in $backupDir"
    $commands = @(
        @{cmd="netsh winsock reset"; desc="Winsock"},
        @{cmd="netsh int ip reset"; desc="TCP/IP"},
        @{cmd="netsh int ipv6 reset"; desc="IPv6"},
        @{cmd="ipconfig /flushdns"; desc="DNS Cache"},
        @{cmd="netsh winhttp reset proxy"; desc="Proxy"},
        @{cmd="netsh int tcp set global autotuninglevel=normal"; desc="TCP AutoTuning"}
    )
    foreach($c in $commands) {
        Log "[>] Reset $($c.desc)..."
        & cmd /c $c.cmd 2>&1 | Out-Null
        Pump-UI; Start-Sleep -Milliseconds 300
    }
    Log "";Log "[OK] Reset completato. Riavvio consigliato."
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Reset rete" $successColor
    Flush-LogBuffer;Pump-UI
}
function Do-WifiPasswords { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Wi-Fi..." $networkColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Password Wi-Fi";Log "===============================================================================================";try{$profiles=& netsh wlan show profiles 2>&1;$pm=$profiles|Select-String "Tutti i profili utente\s*:\s*(.+)$|Profilo tutti gli utenti\s*:\s*(.+)$|All User Profile\s*:\s*(.+)$|User Profile\s*:\s*(.+)$|Profile\s*:\s*(.+)$";if(-not $pm){Log "[i] Nessun profilo.";Log "===============================================================================================";Update-Progress 100;Update-Status "[OK]" $successColor;Flush-LogBuffer;Pump-UI;return};$names=foreach($m in $pm){$m.Matches[0].Groups|Where-Object{$_.Value -and $_.Value.Trim() -ne ""}|Select-Object -Skip 1 -First 1|ForEach-Object{$_.Value.Trim()}};Log "[OK] $($names.Count) reti:";Log "";foreach($n in $names){if(Test-Cancel){return};$d=& netsh wlan show profile name="$n" key=clear 2>&1;$kl=($d|Select-String "Contenuto chiave\s*:\s*(.+)$|Key Content\s*:\s*(.+)$");$pw="N/D";if($kl){$match=$kl.Matches[0];$p1=$match.Groups[1].Value.Trim();$p2=$match.Groups[2].Value.Trim();if($p1){$pw=$p1}elseif($p2){$pw=$p2}};Log " $n : $pw";Pump-UI}}catch{Log "[X] $($_.Exception.Message)"};Log "";Log "===============================================================================================";Update-Progress 100;Update-Status "[OK] Wi-Fi" $successColor;Flush-LogBuffer;Pump-UI }
function Do-SpeedTest { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Ping..." $networkColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Ping Test";Log "===============================================================================================";$targets=@(@{N="Google";I="8.8.8.8"},@{N="Cloudflare";I="1.1.1.1"},@{N="OpenDNS";I="208.67.222.222"});foreach($t in $targets){if(Test-Cancel){return};try{$ping=Test-Connection -ComputerName $t.I -Count 3 -ErrorAction Stop;$prop=$script:pingProperty;$avg=[Math]::Round(($ping|Measure-Object -Property $prop -Average).Average,1);Log " $($t.N): ${avg}ms"}catch{Log " [X] $($t.N)"};Pump-UI};Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] Ping" $successColor;Flush-LogBuffer;Pump-UI }
function Do-SpeedInternet { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Speedtest..." $networkColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Speedtest Cloudflare";Log "===============================================================================================";[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;$latency=0;try{$sw=[System.Diagnostics.Stopwatch]::StartNew();Invoke-WebRequest -Uri "https://speed.cloudflare.com/__down?bytes=0" -Method Get -TimeoutSec 5 -UseBasicParsing|Out-Null;$sw.Stop();$latency=[Math]::Round($sw.Elapsed.TotalMilliseconds,1);Log " Ping: ${latency}ms"}catch{};Flush-LogBuffer;Pump-UI;if(Test-Cancel){return};$dl=0;try{$sw=[System.Diagnostics.Stopwatch]::StartNew();$data=Invoke-WebRequest -Uri "https://speed.cloudflare.com/__down?bytes=20000000" -Method Get -TimeoutSec 30 -UseBasicParsing;$sw.Stop();$bytes=$data.RawContentLength;if($bytes -and $sw.Elapsed.TotalSeconds -gt 0){$dl=[Math]::Round((($bytes*8)/1MB)/$sw.Elapsed.TotalSeconds,2)};Log " DL: ${dl} Mbps"}catch{};Flush-LogBuffer;Pump-UI;if(Test-Cancel){return};$ul=0;try{$buf=New-Object byte[](5MB);(New-Object Random).NextBytes($buf);$sw=[System.Diagnostics.Stopwatch]::StartNew();Invoke-WebRequest -Uri "https://speed.cloudflare.com/__up" -Method Post -Body $buf -TimeoutSec 30 -UseBasicParsing|Out-Null;$sw.Stop();if($sw.Elapsed.TotalSeconds -gt 0){$ul=[Math]::Round((5*8)/$sw.Elapsed.TotalSeconds,2)};Log " UP: ${ul} Mbps"}catch{};Log "";Log " Ping ${latency}ms | DL ${dl} | UP ${ul} Mbps";Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] DL $dl / UP $ul" $successColor;Flush-LogBuffer;Pump-UI }

function Do-SpeedOokla {
    if ($script:isClosing -or (Test-Cancel)) { return }

    Update-Status "[...] Speedtest Ookla..." $networkColor
    Flush-LogBuffer; Pump-UI

    Log ""; Log "==============================================================================================="
    Log "[>] SPEEDTEST OOKLA (dettagliato)"
    Log "==============================================================================================="

    # --- Ottieni IP pubblico ---
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $publicIP = Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5 -ErrorAction Stop
        Log " [🌐] IP Pubblico : $publicIP"
    } catch {
        Log " [🌐] IP Pubblico : non rilevato (verifica connessione)"
    }
    Log ""

    # --- Cerca speedtest.exe in lib ---
    $speedtestExe = Join-Path $scriptRoot "lib" "speedtest.exe"
    if (-not (Test-Path $speedtestExe)) {
        Log "[!] speedtest.exe non trovato in $scriptRoot\lib"
        Log "[i] Esegui 'Full Update' per scaricare i file necessari."
        Update-Status "[X] speedtest.exe mancante" $exitColor
        Flush-LogBuffer; Pump-UI
        Update-Progress 100
        return
    }

    # --- Esegui speedtest con output JSON ---
    try {
        Log "[>] Avvio test (potrebbe richiedere 20-30 secondi)..."
        Flush-LogBuffer; Pump-UI

        $process = Start-Process -FilePath $speedtestExe -ArgumentList "--accept-license --accept-gdpr --format=json" -Wait -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\speedtest_output.json"
        if ($process.ExitCode -ne 0) {
            Log "[X] Errore nell'esecuzione di speedtest (codice: $($process.ExitCode))"
            Update-Status "[X] Errore speedtest" $exitColor
            Flush-LogBuffer; Pump-UI
            Update-Progress 100
            return
        }

        # --- Leggi e parsifica l'output JSON ---
        $json = Get-Content "$env:TEMP\speedtest_output.json" -Raw | ConvertFrom-Json
        if (-not $json) {
            Log "[X] Impossibile leggere i risultati."
            Update-Status "[X] Errore parsing" $exitColor
            Update-Progress 100
            return
        }

        # Estrai i dati principali
        $downloadBps = $json.download.bandwidth
        $uploadBps   = $json.upload.bandwidth
        $latencyMs   = $json.ping.latency
        $jitterMs    = $json.ping.jitter
        $packetLoss  = $json.packetLoss * 100  # Converti in percentuale
        $serverName  = $json.server.name
        $serverLoc   = "$($json.server.location), $($json.server.country)"
        $isp         = $json.isp

        # Converti in Mbps (1 byte = 8 bit, 1 Mbps = 1.000.000 bit/s)
        $downloadMbps = [Math]::Round($downloadBps * 8 / 1e6, 2)
        $uploadMbps   = [Math]::Round($uploadBps * 8 / 1e6, 2)

        # Mostra risultati nel log
        Log ""
        Log "[OK] RISULTATI SPEEDTEST OOKLA"
        Log "─────────────────────────────────────────────"
        Log " Server      : $serverName ($serverLoc)"
        Log " Provider    : $isp"
        Log " Download    : $downloadMbps Mbps"
        Log " Upload      : $uploadMbps Mbps"
        Log " Latenza     : $latencyMs ms"
        Log " Jitter      : $jitterMs ms"
        Log " Packet Loss : $([Math]::Round($packetLoss, 2))%"
        Log "─────────────────────────────────────────────"
        Log ""

        Update-Status "[OK] DL $downloadMbps / UP $uploadMbps Mbps" $successColor

    } catch {
        Log "[X] Errore durante il test: $($_.Exception.Message)"
        Update-Status "[X] Errore" $exitColor
    }

    # Pulizia file temporaneo
    try { Remove-Item "$env:TEMP\speedtest_output.json" -Force -ErrorAction SilentlyContinue } catch {}

    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}


function Do-Traceroute {
    if ($script:isClosing -or (Test-Cancel)) { return }

    # Popup per inserire target (altezza aumentata a 170)
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Traceroute - Inserisci destinazione"
    $inputForm.Size = New-Object System.Drawing.Size(400, 180)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = $bgColor
    $inputForm.ForeColor = $fgColor
    $inputForm.TopMost = $true

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inserisci indirizzo IP o dominio da tracciare:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(340, 22)
    $lbl.ForeColor = $fgColor
    $inputForm.Controls.Add($lbl)

    $txtTarget = New-Object System.Windows.Forms.TextBox
    $txtTarget.Text = "8.8.8.8"
    $txtTarget.Location = New-Object System.Drawing.Point(20, 50)
    $txtTarget.Size = New-Object System.Drawing.Size(340, 26)
    $txtTarget.Font = New-Object System.Drawing.Font("Consolas", 12)
    $txtTarget.BackColor = $bgCard
    $txtTarget.ForeColor = $fgColor
    $inputForm.Controls.Add($txtTarget)

    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Avvia"
    $btnOK.Location = New-Object System.Drawing.Point(20, 95)
    $btnOK.Size = New-Object System.Drawing.Size(100, 32)
    $btnOK.BackColor = $accentColor
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140, 95)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 32)
    $btnCancel.BackColor = $exitColor
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

    # --- Esegui traceroute con output in tempo reale ---
    Update-Status "[...] Traceroute verso $target..." $networkColor
    Flush-LogBuffer; Pump-UI

    Log ""; Log "==============================================================================================="
    Log "[>] TRACEROUTE VERSO $target"
    Log "==============================================================================================="

    # Usa Run-ProcessRealtime per mostrare l'output in tempo reale
    Run-ProcessRealtime "tracert" $target "Traceroute verso $target" 0 100

    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Traceroute completato" $successColor
    Flush-LogBuffer; Pump-UI
}

function Do-ChangeDNS {
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $isAdmin) {
        Log "[X] Per cambiare i DNS servono privilegi amministrativi."
        Update-Status "[!] Admin richiesto" $warningColor
        Flush-LogBuffer; Pump-UI
        Update-Progress 100
        return
    }

    # --- Popup per selezionare DNS ---
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Cambia Server DNS"
    $inputForm.Size = New-Object System.Drawing.Size(450, 280)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = $bgColor
    $inputForm.ForeColor = $fgColor
    $inputForm.TopMost = $true

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Seleziona il provider DNS:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(390, 22)
    $lbl.ForeColor = $fgColor
    $inputForm.Controls.Add($lbl)

    # --- ComboBox per i provider ---
    $cmbProviders = New-Object System.Windows.Forms.ComboBox
    $cmbProviders.Location = New-Object System.Drawing.Point(20, 50)
    $cmbProviders.Size = New-Object System.Drawing.Size(390, 26)
    $cmbProviders.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbProviders.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $cmbProviders.BackColor = $bgCard
    $cmbProviders.ForeColor = $fgColor
    $cmbProviders.Items.AddRange(@(
        "Google DNS (8.8.8.8, 8.8.4.4)",
        "Cloudflare DNS (1.1.1.1, 1.0.0.1)",
        "OpenDNS (208.67.222.222, 208.67.220.220)",
        "Quad9 (9.9.9.9, 149.112.112.112)",
        "Personalizzato (inserisci manualmente)"
    ))
    $cmbProviders.SelectedIndex = 0
    $inputForm.Controls.Add($cmbProviders)

    # --- Campi per DNS personalizzato (inizialmente nascosti) ---
    $lblCustom = New-Object System.Windows.Forms.Label
    $lblCustom.Text = "DNS Primario:"
    $lblCustom.Location = New-Object System.Drawing.Point(20, 95)
    $lblCustom.Size = New-Object System.Drawing.Size(150, 22)
    $lblCustom.ForeColor = $fgColor
    $lblCustom.Visible = $false
    $inputForm.Controls.Add($lblCustom)

    $txtPrimary = New-Object System.Windows.Forms.TextBox
    $txtPrimary.Location = New-Object System.Drawing.Point(20, 125)
    $txtPrimary.Size = New-Object System.Drawing.Size(180, 26)
    $txtPrimary.Font = New-Object System.Drawing.Font("Consolas", 12)
    $txtPrimary.BackColor = $bgCard
    $txtPrimary.ForeColor = $fgColor
    $txtPrimary.Visible = $false
    $inputForm.Controls.Add($txtPrimary)

    $lblCustom2 = New-Object System.Windows.Forms.Label
    $lblCustom2.Text = "DNS Secondario:"
    $lblCustom2.Location = New-Object System.Drawing.Point(220, 95)
    $lblCustom2.Size = New-Object System.Drawing.Size(150, 22)
    $lblCustom2.ForeColor = $fgColor
    $lblCustom2.Visible = $false
    $inputForm.Controls.Add($lblCustom2)

    $txtSecondary = New-Object System.Windows.Forms.TextBox
    $txtSecondary.Location = New-Object System.Drawing.Point(220, 125)
    $txtSecondary.Size = New-Object System.Drawing.Size(180, 26)
    $txtSecondary.Font = New-Object System.Drawing.Font("Consolas", 12)
    $txtSecondary.BackColor = $bgCard
    $txtSecondary.ForeColor = $fgColor
    $txtSecondary.Visible = $false
    $inputForm.Controls.Add($txtSecondary)

    # --- Mostra/nascondi campi personalizzati in base alla selezione ---
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
    $btnOK.BackColor = $accentColor
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140, 175)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 32)
    $btnCancel.BackColor = $exitColor
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

    # --- Determina DNS da impostare ---
    $selected = $cmbProviders.SelectedItem
    $dnsPrimary = $null
    $dnsSecondary = $null

    if ($selected -eq "Google DNS (8.8.8.8, 8.8.4.4)") {
        $dnsPrimary = "8.8.8.8"; $dnsSecondary = "8.8.4.4"
    } elseif ($selected -eq "Cloudflare DNS (1.1.1.1, 1.0.0.1)") {
        $dnsPrimary = "1.1.1.1"; $dnsSecondary = "1.0.0.1"
    } elseif ($selected -eq "OpenDNS (208.67.222.222, 208.67.220.220)") {
        $dnsPrimary = "208.67.222.222"; $dnsSecondary = "208.67.220.220"
    } elseif ($selected -eq "Quad9 (9.9.9.9, 149.112.112.112)") {
        $dnsPrimary = "9.9.9.9"; $dnsSecondary = "149.112.112.112"
    } elseif ($selected -eq "Personalizzato (inserisci manualmente)") {
        $dnsPrimary = $txtPrimary.Text.Trim()
        $dnsSecondary = $txtSecondary.Text.Trim()
        if (-not $dnsPrimary) {
            Log "[X] DNS primario non inserito."
            Update-Progress 100
            return
        }
        # Validazione base (IP)
        if ($dnsPrimary -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            Log "[X] DNS primario non valido: $dnsPrimary"
            Update-Progress 100
            return
        }
        if ($dnsSecondary -and $dnsSecondary -notmatch '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            Log "[X] DNS secondario non valido: $dnsSecondary"
            Update-Progress 100
            return
        }
    }

    # --- Applica DNS a tutte le schede di rete attive ---
    Update-Status "[...] Cambio DNS in corso..." $networkColor
    Flush-LogBuffer; Pump-UI

    Log ""; Log "==============================================================================================="
    Log "[>] CAMBIO DNS"
    Log "==============================================================================================="
    Log "[i] DNS Primario    : $dnsPrimary"
    Log "[i] DNS Secondario  : $dnsSecondary"

    try {
        # Ottieni le schede di rete con indirizzo IP (escludi quelle virtuali o disconnesse)
        $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
        if (-not $adapters) {
            Log "[X] Nessuna scheda di rete attiva trovata."
            Update-Status "[X] Nessuna scheda" $exitColor
            Update-Progress 100
            return
        }

        $modified = 0
        foreach ($adapter in $adapters) {
            try {
                # Imposta i DNS
                if ($dnsPrimary) {
                    Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses @($dnsPrimary, $dnsSecondary) -ErrorAction Stop
                    Log "[OK] $($adapter.Name): DNS impostati a $dnsPrimary, $dnsSecondary"
                    $modified++
                }
            } catch {
                Log "[!] $($adapter.Name): $($_.Exception.Message)"
            }
            Pump-UI
        }

        if ($modified -gt 0) {
            Log "[OK] DNS cambiati su $modified scheda(e)."

            # Flush DNS per rendere effettive le modifiche
            Log "[>] Flush DNS..."
            & ipconfig /flushdns 2>&1 | Out-Null
            Log "[OK] Cache DNS svuotata."
        } else {
            Log "[!] Nessuna scheda modificata."
        }
    } catch {
        Log "[X] Errore durante il cambio DNS: $($_.Exception.Message)"
        Update-Status "[X] Errore" $exitColor
    }

    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] DNS cambiati" $successColor
    Flush-LogBuffer; Pump-UI
}



function Do-Whois {
    if ($script:isClosing -or (Test-Cancel)) { return }

    # --- Popup per inserire target ---
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Whois - Inserisci IP o dominio"
    $inputForm.Size = New-Object System.Drawing.Size(420, 180)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = $bgColor
    $inputForm.ForeColor = $fgColor
    $inputForm.TopMost = $true

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inserisci indirizzo IP o dominio:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(360, 22)
    $lbl.ForeColor = $fgColor
    $inputForm.Controls.Add($lbl)

    $txtTarget = New-Object System.Windows.Forms.TextBox
    $txtTarget.Text = "google.com"
    $txtTarget.Location = New-Object System.Drawing.Point(20, 50)
    $txtTarget.Size = New-Object System.Drawing.Size(360, 26)
    $txtTarget.Font = New-Object System.Drawing.Font("Consolas", 12)
    $txtTarget.BackColor = $bgCard
    $txtTarget.ForeColor = $fgColor
    $inputForm.Controls.Add($txtTarget)

    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Cerca"
    $btnOK.Location = New-Object System.Drawing.Point(20, 90)
    $btnOK.Size = New-Object System.Drawing.Size(100, 32)
    $btnOK.BackColor = $accentColor
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140, 90)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 32)
    $btnCancel.BackColor = $exitColor
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

    # --- Esegui whois ---
    Update-Status "[...] Whois su $target..." $networkColor
    Flush-LogBuffer; Pump-UI

    Log ""; Log "==============================================================================================="
    Log "[>] WHOIS - $target"
    Log "==============================================================================================="

    $whoisSuccess = $false
    $isIP = $target -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'

    # --- Se è un IP, vai direttamente a ipinfo.io ---
    if ($isIP) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $url = "https://ipinfo.io/$target/json"
            $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop

            if ($response -and $response.ip) {
                $whoisSuccess = $true
                Log ""
                Log " [OK] Informazioni su $target (IP)"
                Log " ─────────────────────────────────────────────"
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
                Log " ─────────────────────────────────────────────"
                Log ""
            }
        } catch {
            Log "[X] Errore durante la richiesta per l'IP: $($_.Exception.Message)"
        }
    }

    # --- Se NON è un IP, prova RDAP per il dominio ---
    if (-not $whoisSuccess -and -not $isIP) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            # Tenta RDAP
            $bootstrapUrl = "https://data.iana.org/rdap/dns.json"
            $bootstrap = Invoke-RestMethod -Uri $bootstrapUrl -Method Get -TimeoutSec 10 -ErrorAction Stop

            $parts = $target -split '\.'
            $tld = $parts[-1]

            $rdapServer = $null
            foreach ($service in $bootstrap.services) {
                $tlds = $service[0]
                $urls = $service[1]
                if ($tlds -contains $tld) {
                    $rdapServer = $urls[0]
                    break
                }
            }

            # Fallback hardcodato
            if (-not $rdapServer) {
                $fallbackServers = @{
                    "com" = "https://rdap.verisign.com/com/v1/"
                    "net" = "https://rdap.verisign.com/net/v1/"
                    "org" = "https://rdap.publicinterestregistry.org/v1/"
                    "it"  = "https://rdap.nic.it/"
                    "uk"  = "https://rdap.nominet.uk/"
                    "eu"  = "https://rdap.eu/"
                    "fr"  = "https://rdap.nic.fr/"
                    "de"  = "https://rdap.denic.de/"
                    "nl"  = "https://rdap.sidn.nl/"
                    "ch"  = "https://rdap.nic.ch/"
                    "be"  = "https://rdap.dns.be/"
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

                # Se arriviamo qui, RDAP ha funzionato
                $whoisSuccess = $true
                Log ""
                Log " [OK] Informazioni su $target (RDAP)"
                Log " ─────────────────────────────────────────────"
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
                Log " ─────────────────────────────────────────────"
                Log ""
            }
        } catch {
            # RDAP fallito, passiamo al fallback con risoluzione IP
            if (-not $whoisSuccess) {
                Log "[!] RDAP non disponibile, risolvo IP e provo con ipinfo.io..."
            }
        }
    }

    # --- Fallback: risolvi il dominio in IP e usa ipinfo.io ---
    if (-not $whoisSuccess -and -not $isIP) {
        try {
            Log "[>] Risoluzione IP del dominio..."
            
            # Usa nslookup per risolvere l'IP
            $nslookup = & nslookup $target 2>&1
            $ipLines = $nslookup | Select-String -Pattern "Addresses:|Address:" | Select-Object -Last 1
            
            if ($ipLines) {
                # Estrai l'IP (prende l'ultimo IP nella riga)
                $ipMatch = [regex]::Match($ipLines, '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')
                if ($ipMatch.Success) {
                    $resolvedIP = $ipMatch.Value
                    Log "[OK] IP risolto: $resolvedIP"
                    Log "[>] Whois sull'IP..."

                    # Whois sull'IP con ipinfo.io
                    $url = "https://ipinfo.io/$resolvedIP/json"
                    $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -ErrorAction Stop

                    if ($response -and $response.ip) {
                        $whoisSuccess = $true
                        Log ""
                        Log " [OK] Informazioni su $target (tramite IP $resolvedIP)"
                        Log " ─────────────────────────────────────────────"
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
                        Log " ─────────────────────────────────────────────"
                        Log ""
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
        Update-Status "[X] Errore whois" $exitColor
    }

    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Update-Status "[OK] Whois completato" $successColor
    Flush-LogBuffer; Pump-UI
}


function Do-BlacklistCheck {
    if ($script:isClosing -or (Test-Cancel)) { return }

    # --- Helper interno per scrivere con colori parziali nella RichTextBox ---
    function Log-Color {
        param(
            [string]$TextBefore,
            [string]$TextToColor,
            [string]$TextAfter = "",
            [System.Drawing.Color]$Color
        )
        # >>> ATTENZIONE: Cambia '$script:logBox' con il nome della tua variabile RichTextBox <<<
        $rtb = $script:logBox 
        
        if ($rtb -and $rtb.GetType().Name -eq "RichTextBox") {
            $rtb.AppendText($TextBefore)
            $startIdx = $rtb.TextLength
            $rtb.AppendText($TextToColor)
            $rtb.Select($startIdx, $TextToColor.Length)
            $rtb.SelectionColor = $Color
            $rtb.SelectionLength = 0
            $rtb.SelectionColor = $fgColor
            $rtb.AppendText($TextAfter + "`r`n")
            $rtb.ScrollToCaret()
        } else {
            Log "$TextBefore$TextToColor$TextAfter"
        }
    }

    # --- Popup per inserire target ---
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Blacklist Check - Inserisci dominio o IP"
    $inputForm.Size = New-Object System.Drawing.Size(420, 180)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = $bgColor
    $inputForm.ForeColor = $fgColor
    $inputForm.TopMost = $true

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inserisci dominio o IP da verificare:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(360, 22)
    $lbl.ForeColor = $fgColor
    $inputForm.Controls.Add($lbl)

    $txtTarget = New-Object System.Windows.Forms.TextBox
    $txtTarget.Text = "google.com"
    $txtTarget.Location = New-Object System.Drawing.Point(20, 50)
    $txtTarget.Size = New-Object System.Drawing.Size(360, 26)
    $txtTarget.Font = New-Object System.Drawing.Font("Consolas", 12)
    $txtTarget.BackColor = $bgCard
    $txtTarget.ForeColor = $fgColor
    $inputForm.Controls.Add($txtTarget)

    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Verifica"
    $btnOK.Location = New-Object System.Drawing.Point(20, 90)
    $btnOK.Size = New-Object System.Drawing.Size(100, 32)
    $btnOK.BackColor = $accentColor
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140, 90)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 32)
    $btnCancel.BackColor = $exitColor
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

    Update-Status "[...] Verifica blacklist per $target..." $securityColor
    Flush-LogBuffer; Pump-UI

    Log ""; Log "==============================================================================================="
    Log "[>] BLACKLIST CHECK Attendere - $target"
    Log "==============================================================================================="





# --- INSTALLAZIONE SILENT DEI MODULI (da PSGallery e GitHub) ---

# 1. Imposta PSGallery come trusted
try {
    $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($repo -and $repo.InstallationPolicy -ne "Trusted") {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
        Log "[OK] PSGallery impostata come trusted."
    }
} catch { Log "[!] Impossibile impostare PSGallery come trusted." }

# 2. PSWriteColor (da GitHub - dipendenza di PSBlackListChecker)
$pswritecolorModule = Get-Module -Name PSWriteColor -ListAvailable -ErrorAction SilentlyContinue
if (-not $pswritecolorModule) {
    Log "[!] PSWriteColor non trovato. Installazione da GitHub..."
    try {
        $url = "https://github.com/EvotecIT/PSWriteColor/archive/refs/heads/master.zip"
        $zipPath = "$env:TEMP\PSWriteColor.zip"
        Log "[DL] Download PSWriteColor da GitHub..."
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        $extractPath = "$env:TEMP\PSWriteColor"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force -ErrorAction Stop
        
        $baseFolder = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
        if ($baseFolder) {
            $sourcePath = $baseFolder.FullName
            # Cerca il modulo nelle sottocartelle comuni
            foreach ($sub in @("PSWriteColor", "src", "Module")) {
                $testPath = Join-Path $baseFolder.FullName $sub
                if (Test-Path $testPath) {
                    $sourcePath = $testPath
                    break
                }
            }
            $modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\PSWriteColor"
            New-Item -ItemType Directory -Force -Path $modulePath | Out-Null
            Copy-Item -Path "$sourcePath\*" -Destination $modulePath -Recurse -Force
            Log "[OK] PSWriteColor installato da GitHub"
        }
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        $pswritecolorModule = Get-Module -Name PSWriteColor -ListAvailable -ErrorAction SilentlyContinue
        if ($pswritecolorModule) { Log "[OK] PSWriteColor installato (v$($pswritecolorModule.Version))" }
    } catch {
        Log "[X] Errore installazione PSWriteColor: $($_.Exception.Message)"
        $pswritecolorModule = $null
    }
} else {
    Log "[OK] PSWriteColor già installato (v$($pswritecolorModule.Version))"
}

# 3. PSTeams (da GitHub perché non più disponibile su PSGallery)
$psteamsModule = Get-Module -Name PSTeams -ListAvailable -ErrorAction SilentlyContinue
if (-not $psteamsModule) {
    Log "[!] PSTeams non trovato. Installazione da GitHub..."
    try {
        $url = "https://github.com/EvotecIT/PSTeams/archive/refs/heads/master.zip"
        $zipPath = "$env:TEMP\PSTeams.zip"
        Log "[DL] Download PSTeams da GitHub..."
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        $extractPath = "$env:TEMP\PSTeams"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force -ErrorAction Stop
        $sourcePath = Join-Path $extractPath "PSTeams-main\Module\PSTeams"
        if (Test-Path $sourcePath) {
            $modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\PSTeams"
            New-Item -ItemType Directory -Force -Path $modulePath | Out-Null
            Copy-Item -Path "$sourcePath\*" -Destination $modulePath -Recurse -Force
            Log "[OK] PSTeams installato da GitHub"
        }
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        $psteamsModule = Get-Module -Name PSTeams -ListAvailable -ErrorAction SilentlyContinue
        if ($psteamsModule) { Log "[OK] PSTeams installato (v$($psteamsModule.Version))" }
    } catch {
        Log "[X] Errore installazione PSTeams: $($_.Exception.Message)"
        $psteamsModule = $null
    }
} else {
    Log "[OK] PSTeams già installato (v$($psteamsModule.Version))"
}

# 4. PSSharedGoods (da PSGallery, silent)
if ($psteamsModule) {
    $sharedGoods = Get-Module -Name PSSharedGoods -ListAvailable -ErrorAction SilentlyContinue
    if (-not $sharedGoods) {
        Log "[!] PSSharedGoods non trovato. Installazione silent da PSGallery..."
        try {
            Install-Module -Name PSSharedGoods -Scope CurrentUser -Force -AcceptLicense -SkipPublisherCheck -ErrorAction Stop
            Log "[OK] PSSharedGoods installato da PSGallery"
        } catch {
            Log "[!] PSSharedGoods non installato: $($_.Exception.Message)"
        }
    } else {
        Log "[OK] PSSharedGoods già installato (v$($sharedGoods.Version))"
    }
}

# 5. PSSlack (da PSGallery, silent)
if ($psteamsModule) {
    $psslack = Get-Module -Name PSSlack -ListAvailable -ErrorAction SilentlyContinue
    if (-not $psslack) {
        Log "[!] PSSlack non trovato. Installazione silent da PSGallery..."
        try {
            Install-Module -Name PSSlack -Scope CurrentUser -Force -AcceptLicense -SkipPublisherCheck -ErrorAction Stop
            Log "[OK] PSSlack installato da PSGallery"
        } catch {
            Log "[!] PSSlack non installato: $($_.Exception.Message)"
        }
    } else {
        Log "[OK] PSSlack già installato (v$($psslack.Version))"
    }
}

# 6. PSBlackListChecker (da GitHub perché dipende da PSTeams)
$module = Get-Module -Name PSBlackListChecker -ListAvailable -ErrorAction SilentlyContinue
if (-not $module -and $psteamsModule -and $pswritecolorModule) {
    Log "[!] PSBlackListChecker non trovato. Installazione da GitHub..."
    try {
        $url = "https://github.com/EvotecIT/PSBlackListChecker/archive/refs/heads/master.zip"
        $zipPath = "$env:TEMP\PSBlackListChecker.zip"
        Log "[DL] Download PSBlackListChecker da GitHub..."
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        $extractPath = "$env:TEMP\PSBlackListChecker"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force -ErrorAction Stop
        
        $baseFolder = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
        if ($baseFolder) {
            $sourcePath = $baseFolder.FullName
            foreach ($sub in @("PSBlackListChecker", "src", "Module")) {
                $testPath = Join-Path $baseFolder.FullName $sub
                if (Test-Path $testPath) {
                    $sourcePath = $testPath
                    break
                }
            }
            $modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\PSBlackListChecker"
            New-Item -ItemType Directory -Force -Path $modulePath | Out-Null
            Copy-Item -Path "$sourcePath\*" -Destination $modulePath -Recurse -Force
            Log "[OK] PSBlackListChecker installato da GitHub"
        }
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        $module = Get-Module -Name PSBlackListChecker -ListAvailable -ErrorAction SilentlyContinue
        if ($module) { Log "[OK] PSBlackListChecker installato (v$($module.Version))" }
    } catch {
        Log "[X] Errore installazione PSBlackListChecker: $($_.Exception.Message)"
        $module = $null
    }
} elseif ($module) {
    Log "[OK] PSBlackListChecker già installato (v$($module.Version))"
} else {
    Log "[!] PSTeams o PSWriteColor non disponibili. PSBlackListChecker non installabile."
    Log "[i] Continuo con controlli manuali."
}

# 7. Importa tutti i moduli per verificarli
if ($module) {
    try {
        Import-Module -Name PSBlackListChecker -Force -ErrorAction Stop
        Log "[OK] PSBlackListChecker importato correttamente."
    } catch {
        Log "[!] Errore importazione PSBlackListChecker: $($_.Exception.Message)"
        Log "[i] Continuo con controlli manuali."
        $module = $null
    }
}

#Fine installazione moduli


    # --- Risolvi l'IP ---
    $isIP = $target -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'
    if ($isIP) { $ipToCheck = $target } 
    else {
        try {
            $dnsResult = Resolve-DnsName -Name $target -Type A -ErrorAction Stop
            $ipToCheck = if ($dnsResult -is [System.Array]) { $dnsResult[0].IPAddress } else { $dnsResult.IPAddress }
        } catch {
            Log "[X] Errore risoluzione DNS: $($_.Exception.Message)"
            Update-Status "[X] Errore DNS" $exitColor; Update-Progress 100; return
        }
    }

    # =====================================================================
    # SEZIONE 1: PSBlackListChecker
    # =====================================================================
    $moduleSuccess = $false; $moduleListCount = 0; $moduleListed = 0
    $module = Get-Module -Name PSBlackListChecker -ListAvailable -ErrorAction SilentlyContinue
    
    if ($module) {
        Log ""; Log " [📋] CONTROLLO CON PSBlackListChecker"; Log " ─────────────────────────────────────────────────────────────"
        try {
            Import-Module PSBlackListChecker -Force -ErrorAction Stop
            $results = Search-BlackList -IP $ipToCheck -ReturnAll -ErrorAction Stop
            if ($null -ne $results -and $results.Count -gt 0) {
                $moduleListCount = $results.Count
                foreach ($entry in ($results | Sort-Object -Property IsListed -Descending)) {
                    $listName = if ($entry.BlackList) { $entry.BlackList } else { $entry.BlacklistName }
                    $isListed = [bool]$entry.IsListed
                    if ($isListed) { Log-Color -TextBefore " [⚠️] $($listName.Trim()) : " -TextToColor "SEGNALATO" -Color ([System.Drawing.Color]::Red); $moduleListed++ }
                    else { Log-Color -TextBefore " [✅] $($listName.Trim()) : " -TextToColor "PULITO" -Color ([System.Drawing.Color]::Green) }
                    Pump-UI
                }
                $moduleSuccess = $true
            }
        } catch { Log "[!] Errore PSBlackListChecker: $($_.Exception.Message)" }
    }

    # =====================================================================
    # SEZIONE 2: CONTROLLO MANUALE ESTESO
    # =====================================================================
    Log ""; Log " [📋] CONTROLLO MANUALE ESTESO (Top 16)"; Log " ─────────────────────────────────────────────────────────────"
    $fallbackLists = @(
        @{Name="Spamhaus ZEN"; QuerySuffix="zen.spamhaus.org"}, @{Name="Spamhaus DBL"; QuerySuffix="dbl.spamhaus.org"},
        @{Name="SpamCop"; QuerySuffix="bl.spamcop.net"}, @{Name="SORBS"; QuerySuffix="dnsbl.sorbs.net"},
        @{Name="Barracuda"; QuerySuffix="b.barracudacentral.org"}, @{Name="UCEPROTECT L1"; QuerySuffix="l1.uceprotect.net"},
        @{Name="UCEPROTECT L2"; QuerySuffix="l2.uceprotect.net"}, @{Name="SANS EDU"; QuerySuffix="isc.sans.edu"},
        @{Name="DNSBL FR"; QuerySuffix="dnsbl.spam-rbl.fr"}, @{Name="Mailspike BL"; QuerySuffix="bl.mailspike.net"},
        @{Name="RATS Dyna"; QuerySuffix="rats-dyn.spamrats.com"}, @{Name="RATS Spam"; QuerySuffix="spam.spamrats.com"},
        @{Name="SEM Black"; QuerySuffix="bl.semblack.com"}, @{Name="Abuse.ro"; QuerySuffix="abuse.ro"},
        @{Name="DRONE BL"; QuerySuffix="dnsbl.dronebl.org"}, @{Name="Nix Spam"; QuerySuffix="ix.dnsbl.manitu.net"}
    )
    $ipInvertito = ($ipToCheck -split '\.')[-1..0] -join '.'; $manualListed = 0; $manualCount = $fallbackLists.Count

    foreach ($list in $fallbackLists) {
        try {
            $null = Resolve-DnsName -Name "$ipInvertito.$($list.QuerySuffix)" -Type A -ErrorAction Stop -DnsOnly -QuickTimeout
            Log-Color -TextBefore " [⚠️] $($list.Name) : " -TextToColor "SEGNALATO" -Color ([System.Drawing.Color]::Red); $manualListed++
        } catch { Log-Color -TextBefore " [✅] $($list.Name) : " -TextToColor "PULITO" -Color ([System.Drawing.Color]::Green) }
        Pump-UI
    }

    # =====================================================================
    # SEZIONE 3: CONTROLLO WEB MULTIRBL.VALLI.ORG (Super Robusto)
    # =====================================================================
    Log ""; Log " [🌐] CONTROLLO WEB SU MULTIRBL.VALLI.ORG"; Log " ─────────────────────────────────────────────────────────────"
    Log "[>] Download e analisi pagina web in corso (15-30 sec)..."
    Flush-LogBuffer; Pump-UI

    $webListed = 0; $webCount = 0
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
            # 1. REGEX PRINCIPALE (Tollerante a classi CSS multiple es. "class="rbl-listed other-class")
            $regexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline
            $regex = '<tr\s+class="[^"]*rbl-(?<Status>ok|listed)[^"]*"[^>]*>.*?<a[^>]*>(?<Name>[^<]+)</a>'
            $matches = [regex]::Matches($htmlContent, $regex, $regexOptions)

            if ($matches.Count -gt 0) {
                Log " ─────────────────────────────────────────────────────────────"
                foreach ($match in $matches) {
                    $listName = $match.Groups["Name"].Value.Trim()
                    $status = $match.Groups["Status"].Value.Trim().ToUpper()
                    $webCount++

                    if ($status -eq "LISTED") {
                        Log-Color -TextBefore " [⚠️] $listName : " -TextToColor "SEGNALATO" -TextAfter " (da MultiRBL)" -Color ([System.Drawing.Color]::Red)
                        $webListed++
                    } else {
                        Log-Color -TextBefore " [✅] $listName : " -TextToColor "PULITO" -Color ([System.Drawing.Color]::Green)
                    }
                    Pump-UI
                }
                Log " ─────────────────────────────────────────────────────────────"
                Log " Riepilogo MultiRBL: $webListed SEGNALATI su $webCount liste"
            } else {
                # 2. PARSER FALLBACK (Se la struttura HTML è completamente cambiata)
                Log "[!] Struttura standard non trovata. Tentativo con parser generico di emergenza..."
                $rows = $htmlContent -split '<tr'
                $fallbackListed = 0
                $fallbackTotal = 0
                
                foreach ($row in $rows) {
                    if ($row -match '<a[^>]*>([^<]+)</a>') {
                        $linkText = $Matches[1].Trim()
                        # Esclude link di navigazione del sito e considera solo i nomi plausibili
                        if ($linkText.Length -gt 4 -and $linkText -notmatch '^(Home|About|Contact|Login|MultiRBL|Valli\.org|Donate)$') {
                            $fallbackTotal++
                            if ($row -match '\bLISTED\b') {
                                Log-Color -TextBefore " [⚠️] $linkText : " -TextToColor "SEGNALATO" -TextAfter " (da MultiRBL)" -Color ([System.Drawing.Color]::Red)
                                $fallbackListed++
                            } else {
                                Log-Color -TextBefore " [✅] $linkText : " -TextToColor "PULITO" -Color ([System.Drawing.Color]::Green)
                            }
                            Pump-UI
                        }
                    }
                }
                
                if ($fallbackTotal -gt 0) {
                    $webCount = $fallbackTotal
                    $webListed = $fallbackListed
                    Log " ─────────────────────────────────────────────────────────────"
                    Log " Riepilogo MultiRBL: $webListed SEGNALATI su $webCount liste (tramite fallback)"
                } else {
                    Log "[!] Impossibile estrarre dati. Il sito potrebbe essere temporaneamente irraggiungibile o aver cambiato radicalmente layout."
                }
            }
        }
    } catch {
        Log "[!] Errore durante la richiesta a MultiRBL: $($_.Exception.Message)"
    }

    # =====================================================================
    # SEZIONE 4: RIEPILOGO FINALE TOTALE
    # =====================================================================
    $totalLists = $moduleListCount + $manualCount + $webCount
    $totalListed = $moduleListed + $manualListed + $webListed

    Log ""; Log " [📊] RIEPILOGO COMPLETO"
    Log " ─────────────────────────────────────────────────────────────"
    Log " Controlli PSBlackListChecker : $moduleListCount liste"
    Log " Controlli manuali estesi     : $manualCount liste"
    Log " Controlli Web (MultiRBL)     : $webCount liste"
    Log " TOTALE LISTE CONTROLLATE     : $totalLists"
    Log " TOTALE SEGNALAZIONI          : $totalListed"
    Log " ─────────────────────────────────────────────────────────────"

    if ($totalListed -gt 0) { Update-Status "[⚠️] $totalListed SEGNALAZIONI su $totalLists liste" $exitColor } 
    else { Update-Status "[✅] PULITO (0 segnalazioni su $totalLists liste)" $successColor }

    Log "==============================================================================================="; Log ""
    Update-Progress 100; Flush-LogBuffer; Pump-UI
}



# ============================================================
# BLOCCO 7 - FUNZIONI DI RIPARAZIONE
# ============================================================
function Do-RepairSystem { if($script:isClosing -or(Test-Cancel)){return};if(-not $isAdmin){Log "[X] Admin.";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;Update-Progress 100;return};Update-Status "[...] SFC..." $repairColor;Flush-LogBuffer;Pump-UI;Run-ProcessRealtime "sfc" "/scannow" "SFC" 20 50;if(Test-Cancel){return};Update-Status "[...] DISM..." $repairColor;Flush-LogBuffer;Pump-UI;Run-ProcessRealtime "DISM" "/Online /Cleanup-Image /RestoreHealth" "DISM" 50 85;Update-Progress 100;Update-Status "[OK] Riparazione" $successColor;Flush-LogBuffer;Pump-UI }
function Do-RestorePoint { 
    if($script:isClosing -or (Test-Cancel)) { return }
    if(-not $isAdmin) { 
        Log "[X] Admin richiesto."
        Update-Status "[!] Admin" $warningColor
        Flush-LogBuffer
        Update-Progress 100
        return 
    }
    
    Update-Status "[...] Creazione Punto di Ripristino..." $repairColor
    Flush-LogBuffer; Pump-UI
    Log ""
    Log "==============================================================================================="
    Log "[>] Punto Ripristino"
    Log "==============================================================================================="
    
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
    $regName = "SystemRestorePointCreationFrequency"
    $originalValue = $null

    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Pump-UI
        
        # 1. Bypass limite temporale di 24 ore di Windows
        if (Test-Path $regPath) {
            $originalValue = (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue).$regName
            Set-ItemProperty -Path $regPath -Name $regName -Value 0 -Type DWord -ErrorAction Stop
        }

        # 2. Crea il punto di ripristino
        Checkpoint-Computer -Description "PRO MAX $(Get-Date -Format 'dd/MM HH:mm')" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Log "[OK] Punto di ripristino creato con successo."
        
    } catch {
        Log "[X] Errore durante la creazione: $($_.Exception.Message)"
    } finally {
        # 3. Ripristina sempre il valore originale di sicurezza nel registro
        try {
            if ($null -ne $originalValue) {
                Set-ItemProperty -Path $regPath -Name $regName -Value $originalValue -Type DWord -ErrorAction SilentlyContinue
            } else {
                Set-ItemProperty -Path $regPath -Name $regName -Value 1440 -Type DWord -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    Log "==============================================================================================="
    Log ""
    Update-Progress 100
    Update-Status "[OK] Ripristino" $successColor
    Flush-LogBuffer; Pump-UI
}

# ============================================================
# BLOCCO 8 - FUNZIONI DI SICUREZZA
# ============================================================
function Do-SecurityScan { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Defender..." $securityColor;Flush-LogBuffer;Pump-UI;$mp="$env:ProgramFiles\Windows Defender\MpCmdRun.exe";if(-not(Test-Path $mp)){$mp="${env:ProgramFiles(x86)}\Windows Defender\MpCmdRun.exe"};if(-not(Test-Path $mp)){$pl=Get-ChildItem "$env:ProgramData\Microsoft\Windows Defender\Platform" -Directory -ErrorAction SilentlyContinue|Sort-Object Name -Descending|Select-Object -First 1;if($pl){$mp=Join-Path $pl.FullName "MpCmdRun.exe"}};if(Test-Path $mp){Run-ProcessRealtime $mp "-Scan -ScanType 1" "Defender Scan" 30 80}else{Log "[X] Defender non trovato."};Update-Progress 100;Update-Status "[OK] Scan" $successColor;Flush-LogBuffer;Pump-UI }
function Do-EventLogErrors { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] EventLog..." $securityColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Errori (7gg)";Log "===============================================================================================";try{$ev=Get-WinEvent -LogName System -MaxEvents 100 -ErrorAction SilentlyContinue | Where-Object { $_.LevelDisplayName -match "Critical|Error" -and $_.TimeCreated -gt (Get-Date).AddDays(-7) } | Select-Object -First 10;if($ev){foreach($e in $ev){$m=($e.Message -split "`n")[0];if($m.Length -gt 60){$m=$m.Substring(0,57)+"..."};Log " $($e.TimeCreated.ToString('dd/MM HH:mm')) $m";Pump-UI}}else{Log " [OK] Nessun errore critico."}}catch{if($_.Exception.Message -match "No events"){Log " [OK] Nessun errore."}else{Log "[X] $($_.Exception.Message)"}};Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] EventLog" $successColor;Flush-LogBuffer;Pump-UI }
function Do-SystemHealth {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Health Check..." $securityColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] HEALTH CHECK SISTEMA"
    Log "==============================================================================================="
    $checks = @()
    Log "[...] Verifica integrità file di sistema..."
    $sfcResult = sfc /verifyonly 2>&1 | Out-String
    if($sfcResult -match "corruzione") { $checks += @{Status="[X]"; Test="SFC"; Desc="Corruzione rilevata"} }
    else { $checks += @{Status="[OK]"; Test="SFC"; Desc="Integrità OK"} }
    Pump-UI
    Log "[...] Verifica immagine sistema..."
    $dismResult = DISM /Online /Cleanup-Image /CheckHealth 2>&1 | Out-String
    if($dismResult -match "ripristinabile") { $checks += @{Status="[!]"; Test="DISM"; Desc="Riparazione necessaria"} }
    else { $checks += @{Status="[OK]"; Test="DISM"; Desc="Immagine OK"} }
    Pump-UI
    Log "[...] Verifica eventi critici recenti..."
    $criticalEvents = Get-WinEvent -LogName System -MaxEvents 100 -ErrorAction SilentlyContinue | Where-Object { $_.LevelDisplayName -match "Critical|Error" -and $_.TimeCreated -gt (Get-Date).AddDays(-7) }
    if($criticalEvents) { $checks += @{Status="[!]"; Test="EventLog"; Desc="$($criticalEvents.Count) eventi critici"} }
    else { $checks += @{Status="[OK]"; Test="EventLog"; Desc="Nessun evento critico"} }
    Pump-UI
    Log "[...] Verifica memoria..."
    $mem = Get-CimInstance Win32_OperatingSystem
    $totalMem = [Math]::Round($mem.TotalVisibleMemorySize/1MB, 0)
    $freeMem = [Math]::Round($mem.FreePhysicalMemory/1MB, 0)
    $memPercent = [Math]::Round(($freeMem/$totalMem)*100, 1)
    if($memPercent -lt 20) { $checks += @{Status="[!]"; Test="Memoria"; Desc="Bassa ($memPercent% libera)"} }
    else { $checks += @{Status="[OK]"; Test="Memoria"; Desc="$memPercent% libera"} }
    Pump-UI
    Log "";Log " RISULTATI HEALTH CHECK:";Log " ----------------------"
    foreach($check in $checks) { Log " $($check.Status) $($check.Test): $($check.Desc)" }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Health check completato" $successColor
    Flush-LogBuffer;Pump-UI
}

# ============================================================
# BLOCCO 9 - FUNZIONI DI DIAGNOSTICA
# ============================================================
function Do-SystemInfo { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Sistema..." $infoColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Info Sistema";Log "===============================================================================================";try{$os=Get-CimInstance Win32_OperatingSystem;$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1;$ram=Get-CimInstance Win32_PhysicalMemory;$gpu=Get-CimInstance Win32_VideoController|Select-Object -First 1;$disk=Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3";Pump-UI;Log " OS: $($os.Caption)";Log " CPU: $($cpu.Name)";Log " Cores: $($cpu.NumberOfCores)/$($cpu.NumberOfLogicalProcessors)";$tr=[Math]::Round(($ram|Measure-Object Capacity -Sum).Sum/1GB,1);Log " RAM: ${tr}GB";Log " GPU: $($gpu.Name)";Log "";foreach($d in $disk){$f=[Math]::Round($d.FreeSpace/1GB,1);$t=[Math]::Round($d.Size/1GB,1);Log " $($d.DeviceID) $([Math]::Round($t-$f,1))/${t}GB"}}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] Sistema" $successColor;Flush-LogBuffer;Pump-UI }
function Do-BatteryReport { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Batteria..." $infoColor;Flush-LogBuffer;Pump-UI;try{$rp=Join-Path $tempDir "battery-report.html";& powercfg /batteryreport /output "$rp" 2>&1|Out-Null;if(Test-Path $rp){Log "[OK] $rp";Start-Process $rp}else{Log "[!] Nessuna batteria."}}catch{Log "[X] $($_.Exception.Message)"};Update-Progress 100;Update-Status "[OK] Batteria" $successColor;Flush-LogBuffer;Pump-UI }
function Do-Uptime { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Uptime..." $infoColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Uptime";Log "===============================================================================================";try{$os=Get-CimInstance Win32_OperatingSystem;$b=$os.LastBootUpTime;$u=(Get-Date)-$b;Log " Boot: $($b.ToString('dd/MM/yyyy HH:mm'))";Log " Up: $($u.Days)g $($u.Hours)h";if($u.Days -gt 7){Log " [!] Riavvio consigliato."}}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] Uptime" $successColor;Flush-LogBuffer;Pump-UI }
function Do-TopProcesses { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Processi..." $cpuColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Top CPU";Log "===============================================================================================";try{$procs=Get-Process|Where-Object{$_.CPU -gt 0}|Sort-Object CPU -Descending|Select-Object -First 12;foreach($p in $procs){Log(" {0,-28} {1,6}s {2,5}MB" -f $p.ProcessName,[Math]::Round($p.CPU,1),[Math]::Round($p.WorkingSet64/1MB,0))}}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] Processi" $successColor;Flush-LogBuffer;Pump-UI }
function Do-StartupPrograms { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Startup..." $cpuColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Startup";Log "===============================================================================================";try{$r=Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue;if($r){$r.PSObject.Properties|Where-Object{$_.Name -notmatch '^PS'}|ForEach-Object{Log " $($_.Name)"}};$ru=Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue;if($ru){$ru.PSObject.Properties|Where-Object{$_.Name -notmatch '^PS'}|ForEach-Object{Log " $($_.Name)"}}}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] Startup" $successColor;Flush-LogBuffer;Pump-UI }
function Do-DiskSpace { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Disco..." $maintColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Spazio disco";Log "===============================================================================================";try{$up=$env:USERPROFILE;$fl=@("$up\Downloads","$up\Desktop","$up\Documents","$up\AppData\Local","${env:SystemDrive}\Program Files");$res=@();foreach($f in $fl){if(Test-Cancel){return};if(Test-Path $f){try{$sz=(Get-ChildItem $f -Recurse -Force -ErrorAction SilentlyContinue|Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum;if(-not $sz){$sz=0};$res+=@{P=$f;S=$sz}}catch{}};Pump-UI};$res=$res|Sort-Object{$_.S} -Descending;foreach($r in $res){$d=if($r.S -ge 1GB){"$([Math]::Round($r.S/1GB,1))GB"}else{"$([Math]::Round($r.S/1MB,0))MB"};Log(" {0,-40} {1,7}" -f $r.P.Replace($up,"~"),$d)}}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] Disco" $successColor;Flush-LogBuffer;Pump-UI }
function Do-ServiceStatus { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Servizi..." $infoColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Servizi";Log "===============================================================================================";$svcs=@(@{N="wuauserv";D="WinUpdate"},@{N="WinDefend";D="Defender"},@{N="mpssvc";D="Firewall"},@{N="BITS";D="BITS"},@{N="Dnscache";D="DNS"});foreach($svc in $svcs){try{$s=Get-Service -Name $svc.N -ErrorAction Stop;$st=if($s.Status -eq "Running"){"OK"}else{"--"};Log " [$st] $($svc.D)"}catch{Log " [??] $($svc.D)"};Pump-UI};Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] Servizi" $successColor;Flush-LogBuffer;Pump-UI }

# ============================================================
# BLOCCO 10 - FUNZIONI DI SISTEMA
# ============================================================
function Do-UnlockCPU { if($script:isClosing -or(Test-Cancel)){return};if(-not $isAdmin){Log "[X] Admin.";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;Update-Progress 100;return};Update-Status "[...] CPU..." $cpuColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] CPU Unlock";Log "===============================================================================================";$cat="54533251-82be-4824-96c1-47b60b740d00";$ss=@("be337238-0d82-4146-a960-4f3749d470c7","5d76a2ca-e8c0-402f-a133-2158492d58ad","893dee8e-2bef-41e0-89c6-b55d0929964c","bc5038f7-23e0-4960-96da-33abaf5935ec","0cc5b647-c1df-4637-891a-dec35c318583","ea062031-0e34-4ff1-9b6d-eb1059334028","68dd2f27-a4ce-4e11-8487-3794e4135dfa","2ddd5a84-5a71-437e-912a-db0b8c788732","4b92d758-5a24-4851-a470-815d78aee119","d6ba4903-386f-4c2c-8adb-5c21b3328d25","45bcc044-d885-43e2-8605-ee0ec6e96b59","36687f9e-e3a5-4dbf-b1dc-15eb381c6863","cfeda3d0-7697-4566-a922-a9086cd49dfa","fddc842b-8364-4edc-94cf-c17f60de1c80");$ok=0;foreach($g in $ss){$p="HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$cat\$g";if(Test-Path $p){try{Set-ItemProperty -Path $p -Name "Attributes" -Value 2 -ErrorAction Stop;$ok++}catch{}};Pump-UI};Log "[OK] $ok/$($ss.Count) sbloccate.";Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] CPU ($ok)" $successColor;Flush-LogBuffer;Pump-UI }
function Do-OptimizeVisual {
    if($script:isClosing -or(Test-Cancel)){return}
    Log "";Log "===============================================================================================";Log "[>] OTTIMIZZAZIONE EFFETTI VISIVI";Log "==============================================================================================="
    Update-Status "[...] Ottimizzazione visiva..." $cpuColor;Flush-LogBuffer;Pump-UI
    try{
        $vfxPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if(!(Test-Path $vfxPath)){New-Item -Path $vfxPath -Force|Out-Null}
        Set-ItemProperty -Path $vfxPath -Name "VisualFXSetting" -Value 3 -Force
        Log " [OK] Modalita effetti visivi: Personalizzata"
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value "0" -Force
        $wmPath = "HKCU:\Control Panel\Desktop\WindowMetrics"
        if(!(Test-Path $wmPath)){New-Item -Path $wmPath -Force|Out-Null}
        Set-ItemProperty -Path $wmPath -Name "MinAnimate" -Value "0" -Force
        $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $advPath -Name "TaskbarAnimations" -Value 0 -Force
        Set-ItemProperty -Path $advPath -Name "ListviewAlphaSelect" -Value 0 -Force
        Log " [OK] Animazioni e trasparenze disabilitate"
        $dwmPath = "HKCU:\Software\Microsoft\Windows\DWM"
        if(!(Test-Path $dwmPath)){New-Item -Path $dwmPath -Force|Out-Null}
        Set-ItemProperty -Path $dwmPath -Name "EnableAeroPeek" -Value 1 -Force
        Log " [OK] Attiva Peek: SI"
        Set-ItemProperty -Path $advPath -Name "IconsOnly" -Value 0 -Force
        Log " [OK] Anteprime anziche icone: SI"
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 1 -Force -ErrorAction SilentlyContinue
        $upm = [byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value $upm -Type Binary -Force
        Log " [OK] Ombreggiatura finestre: SI"
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value "2" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothingType" -Value 2 -Force
        Log " [OK] Smussatura caratteri (ClearType): SI"
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "SmoothScroll" -Value 1 -Force -ErrorAction SilentlyContinue
        Log " [OK] Scorrimento uniforme caselle: SI"
        Set-ItemProperty -Path $advPath -Name "ListviewShadow" -Value 1 -Force
        Log " [OK] Ombreggiatura etichette icone: SI"
        Log "";Log " [i] Riavvio Explorer per applicare..."
        Flush-LogBuffer;Pump-UI
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Process explorer
        Start-Sleep -Seconds 1
        Log "";Log "[OK] Effetti visivi ottimizzati!"
        Update-Status "[OK] Effetti visivi ottimizzati" $successColor
    }catch{
        Log "[X] $($_.Exception.Message)"
        Update-Status "[X] Errore ottimizzazione" $exitColor
    }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Flush-LogBuffer;Pump-UI
}
function Do-BootOptimization {
    if($script:isClosing -or(Test-Cancel)){return}
    if(-not $isAdmin){Log "[X] Admin richiesto";Update-Progress 100;return}
    Update-Status "[...] Ottimizzazione avvio..." $cpuColor
    Flush-LogBuffer;Pump-UI
    Log "";Log "==============================================================================================="
    Log "[>] OTTIMIZZAZIONE AVVIO SISTEMA"
    Log "==============================================================================================="
    try {
        $activeScheme = powercfg /getactivescheme 2>&1 | Select-String -Pattern "{(.*?)}"
        if($activeScheme -and $activeScheme.Matches) {
            $guid = $activeScheme.Matches[0].Groups[1].Value
            powercfg /setacvalueindex $guid SUB_SLEEP 94ac6d29-73ce-41a6-809f-6363ba21b47e 1
            powercfg /setdcvalueindex $guid SUB_SLEEP 94ac6d29-73ce-41a6-809f-6363ba21b47e 1
            Log "[OK] Avvio veloce abilitato"
        } else {
            Log "[!] Impossibile determinare il piano energetico attivo"
        }
    } catch { Log "[!] Errore avvio veloce: $($_.Exception.Message)" }
    $services = @{
        "SysMain" = "Automatic"
        "MapsBroker" = "Disabled"
        "RetailDemo" = "Disabled"
        "XblAuthManager" = "Manual"
        "XboxNetApiSvc" = "Manual"
        "XboxGipSvc" = "Manual"
    }
    foreach($svc in $services.GetEnumerator()) {
        try {
            Set-Service -Name $svc.Key -StartupType $svc.Value -ErrorAction SilentlyContinue
            Log "[OK] $($svc.Key): $($svc.Value)"
        } catch { Log "[!] $($svc.Key): non modificabile" }
        Pump-UI
    }
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Ottimizzazione avvio" $successColor
    Flush-LogBuffer;Pump-UI
}

# ============================================================
# BLOCCO 11 - FUNZIONI VARIE
# ============================================================
function Do-RemoteAssist { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] RustDesk..." $remoteColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Assistenza Remota";Log "===============================================================================================";$url="https://github.com/rustdesk/rustdesk/releases/download/1.2.2/rustdesk-1.2.2-x86_64.exe";$tp="C:\Temp\RustDeskPortable";$ep=Join-Path $tp "rustdesk.exe";if(!(Test-Path $tp)){New-Item -ItemType Directory -Force -Path $tp|Out-Null};if(!(Test-Path $ep)){Log " [DL] Download...";Flush-LogBuffer;Pump-UI;try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;Invoke-WebRequest $url -OutFile $ep -UseBasicParsing -ErrorAction Stop}catch{Log " [X] $($_.Exception.Message)";Update-Status "[X]" $exitColor;Flush-LogBuffer;Pump-UI;Update-Progress 100;return}};try{Start-Process $ep;Start-Sleep 4;Pump-UI;$id=& $ep --get-id 2>$null;$pw=& $ep --get-password 2>$null;if($id){Log " ID: $id"};if($pw){Log " PW: $pw"}}catch{Log " [X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Progress 100;Update-Status "[OK] RustDesk" $successColor;Flush-LogBuffer;Pump-UI }
function Do-ExportReport { if($script:isClosing -or(Test-Cancel)){return};try{$rf=Join-Path([Environment]::GetFolderPath("Desktop")) "Manutenzione_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt";if($script:logBox){$script:logBox.Text|Out-File -FilePath $rf -Encoding UTF8;Log "[OK] $rf";Start-Process explorer.exe -ArgumentList "/select,`"$rf`""}}catch{Log "[X] $($_.Exception.Message)"};Update-Progress 100;Update-Status "[OK] Export" $successColor;Flush-LogBuffer;Pump-UI }
function Do-ScheduleShutdown {
    if($script:isClosing){return}
    $taskName = "ShutdownGiornalieroForzato"
    Log "";Log "===============================================================================================";Log "[>] SHUTDOWN SCHEDULATO";Log "==============================================================================================="
    Update-Status "[...] Shutdown schedulato..." $warningColor;Flush-LogBuffer;Pump-UI
    if(-not $isAdmin){Log "[X] Servono privilegi admin.";Update-Status "[!] Admin richiesto" $warningColor;Flush-LogBuffer;Update-Progress 100;return}
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Imposta Ora Shutdown"
    $inputForm.Size = New-Object System.Drawing.Size(320,180)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = $bgColor
    $inputForm.ForeColor = $fgColor
    $inputForm.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Inserisci ora spegnimento (HH:mm):"
    $lbl.Location = New-Object System.Drawing.Point(20,20)
    $lbl.Size = New-Object System.Drawing.Size(260,22)
    $lbl.ForeColor = $fgColor
    $inputForm.Controls.Add($lbl)
    $txtTime = New-Object System.Windows.Forms.TextBox
    $txtTime.Text = "22:30"
    $txtTime.Location = New-Object System.Drawing.Point(20,50)
    $txtTime.Size = New-Object System.Drawing.Size(100,26)
    $txtTime.Font = New-Object System.Drawing.Font("Consolas",12)
    $txtTime.BackColor = $bgCard
    $txtTime.ForeColor = $fgColor
    $inputForm.Controls.Add($txtTime)
    $btnOK = New-Object System.Windows.Forms.Button
    $btnOK.Text = "Conferma"
    $btnOK.Location = New-Object System.Drawing.Point(20,95)
    $btnOK.Size = New-Object System.Drawing.Size(100,32)
    $btnOK.BackColor = $accentColor
    $btnOK.ForeColor = [System.Drawing.Color]::White
    $btnOK.FlatStyle = "Flat"
    $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($btnOK)
    $inputForm.AcceptButton = $btnOK
    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.Location = New-Object System.Drawing.Point(140,95)
    $btnCancel.Size = New-Object System.Drawing.Size(100,32)
    $btnCancel.BackColor = $exitColor
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($btnCancel)
    $inputForm.CancelButton = $btnCancel
    $result = $inputForm.ShowDialog($script:form)
    if($result -ne [System.Windows.Forms.DialogResult]::OK){Log "[i] Annullato.";Update-Status "Annullato" $fgDim;Flush-LogBuffer;Update-Progress 100;return}
    $timeInput = $txtTime.Text.Trim()
    if($timeInput -notmatch '^\d{1,2}:\d{2}$'){
        Log "[X] Formato ora non valido. Usa HH:mm (es. 22:30)"
        Update-Status "[X] Formato non valido" $exitColor;Flush-LogBuffer;Update-Progress 100;return
    }
    try{[datetime]::ParseExact($timeInput,"H:mm",[System.Globalization.CultureInfo]::InvariantCulture)|Out-Null}catch{
        Log "[X] Ora non valida: $timeInput";Update-Status "[X] Ora non valida" $exitColor;Flush-LogBuffer;Update-Progress 100;return
    }
    try{
        $argCreate = "/create /tn `"$taskName`" /tr `"shutdown /s /f /t 0`" /sc daily /st $timeInput /ru SYSTEM /f /rl HIGHEST"
        $proc = Start-Process "schtasks.exe" -ArgumentList $argCreate -Wait -NoNewWindow -PassThru
        if($proc.ExitCode -eq 0){
            Log "[OK] Task schedulato creato: spegnimento forzato ogni giorno alle $timeInput"
            Log "     Nome task: $taskName"
            Update-Status "[OK] Shutdown alle $timeInput" $successColor
        }else{
            Log "[X] Errore creazione task (codice: $($proc.ExitCode))"
            Update-Status "[X] Errore task" $exitColor
        }
    }catch{Log "[X] $($_.Exception.Message)";Update-Status "[X] Errore" $exitColor}
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Flush-LogBuffer;Pump-UI
}
function Do-RemoveShutdown {
    if($script:isClosing){return}
    $taskName = "ShutdownGiornalieroForzato"
    Log "";Log "===============================================================================================";Log "[>] RIMOZIONE SHUTDOWN SCHEDULATO";Log "==============================================================================================="
    Update-Status "[...] Rimozione task..." $warningColor;Flush-LogBuffer;Pump-UI
    if(-not $isAdmin){Log "[X] Servono privilegi admin.";Update-Status "[!] Admin richiesto" $warningColor;Flush-LogBuffer;Update-Progress 100;return}
    try{
        $proc = Start-Process "schtasks.exe" -ArgumentList "/delete /tn `"$taskName`" /f" -Wait -NoNewWindow -PassThru
        if($proc.ExitCode -eq 0){
            Log "[OK] Task '$taskName' rimosso con successo."
            Update-Status "[OK] Shutdown rimosso" $successColor
        }else{
            Log "[X] Task non trovato o errore (codice: $($proc.ExitCode))"
            Update-Status "[!] Task non trovato" $warningColor
        }
    }catch{Log "[X] $($_.Exception.Message)";Update-Status "[X] Errore" $exitColor}
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Flush-LogBuffer;Pump-UI
}

# ---------- FUNZIONE BACKUP AVANZATO (7-ZIP) ----------
function Do-BackupAdvanced {
    if($script:isClosing -or(Test-Cancel)){return}

    # --- 1. Verifica presenza 7za.exe ---
    $7zPath = Join-Path $scriptRoot "lib" "7za.exe"
    $7zFound = Test-Path $7zPath

    if (-not $7zFound) {
        Log "[!] 7za.exe non trovato in $scriptRoot"
        Update-Status "[!] 7-Zip non trovato" $warningColor
        Flush-LogBuffer; Pump-UI

        # --- Tentativo di installazione con winget (se admin) ---
        if ($isAdmin -and (Test-WingetAvailable)) {
            Log "[>] Tentativo installazione 7-Zip tramite winget..."
            Update-Status "[...] Installazione 7-Zip..." $infoColor
            Flush-LogBuffer; Pump-UI

            try {
                $wingetArgs = "install 7zip.7zip --silent --accept-package-agreements --accept-source-agreements"
                Start-Process "winget" -ArgumentList $wingetArgs -Wait -NoNewWindow -ErrorAction Stop
                Log "[OK] 7-Zip installato con winget."

                # Riavviamo la funzione per ricontrollare la presenza (potrebbe essere in Program Files)
                # Ma prima controlliamo se ora esiste nel PATH
                $7zFound = $false
                $possiblePaths = @(
                    "C:\Program Files\7-Zip\7z.exe",
                    "C:\Program Files (x86)\7-Zip\7z.exe"
                )
                foreach ($p in $possiblePaths) {
                    if (Test-Path $p) {
                        $7zPath = $p
                        $7zFound = $true
                        Log "[OK] Trovato 7-Zip in: $p"
                        break
                    }
                }
                if (-not $7zFound) {
                    # Prova a cercare con Get-Command
                    try {
                        $cmd = Get-Command "7z" -ErrorAction Stop
                        $7zPath = $cmd.Source
                        $7zFound = $true
                        Log "[OK] Trovato 7-Zip nel PATH: $7zPath"
                    } catch {}
                }
            } catch {
                Log "[X] Installazione fallita: $($_.Exception.Message)"
                Update-Status "[X] Installazione fallita" $exitColor
                Flush-LogBuffer; Pump-UI
            }
        } else {
            if (-not $isAdmin) {
                Log "[!] Per installare 7-Zip servono privilegi amministrativi."
                Log "[i] Premi 'Eleva Admin' e riprova, oppure usa il backup standard."
            } else {
                Log "[!] Winget non disponibile. Impossibile installare 7-Zip."
            }
        }
    }

    # --- 2. Se 7za non trovato, fallback al backup standard ---
    if (-not $7zFound) {
        $response = [System.Windows.Forms.MessageBox]::Show(
            "7-Zip non disponibile.`n`nVuoi procedere con il backup standard (Compress-Archive)?",
            "7-Zip non trovato",
            "YesNo",
            "Question"
        )
        if ($response -eq "Yes") {
            Log "[i] Esecuzione backup standard..."
            Do-BackupFiles
        } else {
            Log "[i] Backup annullato dall'utente."
        }
        Update-Progress 100
        Update-Status "[i] Backup annullato" $fgDim
        Flush-LogBuffer; Pump-UI
        return
    }

    # --- 3. Se 7za trovato, procedi con il backup avanzato ---
    $folderDialog1 = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog1.Description = "Seleziona la cartella da BACKUP (origine)"
    $folderDialog1.ShowNewFolderButton = $false
    $folderDialog1.RootFolder = "MyComputer"

    if ($folderDialog1.ShowDialog() -ne "OK") {
        Log "[i] Backup annullato."
        Update-Progress 100
        return
    }
    $sourcePath = $folderDialog1.SelectedPath

    $folderDialog2 = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog2.Description = "Seleziona la cartella dove SALVARE il backup (destinazione)"
    $folderDialog2.ShowNewFolderButton = $true
    $folderDialog2.RootFolder = "MyComputer"

    if ($folderDialog2.ShowDialog() -ne "OK") {
        Log "[i] Backup annullato."
        Update-Progress 100
        return
    }
    $destPath = $folderDialog2.SelectedPath

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $folderName = Split-Path $sourcePath -Leaf
    $zipName = "Backup_Advanced_${folderName}_${timestamp}.zip"
    $zipPath = Join-Path $destPath $zipName

    Log ""; Log "==============================================================================================="
    Log "[>] BACKUP AVANZATO (7-ZIP)"
    Log "==============================================================================================="
    Log "[i] Origine    : $sourcePath"
    Log "[i] Destinazione: $zipPath"
    Log "[i] Compressione: massima (mx=9)"
    Log ""

    if (-not (Test-Path $sourcePath)) {
        Log "[X] Cartella origine non trovata!"
        Update-Status "[X] Origine non trovata" $exitColor
        Update-Progress 100
        return
    }

    Update-Status "[...] Calcolo dimensione..." $infoColor
    Flush-LogBuffer; Pump-UI

    try {
        $items = Get-ChildItem -Path $sourcePath -Recurse -Force -ErrorAction SilentlyContinue
        $totalSize = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $totalCount = $items.Count
        Log "[OK] Elementi: $totalCount, Dimensione: $([Math]::Round($totalSize/1MB, 2)) MB"
    } catch {
        Log "[X] Errore calcolo dimensione: $($_.Exception.Message)"
        Update-Progress 100
        return
    }

    $response = [System.Windows.Forms.MessageBox]::Show(
        "Avviare backup avanzato di $totalCount elementi ($([Math]::Round($totalSize/1MB, 2)) MB)?`n`nLa compressione massima richiede più tempo ma riduce notevolmente le dimensioni.",
        "Conferma Backup Avanzato",
        "YesNo",
        "Question"
    )
    if ($response -ne "Yes") {
        Log "[i] Backup annullato."
        Update-Progress 100
        return
    }

    Update-Status "[...] Compressione 7-Zip in corso..." $warningColor
    Flush-LogBuffer; Pump-UI

    # --- 4. Esegui la compressione con 7za ---
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        # Costruisci i parametri:
        # a = aggiungi
        # -tzip = formato ZIP (compatibile)
        # -mx=9 = massima compressione
        # -mmt=on = multithreading
        # -r = ricorsivo
        $args7z = @(
            "a",
            "-tzip",
            "-mx=9",
            "-mmt=on",
            "-r",
            "`"$zipPath`"",
            "`"$sourcePath\*`""
        ) -join " "

        Log "[CMD] $7zPath $args7z"
        Log ""

        # Usiamo Run-ProcessRealtime per mostrare il progresso nel log
        $exitCode = Run-ProcessRealtime $7zPath $args7z "Compressione 7-Zip" 10 90

        $sw.Stop()
        $elapsed = $sw.Elapsed

        if (Test-Path $zipPath) {
            $zipSize = (Get-Item $zipPath).Length
            $ratio = [Math]::Round((1 - ($zipSize / $totalSize)) * 100, 1)
            Log ""
            Log "[OK] BACKUP AVANZATO COMPLETATO!"
            Log "     File: $zipPath"
            Log "     Dimensione: $([Math]::Round($zipSize/1MB, 2)) MB"
            Log "     Compressione: $ratio%"
            Log "     Tempo: $($elapsed.ToString('hh\:mm\:ss'))"
            Update-Status "[OK] Backup avanzato ($([Math]::Round($zipSize/1MB, 1)) MB)" $successColor

            $openFolder = [System.Windows.Forms.MessageBox]::Show(
                "Backup avanzato completato!`nAprire la cartella di destinazione?",
                "Backup Completato",
                "YesNo",
                "Information"
            )
            if ($openFolder -eq "Yes") { Start-Process $destPath }
        } else {
            Log "[X] File backup non trovato dopo la compressione!"
            Update-Status "[X] Errore backup" $exitColor
        }
    } catch {
        Log "[X] Errore compressione: $($_.Exception.Message)"
        Update-Status "[X] Errore backup" $exitColor
    }

    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}

# DISABILITA limiti TPM CPU RAM 
function Do-TpmCpuRamUnlock {
    if($script:isClosing -or(Test-Cancel)){return}
    Update-Status "[...] Sblocco TPM/CPU/RAM..." $securityColor
    Flush-LogBuffer;Pump-UI

    Log "";Log "==============================================================================================="
    Log "[>] RIMOZIONE LIMITAZIONI WINDOWS 11"
    Log "==============================================================================================="
    
    # --- Step 1: Rimozione vecchi marker di compatibilità ---
    Log "[1] Rimozione vecchi record di upgrade falliti..."
    try {
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\CompatMarkers" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Shared" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators" -Recurse -Force -ErrorAction SilentlyContinue
        Log "[OK] Pulizia completata."
    } catch { Log "[X] Errore pulizia: $($_.Exception.Message)" }

    # --- Step 2: Simula hardware compatibile ---
    Log "[2] Impostazione valori hardware compatibili..."
    try {
        $path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\HwReqChk"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "HwReqChkVars" -Value @(
            "SQ_SecureBootCapable=TRUE",
            "SQ_SecureBootEnabled=TRUE",
            "SQ_TpmVersion=2",
            "SQ_RamMB=8192"
        ) -Type MultiString -Force -ErrorAction Stop
        Log "[OK] Valori hardware applicati."
    } catch { Log "[X] Errore impostazione valori: $($_.Exception.Message)" }

    # --- Step 3: Abilita upgrade su hardware non supportato ---
    Log "[3] Abilitazione upgrade su TPM/CPU non supportati..."
    try {
        $path = "HKLM:\SYSTEM\Setup\MoSetup"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -Type DWord -Force -ErrorAction Stop
        Log "[OK] Policy abilitata."
    } catch { Log "[X] Errore policy: $($_.Exception.Message)" }

    # --- Step 4: Imposta flag di eleggibilità ---
    Log "[4] Impostazione flag di eleggibilità..."
    try {
        $path = "HKCU:\Software\Microsoft\PCHC"
        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name "UpgradeEligibility" -Value 1 -Type DWord -Force -ErrorAction Stop
        Log "[OK] Flag eleggibilità impostata."
    } catch { Log "[X] Errore flag: $($_.Exception.Message)" }

    Log ""
    Log "[OK] TUTTE LE OPERAZIONI COMPLETATE!"
    Log "[i] Ora puoi avviare l'upgrade a Windows 11 tramite Assistente o setup.exe."
    Log "[i] Nessun riavvio richiesto."
    Log "===============================================================================================";Log ""
    Update-Progress 100
    Update-Status "[OK] Sblocco completato" $successColor
    Flush-LogBuffer;Pump-UI

    # Notifica all'utente
    [System.Windows.Forms.MessageBox]::Show(
        "Limiti TPM/CPU/RAM rimossi con successo!`n`nPuoi ora eseguire l'upgrade a Windows 11.`nNessun riavvio è necessario.",
        "Sblocco Completato",
        "OK",
        "Information"
    )
}

# ============================================================
# BLOCCO 12 - RUN PROCESS (Utility)
# ============================================================
function Run-ProcessRealtime { param([string]$fileName,[string]$processArguments,[string]$description,[int]$stepStart=-1,[int]$stepEnd=-1);Log "";Log "===============================================================================================";Log "[>] $description";Log "===============================================================================================";$process=$null;try{Log "[CMD] $fileName $processArguments";Log "";$psi=New-Object System.Diagnostics.ProcessStartInfo;$psi.FileName=$fileName;$psi.Arguments=$processArguments;$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$psi.CreateNoWindow=$true;$psi.StandardOutputEncoding=[System.Text.Encoding]::UTF8;$psi.StandardErrorEncoding=[System.Text.Encoding]::UTF8;$process=New-Object System.Diagnostics.Process;$process.StartInfo=$psi;$process.EnableRaisingEvents=$true;$oQ=[System.Collections.Concurrent.ConcurrentQueue[string]]::new();$eQ=[System.Collections.Concurrent.ConcurrentQueue[string]]::new();$oH=Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {$l=$Event.SourceEventArgs.Data;if($null -ne $l){$Event.MessageData.Enqueue($l)}} -MessageData $oQ;$eH=Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {$l=$Event.SourceEventArgs.Data;if($null -ne $l -and $l.Trim()){$Event.MessageData.Enqueue($l)}} -MessageData $eQ;$process.Start()|Out-Null;$process.BeginOutputReadLine();$process.BeginErrorReadLine();while(-not $process.HasExited -or $oQ.Count -gt 0){if($script:cancelRequested){try{$process.Kill()}catch{};Log "[STOP] Terminato.";$script:cancelRequested=$false;break};$l=$null;$c=0;while($oQ.TryDequeue([ref]$l) -and $c -lt 30){$c++;if(-not $l -or(Is-SpinnerLine $l)){continue};$lp=Get-PercentFromLine $l;if($null -ne $lp -and $stepStart -ge 0 -and $stepEnd -ge 0){Set-StepProgress $lp $stepStart $stepEnd};$f=Format-LogLine $l;if($f){Log $f}};$el=$null;while($eQ.TryDequeue([ref]$el)){if($el -and $el.Trim() -and -not(Is-SpinnerLine $el)){Log " [X] $($el.Trim())"}};Flush-LogBuffer;Pump-UI;if(-not $process.HasExited){Start-Sleep -Milliseconds 50}};Start-Sleep -Milliseconds 200;$l=$null;while($oQ.TryDequeue([ref]$l)){if($l -and -not(Is-SpinnerLine $l)){$f=Format-LogLine $l;if($f){Log $f}}};$el=$null;while($eQ.TryDequeue([ref]$el)){if($el -and $el.Trim()){Log " [X] $($el.Trim())"}};Unregister-Event -SourceIdentifier $oH.Name -ErrorAction SilentlyContinue;Unregister-Event -SourceIdentifier $eH.Name -ErrorAction SilentlyContinue;Remove-Job $oH -Force -ErrorAction SilentlyContinue;Remove-Job $eH -Force -ErrorAction SilentlyContinue;$ec=$process.ExitCode;Log "";if($stepStart -ge 0 -and $stepEnd -ge 0 -and $ec -eq 0){Set-StepProgress 100 $stepStart $stepEnd};if($ec -eq 0){Log "[OK] Completato."}else{Log "[!] Codice: $ec"};Update-Progress 100;Flush-LogBuffer;return $ec}catch{Log "[X] $($_.Exception.Message)";Flush-LogBuffer;Update-Progress 100;return -1}finally{if($process){try{$process.Dispose()}catch{}}} }

# ============================================================
# BLOCCO 13 - RUN ALL (Sequenza completa)
# ============================================================
function Do-RunAll {
if($script:isClosing -or(Test-Cancel)){return}
Log "";Log "##################################################################################################";Log "# UPGRADE PROGRAMMI #";Log "##################################################################################################";Log ""
Update-Progress 0;Flush-LogBuffer;Pump-UI
Do-Winget;if(Test-Cancel){return};Do-StoreUpdate;if(Test-Cancel){return};Do-SearchWU;if(Test-Cancel){return};Do-InstallWU;if(Test-Cancel){return};Do-CleanTemp;if(Test-Cancel){return};Do-FlushDNS;if(Test-Cancel){return}
Update-Progress 100;Log "";Log "##################################################################################################";Log "# COMPLETATO #";Log "##################################################################################################";Log ""
Update-Status "[OK] Completato!" $successColor;Flush-LogBuffer;Pump-UI
}
# [Do-RunAll]
# [LE STESSE DEL FILE ORIGINALE]



#BLOCCO 14


function Build-GUI {
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2)
    $script:form = New-Object System.Windows.Forms.Form
    $script:form.Text = "Manutenzione PRO MAX v$($script:currentVersion) Peters"
    $script:form.Size = New-Object System.Drawing.Size(1050, 580)
    $script:form.MinimumSize = New-Object System.Drawing.Size(1050, 580)
    $script:form.StartPosition = "CenterScreen"
    $script:form.BackColor = $bgColor
    $script:form.ForeColor = $fgColor
    $script:form.FormBorderStyle = "Sizable"
    $script:form.MaximizeBox = $true
    $script:form.WindowState = "Maximized"
    $script:form.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $script:form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $dbProp = $script:form.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]"Instance,NonPublic")
    if ($dbProp) { $dbProp.SetValue($script:form, $true) }

    $script:pulseTimer = $null
    $script:pulseState = 0
	$script:pulseColors = @(
		[System.Drawing.Color]::FromArgb(255, 220, 0),   # Giallo acceso
		[System.Drawing.Color]::FromArgb(255, 140, 0),   # Arancione brillante
		[System.Drawing.Color]::FromArgb(0, 255, 100),   # Verde fluo
		[System.Drawing.Color]::FromArgb(255, 80, 80)    # Rosso acceso
	)

    # --- DEFINIZIONE CATEGORIE (con icone e tooltip arricchiti) ---
    $verde = [System.Drawing.Color]::FromArgb(50, 220, 1)
    $availableColors = @(
        $verde, $maintColor, $networkColor, $repairColor,
        $securityColor, $infoColor, $cpuColor, $remoteColor,
        $maintColor, $securityColor, $warningColor
    )
    $colorIndex = 0

    $categories = @{
        "Upgrade" = @{
            Color = [System.Drawing.Color]::FromArgb(0, 220, 255)
            Items = @(
                @{Text="🔑 Eleva Admin"; Action={Restart-AsAdmin}; Tooltip="Riavvia lo script con privilegi amministrativi.\nNecessario per operazioni che richiedono diritti elevati (DISM, SFC, ecc.)"}
                @{Text="💾 Crea Ripristino"; Action={Do-RestorePoint}; Tooltip="Crea un punto di ripristino del sistema prima di eseguire modifiche"}
                @{Text="🔄 Winget"; Action={Do-Winget}; Tooltip="Aggiorna tutti i programmi installati tramite Winget"}
                @{Text="📦 Store"; Action={Do-StoreUpdate}; Tooltip="Aggiorna tutte le app del Microsoft Store"}
                @{Text="🔍 Cerca WU"; Action={Do-SearchWU}; Tooltip="Cerca gli aggiornamenti disponibili per Windows Update"}
                @{Text="⬇️ Installa WU"; Action={Do-InstallWU}; Tooltip="Scarica e installa tutti gli aggiornamenti di Windows in sospeso"}
                @{Text="🔧 Driver"; Action={Do-DriverUpdate}; Tooltip="Aggiorna driver via Windows Update"}
 #               @{Text="📥 Aggiorna Script"; Action={Do-ScriptUpdate}; Tooltip="Controlla e installa la nuova versione dello script da GitHub"}
				@{Text="📦 Full Update Script"; Action={Do-FullUpdate -Force}; Tooltip="Aggiorna FORZATAMENTE TUTTI i file del repository (script, batch, lib, README, license).\nIgnora il controllo versione."}
                @{Text="▶️ UPGRADE TOTAL"; Action={Do-RunAll}; Tooltip="Esegue la sequenza completa di aggiornamento dei Programmi e di Windows"}				
            )
        }
        "Pulizia" = @{
            Color = [System.Drawing.Color]::FromArgb(255, 180, 100)
            Items = @(
                @{Text="🧹 Temp"; Action={Do-CleanTemp}; Tooltip="Pulisce le cartelle temporanee del sistema e dell'utente"}
                @{Text="💾 Disk Cleanup"; Action={Do-DiskCleanup}; Tooltip="Avvia lo strumento di pulizia disco di Windows"}
                @{Text="📝 Pulisci Log"; Action={Do-CleanLogs}; Tooltip="Pulisci file di log e dump"}
                @{Text="📊 Analisi Disco"; Action={Do-DiskAnalysis}; Tooltip="Analisi dettagliata spazio disco"}				
            )
        }
		"Rete" = @{
			Color = [System.Drawing.Color]::FromArgb(255, 50, 200)
			Items = @(
				@{Text="🌐 Flush DNS"; Action={Do-FlushDNS}; Tooltip="Svuota la cache DNS"}
				@{Text="📶 Renew IP"; Action={Do-RenewIP}; Tooltip="Rinnova l'indirizzo IP della scheda di rete"}
				@{Text="ℹ️ Info IP"; Action={Do-InfoIP}; Tooltip="Mostra tutte le informazioni di configurazione di rete"}
				@{Text="🔧 Winsock"; Action={Do-ResetWinsock}; Tooltip="Resetta lo stack Winsock e il protocollo IP"}
				@{Text="🔄 Reset Rete"; Action={Do-NetworkReset}; Tooltip="Reset completo stack di rete"}
				@{Text="🔑 Wi-Fi Pass"; Action={Do-WifiPasswords}; Tooltip="Visualizza le password salvate delle reti Wi-Fi"}
				@{Text="📡 Ping Test"; Action={Do-SpeedTest}; Tooltip="Esegue un test di latenza verso i server DNS principali"}
				@{Text="🚀 Speed Internet"; Action={Do-SpeedInternet}; Tooltip="Esegue un test della velocità di connessione (Cloudflare)"}
				@{Text="📊 Speed Ookla"; Action={Do-SpeedOokla}; Tooltip="Esegue un test di velocità approfondito con Ookla Speedtest (download, upload, latenza, jitter, packet loss)"}
				@{Text="🗺️ Traceroute"; Action={Do-Traceroute}; Tooltip="Traccia il percorso dei pacchetti verso un IP o dominio.\nInserisci l'indirizzo di destinazione nel popup."}
				@{Text="🔄 Cambia DNS"; Action={Do-ChangeDNS}; Tooltip="Modifica i server DNS delle schede di rete attive.\nScegli tra Google, Cloudflare, OpenDNS, Quad9 o personalizzato."}
				@{Text="🔍 Whois"; Action={Do-Whois}; Tooltip="Mostra informazioni sul proprietario di un IP o dominio.\nInserisci l'indirizzo nel popup."}
				@{Text="🚫 Blacklist Check"; Action={Do-BlacklistCheck}; Tooltip="Verifica se un dominio o IP è segnalato in blacklist (spam, malware, phishing).\nControlla su oltre 80 liste DNSBL tramite PSBlackListChecker (installazione automatica) o fallback su Spamhaus."}
			)
		}		
        "Riparazione" = @{
            Color = [System.Drawing.Color]::FromArgb(210, 150, 255)
            Items = @(
                @{Text="🔨 SFC + DISM"; Action={Do-RepairSystem}; Tooltip="Esegue SFC /scannow e DISM per riparare i file di sistema"}
                @{Text="⏱️ Pt. Ripristino"; Action={Do-RestorePoint}; Tooltip="Crea un punto di ripristino del sistema (limite 24 ore)"}
            )
        }
        "Sicurezza" = @{
            Color = [System.Drawing.Color]::FromArgb(155, 120, 200)
            Items = @(
                @{Text="🛡️ Scan Defender"; Action={Do-SecurityScan}; Tooltip="Avvia una scansione rapida con Windows Defender"}
                @{Text="📋 Event Log"; Action={Do-EventLogErrors}; Tooltip="Mostra gli ultimi errori critici del registro eventi (7gg)"}
                @{Text="🏥 Health Check"; Action={Do-SystemHealth}; Tooltip="Verifica integrità critica del sistema"}
				@{Text="🚫 Blacklist Check"; Action={Do-BlacklistCheck}; Tooltip="Verifica se un dominio o IP è segnalato in blacklist (spam, malware, phishing).\nControlla su oltre 80 liste DNSBL tramite PSBlackListChecker (installazione automatica) o fallback su Spamhaus."}
            )
        }
        "Diagnostica" = @{
            Color = [System.Drawing.Color]::FromArgb(80, 255, 200)
            Items = @(
                @{Text="💻 Info Sistema"; Action={Do-SystemInfo}; Tooltip="Mostra informazioni dettagliate su hardware e sistema operativo"}
                @{Text="🔋 Batteria"; Action={Do-BatteryReport}; Tooltip="Genera un report sulla salute della batteria"}
                @{Text="⏰ Uptime"; Action={Do-Uptime}; Tooltip="Visualizza da quanto tempo il sistema è in esecuzione"}
                @{Text="📈 Top Processi"; Action={Do-TopProcesses}; Tooltip="Elenca i processi che consumano più CPU"}
                @{Text="🚀 Startup"; Action={Do-StartupPrograms}; Tooltip="Elenca i programmi avviati automaticamente all'avvio"}
                @{Text="💿 Spazio Disco"; Action={Do-DiskSpace}; Tooltip="Analizza e mostra lo spazio occupato dalle cartelle principali"}
                @{Text="⚙️ Servizi"; Action={Do-ServiceStatus}; Tooltip="Controlla lo stato dei servizi di sistema principali"}

            )
        }
        "Sistema" = @{
            Color = [System.Drawing.Color]::FromArgb(255, 220, 0)
            Items = @(
                @{Text="🎨 Ottimizza Visivi"; Action={Do-OptimizeVisual}; Tooltip="Ottimizza gli effetti visivi di Windows"}
                @{Text="⚡ Ottimizza Avvio"; Action={Do-BootOptimization}; Tooltip="Ottimizza servizi e avvio sistema"}
                @{Text="🔓 CPU Unlock"; Action={Do-UnlockCPU}; Tooltip="Sblocca le opzioni avanzate di gestione energia della CPU"}	
				@{Text="🖥️ TPM CPU RAM"; Action={Do-TpmCpuRamUnlock}; Tooltip="Rimuove le limitazioni di TPM, CPU e RAM per consentire l'upgrade a Windows 11 su hardware non supportato"}				
                @{Text="🔄 Riavvia PC"; Action={$r=[System.Windows.Forms.MessageBox]::Show("Riavviare?","Conferma","YesNo","Warning");if($r -eq "Yes"){shutdown /r /t 5 /c "Riavvio"}}; Tooltip="Riavvia il sistema dopo 5 secondi"}
            )
        }
        "Dominio" = @{
            Color = [System.Drawing.Color]::FromArgb(100, 200, 255)
            Items = @(
                @{Text="🏢 Info Dominio"; Action={Do-DomainInfo}; Tooltip="Mostra informazioni sul dominio e PC"}
                @{Text="🖥️ Test DC"; Action={Do-DCTest}; Tooltip="Test ping ai Domain Controller"}
                @{Text="🕐 Sincronizza Ora"; Action={Do-SyncTime}; Tooltip="Sincronizza orario con Domain Controller"}
                @{Text="🗑️ Flush Kerberos"; Action={Do-FlushKerberos}; Tooltip="Svuota cache ticket Kerberos"}
                @{Text="📋 Info GPO"; Action={Do-GPOInfo}; Tooltip="Mostra le GPO applicate"}
                @{Text="🔄 Reset Profilo"; Action={Do-ResetNetworkProfile}; Tooltip="Reimposta profilo di rete (disconnette brevemente)"}
                @{Text="🌐 Test DNS"; Action={Do-DNSTest}; Tooltip="Verifica risoluzione DNS dominio"}
                @{Text="📍 Info Sito AD"; Action={Do-ADSiteInfo}; Tooltip="Mostra sito AD corrente"}
                @{Text="🔗 Test LDAP"; Action={Do-LDAPTest}; Tooltip="Verifica connettività LDAP"}
                @{Text="🔑 Cambia Password"; Action={Do-DomainPassword}; Tooltip="Cambia password dominio"},
                @{Text="📅 Ultimo Login"; Action={Do-LastLogin}; Tooltip="Mostra ultimo login dominio"}
                @{Text="👥 Gruppi Utente"; Action={Do-GroupMembership}; Tooltip="Mostra gruppi dominio dell'utente"}
            )
        }
		"Backup" = @{
			Color = [System.Drawing.Color]::FromArgb(200, 255, 100)
			Items = @(
				@{Text="💾 Backup Files"; Action={Do-BackupFiles}; Tooltip="Comprimi e salva files in backup .zip (compressione standard)"}
				@{Text="📦 Backup Avanzato (7z)"; Action={Do-BackupAdvanced}; Tooltip="Esegue backup con compressione 7-Zip massima (livello 9).\nRichiede 7za.exe presente nella cartella dello script (scaricato automaticamente con Full Update).\nSe non trovato, tenta installazione automatica via winget."}
				@{Text="💾 Crea Ripristino"; Action={Do-RestorePoint}; Tooltip="Crea un punto di ripristino del sistema prima di eseguire modifiche"}
			)
		}
        "Privacy" = @{
            Color = [System.Drawing.Color]::FromArgb(255, 100, 0)
            Items = @(
                @{Text="🔒 Privacy Windows"; Action={Do-PrivacyWindows}; Tooltip="Disabilita telemetria, Cortana, segnalazione errori Windows"}
                @{Text="📁 Privacy Office"; Action={Do-PrivacyOffice}; Tooltip="Disabilita telemetria e invio dati di Office"}
                @{Text="🌐 Privacy Edge"; Action={Do-PrivacyEdge}; Tooltip="Disabilita telemetria e suggerimenti di Edge"}
                @{Text="⏰ Privacy Task"; Action={Do-PrivacyTasks}; Tooltip="Disabilita attività pianificate di telemetria"}
                @{Text="🚀 DISABILITA TUTTO"; Action={Do-PrivacyAll}; Tooltip="Esegue TUTTE le privacy in sequenza"}
            )
        }
        "Utility" = @{
            Color = [System.Drawing.Color]::FromArgb(155, 220, 0)
            Items = @(
                @{Text="⚙️ Riavvia su BIOS"; Action={Start-Process "C:\Windows\System32\shutdown.exe" -ArgumentList "/r /fw /f /t 0"}; Tooltip="Riavvia il PC direttamente nel BIOS/UEFI"}
                @{Text="🔁 Riavvia PC"; Action={Start-Process "C:\Windows\System32\shutdown.exe" -ArgumentList "-r -t 00"}; Tooltip="Riavvia il computer immediatamente"}
                @{Text="👤 Disconnetti Utente"; Action={Start-Process "C:\Windows\System32\shutdown.exe" -ArgumentList "/l"}; Tooltip="Disconnette l'utente corrente"}
                @{Text="⏻ Arresta PC"; Action={Start-Process "C:\Windows\System32\shutdown.exe" -ArgumentList "-s -f -t 00"}; Tooltip="Spegne il computer immediatamente"}
                @{Text="⏰ Shutdown Sched."; Action={Do-ScheduleShutdown}; Tooltip="Programma lo spegnimento forzato del PC ogni giorno"}
                @{Text="❌ Rimuovi Shutdown"; Action={Do-RemoveShutdown}; Tooltip="Rimuove il task di spegnimento programmato"}
                @{Text="💬 AI Chat"; Action={Show-AIChatDialog}; Tooltip="Apre il dialogo AI Chat con supporto Gemini, Groq, Cloudflare e Bynara"}
                @{Text="🔍 Ricerca File"; Action={Show-SearchDialog}; Tooltip="Apre il dialogo di ricerca rapida file e contenuti"}
                @{Text="⏹️ Annulla"; Action={$script:cancelRequested=$true}; Tooltip="Annulla l'operazione in corso in modo sicuro"}
 #               @{Text="❌ Esci"; Action={$script:isClosing=$true;$script:form.Close()}; Tooltip="Chiude l'applicazione di manutenzione"}
                @{Text="🖥️ Assist. Remota"; Action={Do-RemoteAssist}; Tooltip="Scarica e avvia RustDesk per assistenza remota"}
				@{Text="🌐 Assist. LAN"; Action={Do-VNCViewer}; Tooltip="Avvia TightVNC Viewer portatile per assistenza remota in LAN"}
				@{Text="🖥️ RDP LAN"; Action={Do-RDPManager}; Tooltip="Gestisce, salva e avvia sessioni Desktop Remoto nella cartella Prompt"}				
				
            )
        }
    }

    # --- HEADER CON CATEGORIE A 2 RIGHE E ICONE ---
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Dock = "Top"
    $headerPanel.BackColor = $bgPanel
    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)

    $headerTable = New-Object System.Windows.Forms.TableLayoutPanel
    $headerTable.Dock = "Fill"
    $headerTable.ColumnCount = 2
    $headerTable.RowCount = 1
    $headerTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $headerTable.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $headerTable.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $headerTable.BackColor = $bgPanel
    $headerPanel.Controls.Add($headerTable)

    # Colonna 0: Titolo + badge + versione
    $titleContainer = New-Object System.Windows.Forms.FlowLayoutPanel
    $titleContainer.Dock = "Fill"
    $titleContainer.FlowDirection = "LeftToRight"
    $titleContainer.BackColor = $bgPanel
    $titleContainer.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)

	# Crea un LinkLabel invece di una Label
	$titleLabel = New-Object System.Windows.Forms.LinkLabel
	$titleLabel.Text = "⚡ MANUTENZIONE PRO MAX"
	$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
	$titleLabel.ForeColor = $fgColor
	$titleLabel.AutoSize = $true
	$titleLabel.TextAlign = "MiddleLeft"
	$titleLabel.LinkColor = $fgColor           # Colore del link (bianco/azzurro)
	$titleLabel.ActiveLinkColor = $accentColor # Colore quando cliccato
	$titleLabel.VisitedLinkColor = $fgDim      # Colore dopo la visita
	$titleLabel.LinkBehavior = "AlwaysUnderline" # Sottolineato sempre (o "HoverUnderline")
	$titleLabel.Cursor = [System.Windows.Forms.Cursors]::Hand

	# Aggiungi l'evento click
	$titleLabel.Add_LinkClicked({
		param($sender, $e)
		Start-Process "https://github.com/pierpaolosanna/ManutenzioneProMax/archive/refs/heads/main.zip"
	})

	$titleContainer.Controls.Add($titleLabel)

    $adminBadge = New-Object System.Windows.Forms.Label
    $adminBadge.Font = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
    $adminBadge.AutoSize = $true
    $adminBadge.Margin = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
    if ($isAdmin) {
        $adminBadge.Text = "🔒 ADMIN"
        $adminBadge.ForeColor = $successColor
    } else {
        $adminBadge.Text = "👤 UTENTE"
        $adminBadge.ForeColor = $warningColor
    }
    $titleContainer.Controls.Add($adminBadge)

    $psVer = "PS$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
    $verLabel = New-Object System.Windows.Forms.Label
    $verLabel.Text = "v$($script:currentVersion) | $psVer"
    $verLabel.Font = New-Object System.Drawing.Font("Segoe UI", 7)
    $verLabel.ForeColor = $fgDim
    $verLabel.AutoSize = $true
    $verLabel.TextAlign = "MiddleLeft"
    $verLabel.Margin = New-Object System.Windows.Forms.Padding(15, 0, 0, 0)
    $titleContainer.Controls.Add($verLabel)

    $headerTable.Controls.Add($titleContainer, 0, 0)

    # Colonna 1: Categorie
    $categoryGrid = New-Object System.Windows.Forms.TableLayoutPanel
    $categoryGrid.Dock = "Fill"
    $categoryGrid.RowCount = 2
    $categoryGrid.ColumnCount = 0
    $categoryGrid.BackColor = $bgPanel
    $categoryGrid.Padding = New-Object System.Windows.Forms.Padding(4, 2, 4, 2)
    $categoryGrid.AutoSize = $false
    $categoryGrid.GrowStyle = "AddColumns"
    $categoryGrid.RowStyles.Clear()
    $categoryGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $categoryGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $headerTable.Controls.Add($categoryGrid, 1, 0)

    $script:selectedCategory = $null
    $categoryButtons = @{}
    $catList = @($categories.Keys)
    $numCols = [Math]::Ceiling($catList.Count / 2)
    $colWidth = 155

    $catIcons = @{
        "Upgrade"     = "⬆️"
        "Pulizia"     = "🧹"
        "Rete"        = "🌐"
        "Riparazione" = "🔧"
        "Sicurezza"   = "🛡️"
        "Diagnostica" = "📊"
        "Sistema"     = "⚙️"
        "Dominio"     = "🏢"
        "Backup"      = "💾"
        "Privacy"     = "🔒"
        "Utility"     = "🧰"
    }

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
            $btn.BackColor = $bgCard
            $btn.ForeColor = $catColor
            $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(60, 60, 80)
            $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(80, 80, 100)
            $btn.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
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
                    $b.BackColor = $bgCard
                    $b.ForeColor = $categories[$b.Tag].Color
                    $b.FlatAppearance.BorderColor = $categories[$b.Tag].Color
                }
                $sender.BackColor = $catColor
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

    # --- SEPARATORE ---
    $separator = New-Object System.Windows.Forms.Panel
    $separator.Dock = "Top"
    $separator.Height = 2
    $separator.BackColor = $separatorColor
    $script:form.Controls.Add($separator)

    # --- LAYOUT PRINCIPALE ---
    $mainPanel = New-Object System.Windows.Forms.Panel
    $mainPanel.Dock = "Fill"
    $mainPanel.BackColor = $bgColor
    $mainPanel.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
    $script:form.Controls.Add($mainPanel)

    $tableLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $tableLayout.Dock = "Fill"
    $tableLayout.ColumnCount = 2
    $tableLayout.RowCount = 1
    $tableLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 15)))
    $tableLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 85)))
    $tableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $tableLayout.BackColor = $bgColor
    $mainPanel.Controls.Add($tableLayout)

    # --- PANNELLO PULSANTI (verticale) ---
    $buttonGrid = New-Object System.Windows.Forms.TableLayoutPanel
    $buttonGrid.Dock = "Fill"
    $buttonGrid.ColumnCount = 1
    $buttonGrid.RowCount = 0
    $buttonGrid.AutoScroll = $true
    $buttonGrid.BackColor = $bgPanel
    $buttonGrid.Padding = New-Object System.Windows.Forms.Padding(6, 120, 6, 6)
    $tableLayout.Controls.Add($buttonGrid, 0, 0)

    # --- PANNELLO LOG (riempie lo spazio) ---
    $logPanel = New-Object System.Windows.Forms.Panel
    $logPanel.Dock = "Fill"
    $logPanel.BackColor = $bgColor
    $logPanel.Padding = New-Object System.Windows.Forms.Padding(15, 5, 15, 5)
    $tableLayout.Controls.Add($logPanel, 1, 0)

    # --- LOG BOX ---
    $logBoxPanel = New-Object System.Windows.Forms.Panel
    $logBoxPanel.Dock = "Fill"
    $logBoxPanel.BackColor = $logBg
    $logBoxPanel.Padding = New-Object System.Windows.Forms.Padding(2, 25, 2, 2)
    $logBoxPanel.BorderStyle = "FixedSingle"
    $logPanel.Controls.Add($logBoxPanel)

    $script:logBox = New-Object System.Windows.Forms.RichTextBox
    $script:logBox.Dock = "Fill"
    $script:logBox.BackColor = $logBg
    $script:logBox.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 210)
    $script:logBox.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Regular)
    $script:logBox.ReadOnly = $true
    $script:logBox.BorderStyle = "None"
    $script:logBox.ScrollBars = "ForcedVertical"
    $script:logBox.WordWrap = $false
    $script:logBox.DetectUrls = $false
    $script:logBox.ShortcutsEnabled = $true
    $logBoxPanel.Controls.Add($script:logBox)

    # --- STATO (in basso, aggiunto al mainPanel, non al logPanel) ---
    $statusPanel = New-Object System.Windows.Forms.Panel
    $statusPanel.Dock = "Bottom"
    $statusPanel.Height = 58
    $statusPanel.BackColor = $bgPanel
    $statusPanel.Padding = New-Object System.Windows.Forms.Padding(5, 2, 5, 2)
    $statusPanel.BorderStyle = "FixedSingle"

    $script:statusLabel = New-Object System.Windows.Forms.Label
    $script:statusLabel.Text = "✅ Pronto"
    $script:statusLabel.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 8)
    $script:statusLabel.ForeColor = $fgDim
    $script:statusLabel.Location = New-Object System.Drawing.Point(8, 1)
    $script:statusLabel.Size = New-Object System.Drawing.Size(250, 16)
    $statusPanel.Controls.Add($script:statusLabel)

    $script:progressLabel = New-Object System.Windows.Forms.Label
    $script:progressLabel.Text = "0%"
    $script:progressLabel.Font = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
    $script:progressLabel.ForeColor = $accentColor
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
    $script:progressBar.ForeColor = $accentColor
    $script:progressBar.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 48)
    $statusPanel.Controls.Add($script:progressBar)

    $statusPanel.Add_Resize({ $script:progressBar.Width = $statusPanel.Width - 16 })

    # Aggiungi statusPanel al mainPanel (in basso)
    $mainPanel.Controls.Add($statusPanel)

    # --- FUNZIONE AGGIORNA PULSANTI (verticale) ---
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
            $btn.BackColor = $bgCard
            $btn.ForeColor = $categoryColor
            $btn.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
            $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
            $btn.TextAlign = "MiddleLeft"
            $btn.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
            $btn.Height = 34
            $btn.Margin = New-Object System.Windows.Forms.Padding(5, 4, 5, 4)
            $btn.Dock = [System.Windows.Forms.DockStyle]::Fill
            $btn.Add_Click($btnData.Action)
            if ($btnData.Tooltip) {
                $tt = New-Object System.Windows.Forms.ToolTip
                $tt.SetToolTip($btn, $btnData.Tooltip)
            }
            $buttonGrid.RowCount++
            $buttonGrid.Controls.Add($btn, 0, $rowIndex)
            $buttonGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
            $rowIndex++
        }
        $buttonGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    }

    # --- Progress Pulse ---
    function Start-ProgressPulse {
        if ($script:pulseTimer) { $script:pulseTimer.Stop() }
        $script:pulseTimer = New-Object System.Windows.Forms.Timer
        $script:pulseTimer.Interval = 200
        $script:pulseTimer.Add_Tick({
            $script:pulseState = ($script:pulseState + 1) % 4
            $color = $script:pulseColors[$script:pulseState]
            $script:progressBar.ForeColor = $color
            $script:progressLabel.ForeColor = $color
        })
        $script:pulseTimer.Start()
    }

    function Stop-ProgressPulse {
        if ($script:pulseTimer) {
            $script:pulseTimer.Stop()
            $script:pulseTimer.Dispose()
            $script:pulseTimer = $null
        }
        $script:progressBar.ForeColor = $accentColor
        $script:progressLabel.ForeColor = $accentColor
    }

    function Update-Progress($value) {
        if ($script:progressBar -and -not $script:isClosing) {
            $v = [Math]::Max(0, [Math]::Min($value, 100))
            $script:progressBar.Value = $v
            if ($script:progressLabel) { $script:progressLabel.Text = "$v%" }
            if ($v -gt 0 -and $v -lt 100) {
                Start-ProgressPulse
            } else {
                Stop-ProgressPulse
            }
        }
    }

    # Inizializza
    Update-Buttons

    $script:uiTimer = New-Object System.Windows.Forms.Timer
    $script:uiTimer.Interval = 100
    $script:uiTimer.Add_Tick({ Flush-LogBuffer })
    $script:uiTimer.Start()

    $script:form.Add_Shown({
        Log ""; Log " ⚡ Manutenzione PRO MAX v$($script:currentVersion) Peters"
        Log " $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $psVer"
        Log " Log: $logFile"; Log ""
        Flush-LogBuffer

        $script:logBox.SuspendLayout()
        $script:logBox.SelectionStart = $script:logBox.TextLength
        $script:logBox.SelectionLength = 0
        $script:logBox.SelectionColor = $successColor
        $script:logBox.SelectionFont = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
        if ($isAdmin) {
            $msg = "✅ Sei già amministratore. Tutte le funzionalità sono disponibili.`nCrea sempre un punto di ripristino con Crea Ripristino prima di ogni modifica."
        } else {
            $msg = "🚀 Esegui 'Eleva Admin' per ottenere le complete potenzialità.`nCrea sempre un punto di ripristino con Crea Ripristino prima di ogni modifica."
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
            $remoteVersionUrl = $script:githubRawUrl + $script:versionFileName
            $remoteVersion = (Invoke-WebRequest -Uri $remoteVersionUrl -UseBasicParsing -TimeoutSec 10).Content.Trim()
            if ($remoteVersion -ne $script:currentVersion) {
                Log "[!] Nuova versione disponibile: $remoteVersion (locale: $($script:currentVersion))"
                $response = [System.Windows.Forms.MessageBox]::Show(
                    "Versione $remoteVersion disponibile (hai la $($script:currentVersion)).`nEseguire Full Update?",
                    "Aggiornamento Disponibile",
                    "YesNo",
                    "Question"
                )
                if ($response -eq "Yes") { Do-FullUpdate }
            } else {
                Log "[OK] Script aggiornato da PeterS (v$($script:currentVersion))"
            }
        } catch {
            Log "[!] Impossibile verificare aggiornamenti: $($_.Exception.Message)"
        }
        Flush-LogBuffer; Pump-UI
    })

    [System.Windows.Forms.Application]::Run($script:form)
}
# ============================================================
# BLOCCO 15 - AVVIO APPLICAZIONE
# ============================================================
Build-GUI
