# ============================
# MODULO AICHAT - Finestra chat AI (Multi-Provider)
# Design responsive con input 100px e progress bar blu
# ============================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-AIChatDialog {
    # ---------- VARIABILI ----------
    $script:ApiKey            = $null
    $script:CurrentPromptName = ""
    $script:CurrentProvider   = "llm7-free"
    $script:SelectedModel     = $null
    $script:SystemPrompt      = ""
    $script:CurrentJob        = $null
    $script:CancellationToken = $false
    $script:IsBusy            = $false

    $script:PromptDir = Join-Path $PSScriptRoot "Docs\Buttons"
    if (-not (Test-Path $script:PromptDir)) {
        $script:PromptDir = Join-Path $PSScriptRoot "..\Docs\Buttons"
    }

    # ---------- FORM ----------
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Manutenzione PRO MAX - Assistente AI"
    $form.Size = New-Object System.Drawing.Size(1200, 800)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "Sizable"
    $form.MaximizeBox = $true
    $form.WindowState = "Maximized"
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
    $form.MinimumSize = New-Object System.Drawing.Size(800, 600)

    # ---------- LAYOUT PRINCIPALE ----------
    $mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $mainLayout.Dock = "Fill"
    $mainLayout.RowCount = 4
    $mainLayout.ColumnCount = 1
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))    # Config bar
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) # Chat area
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 100))) # Input area (100px)
    $mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))  # Progress + Status
    $mainLayout.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
    $form.Controls.Add($mainLayout)

    # ---------- BARRA DI CONFIGURAZIONE (Riga 0) ----------
    $configPanel = New-Object System.Windows.Forms.Panel
    $configPanel.Dock = "Fill"
    $configPanel.BackColor = [System.Drawing.Color]::FromArgb(35, 40, 70)
    $configPanel.Padding = New-Object System.Windows.Forms.Padding(10)
    $mainLayout.Controls.Add($configPanel, 0, 0)

    # Usiamo un FlowLayoutPanel per disporre i controlli orizzontalmente con wrap
    $configFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $configFlow.Dock = "Fill"
    $configFlow.FlowDirection = "LeftToRight"
    $configFlow.WrapContents = $true
    $configFlow.AutoSize = $true
    $configFlow.BackColor = [System.Drawing.Color]::Transparent
    $configPanel.Controls.Add($configFlow)

    # Prompt
    $lblPrompt = New-Object System.Windows.Forms.Label
    $lblPrompt.Text = "Prompt:"
    $lblPrompt.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 210)
    $lblPrompt.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblPrompt.AutoSize = $true
    $lblPrompt.Margin = New-Object System.Windows.Forms.Padding(0, 6, 10, 0)
    $configFlow.Controls.Add($lblPrompt)

    $comboPrompt = New-Object System.Windows.Forms.ComboBox
    $comboPrompt.DropDownStyle = "DropDownList"
    $comboPrompt.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
    $comboPrompt.ForeColor = [System.Drawing.Color]::White
    $comboPrompt.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $comboPrompt.Width = 200
    $comboPrompt.Margin = New-Object System.Windows.Forms.Padding(0, 3, 15, 0)
    $configFlow.Controls.Add($comboPrompt)

    # Provider
    $lblProvider = New-Object System.Windows.Forms.Label
    $lblProvider.Text = "Provider:"
    $lblProvider.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 210)
    $lblProvider.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblProvider.AutoSize = $true
    $lblProvider.Margin = New-Object System.Windows.Forms.Padding(0, 6, 10, 0)
    $configFlow.Controls.Add($lblProvider)

    $comboProvider = New-Object System.Windows.Forms.ComboBox
    $comboProvider.DropDownStyle = "DropDownList"
    $comboProvider.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
    $comboProvider.ForeColor = [System.Drawing.Color]::White
    $comboProvider.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $comboProvider.Width = 150
    $comboProvider.Margin = New-Object System.Windows.Forms.Padding(0, 3, 15, 0)
    $comboProvider.Items.AddRange(@("llm7 (free)", "llm7 (API)", "Gemini", "Groq", "HuggingFace", "Mistral", "OpenRouter"))
    $comboProvider.SelectedIndex = 0
    $configFlow.Controls.Add($comboProvider)

    # Link API Key
    $linkApi = New-Object System.Windows.Forms.LinkLabel
    $linkApi.AutoSize = $true
    $linkApi.ForeColor = [System.Drawing.Color]::LightGray
    $linkApi.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    $linkApi.Text = ""
    $linkApi.LinkColor = [System.Drawing.Color]::FromArgb(100, 160, 255)
    $linkApi.VisitedLinkColor = [System.Drawing.Color]::FromArgb(150, 150, 200)
    $linkApi.ActiveLinkColor = [System.Drawing.Color]::FromArgb(200, 200, 255)
    $linkApi.Margin = New-Object System.Windows.Forms.Padding(0, 6, 15, 0)
    $configFlow.Controls.Add($linkApi)

    # API Key
    $lblApi = New-Object System.Windows.Forms.Label
    $lblApi.Text = "API Key:"
    $lblApi.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 210)
    $lblApi.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblApi.AutoSize = $true
    $lblApi.Margin = New-Object System.Windows.Forms.Padding(0, 6, 10, 0)
    $lblApi.Visible = $false
    $configFlow.Controls.Add($lblApi)

    $txtApiKey = New-Object System.Windows.Forms.TextBox
    $txtApiKey.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
    $txtApiKey.ForeColor = [System.Drawing.Color]::White
    $txtApiKey.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $txtApiKey.BorderStyle = "FixedSingle"
    $txtApiKey.Width = 250
    $txtApiKey.Margin = New-Object System.Windows.Forms.Padding(0, 3, 10, 0)
    $txtApiKey.Visible = $false
    $configFlow.Controls.Add($txtApiKey)

    $btnSaveKey = New-Object System.Windows.Forms.Button
    $btnSaveKey.Text = "Salva API Key"
    $btnSaveKey.BackColor = [System.Drawing.Color]::FromArgb(0, 140, 210)
    $btnSaveKey.ForeColor = [System.Drawing.Color]::White
    $btnSaveKey.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnSaveKey.FlatStyle = "Flat"
    $btnSaveKey.FlatAppearance.BorderSize = 0
    $btnSaveKey.AutoSize = $true
    $btnSaveKey.Margin = New-Object System.Windows.Forms.Padding(0, 3, 0, 0)
    $btnSaveKey.Visible = $false
    $configFlow.Controls.Add($btnSaveKey)

    # ---------- AREA CHAT (Riga 1) ----------
    $chatPanel = New-Object System.Windows.Forms.Panel
    $chatPanel.Dock = "Fill"
    $chatPanel.Padding = New-Object System.Windows.Forms.Padding(10)
    $chatPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
    $mainLayout.Controls.Add($chatPanel, 0, 1)

    $outputBox = New-Object System.Windows.Forms.RichTextBox
    $outputBox.Dock = "Fill"
    $outputBox.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 25)
    $outputBox.ForeColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
    $outputBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $outputBox.ReadOnly = $true
    $outputBox.BorderStyle = "None"
    $outputBox.ScrollBars = "Vertical"
    $chatPanel.Controls.Add($outputBox)

    # ---------- AREA INPUT + PULSANTI (Riga 2) ----------
    $inputRow = New-Object System.Windows.Forms.TableLayoutPanel
    $inputRow.Dock = "Fill"
    $inputRow.ColumnCount = 2
    $inputRow.RowCount = 1
    $inputRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) # Input box
    $inputRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))     # Buttons
    $inputRow.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
    $inputRow.Padding = New-Object System.Windows.Forms.Padding(10, 5, 10, 5)
    $mainLayout.Controls.Add($inputRow, 0, 2)

	# Input textbox (100px altezza)
	$inputBox = New-Object System.Windows.Forms.TextBox
	$inputBox.Multiline = $true
	$inputBox.BackColor = [System.Drawing.Color]::FromArgb(30, 40, 60)   # Sfondo blu scuro
	$inputBox.ForeColor = [System.Drawing.Color]::White                 # Testo bianco
	$inputBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
	$inputBox.BorderStyle = "FixedSingle"
	$inputBox.AcceptsReturn = $true
	$inputBox.ScrollBars = "Vertical"
	$inputBox.Dock = "Fill"
	$inputBox.Height = 100 - 10
	$inputRow.Controls.Add($inputBox, 0, 0)

    # Pulsanti allineati verticalmente
    $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonPanel.Dock = "Fill"
    $buttonPanel.FlowDirection = "TopDown"
    $buttonPanel.WrapContents = $false
    $buttonPanel.AutoSize = $true
    $buttonPanel.BackColor = [System.Drawing.Color]::Transparent
    $buttonPanel.Padding = New-Object System.Windows.Forms.Padding(5, 0, 0, 0)
    $inputRow.Controls.Add($buttonPanel, 1, 0)

    $btnSend = New-Object System.Windows.Forms.Button
    $btnSend.Text = "Invia"
    $btnSend.BackColor = [System.Drawing.Color]::FromArgb(0, 140, 210)
    $btnSend.ForeColor = [System.Drawing.Color]::White
    $btnSend.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnSend.FlatStyle = "Flat"
    $btnSend.FlatAppearance.BorderSize = 0
    $btnSend.AutoSize = $true
    $btnSend.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 5)
    $buttonPanel.Controls.Add($btnSend)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Annulla"
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(200, 50, 50)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.FlatAppearance.BorderSize = 0
    $btnCancel.AutoSize = $true
    $btnCancel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 5)
    $btnCancel.Enabled = $false
    $buttonPanel.Controls.Add($btnCancel)

    $btnClear = New-Object System.Windows.Forms.Button
    $btnClear.Text = "Cancella Chat"
    $btnClear.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 80)
    $btnClear.ForeColor = [System.Drawing.Color]::White
    $btnClear.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnClear.FlatStyle = "Flat"
    $btnClear.FlatAppearance.BorderSize = 0
    $btnClear.AutoSize = $true
    $btnClear.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
    $buttonPanel.Controls.Add($btnClear)

    # ---------- PROGRESS + STATUS (Riga 3) ----------
    $statusRow = New-Object System.Windows.Forms.TableLayoutPanel
    $statusRow.Dock = "Fill"
    $statusRow.ColumnCount = 2
    $statusRow.RowCount = 1
    $statusRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize))) # Status label
    $statusRow.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) # Progress bar
    $statusRow.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
    $statusRow.Padding = New-Object System.Windows.Forms.Padding(10, 2, 10, 2)
    $mainLayout.Controls.Add($statusRow, 0, 3)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "Pronto"
    $statusLabel.ForeColor = [System.Drawing.Color]::LightGray
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    $statusLabel.AutoSize = $true
    $statusLabel.Margin = New-Object System.Windows.Forms.Padding(0, 4, 15, 0)
    $statusRow.Controls.Add($statusLabel, 0, 0)

    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Dock = "Fill"
    $progressBar.Style = "Marquee"
    $progressBar.Visible = $false
    $progressBar.ForeColor = [System.Drawing.Color]::FromArgb(0, 140, 210)  # Blu
    $progressBar.Margin = New-Object System.Windows.Forms.Padding(0, 3, 0, 0)
    $statusRow.Controls.Add($progressBar, 1, 0)

    # ---------- FUNZIONI ----------
    function Get-ProviderKeyFile {
        param([string]$Provider)
        switch ($Provider) {
            "llm7 (API)"  { return "api.llm7.txt" }
            "Gemini"      { return "api.gemini.txt" }
            "Groq"        { return "api.groq.txt" }
            "HuggingFace" { return "api.huggingface.txt" }
            "Mistral"     { return "api.mistral.txt" }
            "OpenRouter"  { return "api.openrouter.txt" }
            default       { return $null }
        }
    }

    function Get-ProviderApiUrl {
        param([string]$Provider)
        switch ($Provider) {
            "llm7 (free)"   { return $null }
            "llm7 (API)"    { return "https://dash.llm7.io/" }
            "Gemini"        { return "https://ai.google.dev/" }
            "Groq"          { return "https://console.groq.com/" }
            "HuggingFace"   { return "https://huggingface.co/settings/tokens" }
            "Mistral"       { return "https://console.mistral.ai/api-keys/" }
            "OpenRouter"    { return "https://openrouter.ai/keys" }
            default         { return $null }
        }
    }

    function Update-ApiLink {
        $provider = [string]$comboProvider.SelectedItem
        $url = Get-ProviderApiUrl -Provider $provider
        if ($url) {
            $linkApi.Text = "Crea API Key qui: $url"
            $linkApi.Links.Clear()
            $linkApi.Links.Add(18, $url.Length, $url)
            $linkApi.Visible = $true
        } else {
            $linkApi.Text = "Nessuna API Key richiesta."
            $linkApi.Links.Clear()
            $linkApi.Visible = $true
        }
    }

    function Load-ApiKey {
        $provider = [string]$comboProvider.SelectedItem
        $keyFile = Get-ProviderKeyFile -Provider $provider
        if ($keyFile) {
            $keyPath = Join-Path $script:PromptDir ("..\{0}" -f $keyFile)
            if (Test-Path $keyPath) {
                $key = (Get-Content $keyPath -Raw -Encoding UTF8).Trim()
                $txtApiKey.Text = $key
                $script:ApiKey = $key
            } else {
                $txtApiKey.Text = ""
                $script:ApiKey = ""
            }
            $lblApi.Visible = $true
            $txtApiKey.Visible = $true
            $btnSaveKey.Visible = $true
            if ($provider -in @("Gemini", "Groq", "HuggingFace", "Mistral", "OpenRouter")) {
                Test-ProviderConnection -Provider $provider -ApiKey $script:ApiKey
            }
        } else {
            $lblApi.Visible = $false
            $txtApiKey.Visible = $false
            $btnSaveKey.Visible = $false
            $script:ApiKey = "unused"
            $statusLabel.Text = ("Provider: {0}" -f $provider)
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
        }
        Update-ApiLink
    }

    function Save-ApiKey {
        $provider = [string]$comboProvider.SelectedItem
        $keyFile = Get-ProviderKeyFile -Provider $provider
        if (-not $keyFile) {
            [System.Windows.Forms.MessageBox]::Show("Questo provider non richiede una chiave.", "Info")
            return
        }
        $key = $txtApiKey.Text.Trim()
        if ([string]::IsNullOrEmpty($key)) {
            [System.Windows.Forms.MessageBox]::Show("Inserisci una chiave valida.", "Attenzione")
            return
        }
        $keyPath = Join-Path $script:PromptDir ("..\{0}" -f $keyFile)
        try {
            New-Item -ItemType Directory -Force -Path (Split-Path $keyPath -Parent) | Out-Null
            $key | Out-File -FilePath $keyPath -Encoding UTF8 -Force
            $script:ApiKey = $key
            $statusLabel.Text = ("API Key salvata per {0}" -f $provider)
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
            if ($provider -in @("Gemini", "Groq", "HuggingFace", "Mistral", "OpenRouter")) {
                Test-ProviderConnection -Provider $provider -ApiKey $key
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show(("Errore: {0}" -f $_.Exception.Message), "Errore", "OK", "Error")
        }
    }

    function Test-ProviderConnection {
        param([string]$Provider, [string]$ApiKey)
        if ($script:IsBusy) { return }
        if ([string]::IsNullOrEmpty($ApiKey) -or $ApiKey -eq "unused") {
            $statusLabel.Text = ("{0}: inserisci una chiave valida." -f $Provider)
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
            return
        }

        $statusLabel.Text = ("Verifica {0}... (cercando modello)" -f $Provider)
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(250, 179, 135)
        [System.Windows.Forms.Application]::DoEvents()

        $candidateModels = @()
        $url = ""
        $headers = @{
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer $ApiKey"
        }

        switch ($Provider) {
            "Gemini" {
                $url = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
                $candidateModels = @(
                    "gemini-2.5-flash-lite", "gemini-2.5-flash", "gemini-2.0-flash-lite",
                    "gemini-1.5-flash", "gemini-1.5-flash-8b", "gemini-2.0-flash", "gemini-1.5-pro"
                )
            }
            "Groq" {
                $url = "https://api.groq.com/openai/v1/chat/completions"
                $candidateModels = @("llama-3.1-8b-instant", "gemma2-9b-it", "mixtral-8x7b-32768")
            }
            "HuggingFace" {
                $url = "https://router.huggingface.co/v1/chat/completions"
                $candidateModels = @(
                    "meta-llama/Llama-3.1-8B-Instruct", "meta-llama/Llama-3.2-3B-Instruct",
                    "Qwen/Qwen2.5-7B-Instruct", "microsoft/Phi-3.5-mini-instruct",
                    "mistralai/Mistral-7B-Instruct-v0.3"
                )
            }
            "Mistral" {
                $url = "https://api.mistral.ai/v1/chat/completions"
                try {
                    $modelsResp = Invoke-RestMethod -Uri "https://api.mistral.ai/v1/models" -Headers $headers -TimeoutSec 5
                    $available = @($modelsResp.data | ForEach-Object { $_.id })
                    $preferred = @("mistral-small-latest", "open-mistral-nemo", "ministral-8b-latest", "mistral-medium-latest")
                    $candidateModels = @($preferred | Where-Object { $available -contains $_ })
                    if ($candidateModels.Count -eq 0) { $candidateModels = $available }
                } catch {
                    $candidateModels = @("mistral-small-latest", "open-mistral-nemo", "ministral-8b-latest")
                }
            }
            "OpenRouter" {
                $url = "https://openrouter.ai/api/v1/chat/completions"
                $headers["HTTP-Referer"] = "https://localhost"
                $headers["X-Title"] = "Manutenzione PRO MAX"
                $candidateModels = @(
                    "openrouter/free",
                    "meta-llama/llama-3.1-8b-instruct:free",
                    "meta-llama/llama-3.2-3b-instruct:free",
                    "qwen/qwen-2.5-7b-instruct:free",
                    "google/gemma-2-9b-it:free"
                )
            }
        }

        $selectedModel = $null
        foreach ($m in $candidateModels) {
            $testBody = (@{
                model = $m
                messages = @(@{ role = "user"; content = "ping" })
                max_tokens = 5
                stream = $false
            } | ConvertTo-Json -Depth 5 -Compress)

            try {
                $null = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $testBody -TimeoutSec 10 -ErrorAction Stop
                $selectedModel = $m
                break
            } catch {
                # prova il successivo
            }
        }

        if ($selectedModel) {
            $script:SelectedModel = $selectedModel
            $statusLabel.Text = ("{0} connesso (modello: {1})" -f $Provider, $selectedModel)
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
        } else {
            $statusLabel.Text = ("{0}: nessun modello funzionante. Verifica chiave/quota." -f $Provider)
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
            $script:SelectedModel = $null
        }
    }

    function Load-PromptFile {
        param([string]$FileName)
        if ([string]::IsNullOrEmpty($FileName)) { return }
        $filePath = Join-Path $script:PromptDir ("{0}.txt" -f $FileName)
        if (-not (Test-Path $filePath)) {
            $statusLabel.Text = ("File {0}.txt non trovato!" -f $FileName)
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
            return
        }
        $content = Get-Content $filePath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($content)) {
            $statusLabel.Text = ("Il file {0}.txt e vuoto!" -f $FileName)
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(243, 139, 168)
            return
        }
        $script:SystemPrompt = $content
        $script:CurrentPromptName = $FileName
        $statusLabel.Text = ("Prompt caricato: '{0}'" -f $FileName)
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
    }

    # ---------- POPOLAMENTO COMBOBOX ----------
    if (-not (Test-Path $script:PromptDir)) {
        [System.Windows.Forms.MessageBox]::Show("Cartella Docs\Buttons non trovata!", "Errore", "OK", "Error")
        return
    }
    $txtFiles = Get-ChildItem -Path $script:PromptDir -Filter *.txt -ErrorAction SilentlyContinue
    if (-not $txtFiles -or $txtFiles.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Nessun file .txt in Docs\Buttons.", "Errore", "OK", "Error")
        return
    }
    $comboPrompt.Items.Clear()
    foreach ($file in $txtFiles) { [void]$comboPrompt.Items.Add($file.BaseName) }
    if ($comboPrompt.Items.Contains("prompt")) { $comboPrompt.SelectedItem = "prompt" }
    else { $comboPrompt.SelectedIndex = 0 }

    # ---------- UI HELPERS ----------
    function Add-ChatMessage {
        param([string]$Sender, [string]$Text)
        $timestamp = Get-Date -Format "HH:mm"
        $providerName = [string]$comboProvider.SelectedItem
        if ($Sender -eq "User") {
            $prefix = "Tu"
        } else {
            $prefix = "Assistente $providerName"
        }

        $outputBox.SelectionStart = $outputBox.TextLength
        $outputBox.SelectionLength = 0
        $outputBox.SelectionColor = [System.Drawing.Color]::Gray
        $outputBox.SelectionFont = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
        $outputBox.AppendText("[$timestamp] ")

        $outputBox.SelectionStart = $outputBox.TextLength
        $outputBox.SelectionLength = 0
        if ($Sender -eq "User") {
            $outputBox.SelectionColor = [System.Drawing.Color]::Cyan
            $outputBox.SelectionFont = New-Object System.Drawing.Font("Segoe UI", 12, ([System.Drawing.FontStyle]::Bold -bor [System.Drawing.FontStyle]::Italic))
        } else {
            $outputBox.SelectionColor = [System.Drawing.Color]::LightGreen
            $outputBox.SelectionFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        }
        $outputBox.AppendText("$prefix`n")

        $outputBox.SelectionStart = $outputBox.TextLength
        $outputBox.SelectionLength = 0
        if ($Sender -eq "User") {
            $outputBox.SelectionColor = [System.Drawing.Color]::Cyan
            $outputBox.SelectionFont = New-Object System.Drawing.Font("Segoe UI", 12, ([System.Drawing.FontStyle]::Bold -bor [System.Drawing.FontStyle]::Italic))
        } else {
            $outputBox.SelectionColor = [System.Drawing.Color]::White
            $outputBox.SelectionFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
        }
        $outputBox.AppendText("$Text`n`n")
        $outputBox.ScrollToCaret()
    }

    function Set-BusyState {
        param([bool]$Busy)
        $script:IsBusy = $Busy
        $btnSend.Enabled = -not $Busy
        $btnCancel.Enabled = $Busy
        $btnClear.Enabled = -not $Busy
        $inputBox.Enabled = -not $Busy
        $comboPrompt.Enabled = -not $Busy
        $comboProvider.Enabled = -not $Busy
        $txtApiKey.Enabled = -not $Busy
        $btnSaveKey.Enabled = -not $Busy
        $progressBar.Visible = $Busy
        if ($Busy) {
            $progressBar.Style = "Marquee"
            $statusLabel.Text = "Elaborazione in corso..."
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(250, 179, 135)
        } else {
            $progressBar.Visible = $false
            $statusLabel.Text = "Pronto"
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(166, 227, 161)
        }
    }

    # ---------- TIMER ----------
    $script:Timer = New-Object System.Windows.Forms.Timer
    $script:Timer.Interval = 300
    $script:Timer.Add_Tick({
        if ($null -eq $script:Timer -or $null -eq $script:CurrentJob) {
            if ($null -ne $script:Timer) { $script:Timer.Stop() }
            return
        }
        $job = $script:CurrentJob

        if ($script:CancellationToken) {
            try {
                if ($job.State -eq "Running") { Stop-Job -Job $job -Force -ErrorAction SilentlyContinue }
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            } catch {}
            $script:CurrentJob = $null
            $script:Timer.Stop()
            Set-BusyState $false
            Add-ChatMessage -Sender "Assistant" -Text "Richiesta annullata."
            return
        }

        if ($job.State -eq "Completed") {
            try {
                $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            } catch { $result = "Errore nel ricevere il risultato." }
            $script:CurrentJob = $null
            $script:Timer.Stop()
            Set-BusyState $false
            Add-ChatMessage -Sender "Assistant" -Text $result
            return
        }

        if ($job.State -eq "Failed" -or $job.State -eq "Stopped") {
            $errorMsg = if ($job.JobStateInfo.Reason) { $job.JobStateInfo.Reason.Message } else { "Job interrotto" }
            try { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue } catch {}
            $script:CurrentJob = $null
            $script:Timer.Stop()
            Set-BusyState $false
            Add-ChatMessage -Sender "Assistant" -Text ("Errore: {0}" -f $errorMsg)
            return
        }

        $statusLabel.Text = "In attesa di risposta... (Timeout 60s)"
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(250, 179, 135)
    })

    # ---------- EVENTI ----------
    $comboPrompt.Add_SelectedIndexChanged({
        if ($comboPrompt.SelectedItem) { Load-PromptFile -FileName ([string]$comboPrompt.SelectedItem) }
    })
    $comboProvider.Add_SelectedIndexChanged({ Load-ApiKey })
    $btnSaveKey.Add_Click({ Save-ApiKey })

    $linkApi.Add_LinkClicked({
        $_.Link.Visited = $true
        Start-Process $_.Link.LinkData
    })

    $btnSend.Add_Click({
        $question = $inputBox.Text.Trim()
        if (-not $question) {
            [System.Windows.Forms.MessageBox]::Show("Inserisci una domanda.", "Attenzione")
            return
        }
        if ($script:IsBusy) { return }

        Add-ChatMessage -Sender "User" -Text $question
        $inputBox.Clear()
        Set-BusyState $true
        $script:CancellationToken = $false

        $provider = [string]$comboProvider.SelectedItem
        $apiKey = $script:ApiKey
        $url = ""
        $model = $script:SelectedModel
        $extraHeaders = @{}
        $maxTokens = 1024
        $maxSysChars = 6000

        switch ($provider) {
            "llm7 (free)" {
                $url = "https://api.llm7.io/v1/chat/completions"
                $model = "default"
                $apiKey = "unused"
            }
            "llm7 (API)" {
                $url = "https://api.llm7.io/v1/chat/completions"
                $model = "default"
                if ([string]::IsNullOrEmpty($apiKey)) {
                    Set-BusyState $false
                    Add-ChatMessage -Sender "Assistant" -Text "Nessuna API Key per llm7 (API)."
                    return
                }
            }
            "Gemini" {
                $url = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
                if (-not $model) {
                    Set-BusyState $false
                    Add-ChatMessage -Sender "Assistant" -Text "Nessun modello trovato per Gemini."
                    return
                }
            }
            "Groq" {
                $url = "https://api.groq.com/openai/v1/chat/completions"
                $model = "llama-3.1-8b-instant"
                $maxTokens = 512
                $maxSysChars = 3500
                if ([string]::IsNullOrEmpty($apiKey)) {
                    Set-BusyState $false
                    Add-ChatMessage -Sender "Assistant" -Text "Nessuna API Key per Groq."
                    return
                }
            }
            "HuggingFace" {
                $url = "https://router.huggingface.co/v1/chat/completions"
                if (-not $model) {
                    Set-BusyState $false
                    Add-ChatMessage -Sender "Assistant" -Text "Nessun modello trovato per HuggingFace."
                    return
                }
            }
            "Mistral" {
                $url = "https://api.mistral.ai/v1/chat/completions"
                if (-not $model) {
                    Set-BusyState $false
                    Add-ChatMessage -Sender "Assistant" -Text "Nessun modello trovato per Mistral."
                    return
                }
            }
            "OpenRouter" {
                $url = "https://openrouter.ai/api/v1/chat/completions"
                $extraHeaders["HTTP-Referer"] = "https://localhost"
                $extraHeaders["X-Title"] = "Manutenzione PRO MAX"
                if (-not $model) {
                    Set-BusyState $false
                    Add-ChatMessage -Sender "Assistant" -Text "Nessun modello trovato per OpenRouter."
                    return
                }
            }
            default {
                Set-BusyState $false
                Add-ChatMessage -Sender "Assistant" -Text "Provider non riconosciuto."
                return
            }
        }

        $sysPrompt = if ($null -eq $script:SystemPrompt) { "" } else { [string]$script:SystemPrompt }
        $truncatedNote = ""
        if ($sysPrompt.Length -gt $maxSysChars) {
            $sysPrompt = $sysPrompt.Substring(0, $maxSysChars)
            $truncatedNote = " [prompt troncato per limiti provider]"
        }

        $jobScript = {
            param($Q, $SysPrompt, $ApiKey, $Url, $Model, $Provider, $ExtraHeaders, $MaxTokens)

            $messages = @()

            if ($Provider -eq "Groq") {
                if (-not [string]::IsNullOrWhiteSpace($SysPrompt)) {
                    if ($SysPrompt.Length -le 1500) {
                        $messages += @{ role = "system"; content = $SysPrompt }
                        $messages += @{ role = "user"; content = $Q }
                    } else {
                        $merged = "Istruzioni operative:`n{0}`n`n--- Domanda utente ---`n{1}" -f $SysPrompt, $Q
                        $messages += @{ role = "user"; content = $merged }
                    }
                } else {
                    $messages += @{ role = "user"; content = $Q }
                }

                $bodyObj = @{
                    model       = $Model
                    messages    = $messages
                    temperature = 0.7
                    max_tokens  = $MaxTokens
                }
            } else {
                if (-not [string]::IsNullOrWhiteSpace($SysPrompt)) {
                    $messages += @{ role = "system"; content = $SysPrompt }
                }
                $messages += @{ role = "user"; content = $Q }

                $bodyObj = @{
                    model       = $Model
                    messages    = $messages
                    temperature = 0.7
                    max_tokens  = $MaxTokens
                    stream      = $false
                }
            }

            $bodyJson = $bodyObj | ConvertTo-Json -Depth 8 -Compress

            $headers = @{
                "Content-Type"  = "application/json"
                "Authorization" = "Bearer $ApiKey"
            }
            if ($ExtraHeaders) {
                foreach ($k in @($ExtraHeaders.Keys)) { $headers[$k] = $ExtraHeaders[$k] }
            }

            $maxRetries = 3
            $baseDelay = 5
            for ($i = 0; $i -lt $maxRetries; $i++) {
                try {
                    $response = Invoke-RestMethod -Uri $Url -Method Post -Headers $headers -Body $bodyJson -TimeoutSec 60 -ErrorAction Stop
                    if ($response.choices -and $response.choices.Count -gt 0) {
                        return $response.choices[0].message.content
                    }
                    return "Risposta vuota dal provider."
                }
                catch {
                    $statusCode = 0
                    $errDetail = $_.Exception.Message
                    if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
                    if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $errDetail = $_.ErrorDetails.Message }

                    if ($statusCode -eq 429 -and $i -lt ($maxRetries - 1)) {
                        Start-Sleep -Seconds ($baseDelay * ($i + 1))
                        continue
                    }
                    if ($statusCode -eq 413) {
                        return "ERRORE 413: payload troppo grande. Riduci il file prompt in Docs\Buttons (soprattutto per Groq)."
                    }
                    return ("ERRORE ({0}): {1}" -f $statusCode, $errDetail)
                }
            }
            return "ERRORE: limite richieste 429. Riprova tra poco."
        }

        $script:CurrentJob = Start-Job -ScriptBlock $jobScript -ArgumentList @(
            $question,
            $sysPrompt,
            $apiKey,
            $url,
            $model,
            $provider,
            $extraHeaders,
            $maxTokens
        )
        if ($null -ne $script:Timer) { $script:Timer.Start() }

        if ($truncatedNote) {
            $statusLabel.Text = ("Invio in corso{0}" -f $truncatedNote)
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(250, 179, 135)
        }
    })

    $btnCancel.Add_Click({
        $script:CancellationToken = $true
        $statusLabel.Text = "Annullamento in corso..."
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(250, 179, 135)
    })

    $btnClear.Add_Click({
        if ($script:IsBusy) {
            [System.Windows.Forms.MessageBox]::Show("Attendi il completamento.", "Operazione in corso")
            return
        }
        $outputBox.Clear()
        Add-ChatMessage -Sender "Assistant" -Text ("Chat cancellata. Provider: {0} - Prompt: '{1}'." -f $comboProvider.SelectedItem, $script:CurrentPromptName)
    })

    $inputBox.Add_KeyDown({
        if ($_.KeyCode -eq "Return" -and -not $_.Shift) {
            $_.SuppressKeyPress = $true
            $btnSend.PerformClick()
        }
    })

    # ---------- AVVIO ----------
    Load-PromptFile -FileName ([string]$comboPrompt.SelectedItem)
    Load-ApiKey
    Add-ChatMessage -Sender "Assistant" -Text ("Benvenuto! Provider: {0} - Prompt: '{1}'." -f $comboProvider.SelectedItem, $script:CurrentPromptName)

    [void]$form.ShowDialog()
}
