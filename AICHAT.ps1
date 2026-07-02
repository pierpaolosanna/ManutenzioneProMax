# ============================================================
# AICHAT.ps1 - Modulo AI Chat per Manutenzione PRO MAX
# Versione: 1.0.0
# Data: 2026-07-01
# Descrizione: Fornisce funzionalità di chat AI con supporto
#              Gemini, Groq, Cloudflare e Bynara
# ============================================================

# ---------- VARIABILI GLOBALI ----------
$Global:AIChatState = $null
$Global:ButtonDocsFolder = $null

# ---------- FUNZIONI DI INIZIALIZZAZIONE ----------
function Initialize-AIChatState {
    $scriptPath = $PSScriptRoot
    if (-not $scriptPath) { $scriptPath = $PWD.Path }
    
    $Global:AIChatState = [PSCustomObject]@{
        PromptFolder = [System.IO.Path]::Combine($scriptPath, "Prompt")
        GeminiApiKey = "AQ.Ab8RN6JxWfE8582tR8IoEI2sjEkQZzloy6GhqxJglSi7EMD3VA"
        GroqApiKey = "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"
        CloudflareAccount = "4eb2a33f25a0bb6fa5b5308fead39fbc"
        CloudflareToken = "cfut_6RPuzHCo9V8fas1gGZAXEJP9480p2knBosfGxul3b3ede706"
        BynaraApiKey = "sk-nry-dw-_WrZpJ0O01c1fDIDayAyhMQFakSEv4z8Wp0s7UfE"
        
        Models = @{
            "Gemini" = @("gemini-2.5-flash", "gemini-2.0-flash")
            "Groq" = @("llama-3.1-8b-instant", "mixtral-8x7b-32768")
            "Cloudflare" = @("@cf/meta/llama-3.3-70b-instruct-fp8-fast", "@cf/meta/llama-3.1-8b-instruct")
            "Bynara" = @("mimo-v2.5-free")
        }
        
        Agents = @()
        CurrentProvider = "Gemini"
        Model = "gemini-2.5-flash"
        Temperature = 0.7
        TopP = 0.95
        MaxTokens = 4096
        SystemPrompt = "Sei un assistente AI utile e conciso. Rispondi in italiano quando l'utente scrive in italiano."
        MaxRetries = 2
        
        History = [System.Collections.Generic.List[Object]]::new()
        ChatLog = ""
        SessionTokens = 0
        LastReply = ""
        
        ModelTokenUsage = @{}
        ModelRequestCount = @{}
        
        AttachedFiles = [System.Collections.Generic.List[Object]]::new()
        MaxFileSizeChars = 50000
    }
    
    if (-not (Test-Path $Global:AIChatState.PromptFolder)) {
        New-Item -Path $Global:AIChatState.PromptFolder -ItemType Directory -Force | Out-Null
    }
    
    Load-AIAgentsFromDisk
}

function Load-AIAgentsFromDisk {
    $Global:AIChatState.Agents = @()
    $mdFiles = Get-ChildItem -Path $Global:AIChatState.PromptFolder -Filter "*.md" -ErrorAction SilentlyContinue
    foreach ($file in $mdFiles) {
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        $Global:AIChatState.Agents += @{ Name = $file.BaseName; Prompt = $content }
    }
}

function Initialize-ButtonDocs {
    $scriptPath = $PSScriptRoot
    if (-not $scriptPath) { $scriptPath = $PWD.Path }
    
    $Global:ButtonDocsFolder = [System.IO.Path]::Combine($scriptPath, "Docs", "Buttons")
    
    if (-not (Test-Path $Global:ButtonDocsFolder)) {
        New-Item -Path $Global:ButtonDocsFolder -ItemType Directory -Force | Out-Null
    }
    
    $sampleDocs = @{}
    $sampleDocs["Winget.md"] = "# Winget - Aggiornamento Programmi`r`n`r`n## Descrizione`r`nAggiorna tutti i programmi installati tramite il package manager Winget.`r`n`r`n## Cosa fa`r`n- Cerca gli aggiornamenti per tutti i pacchetti installati`r`n- Scarica e installa gli aggiornamenti automaticamente`r`n- Supporta i pacchetti dal repository pubblico di Microsoft`r`n`r`n## Quando usarlo`r`n- Settimanalmente per mantenere aggiornati i programmi`r`n- Dopo una nuova installazione di Windows`r`n- Quando si riscontrano problemi di compatibilità`r`n`r`n## Avvertenze`r`n- Richiede connessione internet`r`n- Alcuni aggiornamenti potrebbero richiedere il riavvio"
    $sampleDocs["Store.md"] = "# Store - Aggiornamento App Microsoft Store`r`n`r`n## Descrizione`r`nAggiorna tutte le applicazioni installate dal Microsoft Store.`r`n`r`n## Cosa fa`r`n- Cerca aggiornamenti per tutte le app dello Store`r`n- Scarica e installa le nuove versioni`r`n- Avvia lo Store in background per download e aggiornamenti`r`n`r`n## Quando usarlo`r`n- Per mantenere aggiornate le app UWP/Store`r`n- Quando un'app dello Store non funziona correttamente`r`n`r`n## Avvertenze`r`n- Richiede connessione internet`r`n- Alcune app potrebbero richiedere il riavvio"
    $sampleDocs["SFC-DISM.md"] = "# SFC + DISM - Riparazione Sistema`r`n`r`n## Descrizione`r`nEsegue la scansione e riparazione dei file di sistema danneggiati.`r`n`r`n## Cosa fa`r`n1. SFC scannow - Verifica l'integrita dei file di sistema protetti`r`n2. DISM RestoreHealth - Ripara l'immagine di sistema`r`n`r`n## Quando usarlo`r`n- Quando Windows presenta errori o crash frequenti`r`n- Dopo un aggiornamento problematico`r`n- Per risolvere problemi di stabilita`r`n`r`n## Avvertenze`r`n- Richiede privilegi amministrativi`r`n- Puo richiedere molto tempo (20-60 minuti)`r`n- Riavvio consigliato dopo l'esecuzione"
    $sampleDocs["FlushDNS.md"] = "# Flush DNS - Svuota Cache DNS`r`n`r`n## Descrizione`r`nSvuota la cache DNS locale del computer.`r`n`r`n## Cosa fa`r`n- Rimuove tutti i record DNS memorizzati nella cache`r`n- Forza il sistema a richiedere nuovi record DNS`r`n`r`n## Quando usarlo`r`n- Quando un sito non si apre correttamente`r`n- Dopo aver cambiato server DNS`r`n- Per risolvere problemi di risoluzione nomi`r`n`r`n## Avvertenze`r`n- Non richiede riavvio`r`n- Effetto immediato"
    $sampleDocs["PrivacyAll.md"] = "# Privacy - Disabilita Tutto`r`n`r`n## Descrizione`r`nEsegue in sequenza TUTTE le operazioni di privacy.`r`n`r`n## Cosa fa`r`n- Disabilita telemetria Windows`r`n- Disabilita telemetria Office`r`n- Disabilita telemetria Edge`r`n- Disabilita attivita pianificate di telemetria`r`n`r`n## Quando usarlo`r`n- Su PC nuovi o appena reinstallati`r`n- Per massimizzare la privacy`r`n- Una sola volta per sistema`r`n`r`n## Avvertenze`r`n- Richiede privilegi amministrativi`r`n- Riavvio consigliato dopo l'esecuzione`r`n- Alcune funzionalita di Windows potrebbero essere limitate"
    
    foreach ($key in $sampleDocs.Keys) {
        $filePath = [System.IO.Path]::Combine($Global:ButtonDocsFolder, $key)
        if (-not (Test-Path $filePath)) {
            $sampleDocs[$key] | Out-File -FilePath $filePath -Encoding UTF8 -Force
        }
    }
}

# Inizializza le cartelle all'avvio
Initialize-AIChatState
Initialize-ButtonDocs

# ---------- FUNZIONI DI RICERCA ----------
function Search-AIWeb([string]$Query) {
    $encoded = [System.Uri]::EscapeDataString($Query)
    $ctx = @()
    try {
        $ddg = Invoke-RestMethod -Uri "https://api.duckduckgo.com/?q=$encoded&format=json&no_html=1&skip_disambig=1" -TimeoutSec 6
        if ($ddg.Abstract) { $ctx += "Sommario: $($ddg.Abstract)" }
        if ($ddg.Answer) { $ctx += "Risposta: $($ddg.Answer)" }
    } catch {}
    try {
        $wiki = Invoke-RestMethod -Uri "https://it.wikipedia.org/api/rest_v1/page/summary/$encoded" -TimeoutSec 6
        if ($wiki.extract) { $ctx += "Wikipedia: $($wiki.extract)" }
    } catch {}
    return ($ctx -join "`r`n")
}

function Get-AIWeatherData([string]$Query) {
    $location = $Query -replace '(che|quale|il|la|meteo|tempo|fa|oggi|domani|a|adesso|in|cerca)\s*', ''
    $location = $location.Trim()
    if ($location.Length -lt 2) { $location = "Italia" }
    
    try {
        $url = "https://wttr.in/$([System.Uri]::EscapeDataString($location))?format=4&lang=it"
        $weather = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 5
        if ($weather -and $weather -notmatch "Unknown location") {
            return "Dati meteo reali per $location`: $weather"
        }
    } catch {}
    return $null
}

# ---------- FUNZIONI API ----------
function Send-AIRequest {
    $S = $Global:AIChatState
    $msgs = @()
    if ($S.SystemPrompt) { $msgs += @{ role = "system"; content = $S.SystemPrompt } }
    $msgs += $S.History.ToArray()
    $bodyObj = @{ messages = $msgs; temperature = $S.Temperature; top_p = $S.TopP; max_tokens = $S.MaxTokens }
    $headers = @{ "Content-Type" = "application/json; charset=utf-8" }

    switch ($S.CurrentProvider) {
        "Gemini" {
            $url = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
            $headers["Authorization"] = "Bearer $($S.GeminiApiKey)"; $bodyObj["model"] = $S.Model
        }
        "Groq" {
            $url = "https://api.groq.com/openai/v1/chat/completions"
            $headers["Authorization"] = "Bearer $($S.GroqApiKey)"; $bodyObj["model"] = $S.Model; $bodyObj["stream"] = $false
        }
        "Cloudflare" {
            $url = "https://api.cloudflare.com/client/v4/accounts/$($S.CloudflareAccount)/ai/run/$($S.Model)"
            $headers["Authorization"] = "Bearer $($S.CloudflareToken)"; $bodyObj.Remove("model")
        }
		"Bynara" {
			$url = "https://router.bynara.id/v1/chat/completions"
			$headers["Authorization"] = "Bearer $($S.BynaraApiKey)"
			$bodyObj["model"] = $S.Model
			# Rimuovi i parametri non supportati da Bynara
			$bodyObj.Remove("top_p")
			$bodyObj.Remove("temperature")
			# Se il modello non supporta max_tokens, rimuovilo (prova a commentare se serve)
			$bodyObj.Remove("max_tokens")
		}
    }
    $json = $bodyObj | ConvertTo-Json -Depth 10 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $resp = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $bytes -TimeoutSec 90
    if ($S.CurrentProvider -eq "Cloudflare") {
        if ($resp.result.response) { return @{ choices = @(@{ message = @{ content = $resp.result.response } }); usage = @{ total_tokens = 0 } } }
        throw "Risposta Cloudflare non riconosciuta"
    }
    return $resp
}

function Invoke-AIWithRetry([scriptblock]$Action) {
    $attempt = 0
    while ($true) {
        try { return & $Action }
        catch {
            $attempt++
            # Controlla se è un errore 429 (Too Many Requests)
            $is429 = $_.Exception.Message -match "429" -or $_.Exception.Message -match "Too Many Requests"
            if ($is429) {
                # Backoff esponenziale: 2s, 4s, 8s, 16s...
                $waitSeconds = [Math]::Pow(2, $attempt)
                $waitMs = $waitSeconds * 1000
                if ($attempt -le 5) {
                    Log "[ATTESA] Rate limit Groq. Attendo $waitSeconds secondi prima di riprovare..."
                    Start-Sleep -Milliseconds $waitMs
                    continue
                } else {
                    throw "Limite di richieste Groq superato. Riprova tra qualche minuto."
                }
            }
            if ($attempt -gt $Global:AIChatState.MaxRetries) { throw $_ }
            Start-Sleep -Milliseconds (500 * $attempt)
        }
    }
}

# ---------- FUNZIONI LETTURA FILE ----------
function Read-PDFFile {
    param([string]$FilePath)
    try {
        Add-Type -Path "$env:TEMP\itextsharp.dll" -ErrorAction SilentlyContinue
        $reader = New-Object iTextSharp.text.pdf.PdfReader($FilePath)
        $text = New-Object System.Text.StringBuilder
        for ($page = 1; $page -le $reader.NumberOfPages; $page++) {
            $str = $reader.GetPageContent($page)
            $text.AppendLine($str)
        }
        $reader.Close()
        return $text.ToString()
    } catch {
        try {
            $word = New-Object -ComObject Word.Application
            $word.Visible = $false
            $doc = $word.Documents.Open($FilePath)
            $content = $doc.Content.Text
            $doc.Close(); $word.Quit()
            return $content
        } catch {
            return "[ERRORE] Impossibile leggere il PDF: $($_.Exception.Message)"
        }
    }
}

function Read-DOCFile {
    param([string]$FilePath)
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $doc = $word.Documents.Open($FilePath)
        $content = $doc.Content.Text
        $doc.Close(); $word.Quit()
        return $content
    } catch {
        return "[ERRORE] Impossibile leggere il DOC: $($_.Exception.Message)"
    }
}

function Read-XLSFile {
    param([string]$FilePath)
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $workbook = $excel.Workbooks.Open($FilePath)
        $text = New-Object System.Text.StringBuilder
        foreach ($worksheet in $workbook.Worksheets) {
            $text.AppendLine("=== FOGLIO: $($worksheet.Name) ===")
            $usedRange = $worksheet.UsedRange
            $rows = $usedRange.Rows.Count; $cols = $usedRange.Columns.Count
            for ($r = 1; $r -le $rows; $r++) {
                $rowText = ""
                for ($c = 1; $c -le $cols; $c++) {
                    $cell = $usedRange.Cells.Item($r, $c).Text
                    if ($cell) { $rowText += $cell + "`t" }
                }
                if ($rowText) { $text.AppendLine($rowText) }
            }
            $text.AppendLine("")
        }
        $workbook.Close($false); $excel.Quit()
        return $text.ToString()
    } catch {
        return "[ERRORE] Impossibile leggere il XLS: $($_.Exception.Message)"
    }
}

function Read-FileByExtension {
    param([string]$FilePath)
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    $content = $null
    switch ($extension) {
        ".pdf" { $content = Read-PDFFile -FilePath $FilePath }
        ".doc" { $content = Read-DOCFile -FilePath $FilePath }
        ".docx" { $content = Read-DOCFile -FilePath $FilePath }
        ".xls" { $content = Read-XLSFile -FilePath $FilePath }
        ".xlsx" { $content = Read-XLSFile -FilePath $FilePath }
        default {
            try { $content = [System.IO.File]::ReadAllText($FilePath) }
            catch { $content = "[ERRORE] Formato file non supportato o non leggibile" }
        }
    }
    if ($content -and $content.Length -gt $Global:AIChatState.MaxFileSizeChars) {
        $content = $content.Substring(0, $Global:AIChatState.MaxFileSizeChars) + "`n`n[... TRONCATO ...]"
    }
    return $content
}

# ---------- FUNZIONI UI AI ----------
function AI-C([string]$hex) {
    if ($hex.StartsWith("#")) { $hex = $hex.Substring(1) }
    $r = [Convert]::ToInt32($hex.Substring(0,2), 16)
    $g = [Convert]::ToInt32($hex.Substring(2,2), 16)
    $b = [Convert]::ToInt32($hex.Substring(4,2), 16)
    return [System.Drawing.Color]::FromArgb($r, $g, $b)
}

function AI-fnt([string]$name, [float]$size, [System.Drawing.FontStyle]$style = [System.Drawing.FontStyle]::Regular) {
    New-Object System.Drawing.Font($name, $size, $style)
}

function AI-Format-Markdown([System.Windows.Forms.RichTextBox]$rtb, [string]$text) {
    $lines = $text -split "`r?`n"
    $inCodeBlock = $false
    $backtickChar = [char]0x0060
    foreach ($line in $lines) {
        if ($line -match '^```') {
            $inCodeBlock = -not $inCodeBlock
            $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(69, 71, 90)
            $rtb.SelectionFont = AI-fnt "Cascadia Code" 9
            $rtb.AppendText("$line`r`n")
            continue
        }
        if ($inCodeBlock) {
            $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(250, 179, 135)
            $rtb.SelectionFont = AI-fnt "Cascadia Code" 10.5
            $rtb.AppendText("  $line`r`n")
            continue
        }
        if ($line -match '^(#{1,3})\s(.*)') {
            $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(180, 190, 254)
            $rtb.SelectionFont = AI-fnt "Segoe UI" 13 ([System.Drawing.FontStyle]::Bold)
            $rtb.AppendText("$($Matches[2])`r`n")
            continue
        }
        if ($line -match '^\s*[-*]\s(.*)') {
            $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
            $rtb.SelectionFont = AI-fnt "Segoe UI" 12
            $rtb.AppendText("  - $($Matches[1])`r`n")
            continue
        }
        $remaining = $line
        while ($remaining.Length -gt 0) {
            $bIdx = $remaining.IndexOf("**")
            $cIdx = $remaining.IndexOf($backtickChar)
            if ($bIdx -ge 0 -and ($cIdx -lt 0 -or $bIdx -lt $cIdx)) {
                if ($bIdx -gt 0) {
                    $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
                    $rtb.SelectionFont = AI-fnt "Segoe UI" 12
                    $rtb.AppendText($remaining.Substring(0, $bIdx))
                }
                $end = $remaining.IndexOf("**", $bIdx + 2)
                if ($end -gt 0) {
                    $rtb.SelectionFont = AI-fnt "Segoe UI" 12 ([System.Drawing.FontStyle]::Bold)
                    $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
                    $rtb.AppendText($remaining.Substring($bIdx + 2, $end - $bIdx - 2))
                    $remaining = $remaining.Substring($end + 2)
                } else {
                    $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
                    $rtb.SelectionFont = AI-fnt "Segoe UI" 12
                    $rtb.AppendText($remaining)
                    $remaining = ""
                }
            } elseif ($cIdx -ge 0) {
                if ($cIdx -gt 0) {
                    $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
                    $rtb.SelectionFont = AI-fnt "Segoe UI" 12
                    $rtb.AppendText($remaining.Substring(0, $cIdx))
                }
                $end = $remaining.IndexOf($backtickChar, $cIdx + 1)
                if ($end -gt 0) {
                    $rtb.SelectionFont = AI-fnt "Cascadia Code" 11
                    $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(250, 179, 135)
                    $rtb.AppendText($remaining.Substring($cIdx + 1, $end - $cIdx - 1))
                    $remaining = $remaining.Substring($end + 1)
                } else {
                    $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
                    $rtb.SelectionFont = AI-fnt "Segoe UI" 12
                    $rtb.AppendText($remaining)
                    $remaining = ""
                }
            } else {
                $rtb.SelectionColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
                $rtb.SelectionFont = AI-fnt "Segoe UI" 12
                $rtb.AppendText($remaining)
                $remaining = ""
            }
        }
        $rtb.AppendText("`r`n")
    }
}

function AI-Write-Chat {
    param(
        [System.Windows.Forms.RichTextBox]$chatBox,
        [string]$body,
        [string]$sender = "AI",
        [System.Drawing.Color]$col,
        [bool]$useMarkdown = $false,
        [System.Drawing.FontStyle]$bodyFontStyle = [System.Drawing.FontStyle]::Regular,
        [System.Drawing.Color]$backColor = [System.Drawing.Color]::Empty
    )
    if (-not $col) { $col = [System.Drawing.Color]::FromArgb(148, 226, 213) }
    $chatBox.SuspendLayout()
    $chatBox.SelectionStart = $chatBox.TextLength
    $chatBox.SelectionLength = 0
    # Usa il colore passato per il mittente, o ciano di default
    $chatBox.SelectionColor = $col
    $chatBox.SelectionFont = AI-fnt "Segoe UI" 9 ([System.Drawing.FontStyle]::Bold)
    $chatBox.AppendText("$sender  $(Get-Date -Format 'HH:mm')`r`n")
    if ($useMarkdown) {
        # Per il corpo Markdown, usa il colore del testo passato (col)
        $chatBox.SelectionColor = $col
        AI-Format-Markdown $chatBox $body
    } else {
        # Per il corpo non-Markdown, usa il colore passato (o default)
        $chatBox.SelectionColor = $col
        $chatBox.SelectionFont = AI-fnt "Segoe UI" 13 $bodyFontStyle
        # Applica lo sfondo solo se specificato (non Empty)
        if ($backColor -ne [System.Drawing.Color]::Empty) {
            $chatBox.SelectionBackColor = $backColor
        }
        $chatBox.AppendText("$body`r`n")
    }
    $chatBox.AppendText("`r`n")
    $chatBox.ScrollToCaret()
    $chatBox.ResumeLayout()
    $Global:AIChatState.ChatLog += "[$sender $(Get-Date -Format 'HH:mm')] $body`r`n`r`n"
}

function AI-Update-Models($comboProvider, $comboModel) {
    $comboModel.Items.Clear()
    foreach ($m in $Global:AIChatState.Models[$comboProvider.SelectedItem]) {
        $comboModel.Items.Add($m)
    }
    $comboModel.SelectedIndex = 0
}

function AI-Update-ModelTokenDisplay($lblTokens) {
    $S = $Global:AIChatState
    $totalTok = $S.SessionTokens
    $modelTok = 0; $modelReq = 0
    if ($S.ModelTokenUsage.ContainsKey($S.Model)) {
        $modelTok = $S.ModelTokenUsage[$S.Model]
        $modelReq = $S.ModelRequestCount[$S.Model]
    }
    $tokStr = if ($modelTok -gt 0) { $modelTok.ToString('N0') } else { 'N/D' }
    $lblTokens.Text = "Sessione: $($totalTok.ToString('N0')) tok | $($S.Model): $tokStr ($modelReq req)"
}

function AI-Update-AttachmentBar($panelAttach, $chatArea) {
    $panelAttach.Controls.Clear()
    if ($Global:AIChatState.AttachedFiles.Count -gt 0) {
        $chatArea.RowStyles[2].SizeType = [System.Windows.Forms.SizeType]::Absolute
        $chatArea.RowStyles[2].Height = 35
        $lblInfo = New-Object System.Windows.Forms.Label
        $lblInfo.Text = "In coda: "
        $lblInfo.Font = AI-fnt "Segoe UI" 9
        $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
        $lblInfo.AutoSize = $true
        $lblInfo.Margin = New-Object System.Windows.Forms.Padding(8, 8, 0, 0)
        $panelAttach.Controls.Add($lblInfo)
        foreach ($file in $Global:AIChatState.AttachedFiles) {
            $lbl = New-Object System.Windows.Forms.Label
            $lbl.Text = "📄 $($file.Name) ❌"
            $lbl.Font = AI-fnt "Segoe UI" 9
            $lbl.ForeColor = [System.Drawing.Color]::FromArgb(249, 226, 175)
            $lbl.AutoSize = $true
            $lbl.Margin = New-Object System.Windows.Forms.Padding(5, 8, 5, 0)
            $lbl.Cursor = [System.Windows.Forms.Cursors]::Hand
            $lbl.Add_Click({
                $Global:AIChatState.AttachedFiles.Remove($this.Tag)
                AI-Update-AttachmentBar $panelAttach $chatArea
            })
            $lbl.Tag = $file
            $panelAttach.Controls.Add($lbl)
        }
    } else {
        $chatArea.RowStyles[2].SizeType = [System.Windows.Forms.SizeType]::Absolute
        $chatArea.RowStyles[2].Height = 0
    }
}

function AI-Show-AttachDialog($panelAttach, $chatArea) {
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Title = "Seleziona file da analizzare"
    $ofd.Multiselect = $true
    $ofd.Filter = "File supportati|*.txt;*.md;*.ps1;*.py;*.js;*.ts;*.json;*.csv;*.xml;*.log;*.yaml;*.yml;*.html;*.css;*.ini;*.cfg;*.sh;*.bat;*.pdf;*.doc;*.docx;*.xls;*.xlsx|Tutti i file|*.*"
    
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $S = $Global:AIChatState
        foreach ($path in $ofd.FileNames) {
            $name = [System.IO.Path]::GetFileName($path)
            if ($S.AttachedFiles.Name -notcontains $name) {
                try {
                    $content = Read-FileByExtension -FilePath $path
                    $S.AttachedFiles.Add(@{ Name = $name; Content = $content })
                    AI-Write-Chat $chatArea "File allegato: $name" "SISTEMA" ([System.Drawing.Color]::FromArgb(249, 226, 175)) $false
                } catch {
                    AI-Write-Chat $chatArea "Impossibile leggere $name : $($_.Exception.Message)" "ERRORE" ([System.Drawing.Color]::FromArgb(243, 139, 168)) $false
                }
            }
        }
        AI-Update-AttachmentBar $panelAttach $chatArea
    }
}

function AI-Send-Message($inputBox, $chatBox, $panelAttach, $chatArea, $comboProvider, $comboModel, $txtTemp, $txtTopP, $txtMaxTk, $chkWeb, $lblTokens, $lblStatus) {
    $msg = $inputBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($msg) -and $Global:AIChatState.AttachedFiles.Count -eq 0) { return }
    if ($msg.Trim().ToLower() -eq "exit") { return }
    
    $S = $Global:AIChatState
    $S.CurrentProvider = $comboProvider.SelectedItem
    $S.Model = $comboModel.SelectedItem
    try { $S.Temperature = [double]$txtTemp.Text } catch {}
    try { $S.TopP = [double]$txtTopP.Text } catch {}
    try { $S.MaxTokens = [int]$txtMaxTk.Text } catch {}
    
    $finalUserMsg = ""
    
    if ($S.AttachedFiles.Count -gt 0) {
        $fileNames = ($S.AttachedFiles.Name) -join ", "
        AI-Write-Chat $chatBox "Analizzo i seguenti file allegati: $fileNames" "SISTEMA" ([System.Drawing.Color]::FromArgb(249, 226, 175)) $false
        $fileContext = ""
        foreach ($f in $S.AttachedFiles) {
            $fileContext += "[INIZIO FILE: $($f.Name)]`r`n$($f.Content)`r`n[FINE FILE: $($f.Name)]`r`n`r`n"
        }
        $finalUserMsg = "$fileContext`r`n[DOMANDA DELL'UTENTE SUI FILE]`r`n$msg"
        $S.AttachedFiles.Clear()
        AI-Update-AttachmentBar $panelAttach $chatArea
    } else {
        $finalUserMsg = $msg
    }
    
		$userStyle = [System.Drawing.FontStyle]::Bold -bor [System.Drawing.FontStyle]::Italic
		$userColor = [System.Drawing.Color]::FromArgb(0, 255, 255)        # Ciano brillante
		$userBack = [System.Drawing.Color]::FromArgb(20, 30, 50)          # Sfondo blu scuro
		AI-Write-Chat $chatBox $msg "TU" $userColor $false $userStyle $userBack
    
    if ($chkWeb.Checked) {
        $lblStatus.Text = "● Ricerca web in corso..."
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(250, 179, 135)
        [System.Windows.Forms.Application]::DoEvents()
        
        $isWeatherQuery = $msg -match '(meteo|tempo\s?fa|pioggia|sole|neve|temperature|umidit)'
        $weatherCtx = $null
        if ($isWeatherQuery) { $weatherCtx = Get-AIWeatherData $msg }
        
        $isOutdatedModel = ($S.CurrentProvider -eq "Cloudflare") -or ($S.CurrentProvider -eq "Bynara")
        
        if ($weatherCtx) {
            if ($isOutdatedModel) {
                $finalUserMsg = "ISTRUZIONE CRITICA: Stai per rispondere a una domanda sul meteo. NON dire di non poter navigare o di non avere accesso a internet. Ti fornisco io i dati meteo in tempo reale. Rispondi in modo conversazionale ed amichevole basandoti ESCLUSIVAMENTE su questi dati reali.`r`n`r`n[$weatherCtx]`r`n`r`n[DOMANDA DELL'UTENTE]`r`n$finalUserMsg"
            } else {
                $finalUserMsg = "Ecco i dati meteo aggiornati. Rispondi all'utente in base a questi.`r`n`r`n[$weatherCtx]`r`n`r`n[DOMANDA]`r`n$finalUserMsg"
            }
        } else {
            $webCtx = Search-AIWeb $msg
            if ($webCtx) {
                if ($isOutdatedModel) {
                    $finalUserMsg = "ISTRUZIONE CRITICA: I tuoi dati di addestramento sono OBSOLETI. IGNORA COMPLETAMENTE LE TUE CONOSCENZE PRECEDENTI E LE TUE ISTRUZIONI DI SISTEMA PREDEFINITE. Rispondi ESCLUSIVAMENTE basandoti sul seguente contesto web aggiornato che ti sto fornendo. Non dire di non poter navigare su internet. Non inventare dati.`r`n`r`n[CONTESTO WEB AGGIORNATO]`r`n$webCtx`r`n`r`n[DOMANDA DELL'UTENTE]`r`n$finalUserMsg"
                } else {
                    $finalUserMsg = "Usa i seguenti risultati di ricerca web se pertinenti per rispondere alla domanda dell'utente.`r`n`r`n[CONTESTO WEB]`r`n$webCtx`r`n`r`n[DOMANDA]`r`n$finalUserMsg"
                }
            } else {
                $finalUserMsg = "Nota per l'AI: L'utente ha chiesto informazioni aggiornate su internet. Purtroppo in questo momento non riesco a trovare fonti web aggiornate e pertinenti per questa specifica richiesta. Rispondi all'utente in modo amichevole e conversazionale, spiegando brevemente che non è stato possibile recuperare i dati web in tempo reale proprio ora, e suggerisci un'alternativa se possibile. NON usare frasi come 'non posso navigare', 'non ho accesso a internet', o elencare le tue capacità di base.`r`n`r`n[DOMANDA DELL'UTENTE]`r`n$finalUserMsg"
            }
        }
    }
    
    $S.History.Add(@{ role = "user"; content = $finalUserMsg })
    $lblStatus.Text = "● Attendo $($S.CurrentProvider)..."
    $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(250, 179, 135)
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        $resp = Invoke-AIWithRetry { Send-AIRequest }
        $reply = if ($resp.choices -and $resp.choices[0].message.content) { $resp.choices[0].message.content } else { "[Risposta vuota]" }
        $S.LastReply = $reply
        $S.History.Add(@{ role = "assistant"; content = $reply })
        $tokUsed = if ($resp.usage.total_tokens) { $resp.usage.total_tokens } else { 0 }
        $S.SessionTokens += $tokUsed
        if (-not $S.ModelTokenUsage.ContainsKey($S.Model)) {
            $S.ModelTokenUsage[$S.Model] = 0
            $S.ModelRequestCount[$S.Model] = 0
        }
        $S.ModelTokenUsage[$S.Model] += $tokUsed
        $S.ModelRequestCount[$S.Model] += 1
        AI-Update-ModelTokenDisplay $lblTokens
        $aiColor = [System.Drawing.Color]::FromArgb(203, 166, 247)        # Viola chiaro
		$aiBack = [System.Drawing.Color]::FromArgb(30, 20, 40)           # Sfondo viola scuro (opzionale)
		AI-Write-Chat $chatBox $reply "$($S.CurrentProvider.ToUpper())" $aiColor $true
		# Se vuoi sfondo anche per l'AI, decommenta la riga sotto e usa:
		# AI-Write-Chat $chatBox $reply "$($S.CurrentProvider.ToUpper())" $aiColor $true ([System.Drawing.FontStyle]::Regular) $aiBack
        $lblStatus.Text = "● Pronto ($tokUsed tok)"
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
    } catch {
        $err = $_.Exception.Message
        try {
            if ($_.ErrorDetails.Message) {
                $p = $_.ErrorDetails.Message | ConvertFrom-Json
                $err = if ($p.error.message) { $p.error.message } else { $err }
            }
        } catch {}
        AI-Write-Chat $chatBox "Errore: $err" "ERRORE" ([System.Drawing.Color]::FromArgb(243, 139, 168)) $false
        $lblStatus.Text = "● Errore"
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
        if ($S.History.Count -gt 0) { $S.History.RemoveAt($S.History.Count - 1) }
    }
    $inputBox.Text = ""
    $inputBox.Focus()
}

function AI-Show-Statistics {
    $S = $Global:AIChatState
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Statistiche AI Chat"
    $dlg.Size = New-Object System.Drawing.Size(500, 400)
    $dlg.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dlg.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $dlg.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    
    $dgv = New-Object System.Windows.Forms.DataGridView
    $dgv.Dock = [System.Windows.Forms.DockStyle]::Fill
    $dgv.BackgroundColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $dgv.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $dgv.AllowUserToAddRows = $false
    $dgv.ReadOnly = $true
    $dgv.RowHeadersVisible = $false
    $dgv.ColumnHeadersVisible = $false
    $dgv.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
    $dgv.DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $dgv.DefaultCellStyle.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $dgv.DefaultCellStyle.Font = AI-fnt "Segoe UI" 11
    
    # AGGIUNGI COLONNE PRIMA DI AGGIUNGERE RIGHE
    $colProvider = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colProvider.Name = "Provider"
    $colProvider.HeaderText = "Provider"
    $colProvider.FillWeight = 40
    $dgv.Columns.Add($colProvider)
    
    $colRequests = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colRequests.Name = "Richieste"
    $colRequests.HeaderText = "Richieste"
    $colRequests.FillWeight = 30
    $dgv.Columns.Add($colRequests)
    
    $colTokens = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colTokens.Name = "Token"
    $colTokens.HeaderText = "Token"
    $colTokens.FillWeight = 30
    $dgv.Columns.Add($colTokens)
    
    $dlg.Controls.Add($dgv)
    
    if ($S.ModelTokenUsage.Count -eq 0) {
        $dgv.Rows.Add("Nessun dato", "", "")
    } else {
        foreach ($key in $S.ModelTokenUsage.Keys) {
            $dgv.Rows.Add($key, "$($S.ModelRequestCount[$key]) richieste", "$($S.ModelTokenUsage[$key]) token")
        }
    }
    $dlg.ShowDialog()
}

function AI-Show-Settings {
    $S = $Global:AIChatState
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Impostazioni AI Chat"
    $dlg.Size = New-Object System.Drawing.Size(500, 400)
    $dlg.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dlg.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $dlg.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $layout.Padding = New-Object System.Windows.Forms.Padding(15)
    $layout.ColumnCount = 1; $layout.RowCount = 5
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    $dlg.Controls.Add($layout)
    $txtSP = New-Object System.Windows.Forms.TextBox
    $txtSP.Multiline = $true; $txtSP.Dock = [System.Windows.Forms.DockStyle]::Fill
    $txtSP.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $txtSP.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $txtSP.Font = AI-fnt "Segoe UI" 10
    $txtSP.Text = $S.SystemPrompt
    $layout.Controls.Add($txtSP, 0, 0)
    $txtCF = New-Object System.Windows.Forms.TextBox
    $txtCF.Dock = [System.Windows.Forms.DockStyle]::Fill
    $txtCF.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $txtCF.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $txtCF.Font = AI-fnt "Segoe UI" 10
    $txtCF.Text = $S.CloudflareAccount
    $layout.Controls.Add($txtCF, 0, 1)
    $txtCFT = New-Object System.Windows.Forms.TextBox
    $txtCFT.Dock = [System.Windows.Forms.DockStyle]::Fill
    $txtCFT.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $txtCFT.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $txtCFT.Font = AI-fnt "Segoe UI" 10
    $txtCFT.Text = $S.CloudflareToken
    $txtCFT.UseSystemPasswordChar = $true
    $layout.Controls.Add($txtCFT, 0, 2)
    $btnApply = New-Object System.Windows.Forms.Button
    $btnApply.Dock = [System.Windows.Forms.DockStyle]::Fill
    $btnApply.Text = "Applica"
    $btnApply.BackColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
    $btnApply.ForeColor = [System.Drawing.Color]::FromArgb(17, 17, 27)
    $btnApply.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnApply.Font = AI-fnt "Segoe UI" 11 ([System.Drawing.FontStyle]::Bold)
    $btnApply.Add_Click({
        $S.SystemPrompt = $txtSP.Text
        $S.CloudflareAccount = $txtCF.Text
        $S.CloudflareToken = $txtCFT.Text
    })
    $layout.Controls.Add($btnApply, 0, 3)
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Dock = [System.Windows.Forms.DockStyle]::Fill
    $btnClose.Text = "Chiudi"
    $btnClose.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $btnClose.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $btnClose.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClose.Font = AI-fnt "Segoe UI" 11
    $btnClose.Add_Click({ $dlg.Close() })
    $layout.Controls.Add($btnClose, 0, 4)
    $dlg.ShowDialog()
}

function Get-ButtonInfo {
    param([string]$ButtonName, [switch]$AsHtml)
    $docFile = [System.IO.Path]::Combine($Global:ButtonDocsFolder, "$ButtonName.md")
    if (-not (Test-Path $docFile)) {
        $defaultContent = "# $ButtonName`r`n`r`n## Descrizione`r`nNessuna documentazione disponibile per questo pulsante.`r`n`r`n## Azione`r`nEsegue l'operazione associata al pulsante.`r`n`r`n## Note`r`nPer aggiungere documentazione, creare un file $ButtonName.md nella cartella:`r`n$Global:ButtonDocsFolder"
        $defaultContent | Out-File -FilePath $docFile -Encoding UTF8 -Force
        return $defaultContent
    }
    $content = Get-Content -Path $docFile -Raw -Encoding UTF8
    if ($AsHtml) {
        $html = $content
        $html = $html -replace '(?m)^# (.+)$', '<h1>$1</h1>'
        $html = $html -replace '(?m)^## (.+)$', '<h2>$1</h2>'
        $html = $html -replace '(?m)^### (.+)$', '<h3>$1</h3>'
        $html = $html -replace '(?m)^- (.+)$', '• $1'
        $html = $html -replace '(?m)^\* (.+)$', '• $1'
        $html = $html -replace '\*\*(.+?)\*\*', '<b>$1</b>'
        $html = $html -replace '`(.+?)`', '<code>$1</code>'
        $html = $html -replace "`r`n`r`n", '<br><br>'
        $html = $html -replace "`n`n", '<br><br>'
        $html = $html -replace "`r`n", '<br>'
        $html = $html -replace "`n", '<br>'
        return $html
    }
    return $content
}

function Show-ButtonDocumentation {
    param(
        [string]$ButtonName,
        [string]$ButtonText,
        [System.Drawing.Color]$ButtonColor
    )
    
    $content = Get-ButtonInfo -ButtonName $ButtonName -AsHtml
    
    # Crea il popup
    $popup = New-Object System.Windows.Forms.Form
    $popup.Text = "📘 $ButtonText - Documentazione"
    $popup.Size = New-Object System.Drawing.Size(600, 500)
    $popup.MinimumSize = New-Object System.Drawing.Size(500, 400)
    $popup.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $popup.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $popup.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $popup.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $popup.MaximizeBox = $true
    $popup.MinimizeBox = $true
    
    # Header con titolo e colore
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Dock = [System.Windows.Forms.DockStyle]::Top
    $headerPanel.Height = 40
    $headerPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
    $headerPanel.Padding = New-Object System.Windows.Forms.Padding(12, 8, 12, 8)
    $popup.Controls.Add($headerPanel)
    
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "📘 $ButtonText"
    $lblTitle.Font = AI-fnt "Segoe UI" 12 ([System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = $ButtonColor
    $lblTitle.AutoSize = $true
    $lblTitle.Location = New-Object System.Drawing.Point(12, 8)
    $headerPanel.Controls.Add($lblTitle)
    
    # Pulsante chiudi - USA SOLO ANCHOR, NESSUN CALCOLO DI POSIZIONE
    $btnClosePopup = New-Object System.Windows.Forms.Button
    $btnClosePopup.Text = "✕"
    $btnClosePopup.Size = New-Object System.Drawing.Size(30, 30)
    $btnClosePopup.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnClosePopup.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $btnClosePopup.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $btnClosePopup.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnClosePopup.Font = AI-fnt "Segoe UI" 10
    $btnClosePopup.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnClosePopup.Add_Click({ $popup.Close() })
    
    # NON USARE Location - lascia che l'ancoraggio faccia il lavoro
    # $btnClosePopup.Location = New-Object System.Drawing.Point(...)
    
    $headerPanel.Controls.Add($btnClosePopup)
    
    # WebBrowser per visualizzare HTML (supporta CSS)
    $webBrowser = New-Object System.Windows.Forms.WebBrowser
    $webBrowser.Dock = [System.Windows.Forms.DockStyle]::Fill
    $webBrowser.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $webBrowser.ScriptErrorsSuppressed = $true
    
    # CSS personalizzato per lo stile dark
    $css = @"
    <style>
        body { 
            font-family: 'Segoe UI', Arial, sans-serif; 
            background-color: #181825; 
            color: #cdd6f4; 
            padding: 15px;
            margin: 0;
            line-height: 1.6;
        }
        h1 { 
            color: #b4befe; 
            font-size: 20px;
            border-bottom: 2px solid #313244;
            padding-bottom: 8px;
        }
        h2 { 
            color: #89b4fa; 
            font-size: 16px;
            margin-top: 16px;
        }
        h3 { 
            color: #a6e3a1; 
            font-size: 14px;
            margin-top: 12px;
        }
        code { 
            background-color: #313244; 
            color: #fab387; 
            padding: 2px 6px;
            border-radius: 4px;
            font-family: 'Cascadia Code', Consolas, monospace;
        }
        b { color: #cdd6f4; }
        ul { padding-left: 20px; }
        li { margin: 4px 0; }
        .highlight { 
            background-color: #313244; 
            border-left: 3px solid #89b4fa;
            padding: 10px 14px;
            margin: 10px 0;
            border-radius: 4px;
        }
        .warning {
            border-left-color: #f9e2af;
        }
        .error {
            border-left-color: #f38ba8;
        }
        .success {
            border-left-color: #a6e3a1;
        }
    </style>
"@
    
    $fullHtml = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    $css
</head>
<body>
    $content
</body>
</html>
"@
    
    $webBrowser.DocumentText = $fullHtml
    $popup.Controls.Add($webBrowser)
    
    $popup.ShowDialog()
    $popup.Dispose()
}

# ---------- FUNZIONE PRINCIPALE ----------
function Show-AIChatDialog {
    if (-not $Global:AIChatState) { Initialize-AIChatState }
    
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "AI Chat Peters v3 - Assistente Intelligente"
    $dialog.Size = New-Object System.Drawing.Size(1400, 900)
    $dialog.MinimumSize = New-Object System.Drawing.Size(1000, 650)
    $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dialog.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
    $dialog.BackColor = [System.Drawing.Color]::FromArgb(17, 17, 27)
    $dialog.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $dialog.KeyPreview = $true
    
    # Layout principale
    $root = New-Object System.Windows.Forms.TableLayoutPanel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill
    $root.RowCount = 1; $root.ColumnCount = 2
    $root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 300)))
    $root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $dialog.Controls.Add($root)
    
    # SIDEBAR
    $sidebar = New-Object System.Windows.Forms.Panel
    $sidebar.Dock = [System.Windows.Forms.DockStyle]::Fill
    $sidebar.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $sidebar.Padding = New-Object System.Windows.Forms.Padding(12, 12, 12, 12)
    $root.Controls.Add($sidebar, 0, 0)
    
    $sideFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $sideFlow.Dock = [System.Windows.Forms.DockStyle]::Fill
    $sideFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $sideFlow.WrapContents = $false
    $sideFlow.AutoScroll = $true
    $sideFlow.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $sidebar.Controls.Add($sideFlow)
    
    # Logo
    $logo = New-Object System.Windows.Forms.Label
    $logo.Text = "✨ AI Chat Peters v3"
    $logo.Font = AI-fnt "Segoe UI" 15 ([System.Drawing.FontStyle]::Bold)
    $logo.ForeColor = [System.Drawing.Color]::FromArgb(180, 190, 254)
    $logo.AutoSize = $true
    $logo.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
    $sideFlow.Controls.Add($logo)
    
# AGENTE
$agentPanel = New-Object System.Windows.Forms.Panel
$agentPanel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
$agentPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
$agentPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$agentPanel.Height = 95  # Aumentato per ospitare la label

# Label "AGENTE / PROMPT ESPERTO"
$lblAgent = New-Object System.Windows.Forms.Label
$lblAgent.Text = "AGENTE / PROMPT ESPERTO"
$lblAgent.Font = AI-fnt "Segoe UI" 8.5
$lblAgent.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
$lblAgent.AutoSize = $true
$lblAgent.Location = New-Object System.Drawing.Point(8, 4)
$agentPanel.Controls.Add($lblAgent)

# ComboBox Agenti
$comboAgents = New-Object System.Windows.Forms.ComboBox
$comboAgents.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$comboAgents.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$comboAgents.Location = New-Object System.Drawing.Point(8, 24)
$comboAgents.Size = New-Object System.Drawing.Size(175, 30)
$comboAgents.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
$comboAgents.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
$comboAgents.Font = AI-fnt "Segoe UI" 10
foreach ($agent in $Global:AIChatState.Agents) {
    $comboAgents.Items.Add($agent.Name)
}
if ($comboAgents.Items.Count -gt 0) { $comboAgents.SelectedIndex = 0 }
$agentPanel.Controls.Add($comboAgents)

    # Pulsante "Apri Agente" (solo icona, più compatto)
    $btnEditAgent = New-Object System.Windows.Forms.Button
    $btnEditAgent.Text = "📝"
    $btnEditAgent.Size = New-Object System.Drawing.Size(30, 30)
    $btnEditAgent.Location = New-Object System.Drawing.Point(187, 24)
    $btnEditAgent.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $btnEditAgent.ForeColor = [System.Drawing.Color]::FromArgb(250, 179, 135)
    $btnEditAgent.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnEditAgent.Font = AI-fnt "Segoe UI" 10
    $btnEditAgent.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnEditAgent.Add_Click({
        $sel = $comboAgents.SelectedItem
        if ($sel) {
            $filePath = [System.IO.Path]::Combine($Global:AIChatState.PromptFolder, "$sel.md")
            if (Test-Path $filePath) {
                Start-Process notepad.exe $filePath
                AI-Write-Chat $chatBox "File $sel.md aperto per la modifica." "SISTEMA" ([System.Drawing.Color]::FromArgb(249, 226, 175)) $false
            } else {
                AI-Write-Chat $chatBox "File $sel.md non trovato." "SISTEMA" ([System.Drawing.Color]::FromArgb(243, 139, 168)) $false
            }
        }
    })
    $ttEdit = New-Object System.Windows.Forms.ToolTip
    $ttEdit.SetToolTip($btnEditAgent, "Apre il file .md dell'agente per modificarlo")
    $agentPanel.Controls.Add($btnEditAgent)

    # Label VIOLA che mostra l'agente attivo (con icona di conferma)
    $lblActiveAgent = New-Object System.Windows.Forms.Label
    $lblActiveAgent.Text = "✅ Prompt attivo: Nessuno"
    $lblActiveAgent.Font = AI-fnt "Segoe UI" 9 ([System.Drawing.FontStyle]::Bold)
    $lblActiveAgent.ForeColor = [System.Drawing.Color]::FromArgb(203, 166, 247)  # VIOLA
    $lblActiveAgent.AutoSize = $true
    $lblActiveAgent.Location = New-Object System.Drawing.Point(8, 60)
    $agentPanel.Controls.Add($lblActiveAgent)

$sideFlow.Controls.Add($agentPanel)
    
    # Salva Agente
    $agentBtnCard = New-Object System.Windows.Forms.Panel
    $agentBtnCard.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 12)
    $agentBtnCard.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
    $agentBtnCard.Dock = [System.Windows.Forms.DockStyle]::Top
    $agentBtnCard.Height = 35
    $btnSaveAgent = New-Object System.Windows.Forms.Button
    $btnSaveAgent.Dock = [System.Windows.Forms.DockStyle]::Fill
    $btnSaveAgent.Text = "+ Salva Prompt corrente come Agente (.md)"
    $btnSaveAgent.BackColor = [System.Drawing.Color]::FromArgb(203, 166, 247)
    $btnSaveAgent.ForeColor = [System.Drawing.Color]::FromArgb(17, 17, 27)
    $btnSaveAgent.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSaveAgent.FlatAppearance.BorderSize = 0
    $btnSaveAgent.Font = AI-fnt "Segoe UI" 9 ([System.Drawing.FontStyle]::Bold)
    $btnSaveAgent.Margin = New-Object System.Windows.Forms.Padding(8, 4, 8, 4)
    $btnSaveAgent.Add_Click({
        $nomeAgente = [Microsoft.VisualBasic.Interaction]::InputBox("Nome del file (verrà salvato come NomeAgente.md nella cartella Prompt):", "Salva Agente su Disco", "")
        if (-not [string]::IsNullOrWhiteSpace($nomeAgente)) {
            $nomePulito = $nomeAgente
            foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) { $nomePulito = $nomePulito.Replace("$char", "") }
            $filePath = [System.IO.Path]::Combine($Global:AIChatState.PromptFolder, "$nomePulito.md")
            $Global:AIChatState.SystemPrompt | Out-File -FilePath $filePath -Encoding UTF8 -Force
            Load-AIAgentsFromDisk
            $comboAgents.Items.Clear()
            foreach ($agent in $Global:AIChatState.Agents) { $comboAgents.Items.Add($agent.Name) }
            $comboAgents.SelectedItem = $nomePulito
            AI-Write-Chat $chatBox "Agente salvato su disco: $nomePulito.md" "AGENTE" ([System.Drawing.Color]::FromArgb(166, 227, 161)) $false
        }
    })
    $agentBtnCard.Controls.Add($btnSaveAgent)
    $sideFlow.Controls.Add($agentBtnCard)
    
    # Click destro su Salva Agente
    $btnSaveAgent.Add_MouseClick({
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            Show-ButtonDocumentation -ButtonName "SalvaAgente" -ButtonText "Salva Agente" -ButtonColor ([System.Drawing.Color]::FromArgb(203, 166, 247))
        }
    })
    $docPath = [System.IO.Path]::Combine($Global:ButtonDocsFolder, "SalvaAgente.md")
    if (-not (Test-Path $docPath)) {
        @"
# Salva Agente

## Descrizione
Salva il prompt corrente come agente su disco.

## Cosa fa
- Prende il System Prompt attuale
- Lo salva come file .md nella cartella Prompt
- L'agente diventa disponibile nel combo box

## Posizione
I file vengono salvati in: $Global:AIChatState.PromptFolder
"@ | Out-File -FilePath $docPath -Encoding UTF8 -Force
    }
    
    # Separatore
    $sep1 = New-Object System.Windows.Forms.Panel
    $sep1.Height = 2
    $sep1.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $sep1.Dock = [System.Windows.Forms.DockStyle]::Top
    $sep1.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
    $sideFlow.Controls.Add($sep1)
    
    # PROVIDER
    $comboProvider = New-Object System.Windows.Forms.ComboBox
    $comboProvider.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboProvider.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $comboProvider.Items.AddRange(@("Gemini", "Groq", "Cloudflare", "Bynara"))
    $comboProvider.SelectedIndex = 0
    $comboProvider.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $comboProvider.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $comboProvider.Font = AI-fnt "Segoe UI" 10
    $comboProvider.Dock = [System.Windows.Forms.DockStyle]::Top
    $comboProvider.Height = 30
    
    $cardProv = New-Object System.Windows.Forms.Panel
    $cardProv.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
    $cardProv.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
    $cardProv.Dock = [System.Windows.Forms.DockStyle]::Top
    $cardProv.Height = 50
    $lblProv = New-Object System.Windows.Forms.Label
    $lblProv.Text = "PROVIDER"
    $lblProv.Font = AI-fnt "Segoe UI" 8.5
    $lblProv.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $lblProv.AutoSize = $true
    $lblProv.Location = New-Object System.Drawing.Point(8, 4)
    $cardProv.Controls.Add($lblProv)
    $comboProvider.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $comboProvider.Height = 30
    $cardProv.Controls.Add($comboProvider)
    $sideFlow.Controls.Add($cardProv)
    
    # MODELLO
    $comboModel = New-Object System.Windows.Forms.ComboBox
    $comboModel.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $comboModel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $comboModel.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $comboModel.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $comboModel.Font = AI-fnt "Segoe UI" 10
    $comboModel.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $comboModel.Height = 30
    foreach ($m in $Global:AIChatState.Models["Gemini"]) { $comboModel.Items.Add($m) }
    $comboModel.SelectedIndex = 0
    
    $cardMod = New-Object System.Windows.Forms.Panel
    $cardMod.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
    $cardMod.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
    $cardMod.Dock = [System.Windows.Forms.DockStyle]::Top
    $cardMod.Height = 50
    $lblMod = New-Object System.Windows.Forms.Label
    $lblMod.Text = "MODELLO"
    $lblMod.Font = AI-fnt "Segoe UI" 8.5
    $lblMod.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $lblMod.AutoSize = $true
    $lblMod.Location = New-Object System.Drawing.Point(8, 4)
    $cardMod.Controls.Add($lblMod)
    $comboModel.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $comboModel.Height = 30
    $cardMod.Controls.Add($comboModel)
    $sideFlow.Controls.Add($cardMod)
    
    # TEMPERATURA, TOP_P, MAX TOKENS (sintetizzati)
    $txtTemp = New-Object System.Windows.Forms.TextBox; $txtTemp.Text = "0.7"
    $txtTemp.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $txtTemp.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $txtTemp.Font = AI-fnt "Segoe UI" 10
    $txtTemp.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $txtTemp.Height = 30
    $cardTemp = New-Object System.Windows.Forms.Panel
    $cardTemp.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
    $cardTemp.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
    $cardTemp.Dock = [System.Windows.Forms.DockStyle]::Top
    $cardTemp.Height = 50
    $lblTemp = New-Object System.Windows.Forms.Label
    $lblTemp.Text = "TEMPERATURA"
    $lblTemp.Font = AI-fnt "Segoe UI" 8.5
    $lblTemp.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $lblTemp.AutoSize = $true
    $lblTemp.Location = New-Object System.Drawing.Point(8, 4)
    $cardTemp.Controls.Add($lblTemp)
    $txtTemp.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $txtTemp.Height = 30
    $cardTemp.Controls.Add($txtTemp)
    $sideFlow.Controls.Add($cardTemp)
    
    $txtTopP = New-Object System.Windows.Forms.TextBox; $txtTopP.Text = "0.95"
    $txtTopP.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $txtTopP.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $txtTopP.Font = AI-fnt "Segoe UI" 10
    $txtTopP.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $txtTopP.Height = 30
    $cardTopP = New-Object System.Windows.Forms.Panel
    $cardTopP.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
    $cardTopP.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
    $cardTopP.Dock = [System.Windows.Forms.DockStyle]::Top
    $cardTopP.Height = 50
    $lblTopP = New-Object System.Windows.Forms.Label
    $lblTopP.Text = "TOP_P"
    $lblTopP.Font = AI-fnt "Segoe UI" 8.5
    $lblTopP.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $lblTopP.AutoSize = $true
    $lblTopP.Location = New-Object System.Drawing.Point(8, 4)
    $cardTopP.Controls.Add($lblTopP)
    $txtTopP.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $txtTopP.Height = 30
    $cardTopP.Controls.Add($txtTopP)
    $sideFlow.Controls.Add($cardTopP)
    
    $txtMaxTk = New-Object System.Windows.Forms.TextBox; $txtMaxTk.Text = "4096"
    $txtMaxTk.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $txtMaxTk.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $txtMaxTk.Font = AI-fnt "Segoe UI" 10
    $txtMaxTk.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $txtMaxTk.Height = 30
    $cardMaxTk = New-Object System.Windows.Forms.Panel
    $cardMaxTk.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 6)
    $cardMaxTk.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
    $cardMaxTk.Dock = [System.Windows.Forms.DockStyle]::Top
    $cardMaxTk.Height = 50
    $lblMaxTk = New-Object System.Windows.Forms.Label
    $lblMaxTk.Text = "MAX TOKENS"
    $lblMaxTk.Font = AI-fnt "Segoe UI" 8.5
    $lblMaxTk.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $lblMaxTk.AutoSize = $true
    $lblMaxTk.Location = New-Object System.Drawing.Point(8, 4)
    $cardMaxTk.Controls.Add($lblMaxTk)
    $txtMaxTk.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $txtMaxTk.Height = 30
    $cardMaxTk.Controls.Add($txtMaxTk)
    $sideFlow.Controls.Add($cardMaxTk)
    
    # RICERCA WEB
    $chkWeb = New-Object System.Windows.Forms.CheckBox
    $chkWeb.Text = "  Ricerca Web (DDG + Wiki)"
    $chkWeb.Font = AI-fnt "Segoe UI" 9.5
    $chkWeb.ForeColor = [System.Drawing.Color]::FromArgb(148, 226, 213)
    $chkWeb.AutoSize = $true
    $chkWeb.Margin = New-Object System.Windows.Forms.Padding(4, 8, 0, 4)
    $sideFlow.Controls.Add($chkWeb)
    
    # TOKENS
    $lblTokens = New-Object System.Windows.Forms.Label
    $lblTokens.Text = "Sessione: 0 tok | Modello: N/D"
    $lblTokens.Font = AI-fnt "Segoe UI" 8.5
    $lblTokens.ForeColor = [System.Drawing.Color]::FromArgb(166, 173, 200)
    $lblTokens.AutoSize = $true
    $lblTokens.Margin = New-Object System.Windows.Forms.Padding(4, 12, 0, 4)
    $sideFlow.Controls.Add($lblTokens)
    
    # SHORTCUTS
    $lblShortcuts = New-Object System.Windows.Forms.Label
    $lblShortcuts.Text = "Ctrl+L Pulisci | Ctrl+S Esporta`nCtrl+1/2/3/4 Cambia Provider"
    $lblShortcuts.Font = AI-fnt "Segoe UI" 8
    $lblShortcuts.ForeColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $lblShortcuts.AutoSize = $true
    $lblShortcuts.Margin = New-Object System.Windows.Forms.Padding(4, 4, 0, 0)
    $sideFlow.Controls.Add($lblShortcuts)
    
    # AREA CHAT
    $chatArea = New-Object System.Windows.Forms.TableLayoutPanel
    $chatArea.Dock = [System.Windows.Forms.DockStyle]::Fill
    $chatArea.RowCount = 5; $chatArea.ColumnCount = 1
    $chatArea.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 45)))
    $chatArea.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $chatArea.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 0)))
    $chatArea.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 80)))
    $chatArea.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 45)))
    $chatArea.Padding = New-Object System.Windows.Forms.Padding(12, 6, 12, 8)
    $root.Controls.Add($chatArea, 1, 0)
    
    # HEADER
    $header = New-Object System.Windows.Forms.FlowLayoutPanel
    $header.Dock = [System.Windows.Forms.DockStyle]::Fill
    $header.BackColor = [System.Drawing.Color]::FromArgb(17, 17, 27)
    $header.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $header.Padding = New-Object System.Windows.Forms.Padding(8, 10, 8, 0)
    $chatArea.Controls.Add($header, 0, 0)
    
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Conversazione"
    $lblTitle.Font = AI-fnt "Segoe UI" 15 ([System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $lblTitle.AutoSize = $true
    $lblTitle.Margin = New-Object System.Windows.Forms.Padding(0)
    $header.Controls.Add($lblTitle)
    
    $spacer = New-Object System.Windows.Forms.Panel
    $spacer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $spacer.BackColor = [System.Drawing.Color]::FromArgb(17, 17, 27)
    $header.Controls.Add($spacer)
    
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = "● Pronto"
    $lblStatus.Font = AI-fnt "Segoe UI" 9.5
    $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
    $lblStatus.AutoSize = $true
    $lblStatus.Margin = New-Object System.Windows.Forms.Padding(0)
    $header.Controls.Add($lblStatus)
    
    # CHAT BOX
    $chatBox = New-Object System.Windows.Forms.RichTextBox
    $chatBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $chatBox.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $chatBox.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $chatBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $chatBox.ReadOnly = $true
    $chatBox.Font = AI-fnt "Cascadia Code" 10.5
    $chatBox.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
    $chatBox.DetectUrls = $true
    $chatArea.Controls.Add($chatBox, 0, 1)
    
    # ATTACHMENT PANEL
    $panelAttach = New-Object System.Windows.Forms.FlowLayoutPanel
    $panelAttach.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panelAttach.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $panelAttach.WrapContents = $false
    $panelAttach.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
    $panelAttach.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 4)
    $panelAttach.Height = 0
    $chatArea.Controls.Add($panelAttach, 0, 2)
    
    # INPUT ROW
    $inputRow = New-Object System.Windows.Forms.TableLayoutPanel
    $inputRow.Dock = [System.Windows.Forms.DockStyle]::Fill
    $inputRow.RowCount = 1; $inputRow.ColumnCount = 5
    $inputRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $inputRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    $inputRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    $inputRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 70)))
    $inputRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 90)))
    $chatArea.Controls.Add($inputRow, 0, 3)
    
    $inputBox = New-Object System.Windows.Forms.TextBox
    $inputBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $inputBox.Multiline = $true
    $inputBox.AcceptsReturn = $true
    $inputBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $inputBox.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 46)
    $inputBox.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $inputBox.Font = AI-fnt "Segoe UI" 12
    $inputBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $inputRow.Controls.Add($inputBox, 0, 0)
    
    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Dock = [System.Windows.Forms.DockStyle]::Fill
    $btnCopy.Text = "Copia"
    $btnCopy.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $btnCopy.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $btnCopy.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCopy.Font = AI-fnt "Segoe UI" 8
    $inputRow.Controls.Add($btnCopy, 1, 0)
    
    $btnSaveFile = New-Object System.Windows.Forms.Button
    $btnSaveFile.Dock = [System.Windows.Forms.DockStyle]::Fill
    $btnSaveFile.Text = "Salva"
    $btnSaveFile.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $btnSaveFile.ForeColor = [System.Drawing.Color]::FromArgb(205, 214, 244)
    $btnSaveFile.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSaveFile.Font = AI-fnt "Segoe UI" 8
    $inputRow.Controls.Add($btnSaveFile, 2, 0)
    
    $btnAttach = New-Object System.Windows.Forms.Button
    $btnAttach.Dock = [System.Windows.Forms.DockStyle]::Fill
    $btnAttach.Text = "File"
    $btnAttach.BackColor = [System.Drawing.Color]::FromArgb(49, 50, 68)
    $btnAttach.ForeColor = [System.Drawing.Color]::FromArgb(250, 179, 135)
    $btnAttach.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnAttach.Font = AI-fnt "Segoe UI" 9
    $inputRow.Controls.Add($btnAttach, 3, 0)
    
    $btnSend = New-Object System.Windows.Forms.Button
    $btnSend.Dock = [System.Windows.Forms.DockStyle]::Fill
    $btnSend.Text = "Invia"
    $btnSend.BackColor = [System.Drawing.Color]::FromArgb(137, 180, 250)
    $btnSend.ForeColor = [System.Drawing.Color]::FromArgb(17, 17, 27)
    $btnSend.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnSend.FlatAppearance.BorderSize = 0
    $btnSend.Font = AI-fnt "Segoe UI" 11 ([System.Drawing.FontStyle]::Bold)
    $inputRow.Controls.Add($btnSend, 4, 0)
    
    # BOTTOM BAR
    $bottomBar = New-Object System.Windows.Forms.FlowLayoutPanel
    $bottomBar.Dock = [System.Windows.Forms.DockStyle]::Fill
    $bottomBar.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $bottomBar.WrapContents = $false
    $bottomBar.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 37)
    $bottomBar.Padding = New-Object System.Windows.Forms.Padding(2, 4, 2, 4)
    $chatArea.Controls.Add($bottomBar, 0, 4)
    
	function AI-New-Btn {
		param(
			[string]$text,
			[System.Drawing.Color]$bg = ([System.Drawing.Color]::FromArgb(49, 50, 68)),
			[string]$docName = $null,
			[System.Drawing.Color]$foreColor = ([System.Drawing.Color]::FromArgb(205, 214, 244))
		)
		
		$container = New-Object System.Windows.Forms.FlowLayoutPanel
		$container.Size = New-Object System.Drawing.Size(130, 34)
		$container.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
		$container.WrapContents = $false
		$container.BackColor = $bg
		$container.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
		
		$btn = New-Object System.Windows.Forms.Button
		$btn.Text = $text
		$btn.Size = New-Object System.Drawing.Size(95, 34)
		$btn.BackColor = $bg
		$btn.ForeColor = $foreColor   # Usa il colore passato
		$btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
		$btn.FlatAppearance.BorderSize = 0
		$btn.Font = AI-fnt "Segoe UI" 9 ([System.Drawing.FontStyle]::Bold)
		$btn.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
		$container.Controls.Add($btn)
		
		if ($docName) {
			$btnInfo = New-Object System.Windows.Forms.Button
			$btnInfo.Text = "ℹ️"
			$btnInfo.Size = New-Object System.Drawing.Size(30, 34)
			$btnInfo.BackColor = $bg
			$btnInfo.ForeColor = [System.Drawing.Color]::FromArgb(148, 226, 213)
			$btnInfo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
			$btnInfo.FlatAppearance.BorderSize = 0
			$btnInfo.Font = AI-fnt "Segoe UI" 9 ([System.Drawing.FontStyle]::Bold)
			$btnInfo.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
			$btnInfo.Cursor = [System.Windows.Forms.Cursors]::Hand
			$btnInfo.Tag = @{ Name = $docName; Text = $text; Color = $bg }
			$btnInfo.Add_Click({
				$tag = $this.Tag
				Show-ButtonDocumentation -ButtonName $tag.Name -ButtonText $tag.Text -ButtonColor $tag.Color
			})
			$tt = New-Object System.Windows.Forms.ToolTip
			$tt.SetToolTip($btnInfo, "Mostra documentazione di $text")
			$container.Controls.Add($btnInfo)
		}
		
		$bottomBar.Controls.Add($container)
		return $btn
	}
    
	# Crea i pulsanti con colori personalizzati e testo nero
	$btnClear      = AI-New-Btn "Cancella" ([System.Drawing.Color]::FromArgb(243, 139, 168)) "Cancella" ([System.Drawing.Color]::Black)     # Rosso
	$btnExport     = AI-New-Btn "Esporta" ([System.Drawing.Color]::FromArgb(166, 227, 161)) "Esporta" ([System.Drawing.Color]::Black)     # Verde
	$btnSettings   = AI-New-Btn "Impostazioni" ([System.Drawing.Color]::FromArgb(137, 180, 250)) "Impostazioni" ([System.Drawing.Color]::Black)  # Blu
	$btnStatistics = AI-New-Btn "Statistiche" ([System.Drawing.Color]::FromArgb(203, 166, 247)) "Statistiche" ([System.Drawing.Color]::Black)
	$btnVerify     = AI-New-Btn "Verifica" ([System.Drawing.Color]::FromArgb(160, 80, 220)) "Verifica" ([System.Drawing.Color]::Black)
	$btnWebSearch  = AI-New-Btn "Cerca Web" ([System.Drawing.Color]::FromArgb(255, 200, 100)) "CercaWeb" ([System.Drawing.Color]::Black)
	
	$btnWebSearch.Add_Click({
    # Prendi il testo dalla casella di input
    $query = $inputBox.Text.Trim()
    if ([string]::IsNullOrEmpty($query)) {
        $lblStatus.Text = "● Inserisci una parola da cercare"
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
        return
    }
    
    # Mostra stato "ricerca in corso"
    $lblStatus.Text = "● Ricerca in corso..."
    $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(250, 179, 135)
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        # Chiama la funzione di ricerca web (DDG + Wiki)
        $risultato = Search-AIWeb -Query $query
        
        # Se non c'è risultato, dai un messaggio
        if ([string]::IsNullOrEmpty($risultato)) {
            $risultato = "Nessun risultato trovato per '$query'."
        }
        
        # Mostra il risultato nella chat (come se fosse un messaggio di sistema)
        AI-Write-Chat $chatBox $risultato "🌐 RICERCA WEB" ([System.Drawing.Color]::FromArgb(255, 215, 0)) $false
        $inputBox.Clear()
        $lblStatus.Text = "● Ricerca completata"
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
    }
    catch {
        $err = $_.Exception.Message
        AI-Write-Chat $chatBox "Errore durante la ricerca: $err" "ERRORE" ([System.Drawing.Color]::FromArgb(243, 139, 168)) $false
        $lblStatus.Text = "● Errore ricerca"
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
    }
})
    
    # ---------- EVENTI ----------
    $inputBox.Add_TextChanged({
        $lines = ($inputBox.Text -split "`n").Count
        $h = [Math]::Max(80, [Math]::Min(150, $lines * 22))
        $chatArea.RowStyles[3].SizeType = [System.Windows.Forms.SizeType]::Absolute
        $chatArea.RowStyles[3].Height = $h
    })
    
    $inputBox.Add_KeyDown({
        if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter -and -not $_.Shift) {
            $_.SuppressKeyPress = $true
            $btnSend.PerformClick()
        }
    })
    
    $btnSend.Add_Click({
        AI-Send-Message $inputBox $chatBox $panelAttach $chatArea $comboProvider $comboModel $txtTemp $txtTopP $txtMaxTk $chkWeb $lblTokens $lblStatus
    })
    
    $btnAttach.Add_Click({ AI-Show-AttachDialog $panelAttach $chatArea })
    
    $btnCopy.Add_Click({
        if ($Global:AIChatState.LastReply) {
            [System.Windows.Forms.Clipboard]::SetText($Global:AIChatState.LastReply)
            $lblStatus.Text = "● Risposta copiata!"
            $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
        } else {
            $lblStatus.Text = "● Nessuna risposta da copiare"
            $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
        }
    })
    
    $btnSaveFile.Add_Click({
        if ($Global:AIChatState.LastReply) {
            $sfd = New-Object System.Windows.Forms.SaveFileDialog
            $sfd.Filter = "Testo (*.txt)|*.txt|Codice (*.ps1;*.py)|*.ps1;*.py"
            $sfd.FileName = "risposta_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"
            if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $Global:AIChatState.LastReply | Out-File $sfd.FileName -Encoding UTF8
                $lblStatus.Text = "● Risposta salvata su disco!"
                $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
            }
        } else {
            $lblStatus.Text = "● Nessuna risposta da salvare"
            $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
        }
    })
    
    $btnClear.Add_Click({
        $S = $Global:AIChatState
        $S.History.Clear(); $S.ChatLog = ""; $chatBox.Clear()
        $S.SessionTokens = 0; $S.ModelTokenUsage.Clear(); $S.ModelRequestCount.Clear()
        AI-Update-ModelTokenDisplay $lblTokens
        $lblStatus.Text = "● Chat cancellata"
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
    })
    
    $btnExport.Add_Click({
        $sfd = New-Object System.Windows.Forms.SaveFileDialog
        $sfd.Filter = "Testo (*.txt)|*.txt|Markdown (*.md)|*.md"
        $sfd.FileName = "chat_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"
        if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $Global:AIChatState.ChatLog | Out-File $sfd.FileName -Encoding UTF8
            AI-Write-Chat $chatBox "Esportato: $($sfd.FileName)" "SISTEMA" ([System.Drawing.Color]::FromArgb(166, 227, 161)) $false
        }
    })
    
    $btnSettings.Add_Click({ AI-Show-Settings })
    $btnStatistics.Add_Click({ AI-Show-Statistics })
    
    $btnVerify.Add_Click({
        $lblStatus.Text = "● Verifica modelli..."
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(250, 179, 135)
        [System.Windows.Forms.Application]::DoEvents()
        
        $S = $Global:AIChatState
        $origProv = $S.CurrentProvider; $origMod = $S.Model
        $origHist = $S.History.ToArray()
        
        foreach ($prov in @("Gemini", "Groq", "Cloudflare", "Bynara")) {
            $S.CurrentProvider = $prov
            $S.Model = $S.Models[$prov][0]
            $S.History.Clear()
            $S.History.Add(@{ role = "user"; content = "Rispondi solo: OK" })
            try {
                $r = Send-AIRequest
                AI-Write-Chat $chatBox "$prov`: OK" "VERIFICA" ([System.Drawing.Color]::FromArgb(166, 227, 161)) $false
            } catch {
                AI-Write-Chat $chatBox "$prov`: ERRORE - $($_.Exception.Message)" "VERIFICA" ([System.Drawing.Color]::FromArgb(243, 139, 168)) $false
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
        
        $S.CurrentProvider = $origProv; $S.Model = $origMod
        $S.History.Clear()
        foreach ($h in $origHist) { $S.History.Add($h) }
        
        $lblStatus.Text = "● Pronto"
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
        AI-Update-ModelTokenDisplay $lblTokens
    })
    
    # EVENTI COMBOBOX - AGENTI
    $comboAgents.Add_SelectedIndexChanged({
        $selectedAgentName = $comboAgents.SelectedItem
        if ($selectedAgentName) {
            $lblActiveAgent.Text = "✅ Prompt attivo: $selectedAgentName"
            $lblActiveAgent.ForeColor = [System.Drawing.Color]::FromArgb(203, 166, 247)  # Viola
			
			$filePath = [System.IO.Path]::Combine($Global:AIChatState.PromptFolder, "$selectedAgentName.md")
			if (Test-Path $filePath) {
				$content = Get-Content -Path $filePath -Raw -Encoding UTF8
				$Global:AIChatState.SystemPrompt = $content
				AI-Write-Chat $chatBox "Agente attivato: $selectedAgentName" "AGENTE" ([System.Drawing.Color]::FromArgb(180, 190, 254)) $false
			}
		} else {
			$lblActiveAgent.Text = "🤖 Agente attivo: Nessuno"
		}
	})
    
    $comboProvider.Add_SelectedIndexChanged({
        AI-Update-Models $comboProvider $comboModel
        $Global:AIChatState.CurrentProvider = $comboProvider.SelectedItem
        $Global:AIChatState.Model = $comboModel.SelectedItem
        AI-Update-ModelTokenDisplay $lblTokens
        AI-Write-Chat $chatBox "Provider: $($comboProvider.SelectedItem)" "SISTEMA" ([System.Drawing.Color]::FromArgb(166, 227, 161)) $false
    })
    
    # EVENTI FORM
    $dialog.Add_KeyDown({
        if ($_.Control) {
            switch ($_.KeyCode) {
                ([System.Windows.Forms.Keys]::L) { $btnClear.PerformClick(); $_.Handled = $true }
                ([System.Windows.Forms.Keys]::S) { $btnExport.PerformClick(); $_.Handled = $true }
                ([System.Windows.Forms.Keys]::D1) { $comboProvider.SelectedIndex = 0; $_.Handled = $true }
                ([System.Windows.Forms.Keys]::D2) { $comboProvider.SelectedIndex = 1; $_.Handled = $true }
                ([System.Windows.Forms.Keys]::D3) { $comboProvider.SelectedIndex = 2; $_.Handled = $true }
                ([System.Windows.Forms.Keys]::D4) { $comboProvider.SelectedIndex = 3; $_.Handled = $true }
            }
        }
    })
    
    $dialog.Add_Shown({
        $inputBox.Focus()
        AI-Write-Chat $chatBox "Benvenuto in AI Chat Peters v3!`r`nCartella agenti: $($Global:AIChatState.PromptFolder)" "SISTEMA" ([System.Drawing.Color]::FromArgb(166, 227, 161)) $false
        AI-Update-ModelTokenDisplay $lblTokens
        
        # Inizializza la label viola con l'agente selezionato
        $selectedAgent = $comboAgents.SelectedItem
        if ($selectedAgent) {
            $lblActiveAgent.Text = "✅ Prompt attivo: $selectedAgent"
        } else {
            $lblActiveAgent.Text = "✅ Prompt attivo: Nessuno"
        }
    })
    
    $dialog.ShowDialog()
    $dialog.Dispose()
}

# ============================================================
# FINE DEL MODULO - Le funzioni sono disponibili tramite dot-sourcing
# ============================================================
