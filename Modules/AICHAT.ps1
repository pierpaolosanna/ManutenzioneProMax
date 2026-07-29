# ============================
# MODULO AICHAT - Finestra chat AI
# ============================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-AIChatDialog {
    # ============================
    # CONFIGURAZIONE
    # ============================
    $script:ApiUrl     = "https://api.llm7.io/v1/chat/completions"
    $script:ApiKey     = "unused"
    $script:Model      = "default"

    # Percorso del prompt
    $script:PromptFile = Join-Path $PSScriptRoot "Docs\Buttons\prompt.txt"
    if (-not (Test-Path $script:PromptFile)) {
        $script:PromptFile = Join-Path $PSScriptRoot "..\Docs\Buttons\prompt.txt"
    }
    if (-not (Test-Path $script:PromptFile)) {
        [System.Windows.Forms.MessageBox]::Show(
            "File prompt.txt non trovato.`nCercato in:`n$($script:PromptFile)",
            "Errore", "OK", "Error"
        )
        return
    }

    $script:SystemPrompt = Get-Content $script:PromptFile -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($script:SystemPrompt)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Il file prompt.txt è vuoto.",
            "Errore", "OK", "Error"
        )
        return
    }

    # ============================
    # VARIABILI LOCALI
    # ============================
    $script:CurrentJob        = $null
    $script:CancellationToken = $false
    $script:IsBusy            = $false

    # ============================
    # CREAZIONE INTERFACCIA
    # ============================
    $form                 = New-Object System.Windows.Forms.Form
    $form.Text            = "🧠 Manutenzione PRO MAX - Assistente AI"
    $form.Size            = New-Object System.Drawing.Size(840, 740)
    $form.StartPosition   = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.BackColor       = [System.Drawing.Color]::FromArgb(28, 28, 30)
    $form.MaximizeBox     = $false
    $form.Padding         = New-Object System.Windows.Forms.Padding(10)

    # --- Output chat ---
    $outputBox             = New-Object System.Windows.Forms.RichTextBox
    $outputBox.Size        = New-Object System.Drawing.Size(780, 480)
    $outputBox.Location    = New-Object System.Drawing.Point(20, 20)
    $outputBox.BackColor   = [System.Drawing.Color]::FromArgb(38, 38, 42)
    $outputBox.ForeColor   = [System.Drawing.Color]::White
    $outputBox.Font        = New-Object System.Drawing.Font("Segoe UI", 10)
    $outputBox.ReadOnly    = $true
    $outputBox.BorderStyle = "FixedSingle"
    $outputBox.ScrollBars  = "Vertical"
    $form.Controls.Add($outputBox)

    # --- Separatore ---
    $sep           = New-Object System.Windows.Forms.Panel
    $sep.Size      = New-Object System.Drawing.Size(780, 1)
    $sep.Location  = New-Object System.Drawing.Point(20, 510)
    $sep.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 90)
    $form.Controls.Add($sep)

    # --- Label domanda ---
    $lbl           = New-Object System.Windows.Forms.Label
    $lbl.Text      = "💬 La tua domanda:"
    $lbl.Location  = New-Object System.Drawing.Point(20, 525)
    $lbl.Size      = New-Object System.Drawing.Size(200, 25)
    $lbl.ForeColor = [System.Drawing.Color]::LightGray
    $lbl.Font      = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lbl)

    # --- Input textbox ---
    $inputBox               = New-Object System.Windows.Forms.TextBox
    $inputBox.Multiline     = $true
    $inputBox.Size          = New-Object System.Drawing.Size(650, 80)
    $inputBox.Location      = New-Object System.Drawing.Point(20, 555)
    $inputBox.BackColor     = [System.Drawing.Color]::FromArgb(45, 45, 50)
    $inputBox.ForeColor     = [System.Drawing.Color]::White
    $inputBox.Font          = New-Object System.Drawing.Font("Segoe UI", 10)
    $inputBox.BorderStyle   = "FixedSingle"
    $inputBox.AcceptsReturn = $true
    $inputBox.ScrollBars    = "Vertical"
    $form.Controls.Add($inputBox)

    # --- Pulsante Invia ---
    $btnSend                           = New-Object System.Windows.Forms.Button
    $btnSend.Text                      = "🚀 Invia"
    $btnSend.Size                      = New-Object System.Drawing.Size(100, 35)
    $btnSend.Location                  = New-Object System.Drawing.Point(690, 555)
    $btnSend.BackColor                 = [System.Drawing.Color]::FromArgb(0, 140, 210)
    $btnSend.ForeColor                 = [System.Drawing.Color]::White
    $btnSend.Font                      = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnSend.FlatStyle                 = "Flat"
    $btnSend.FlatAppearance.BorderSize = 0
    $btnSend.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(0, 160, 230)
    $form.Controls.Add($btnSend)

    # --- Pulsante Annulla ---
    $btnCancel                           = New-Object System.Windows.Forms.Button
    $btnCancel.Text                      = "⛔ Annulla"
    $btnCancel.Size                      = New-Object System.Drawing.Size(100, 35)
    $btnCancel.Location                  = New-Object System.Drawing.Point(690, 600)
    $btnCancel.BackColor                 = [System.Drawing.Color]::FromArgb(200, 50, 50)
    $btnCancel.ForeColor                 = [System.Drawing.Color]::White
    $btnCancel.Font                      = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnCancel.FlatStyle                 = "Flat"
    $btnCancel.FlatAppearance.BorderSize = 0
    $btnCancel.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(220, 70, 70)
    $btnCancel.Enabled                   = $false
    $form.Controls.Add($btnCancel)

    # --- Pulsante Cancella Chat ---
    $btnClear                           = New-Object System.Windows.Forms.Button
    $btnClear.Text                      = "🗑️ Cancella"
    $btnClear.Size                      = New-Object System.Drawing.Size(100, 35)
    $btnClear.Location                  = New-Object System.Drawing.Point(690, 645)
    $btnClear.BackColor                 = [System.Drawing.Color]::FromArgb(70, 70, 80)
    $btnClear.ForeColor                 = [System.Drawing.Color]::White
    $btnClear.Font                      = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnClear.FlatStyle                 = "Flat"
    $btnClear.FlatAppearance.BorderSize = 0
    $btnClear.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(90, 90, 100)
    $form.Controls.Add($btnClear)

    # --- Barra stato ---
    $statusLabel           = New-Object System.Windows.Forms.Label
    $statusLabel.Text      = "✅ Pronto"
    $statusLabel.Location  = New-Object System.Drawing.Point(20, 645)
    $statusLabel.Size      = New-Object System.Drawing.Size(600, 25)
    $statusLabel.ForeColor = [System.Drawing.Color]::LightGray
    $statusLabel.Font      = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    $form.Controls.Add($statusLabel)

    # --- ProgressBar ---
    $progressBar          = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Size     = New-Object System.Drawing.Size(650, 15)
    $progressBar.Location = New-Object System.Drawing.Point(20, 675)
    $progressBar.Style    = "Marquee"
    $progressBar.Visible  = $false
    $progressBar.ForeColor = [System.Drawing.Color]::FromArgb(0, 140, 210)
    $form.Controls.Add($progressBar)

    # ============================
    # TIMER
    # ============================
    $script:Timer          = New-Object System.Windows.Forms.Timer
    $script:Timer.Interval = 300
    $script:Timer.Add_Tick({
        if ($null -eq $script:Timer) { return }
        if ($null -eq $script:CurrentJob) {
            if ($null -ne $script:Timer) { $script:Timer.Stop() }
            return
        }
        $job = $script:CurrentJob

        if ($script:CancellationToken) {
            try {
                if ($job.State -eq 'Running') { Stop-Job -Job $job -Force -ErrorAction SilentlyContinue }
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            } catch {}
            $script:CurrentJob = $null
            if ($null -ne $script:Timer) { $script:Timer.Stop() }
            Set-BusyState $false
            Add-ChatMessage -Sender "Assistant" -Text "⛔ Richiesta annullata."
            return
        }

        if ($job.State -eq 'Completed') {
            try {
                $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            } catch { $result = "❌ Errore nel ricevere il risultato del job." }
            $script:CurrentJob = $null
            if ($null -ne $script:Timer) { $script:Timer.Stop() }
            Set-BusyState $false
            Add-ChatMessage -Sender "Assistant" -Text $result
            return
        }

        if ($job.State -eq 'Failed' -or $job.State -eq 'Stopped') {
            $errorMsg = if ($job.JobStateInfo.Reason) { $job.JobStateInfo.Reason.Message } else { "Job interrotto" }
            try { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue } catch {}
            $script:CurrentJob = $null
            if ($null -ne $script:Timer) { $script:Timer.Stop() }
            Set-BusyState $false
            Add-ChatMessage -Sender "Assistant" -Text "❌ Errore: $errorMsg"
            return
        }

        $statusLabel.Text = "⏳ In attesa di risposta... (Timeout 45s)"
    })

    # ============================
    # FUNZIONE AGGIUNTA MESSAGGIO (CON FONT DIMENSIONI DIFFERENZIATE)
    # ============================
    function Add-ChatMessage {
        param(
            [string]$Sender,
            [string]$Text
        )

        $timestamp = Get-Date -Format "HH:mm"
        $prefix    = if ($Sender -eq "User") { "🧑‍💻 Tu" } else { "🤖 Assistente" }

        # --- Timestamp (grigio, piccolo, corsivo) ---
        $outputBox.SelectionStart = $outputBox.TextLength
        $outputBox.SelectionLength = 0
        $outputBox.SelectionColor = [System.Drawing.Color]::Gray
        $outputBox.SelectionFont = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
        $outputBox.AppendText("[$timestamp] ")

        if ($Sender -eq "User") {
            # UTENTE: prefisso e testo in CIANO, GRASSETTO+CORSIVO, DIMENSIONE 12
            $font = New-Object System.Drawing.Font("Segoe UI", 12, ([System.Drawing.FontStyle]::Bold -bor [System.Drawing.FontStyle]::Italic))
            $color = [System.Drawing.Color]::Cyan
        } else {
            # ASSISTENTE: prefisso in VERDE CHIARO GRASSETTO (10), TESTO in BIANCO NORMALE (10)
            $fontPrefix = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
            $colorPrefix = [System.Drawing.Color]::LightGreen
            $fontText = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
            $colorText = [System.Drawing.Color]::White
        }

        # Prefisso
        $outputBox.SelectionStart = $outputBox.TextLength
        $outputBox.SelectionLength = 0
        if ($Sender -eq "User") {
            $outputBox.SelectionColor = $color
            $outputBox.SelectionFont = $font
        } else {
            $outputBox.SelectionColor = $colorPrefix
            $outputBox.SelectionFont = $fontPrefix
        }
        $outputBox.AppendText("$prefix`n")

        # Contenuto
        $outputBox.SelectionStart = $outputBox.TextLength
        $outputBox.SelectionLength = 0
        if ($Sender -eq "User") {
            $outputBox.SelectionColor = $color
            $outputBox.SelectionFont = $font
        } else {
            $outputBox.SelectionColor = $colorText
            $outputBox.SelectionFont = $fontText
        }
        $outputBox.AppendText("$Text`n`n")

        $outputBox.ScrollToCaret()
    }

    # ============================
    # FUNZIONE SET-BUSYSTATE
    # ============================
    function Set-BusyState {
        param([bool]$Busy)
        $script:IsBusy       = $Busy
        $btnSend.Enabled     = -not $Busy
        $btnCancel.Enabled   = $Busy
        $btnClear.Enabled    = -not $Busy
        $inputBox.Enabled    = -not $Busy
        $progressBar.Visible = $Busy
        if ($Busy) {
            $progressBar.Style = "Marquee"
            $statusLabel.Text  = "⏳ Elaborazione in corso..."
        } else {
            $progressBar.Visible = $false
            $statusLabel.Text    = "✅ Pronto"
        }
    }

    # ============================
    # GESTIONE EVENTI
    # ============================
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

        $jobScript = {
            param($Q, $SysPrompt)
            $messages = @(
                @{ role = "system"; content = $SysPrompt }
                @{ role = "user";   content = $Q }
            )
            $body = @{
                model    = "default"
                messages = $messages
                stream   = $false
            } | ConvertTo-Json -Depth 5
            $headers = @{
                "Content-Type"  = "application/json"
                "Authorization" = "Bearer unused"
            }
            try {
                $response = Invoke-RestMethod -Uri "https://api.llm7.io/v1/chat/completions" `
                    -Method Post -Headers $headers -Body $body -TimeoutSec 45 -ErrorAction Stop
                return $response.choices[0].message.content
            }
            catch {
                return "❌ ERRORE: $($_.Exception.Message)"
            }
        }

        $script:CurrentJob = Start-Job -ScriptBlock $jobScript -ArgumentList $question, $script:SystemPrompt
        if ($null -ne $script:Timer) { $script:Timer.Start() }
    })

    $btnCancel.Add_Click({
        $script:CancellationToken = $true
        $statusLabel.Text = "⏳ Annullamento in corso..."
    })

    $btnClear.Add_Click({
        if ($script:IsBusy) {
            [System.Windows.Forms.MessageBox]::Show("Attendi il completamento della richiesta.", "Operazione in corso")
            return
        }
        $outputBox.Clear()
        Add-ChatMessage -Sender "Assistant" -Text "👋 Chat cancellata. Sono qui per rispondere a tutte le tue domande su Manutenzione PRO MAX!"
    })

    $inputBox.Add_KeyDown({
        if ($_.KeyCode -eq 'Return' -and -not $_.Shift) {
            $_.SuppressKeyPress = $true
            $btnSend.PerformClick()
        }
    })

    # ============================
    # MESSAGGIO DI BENVENUTO E AVVIO
    # ============================
    Add-ChatMessage -Sender "Assistant" -Text "👋 Benvenuto! Sono l'assistente specializzato su Manutenzione PRO MAX. Chiedimi qualsiasi cosa sul software, i moduli, le funzionalità o l'installazione."
    [void]$form.ShowDialog()
}
