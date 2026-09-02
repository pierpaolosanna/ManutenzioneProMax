# ============================================================
# BACKUP.psm1 - Backup files, avanzato e driver di sistema
# Versione: 1.1.0
# ============================================================

function Do-BackupFiles {
    if ($script:isClosing -or (Test-Cancel)) { return }
    $folderDialog1 = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog1.Description = "Seleziona la cartella da BACKUP (origine)"
    $folderDialog1.ShowNewFolderButton = $false
    $folderDialog1.RootFolder = "MyComputer"
    if ($folderDialog1.ShowDialog() -ne "OK") { Log "[i] Backup annullato."; Update-Progress 100; return }
    $sourcePath = $folderDialog1.SelectedPath
    $folderDialog2 = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog2.Description = "Seleziona la cartella dove SALVARE il backup (destinazione)"
    $folderDialog2.ShowNewFolderButton = $true
    $folderDialog2.RootFolder = "MyComputer"
    if ($folderDialog2.ShowDialog() -ne "OK") { Log "[i] Backup annullato."; Update-Progress 100; return }
    $destPath = $folderDialog2.SelectedPath
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $folderName = Split-Path $sourcePath -Leaf
    $zipName = "Backup_${folderName}_${timestamp}.zip"
    $zipPath = Join-Path $destPath $zipName
    Log ""; Log "==============================================================================================="; Log "[>] BACKUP COMPRESSO FILES"; Log "==============================================================================================="
    Log "[i] Origine    : $sourcePath"
    Log "[i] Destinazione: $zipPath"
    Log "[i] Esclusi    : cartelle e file che iniziano con 'backup'"
    Log ""
    if (-not (Test-Path $sourcePath)) { Log "[X] Cartella origine non trovata!"; Update-Status "[X] Origine non trovata" $global:exitColor; Update-Progress 100; return }
    Update-Status "[...] Calcolo dimensione..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    try {
        $items = Get-ChildItem -Path $sourcePath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "backup*" }
        $totalSize = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $totalCount = $items.Count
        Log "[OK] Elementi da comprimere: $totalCount, Dimensione: $([Math]::Round($totalSize/1MB, 2)) MB"
    } catch {
        Log "[X] Errore calcolo dimensione: $($_.Exception.Message)"
        Update-Progress 100; return
    }
    $response = [System.Windows.Forms.MessageBox]::Show("Avviare backup di $totalCount elementi ($([Math]::Round($totalSize/1MB, 2)) MB)?`n(escluse cartelle 'backup*')", "Conferma Backup", "YesNo", "Question")
    if ($response -ne "Yes") { Log "[i] Backup annullato."; Update-Progress 100; return }
    Update-Status "[...] Compressione in corso..." $global:warningColor
    Flush-LogBuffer; Pump-UI
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $compressParams = @{
            Path = $sourcePath
            DestinationPath = $zipPath
            CompressionLevel = "Optimal"
            Force = $true
            Exclude = "backup*"
        }
        Compress-Archive @compressParams -ErrorAction Stop
        $sw.Stop(); $elapsed = $sw.Elapsed
        if (Test-Path $zipPath) {
            $zipSize = (Get-Item $zipPath).Length
            $ratio = [Math]::Round((1 - ($zipSize / $totalSize)) * 100, 1)
            Log ""; Log "[OK] BACKUP COMPLETATO!"
            Log "     File: $zipPath"
            Log "     Dimensione: $([Math]::Round($zipSize/1MB, 2)) MB"
            Log "     Compressione: $ratio%"
            Log "     Tempo: $($elapsed.ToString('hh\:mm\:ss'))"
            Update-Status "[OK] Backup completato ($([Math]::Round($zipSize/1MB, 1)) MB)" $global:successColor
            $openFolder = [System.Windows.Forms.MessageBox]::Show("Backup completato!`nAprire la cartella di destinazione?", "Backup Completato", "YesNo", "Information")
            if ($openFolder -eq "Yes") { Start-Process $destPath }
        } else {
            Log "[X] File backup non trovato dopo la compressione!"
            Update-Status "[X] Errore backup" $global:exitColor
        }
    } catch {
        Log "[X] Errore compressione: $($_.Exception.Message)"
        Update-Status "[X] Errore backup" $global:exitColor
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}

function Do-BackupAdvanced {
    if ($script:isClosing -or (Test-Cancel)) { return }
    $7zPath = Join-Path $global:scriptRoot "lib" "7za.exe"
    $7zFound = Test-Path $7zPath
    if (-not $7zFound) {
        Log "[!] 7za.exe non trovato in $global:scriptRoot"
        Update-Status "[!] 7-Zip non trovato" $global:warningColor
        Flush-LogBuffer; Pump-UI
        if ($global:isAdmin -and (Test-WingetAvailable)) {
            Log "[>] Tentativo installazione 7-Zip tramite winget..."
            Update-Status "[...] Installazione 7-Zip..." $global:infoColor
            Flush-LogBuffer; Pump-UI
            try {
                $wingetArgs = "install 7zip.7zip --silent --accept-package-agreements --accept-source-agreements"
                Start-Process "winget" -ArgumentList $wingetArgs -Wait -NoNewWindow -ErrorAction Stop
                Log "[OK] 7-Zip installato con winget."
                $7zFound = $false
                $possiblePaths = @("C:\Program Files\7-Zip\7z.exe", "C:\Program Files (x86)\7-Zip\7z.exe")
                foreach ($p in $possiblePaths) {
                    if (Test-Path $p) { $7zPath = $p; $7zFound = $true; Log "[OK] Trovato 7-Zip in: $p"; break }
                }
                if (-not $7zFound) {
                    try { $cmd = Get-Command "7z" -ErrorAction Stop; $7zPath = $cmd.Source; $7zFound = $true; Log "[OK] Trovato 7-Zip nel PATH: $7zPath" } catch { }
                }
            } catch {
                Log "[X] Installazione fallita: $($_.Exception.Message)"
                Update-Status "[X] Installazione fallita" $global:exitColor
                Flush-LogBuffer; Pump-UI
            }
        } else {
            if (-not $global:isAdmin) {
                Log "[!] Per installare 7-Zip servono privilegi amministrativi."
                Log "[i] Premi 'Eleva Admin' e riprova, oppure usa il backup standard."
            } else {
                Log "[!] Winget non disponibile. Impossibile installare 7-Zip."
            }
        }
    }
    if (-not $7zFound) {
        $response = [System.Windows.Forms.MessageBox]::Show("7-Zip non disponibile.`n`nVuoi procedere con il backup standard (Compress-Archive)?", "7-Zip non trovato", "YesNo", "Question")
        if ($response -eq "Yes") { Log "[i] Esecuzione backup standard..."; Do-BackupFiles } else { Log "[i] Backup annullato dall'utente." }
        Update-Progress 100; Update-Status "[i] Backup annullato" $global:fgDim; Flush-LogBuffer; Pump-UI; return
    }
    $folderDialog1 = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog1.Description = "Seleziona la cartella da BACKUP (origine)"
    $folderDialog1.ShowNewFolderButton = $false
    $folderDialog1.RootFolder = "MyComputer"
    if ($folderDialog1.ShowDialog() -ne "OK") { Log "[i] Backup annullato."; Update-Progress 100; return }
    $sourcePath = $folderDialog1.SelectedPath
    $folderDialog2 = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog2.Description = "Seleziona la cartella dove SALVARE il backup (destinazione)"
    $folderDialog2.ShowNewFolderButton = $true
    $folderDialog2.RootFolder = "MyComputer"
    if ($folderDialog2.ShowDialog() -ne "OK") { Log "[i] Backup annullato."; Update-Progress 100; return }
    $destPath = $folderDialog2.SelectedPath
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $folderName = Split-Path $sourcePath -Leaf
    $zipName = "Backup_Advanced_${folderName}_${timestamp}.zip"
    $zipPath = Join-Path $destPath $zipName
    Log ""; Log "==============================================================================================="; Log "[>] BACKUP AVANZATO (7-ZIP)"; Log "==============================================================================================="
    Log "[i] Origine    : $sourcePath"
    Log "[i] Destinazione: $zipPath"
    Log "[i] Compressione: massima (mx=9)"
    Log "[i] Esclusi    : cartelle e file che iniziano con 'backup'"
    Log ""
    if (-not (Test-Path $sourcePath)) { Log "[X] Cartella origine non trovata!"; Update-Status "[X] Origine non trovata" $global:exitColor; Update-Progress 100; return }
    Update-Status "[...] Calcolo dimensione..." $global:infoColor
    Flush-LogBuffer; Pump-UI
    try {
        $items = Get-ChildItem -Path $sourcePath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "backup*" }
        $totalSize = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        $totalCount = $items.Count
        Log "[OK] Elementi da comprimere: $totalCount, Dimensione: $([Math]::Round($totalSize/1MB, 2)) MB"
    } catch {
        Log "[X] Errore calcolo dimensione: $($_.Exception.Message)"
        Update-Progress 100; return
    }
    $response = [System.Windows.Forms.MessageBox]::Show("Avviare backup avanzato di $totalCount elementi ($([Math]::Round($totalSize/1MB, 2)) MB)?`n(escluse cartelle 'backup*')`n`nLa compressione massima richiede più tempo ma riduce notevolmente le dimensioni.", "Conferma Backup Avanzato", "YesNo", "Question")
    if ($response -ne "Yes") { Log "[i] Backup annullato."; Update-Progress 100; return }
    Update-Status "[...] Compressione 7-Zip in corso..." $global:warningColor
    Flush-LogBuffer; Pump-UI
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $args7z = @("a", "-tzip", "-mx=9", "-mmt=on", "-r", "-xr!backup*", "`"$zipPath`"", "`"$sourcePath\*`"") -join " "
        Log "[CMD] $7zPath $args7z"; Log ""
        $exitCode = Run-ProcessRealtime $7zPath $args7z "Compressione 7-Zip" 10 90
        $sw.Stop(); $elapsed = $sw.Elapsed
        if (Test-Path $zipPath) {
            $zipSize = (Get-Item $zipPath).Length
            $ratio = [Math]::Round((1 - ($zipSize / $totalSize)) * 100, 1)
            Log ""; Log "[OK] BACKUP AVANZATO COMPLETATO!"
            Log "     File: $zipPath"
            Log "     Dimensione: $([Math]::Round($zipSize/1MB, 2)) MB"
            Log "     Compressione: $ratio%"
            Log "     Tempo: $($elapsed.ToString('hh\:mm\:ss'))"
            Update-Status "[OK] Backup avanzato ($([Math]::Round($zipSize/1MB, 1)) MB)" $global:successColor
            $openFolder = [System.Windows.Forms.MessageBox]::Show("Backup avanzato completato!`nAprire la cartella di destinazione?", "Backup Completato", "YesNo", "Information")
            if ($openFolder -eq "Yes") { Start-Process $destPath }
        } else {
            Log "[X] File backup non trovato dopo la compressione!"
            Update-Status "[X] Errore backup" $global:exitColor
        }
    } catch {
        Log "[X] Errore compressione: $($_.Exception.Message)"
        Update-Status "[X] Errore backup" $global:exitColor
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}

function Do-BackupSystem {
    <#
    .SYNOPSIS
    Esegue il backup di tutti i driver installati tramite DISM.
    .DESCRIPTION
    Esporta i driver in una cartella scelta dall'utente, con una struttura simile a quella dei backup normali.
    #>
    if ($script:isClosing -or (Test-Cancel)) { return }
    if (-not $global:isAdmin) {
        Log "[X] Richiesti privilegi amministrativi per esportare i driver."
        Update-Status "[!] Admin richiesto" $global:warningColor
        Flush-LogBuffer; Update-Progress 100; Pump-UI; return
    }

    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Seleziona la cartella dove SALVARE il backup dei driver"
    $folderDialog.ShowNewFolderButton = $true
    $folderDialog.RootFolder = "MyComputer"
    if ($folderDialog.ShowDialog() -ne "OK") { Log "[i] Backup driver annullato."; Update-Progress 100; return }
    $destPath = $folderDialog.SelectedPath
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $driverFolder = Join-Path $destPath "Backup_Drivers_${timestamp}"
    New-Item -ItemType Directory -Force -Path $driverFolder | Out-Null

    Log ""; Log "==============================================================================================="; Log "[>] BACKUP DRIVER DI SISTEMA (DISM)"; Log "==============================================================================================="
    Log "[i] Destinazione: $driverFolder"
    Log ""

    # Verifica spazio disponibile (messaggio informativo)
    $drive = Split-Path $destPath -Qualifier
    $freeSpace = (Get-PSDrive -Name $drive.Substring(0,1)).Free
    Log "[i] Spazio disponibile su $drive : $([Math]::Round($freeSpace/1GB, 2)) GB"
    Log "[i] I driver possono occupare diversi GB. Assicurati di avere spazio sufficiente."
    Log ""

    $response = [System.Windows.Forms.MessageBox]::Show("Avviare il backup di TUTTI i driver installati?`n`nLa cartella selezionata è:`n$driverFolder", "Conferma Backup Driver", "YesNo", "Question")
    if ($response -ne "Yes") { Log "[i] Backup driver annullato."; Update-Progress 100; return }

    Update-Status "[...] Esportazione driver in corso..." $global:warningColor
    Flush-LogBuffer; Pump-UI

    try {
        $dismArgs = "/online /export-driver /destination:`"$driverFolder`""
        Log "[CMD] dism $dismArgs"
        $exitCode = Run-ProcessRealtime "dism.exe" $dismArgs "Esportazione driver" 10 90
        
        if (Test-Path $driverFolder) {
            $driverCount = (Get-ChildItem -Path $driverFolder -Recurse -File -ErrorAction SilentlyContinue).Count
            Log ""; Log "[OK] BACKUP DRIVER COMPLETATO!"
            Log "     Cartella: $driverFolder"
            Log "     File esportati: $driverCount"
            Log "     Nota: I driver sono in formato .inf, .sys e altri file di supporto."
            Update-Status "[OK] Backup driver completato ($driverCount file)" $global:successColor
            $openFolder = [System.Windows.Forms.MessageBox]::Show("Backup driver completato!`nAprire la cartella?", "Backup Completato", "YesNo", "Information")
            if ($openFolder -eq "Yes") { Start-Process $driverFolder }
        } else {
            Log "[X] Cartella driver non trovata dopo l'esportazione!"
            Update-Status "[X] Errore backup driver" $global:exitColor
        }
    } catch {
        Log "[X] Errore esportazione driver: $($_.Exception.Message)"
        Update-Status "[X] Errore backup driver" $global:exitColor
    }
    Log "==============================================================================================="; Log ""
    Update-Progress 100
    Flush-LogBuffer; Pump-UI
}

Export-ModuleMember -Function @(
    'Do-BackupFiles',
    'Do-BackupAdvanced',
    'Do-BackupSystem'
)
