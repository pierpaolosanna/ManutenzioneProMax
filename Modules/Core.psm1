# ============================================================
# CORE.psm1 - Funzioni di base per Manutenzione PRO MAX
# Versione: 1.0.1
# ============================================================

# ---------- VARIABILI INTERNE DEL MODULO ----------
$script:logBox = $null
$script:progressBar = $null
$script:progressLabel = $null
$script:statusLabel = $null
$script:form = $null
$script:isClosing = $false
$script:cancelRequested = $false
$script:logBuffer = [System.Text.StringBuilder]::new()
$script:lastFlush = [DateTime]::Now
$script:pulseTimer = $null
$script:pulseState = 0
$script:pulseColors = @(
    [System.Drawing.Color]::FromArgb(255, 220, 0),
    [System.Drawing.Color]::FromArgb(255, 140, 0),
    [System.Drawing.Color]::FromArgb(0, 255, 100),
    [System.Drawing.Color]::FromArgb(255, 80, 80)
)
$script:accentColor = [System.Drawing.Color]::FromArgb(56, 132, 244)
$script:logFile = $null

function Log-Color {
    param(
        [string]$TextBefore,
        [string]$TextToColor,
        [string]$TextAfter = "",
        [System.Drawing.Color]$Color,
        [string]$FontStyle = "Regular"
    )
    $rtb = $script:logBox
    if ($rtb -and $rtb.GetType().Name -eq "RichTextBox") {
        $rtb.AppendText($TextBefore)
        $startIdx = $rtb.TextLength
        $rtb.AppendText($TextToColor)
        $rtb.Select($startIdx, $TextToColor.Length)
        if ($Color) { $rtb.SelectionColor = $Color }
        if ($FontStyle -eq "Bold") {
            $rtb.SelectionFont = New-Object System.Drawing.Font($rtb.Font.FontFamily, $rtb.Font.Size, [System.Drawing.FontStyle]::Bold)
        }
        $rtb.SelectionLength = 0
        $rtb.SelectionColor = $rtb.ForeColor
        $rtb.AppendText($TextAfter + "`r`n")
        $rtb.ScrollToCaret()
    } else {
        Log "$TextBefore$TextToColor$TextAfter"
    }
}
# ---------- FUNZIONE DI INIZIALIZZAZIONE UI ----------
function Set-CoreUI {
    param(
        $LogBox,
        $ProgressBar,
        $ProgressLabel,
        $StatusLabel,
        $Form,
        [string]$LogFile
    )
    $script:logBox = $LogBox
    $script:progressBar = $ProgressBar
    $script:progressLabel = $ProgressLabel
    $script:statusLabel = $StatusLabel
    $script:form = $Form
    $script:logFile = $LogFile
}

# ---------- FUNZIONI DI LOGGING E UTILITY ----------
function Is-SpinnerLine($line) {
    if (-not $line) { return $false }
    $s = "$line".Trim()
    if (-not $s) { return $false }
    return ($s -match '^(?:[-\\|/])$' -or $s -match '^(?:[-\\|/]\s*)+$')
}

function Get-PercentFromLine($line) {
    if (-not $line) { return $null }
    $m = [regex]::Match("$line", '(?<!\d)(0|[1-9]?\d)%')
    if ($m.Success) { return [int]$m.Groups[1].Value } else { return $null }
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
    try {
        if ($script:logFile) { "$msg" | Out-File -FilePath $script:logFile -Append -Encoding UTF8 -ErrorAction SilentlyContinue }
    } catch {}
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

function Pump-UI {
    if (-not $script:isClosing) {
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Test-Cancel {
    Pump-UI
    if ($script:cancelRequested) {
        Log "[STOP] Annullato."
        $script:cancelRequested = $false
        return $true
    } else {
        return $false
    }
}

function Test-WingetAvailable {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Set-StepProgress($stepPercent, $stepStart, $stepEnd) {
    $p = [Math]::Max(0, [Math]::Min($stepPercent, 100))
    $start = [Math]::Max(0, [Math]::Min($stepStart, 100))
    $end = [Math]::Max(0, [Math]::Min($stepEnd, 100))
    $overall = [Math]::Round($start + (($end - $start) * ($p / 100.0)))
    Update-Progress $overall
    if ($script:progressLabel) { $script:progressLabel.Text = "$p%" }
}

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
    $script:progressBar.ForeColor = $script:accentColor
    $script:progressLabel.ForeColor = $script:accentColor
}

# ---------- FUNZIONI DI ESECUZIONE PROCESSI ----------
function Run-ProcessRealtime {
    param([string]$fileName, [string]$processArguments, [string]$description, [int]$stepStart = -1, [int]$stepEnd = -1)
    Log ""; Log "==============================================================================================="; Log "[>] $description"; Log "==============================================================================================="
    $process = $null
    try {
        Log "[CMD] $fileName $processArguments"; Log ""
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $fileName; $psi.Arguments = $processArguments; $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.CreateNoWindow = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8; $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        $process = New-Object System.Diagnostics.Process; $process.StartInfo = $psi; $process.EnableRaisingEvents = $true
        $oQ = [System.Collections.Concurrent.ConcurrentQueue[string]]::new(); $eQ = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
        $oH = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action { $l = $Event.SourceEventArgs.Data; if ($null -ne $l) { $Event.MessageData.Enqueue($l) } } -MessageData $oQ
        $eH = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action { $l = $Event.SourceEventArgs.Data; if ($null -ne $l -and $l.Trim()) { $Event.MessageData.Enqueue($l) } } -MessageData $eQ
        $process.Start() | Out-Null; $process.BeginOutputReadLine(); $process.BeginErrorReadLine()
        while (-not $process.HasExited -or $oQ.Count -gt 0) {
            if ($script:cancelRequested) { try { $process.Kill() } catch { }; Log "[STOP] Terminato."; $script:cancelRequested = $false; break }
            $l = $null; $c = 0
            while ($oQ.TryDequeue([ref]$l) -and $c -lt 30) { $c++; if (-not $l -or (Is-SpinnerLine $l)) { continue }; $lp = Get-PercentFromLine $l; if ($null -ne $lp -and $stepStart -ge 0 -and $stepEnd -ge 0) { Set-StepProgress $lp $stepStart $stepEnd }; $f = Format-LogLine $l; if ($f) { Log $f } }
            $el = $null; while ($eQ.TryDequeue([ref]$el)) { if ($el -and $el.Trim() -and -not (Is-SpinnerLine $el)) { Log " [X] $($el.Trim())" } }
            Flush-LogBuffer; Pump-UI; if (-not $process.HasExited) { Start-Sleep -Milliseconds 50 }
        }
        Start-Sleep -Milliseconds 200
        $l = $null; while ($oQ.TryDequeue([ref]$l)) { if ($l -and -not (Is-SpinnerLine $l)) { $f = Format-LogLine $l; if ($f) { Log $f } } }
        $el = $null; while ($eQ.TryDequeue([ref]$el)) { if ($el -and $el.Trim()) { Log " [X] $($el.Trim())" } }
        Unregister-Event -SourceIdentifier $oH.Name -ErrorAction SilentlyContinue; Unregister-Event -SourceIdentifier $eH.Name -ErrorAction SilentlyContinue
        Remove-Job $oH -Force -ErrorAction SilentlyContinue; Remove-Job $eH -Force -ErrorAction SilentlyContinue
        $ec = $process.ExitCode; Log ""
        if ($stepStart -ge 0 -and $stepEnd -ge 0 -and $ec -eq 0) { Set-StepProgress 100 $stepStart $stepEnd }
        if ($ec -eq 0) { Log "[OK] Completato." } else { Log "[!] Codice: $ec" }
        Update-Progress 100; Flush-LogBuffer; return $ec
    } catch { Log "[X] $($_.Exception.Message)"; Flush-LogBuffer; Update-Progress 100; return -1 } finally { if ($process) { try { $process.Dispose() } catch { } } }
}

function Run-SimpleCommand {
    param([string]$cmd, [string]$args, [string]$desc, [int]$start = 0, [int]$end = 100)
    Run-ProcessRealtime $cmd $args $desc $start $end
}

# ---------- FUNZIONI DI INSTALLAZIONE MODULI DA GITHUB ----------
function Install-ModuleFromGitHub {
    param(
        [string]$ModuleName,
        [string]$RepoUrl,
        [string]$SubFolder = $null
    )
    if (Get-Module -Name $ModuleName -ListAvailable -ErrorAction SilentlyContinue) {
        Log "[OK] $ModuleName già installato."
        return $true
    }
    Log "[!] $ModuleName non trovato. Installazione da GitHub..."
    try {
        $zipPath = "$env:TEMP\$ModuleName.zip"
        Log "[DL] Download $ModuleName da GitHub..."
        Invoke-WebRequest -Uri $RepoUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        $extractPath = "$env:TEMP\$ModuleName"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force -ErrorAction Stop
        $baseFolder = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
        if ($baseFolder) {
            $sourcePath = $baseFolder.FullName
            if ($SubFolder) {
                $testPath = Join-Path $baseFolder.FullName $SubFolder
                if (Test-Path $testPath) { $sourcePath = $testPath }
            }
            $modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\$ModuleName"
            New-Item -ItemType Directory -Force -Path $modulePath | Out-Null
            Copy-Item -Path "$sourcePath\*" -Destination $modulePath -Recurse -Force
            Log "[OK] $ModuleName installato da GitHub"
        }
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        if (Get-Module -Name $ModuleName -ListAvailable -ErrorAction SilentlyContinue) { Log "[OK] $ModuleName installato."; return $true }
    } catch {
        Log "[X] Errore installazione $ModuleName : $($_.Exception.Message)"
    }
    return $false
}

function Ensure-ModulesForBlacklist {
    Install-ModuleFromGitHub -ModuleName "PSWriteColor" -RepoUrl "https://github.com/EvotecIT/PSWriteColor/archive/refs/heads/master.zip" -SubFolder "PSWriteColor"
    Install-ModuleFromGitHub -ModuleName "PSTeams" -RepoUrl "https://github.com/EvotecIT/PSTeams/archive/refs/heads/master.zip" -SubFolder "Module\PSTeams"
    Install-ModuleFromGitHub -ModuleName "PSSharedGoods" -RepoUrl "https://github.com/EvotecIT/PSSharedGoods/archive/refs/heads/master.zip" -SubFolder "PSSharedGoods"
    Install-ModuleFromGitHub -ModuleName "PSSlack" -RepoUrl "https://github.com/RamblingCookieMonster/PSSlack/archive/refs/heads/master.zip" -SubFolder "PSSlack"
    Install-ModuleFromGitHub -ModuleName "PSDiscord" -RepoUrl "https://github.com/EvotecIT/PSDiscord/archive/refs/heads/master.zip" -SubFolder "PSDiscord"
    if (Install-ModuleFromGitHub -ModuleName "PSBlackListChecker" -RepoUrl "https://github.com/EvotecIT/PSBlackListChecker/archive/refs/heads/master.zip" -SubFolder "PSBlackListChecker") {
        try { Import-Module -Name PSBlackListChecker -Force -ErrorAction Stop; return $true }
        catch { Log "[!] Errore importazione PSBlackListChecker: $($_.Exception.Message)" }
    }
    return $false
}

function Invoke-GitHubDownloadRecursive {
    param([string]$ApiUrl, [string]$LocalPath, [string]$BasePath = "")
    $items = Invoke-RestMethod -Uri $ApiUrl -Method Get -UseBasicParsing -TimeoutSec 15
    foreach ($item in $items) {
        if ($item.type -eq "dir") {
            if ($item.name -in @("Prompt", "Docs")) { continue }
            $newLocalPath = Join-Path $LocalPath $item.name
            New-Item -ItemType Directory -Force -Path $newLocalPath | Out-Null
            Invoke-GitHubDownloadRecursive -ApiUrl $item.url -LocalPath $newLocalPath -BasePath "$BasePath/$($item.name)"
        } elseif ($item.type -eq "file") {
            $localFile = Join-Path $LocalPath $item.name
            try { Log "[DL] Download: $BasePath/$($item.name)..."; Invoke-WebRequest -Uri $item.download_url -OutFile $localFile -UseBasicParsing -ErrorAction Stop; Log "[OK] Scaricato: $BasePath/$($item.name)" } catch { Log "[X] Errore download $BasePath/$($item.name): $($_.Exception.Message)" }
        }
    }
}

# Espone le funzioni agli altri moduli
Export-ModuleMember -Function @(
    'Set-CoreUI',
    'Is-SpinnerLine',
    'Get-PercentFromLine',
    'Format-LogLine',
    'Flush-LogBuffer',
    'Log',
    'Log-Output',
    'Log-Color',                    # <--- AGGIUNGI QUI
    'Update-Progress',
    'Update-Status',
    'Pump-UI',
    'Test-Cancel',
    'Test-WingetAvailable',
    'Set-StepProgress',
    'Start-ProgressPulse',
    'Stop-ProgressPulse',
    'Run-ProcessRealtime',
    'Run-SimpleCommand',
    'Install-ModuleFromGitHub',
    'Ensure-ModulesForBlacklist',
    'Invoke-GitHubDownloadRecursive'
)
