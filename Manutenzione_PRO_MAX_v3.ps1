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
# AUTO-INSTALLA CERTIFICATO
# ============================
$script:certThumbprint = "1D51CF0E33DB5E1F124FE14CC1049DBF4294F03F"
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

$bgColor=[System.Drawing.Color]::FromArgb(20,20,24);$bgPanel=[System.Drawing.Color]::FromArgb(28,28,34);$bgCard=[System.Drawing.Color]::FromArgb(36,36,42)
$fgColor=[System.Drawing.Color]::FromArgb(230,230,235);$fgDim=[System.Drawing.Color]::FromArgb(120,120,130)
$sectionColor=[System.Drawing.Color]::FromArgb(50,220,110)
$accentColor=[System.Drawing.Color]::FromArgb(56,132,244);$warningColor=[System.Drawing.Color]::FromArgb(240,180,40);$successColor=[System.Drawing.Color]::FromArgb(60,210,120)
$exitColor=[System.Drawing.Color]::FromArgb(220,60,60);$restartColor=[System.Drawing.Color]::FromArgb(230,120,30);$infoColor=[System.Drawing.Color]::FromArgb(40,170,220)
$repairColor=[System.Drawing.Color]::FromArgb(160,80,220);$networkColor=[System.Drawing.Color]::FromArgb(40,200,200);$runAllColor=[System.Drawing.Color]::FromArgb(40,200,100)
$elevateColor=[System.Drawing.Color]::FromArgb(240,200,40);$securityColor=[System.Drawing.Color]::FromArgb(220,70,70);$maintColor=[System.Drawing.Color]::FromArgb(200,140,30)
$cpuColor=[System.Drawing.Color]::FromArgb(140,100,240);$remoteColor=[System.Drawing.Color]::FromArgb(255,100,50)
$logBg=[System.Drawing.Color]::FromArgb(14,14,18);$btnHover=[System.Drawing.Color]::FromArgb(48,48,56)
$runAllBg=[System.Drawing.Color]::FromArgb(25,60,40);$separatorColor=[System.Drawing.Color]::FromArgb(50,50,58)

$script:logBox=$null;$script:progressBar=$null;$script:progressLabel=$null;$script:statusLabel=$null;$script:form=$null
$script:isClosing=$false;$script:cancelRequested=$false;$script:pendingUpdates=$null
$script:logBuffer=[System.Text.StringBuilder]::new();$script:lastFlush=[DateTime]::Now;$script:uiTimer=$null
$tempDir=[System.IO.Path]::GetTempPath();$logFile=Join-Path $tempDir "Manutenzione_PRO_MAX_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$isPwsh7=($PSVersionTable.PSVersion.Major -ge 7)
$script:pingProperty = if ($isPwsh7) { "Latency" } else { "ResponseTime" }

function Restart-AsAdmin { if ($isAdmin) { Log "[i] Gia amministratore!"; return }; try { $scriptPath = $PSCommandPath; if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }; if (-not $scriptPath) { $scriptPath = $MyInvocation.ScriptName }; if ($scriptPath -and (Test-Path $scriptPath)) { $exe = "$env:ProgramFiles\PowerShell\7\pwsh.exe"; if (-not (Test-Path $exe)) { $exe = if ($isPwsh7) { "pwsh.exe" } else { "powershell.exe" } }; Start-Process $exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs; $script:isClosing = $true; $script:form.Close() } else { [System.Windows.Forms.MessageBox]::Show("Salva lo script come .ps1 e rieseguilo.", "Info", "OK", "Information") | Out-Null } } catch { if ($_.Exception.Message -notmatch "canceled|annullat|cancelled") { Log "[X] $($_.Exception.Message)" } } }
function Is-SpinnerLine($line) { if (-not $line) { return $false }; $s = "$line".Trim(); if (-not $s) { return $false }; return ($s -match '^(?:[-\\|/])$' -or $s -match '^(?:[-\\|/]\s*)+$') }
function Get-PercentFromLine($line) { if (-not $line) { return $null }; $m = [regex]::Match("$line", '(?<!\d)(100|[1-9]?\d)%'); if ($m.Success) { return [int]$m.Groups[1].Value }; return $null }
function Set-StepProgress($stepPercent,$stepStart,$stepEnd) { $p=[Math]::Max(0,[Math]::Min($stepPercent,100));$start=[Math]::Max(0,[Math]::Min($stepStart,100));$end=[Math]::Max(0,[Math]::Min($stepEnd,100));$overall=[Math]::Round($start+(($end-$start)*($p/100.0)));Update-Progress $overall;if($script:progressLabel){$script:progressLabel.Text="$p%"} }
function Format-LogLine($line) { if(-not $line){return $null};if(Is-SpinnerLine $line){return $null};$s="$line".TrimEnd();if(-not $s){return $null};if($s -match "ERRORE|ERROR|failed|fallito|denied|Impossibile|non riesce|Accesso negato"){return " [X] $s"}elseif($s -match "WARNING|AVVISO|warning"){return " [!] $s"}elseif($s -match "success|completato|done|OK|trovato|installato|aggiornato|completata"){return " [OK] $s"}elseif($s -match "Download|Downloading|Scaricamento|Scarico"){return " [DL] $s"}elseif($s -match "Install|Installing|Installazione|Aggiornamento|Updating"){return " [PKG] $s"}elseif($s -match "Found|Trovato|Rilevato"){return " [>>] $s"}elseif($s -match "(?<!\d)(100|[1-9]?\d)%"){return " [%] $s"}else{return " $s"} }
function Flush-LogBuffer { if($script:logBuffer.Length -gt 0 -and $script:logBox -and -not $script:isClosing){$text=$script:logBuffer.ToString();$script:logBuffer.Clear();$script:logBox.SuspendLayout();$script:logBox.AppendText($text);$script:logBox.SelectionStart=$script:logBox.Text.Length;$script:logBox.ScrollToCaret();$script:logBox.ResumeLayout();$script:lastFlush=[DateTime]::Now} }
function Log($msg) { if($script:isClosing){return};[void]$script:logBuffer.AppendLine($msg);if(([DateTime]::Now-$script:lastFlush).TotalMilliseconds -gt 80 -or $script:logBuffer.Length -gt 2000){Flush-LogBuffer};try{"$msg"|Out-File -FilePath $logFile -Append -Encoding UTF8 -ErrorAction SilentlyContinue}catch{} }
function Log-Output($output,[int]$stepStart=-1,[int]$stepEnd=-1) { if(-not $output -or $script:isClosing){return};foreach($line in $output){if(Is-SpinnerLine $line){continue};$linePercent=Get-PercentFromLine $line;if($null -ne $linePercent -and $stepStart -ge 0 -and $stepEnd -ge 0){Set-StepProgress $linePercent $stepStart $stepEnd};$f=Format-LogLine $line;if($f){Log $f}} }
function Update-Progress($value) { if($script:progressBar -and -not $script:isClosing){$v=[Math]::Max(0,[Math]::Min($value,100));$script:progressBar.Value=$v;if($script:progressLabel){$script:progressLabel.Text="$v%"}} }
function Update-Status($msg,$color) { if($script:statusLabel -and -not $script:isClosing){$script:statusLabel.Text=$msg;if($color){$script:statusLabel.ForeColor=$color}} }
function Pump-UI { if(-not $script:isClosing){[System.Windows.Forms.Application]::DoEvents()} }
function Test-Cancel { Pump-UI;if($script:cancelRequested){Log "[STOP] Annullato.";$script:cancelRequested=$false;return $true};return $false }
function Test-WingetAvailable { try{$null=Get-Command winget -ErrorAction Stop;return $true}catch{Log "[X] Winget non trovato!";return $false} }

# === WINDOWS UPDATE ===
function Do-SearchWU { if($script:isClosing -or(Test-Cancel)){return};Log "";Log "===============================================================================================";Log "[>] RICERCA: Windows Update";Log "===============================================================================================";Update-Progress 50;Update-Status "[...] Ricerca WU..." $fgColor;Flush-LogBuffer;Pump-UI;if(-not $isAdmin){Log "[!] Servono privilegi admin.";Update-Status "[!] Privilegi insufficienti" $warningColor;Flush-LogBuffer;return};try{$session=New-Object -ComObject Microsoft.Update.Session;$searcher=$session.CreateUpdateSearcher();Pump-UI;$result=$searcher.Search("IsInstalled=0 and Type='Software'");Pump-UI;if($result.Updates.Count -gt 0){Log "[OK] Trovati $($result.Updates.Count):";for($i=0;$i -lt $result.Updates.Count;$i++){$u=$result.Updates.Item($i);$kb="";if($u.KBArticleIDs.Count -gt 0){$kb="KB$($u.KBArticleIDs.Item(0)) - "};Log " $($i+1). $kb$($u.Title)"};$script:pendingUpdates=$result}else{Log "[OK] Nessun aggiornamento.";$script:pendingUpdates=$null}}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Status "[OK] Ricerca completata" $successColor;Flush-LogBuffer;Pump-UI }
function Do-InstallWU { if($script:isClosing -or(Test-Cancel)){return};Log "";Log "===============================================================================================";Log "[>] INSTALLAZIONE: Windows Update";Log "===============================================================================================";Update-Progress 70;Update-Status "[...] Installazione WU..." $fgColor;Flush-LogBuffer;Pump-UI;if(-not $isAdmin){Log "[X] Servono privilegi admin.";Update-Status "[!] Privilegi insufficienti" $warningColor;Flush-LogBuffer;return};try{if(-not $script:pendingUpdates){$session=New-Object -ComObject Microsoft.Update.Session;$script:pendingUpdates=$session.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Software'");Pump-UI};$sr=$script:pendingUpdates;if($sr.Updates.Count -eq 0){Log "[OK] Nessun aggiornamento."}else{Set-StepProgress 10 70 85;$dlC=New-Object -ComObject Microsoft.Update.UpdateColl;for($i=0;$i -lt $sr.Updates.Count;$i++){$u=$sr.Updates.Item($i);if(-not $u.EulaAccepted){$u.AcceptEula()};if(-not $u.IsDownloaded){$dlC.Add($u)|Out-Null}};if($dlC.Count -gt 0){Log " [DL] Download...";Flush-LogBuffer;Pump-UI;$session=New-Object -ComObject Microsoft.Update.Session;$dl=$session.CreateUpdateDownloader();$dl.Updates=$dlC;$dl.Download()|Out-Null;Pump-UI;Set-StepProgress 50 70 85};$iC=New-Object -ComObject Microsoft.Update.UpdateColl;for($i=0;$i -lt $sr.Updates.Count;$i++){$u=$sr.Updates.Item($i);if($u.IsDownloaded){$iC.Add($u)|Out-Null}};if($iC.Count -gt 0){Log " [PKG] Installazione...";Flush-LogBuffer;Pump-UI;$session=New-Object -ComObject Microsoft.Update.Session;$inst=$session.CreateUpdateInstaller();$inst.Updates=$iC;Pump-UI;$ir=$inst.Install();Pump-UI;for($i=0;$i -lt $iC.Count;$i++){$rc=$ir.GetUpdateResult($i).ResultCode;$st=switch($rc){2{"[OK]"}3{"[OK*]"}4{"[X]"}5{"[!]"}default{"[?]"}};Log " $st $($iC.Item($i).Title)";Set-StepProgress([Math]::Round((($i+1)/$iC.Count)*100)) 70 85;Pump-UI};if($ir.RebootRequired){Log "";Log "[!] RIAVVIO NECESSARIO."}}};$script:pendingUpdates=$null}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Set-StepProgress 100 70 85;Update-Status "[OK] Installazione completata" $successColor;Flush-LogBuffer;Pump-UI }

# === RUN PROCESS ===
function Run-ProcessRealtime { param([string]$fileName,[string]$processArguments,[string]$description,[int]$stepStart=-1,[int]$stepEnd=-1);Log "";Log "===============================================================================================";Log "[>] $description";Log "===============================================================================================";$process=$null;try{Log "[CMD] $fileName $processArguments";Log "";$psi=New-Object System.Diagnostics.ProcessStartInfo;$psi.FileName=$fileName;$psi.Arguments=$processArguments;$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$psi.CreateNoWindow=$true;$psi.StandardOutputEncoding=[System.Text.Encoding]::UTF8;$psi.StandardErrorEncoding=[System.Text.Encoding]::UTF8;$process=New-Object System.Diagnostics.Process;$process.StartInfo=$psi;$process.EnableRaisingEvents=$true;$oQ=[System.Collections.Concurrent.ConcurrentQueue[string]]::new();$eQ=[System.Collections.Concurrent.ConcurrentQueue[string]]::new();$oH=Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {$l=$Event.SourceEventArgs.Data;if($null -ne $l){$Event.MessageData.Enqueue($l)}} -MessageData $oQ;$eH=Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {$l=$Event.SourceEventArgs.Data;if($null -ne $l -and $l.Trim()){$Event.MessageData.Enqueue($l)}} -MessageData $eQ;$process.Start()|Out-Null;$process.BeginOutputReadLine();$process.BeginErrorReadLine();while(-not $process.HasExited -or $oQ.Count -gt 0){if($script:cancelRequested){try{$process.Kill()}catch{};Log "[STOP] Terminato.";$script:cancelRequested=$false;break};$l=$null;$c=0;while($oQ.TryDequeue([ref]$l) -and $c -lt 30){$c++;if(-not $l -or(Is-SpinnerLine $l)){continue};$lp=Get-PercentFromLine $l;if($null -ne $lp -and $stepStart -ge 0 -and $stepEnd -ge 0){Set-StepProgress $lp $stepStart $stepEnd};$f=Format-LogLine $l;if($f){Log $f}};$el=$null;while($eQ.TryDequeue([ref]$el)){if($el -and $el.Trim() -and -not(Is-SpinnerLine $el)){Log " [X] $($el.Trim())"}};Flush-LogBuffer;Pump-UI;if(-not $process.HasExited){Start-Sleep -Milliseconds 50}};Start-Sleep -Milliseconds 200;$l=$null;while($oQ.TryDequeue([ref]$l)){if($l -and -not(Is-SpinnerLine $l)){$f=Format-LogLine $l;if($f){Log $f}}};$el=$null;while($eQ.TryDequeue([ref]$el)){if($el -and $el.Trim()){Log " [X] $($el.Trim())"}};Unregister-Event -SourceIdentifier $oH.Name -ErrorAction SilentlyContinue;Unregister-Event -SourceIdentifier $eH.Name -ErrorAction SilentlyContinue;Remove-Job $oH -Force -ErrorAction SilentlyContinue;Remove-Job $eH -Force -ErrorAction SilentlyContinue;$ec=$process.ExitCode;Log "";if($stepStart -ge 0 -and $stepEnd -ge 0 -and $ec -eq 0){Set-StepProgress 100 $stepStart $stepEnd};if($ec -eq 0){Log "[OK] Completato."}else{Log "[!] Codice: $ec"};Flush-LogBuffer;return $ec}catch{Log "[X] $($_.Exception.Message)";Flush-LogBuffer;return -1}finally{if($process){try{$process.Dispose()}catch{}}} }

# === TUTTE LE FUNZIONI ===
function Do-Winget { if($script:isClosing -or(Test-Cancel)){return};if(-not(Test-WingetAvailable)){return};Update-Progress 10;Update-Status "[...] Winget..." $fgColor;Flush-LogBuffer;Pump-UI;Run-ProcessRealtime "winget" "upgrade --all --force --accept-package-agreements --accept-source-agreements --include-unknown" "Winget Upgrade" 10 25;Set-StepProgress 100 10 25;Update-Status "[OK] Winget" $successColor;Flush-LogBuffer;Pump-UI }
function Do-StoreUpdate { if($script:isClosing -or(Test-Cancel)){return};if(-not(Test-WingetAvailable)){return};Update-Progress 30;Update-Status "[...] Store..." $fgColor;Flush-LogBuffer;Pump-UI;Run-ProcessRealtime "winget" "upgrade --source msstore --all --accept-package-agreements --accept-source-agreements --include-unknown" "Store Update" 30 40;try{Start-Process "ms-windows-store://downloadsandupdates" -WindowStyle Hidden -ErrorAction SilentlyContinue}catch{};Log " [OK] Store in background.";Set-StepProgress 100 30 40;Update-Status "[OK] Store" $successColor;Flush-LogBuffer;Pump-UI }
function Do-CleanTemp { if($script:isClosing -or(Test-Cancel)){return};Log "";Log "===============================================================================================";Log "[>] PULIZIA Temp";Log "===============================================================================================";Update-Progress 90;Update-Status "[...] Pulizia..." $fgColor;Flush-LogBuffer;Pump-UI;$paths=@(@{Path=$env:TEMP;Name="Temp"},@{Path="$env:LOCALAPPDATA\Temp";Name="Local"},@{Path="$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache";Name="INet"},@{Path="$env:USERPROFILE\AppData\Local\CrashDumps";Name="Crash"});if($isAdmin){$paths+=@{Path="$env:WINDIR\Temp";Name="WinTemp"}};$tot=[long]0;foreach($p in $paths){if(Test-Cancel){return};if(Test-Path $p.Path){try{$items=Get-ChildItem -Path $p.Path -Force -Recurse -ErrorAction SilentlyContinue;$sz=($items|Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum;if(-not $sz){$sz=0};$cnt=($items|Measure-Object).Count;if($cnt -gt 0){Remove-Item "$($p.Path)\*" -Recurse -Force -ErrorAction SilentlyContinue;$tot+=$sz};Log " [$($p.Name)] $cnt, $([Math]::Round($sz/1MB,1))MB"}catch{}};Pump-UI};$mb=[Math]::Round($tot/1MB,1);Log "";Log "[OK] Liberati: ${mb}MB";Log "===============================================================================================";Log "";Update-Status "[OK] Pulizia (${mb}MB)" $successColor;Flush-LogBuffer;Pump-UI }
function Do-DiskCleanup { if($script:isClosing -or(Test-Cancel)){return};if(-not $isAdmin){Log "[X] Admin.";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;return};Update-Status "[...] Cleanup..." $maintColor;Flush-LogBuffer;Pump-UI;try{$cp="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches";if(Test-Path $cp){Get-ChildItem $cp -ErrorAction SilentlyContinue|ForEach-Object{Set-ItemProperty -Path $_.PSPath -Name "StateFlags0100" -Value 2 -ErrorAction SilentlyContinue}};Run-ProcessRealtime "cleanmgr" "/sagerun:100" "Disk Cleanup" 80 95}catch{Log "[X] $($_.Exception.Message)"};Update-Status "[OK] Cleanup" $successColor;Flush-LogBuffer;Pump-UI }
function Do-FlushDNS { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] DNS..." $networkColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Flush DNS";Log "===============================================================================================";try{$o=& ipconfig /flushdns 2>&1;Log-Output $o;Log "[OK] DNS svuotata."}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Status "[OK] DNS" $successColor;Flush-LogBuffer;Pump-UI }
function Do-RenewIP { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] IP..." $networkColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Rinnovo IP";Log "===============================================================================================";try{& ipconfig /release 2>&1|Out-Null;Pump-UI;Start-Sleep 2;Pump-UI;$o=& ipconfig /renew 2>&1;Log-Output $o;Log "[OK] IP rinnovato."}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Status "[OK] IP" $successColor;Flush-LogBuffer;Pump-UI }
function Do-InfoIP { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Info..." $infoColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Info Rete";Log "===============================================================================================";try{$o=& ipconfig /all 2>&1;foreach($l in $o){Log " $l"}}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Status "[OK] Info" $successColor;Flush-LogBuffer;Pump-UI }
function Do-ResetWinsock { if($script:isClosing -or(Test-Cancel)){return};if(-not $isAdmin){Log "[X] Admin.";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;return};Update-Status "[...] Winsock..." $networkColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Winsock Reset";Log "===============================================================================================";try{& netsh winsock reset 2>&1|Out-Null;& netsh int ip reset 2>&1|Out-Null;Log "[OK] Reset. Riavvio consigliato."}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Status "[OK] Winsock" $successColor;Flush-LogBuffer;Pump-UI }
function Do-WifiPasswords { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Wi-Fi..." $networkColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Password Wi-Fi";Log "===============================================================================================";try{$profiles=& netsh wlan show profiles 2>&1;$pm=$profiles|Select-String "Tutti i profili utente\s*:\s*(.+)$|Profilo tutti gli utenti\s*:\s*(.+)$|All User Profile\s*:\s*(.+)$|User Profile\s*:\s*(.+)$|Profile\s*:\s*(.+)$";if(-not $pm){Log "[i] Nessun profilo.";Log "===============================================================================================";Update-Status "[OK]" $successColor;Flush-LogBuffer;Pump-UI;return};$names=foreach($m in $pm){$m.Matches[0].Groups|Where-Object{$_.Value -and $_.Value.Trim() -ne ""}|Select-Object -Skip 1 -First 1|ForEach-Object{$_.Value.Trim()}};Log "[OK] $($names.Count) reti:";Log "";foreach($n in $names){if(Test-Cancel){return};$d=& netsh wlan show profile name="$n" key=clear 2>&1;$kl=($d|Select-String "Contenuto chiave\s*:\s*(.+)$|Key Content\s*:\s*(.+)$");$pw="N/D";if($kl){$match=$kl.Matches[0];$p1=$match.Groups[1].Value.Trim();$p2=$match.Groups[2].Value.Trim();if($p1){$pw=$p1}elseif($p2){$pw=$p2}};Log " $n : $pw";Pump-UI}}catch{Log "[X] $($_.Exception.Message)"};Log "";Log "===============================================================================================";Update-Status "[OK] Wi-Fi" $successColor;Flush-LogBuffer;Pump-UI }
function Do-SpeedTest { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Ping..." $networkColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Ping Test";Log "===============================================================================================";$targets=@(@{N="Google";I="8.8.8.8"},@{N="Cloudflare";I="1.1.1.1"},@{N="OpenDNS";I="208.67.222.222"});foreach($t in $targets){if(Test-Cancel){return};try{$ping=Test-Connection -ComputerName $t.I -Count 3 -ErrorAction Stop;$prop=$script:pingProperty;$avg=[Math]::Round(($ping|Measure-Object -Property $prop -Average).Average,1);Log " $($t.N): ${avg}ms"}catch{Log " [X] $($t.N)"};Pump-UI};Log "===============================================================================================";Log "";Update-Status "[OK] Ping" $successColor;Flush-LogBuffer;Pump-UI }
function Do-SpeedInternet { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Speedtest..." $networkColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Speedtest Cloudflare";Log "===============================================================================================";[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;$latency=0;try{$sw=[System.Diagnostics.Stopwatch]::StartNew();Invoke-WebRequest -Uri "https://speed.cloudflare.com/__down?bytes=0" -Method Get -TimeoutSec 5 -UseBasicParsing|Out-Null;$sw.Stop();$latency=[Math]::Round($sw.Elapsed.TotalMilliseconds,1);Log " Ping: ${latency}ms"}catch{};Flush-LogBuffer;Pump-UI;if(Test-Cancel){return};$dl=0;try{$sw=[System.Diagnostics.Stopwatch]::StartNew();$data=Invoke-WebRequest -Uri "https://speed.cloudflare.com/__down?bytes=20000000" -Method Get -TimeoutSec 30 -UseBasicParsing;$sw.Stop();$bytes=$data.RawContentLength;if($bytes -and $sw.Elapsed.TotalSeconds -gt 0){$dl=[Math]::Round((($bytes*8)/1MB)/$sw.Elapsed.TotalSeconds,2)};Log " DL: ${dl} Mbps"}catch{};Flush-LogBuffer;Pump-UI;if(Test-Cancel){return};$ul=0;try{$buf=New-Object byte[](5MB);(New-Object Random).NextBytes($buf);$sw=[System.Diagnostics.Stopwatch]::StartNew();Invoke-WebRequest -Uri "https://speed.cloudflare.com/__up" -Method Post -Body $buf -TimeoutSec 30 -UseBasicParsing|Out-Null;$sw.Stop();if($sw.Elapsed.TotalSeconds -gt 0){$ul=[Math]::Round((5*8)/$sw.Elapsed.TotalSeconds,2)};Log " UP: ${ul} Mbps"}catch{};Log "";Log " Ping ${latency}ms | DL ${dl} | UP ${ul} Mbps";Log "===============================================================================================";Log "";Update-Status "[OK] DL $dl / UP $ul" $successColor;Flush-LogBuffer;Pump-UI }
function Do-RepairSystem { if($script:isClosing -or(Test-Cancel)){return};if(-not $isAdmin){Log "[X] Admin.";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;return};Update-Status "[...] SFC..." $repairColor;Flush-LogBuffer;Pump-UI;Run-ProcessRealtime "sfc" "/scannow" "SFC" 20 50;if(Test-Cancel){return};Update-Status "[...] DISM..." $repairColor;Flush-LogBuffer;Pump-UI;Run-ProcessRealtime "DISM" "/Online /Cleanup-Image /RestoreHealth" "DISM" 50 85;Update-Status "[OK] Riparazione" $successColor;Flush-LogBuffer;Pump-UI }
function Do-RestorePoint { if($script:isClosing -or(Test-Cancel)){return};if(-not $isAdmin){Log "[X] Admin.";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;return};Update-Status "[...] Ripristino..." $repairColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Punto Ripristino";Log "===============================================================================================";try{Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue;Pump-UI;Checkpoint-Computer -Description "PRO MAX $(Get-Date -Format 'dd/MM HH:mm')" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop;Log "[OK] Creato."}catch{if($_.Exception.Message -match "frequenza|frequency|1410"){Log "[!] Limite 24h."}else{Log "[X] $($_.Exception.Message)"}};Log "===============================================================================================";Log "";Update-Status "[OK] Ripristino" $successColor;Flush-LogBuffer;Pump-UI }
function Do-SecurityScan { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Defender..." $securityColor;Flush-LogBuffer;Pump-UI;$mp="$env:ProgramFiles\Windows Defender\MpCmdRun.exe";if(-not(Test-Path $mp)){$mp="${env:ProgramFiles(x86)}\Windows Defender\MpCmdRun.exe"};if(-not(Test-Path $mp)){$pl=Get-ChildItem "$env:ProgramData\Microsoft\Windows Defender\Platform" -Directory -ErrorAction SilentlyContinue|Sort-Object Name -Descending|Select-Object -First 1;if($pl){$mp=Join-Path $pl.FullName "MpCmdRun.exe"}};if(Test-Path $mp){Run-ProcessRealtime $mp "-Scan -ScanType 1" "Defender Scan" 30 80}else{Log "[X] Defender non trovato."};Update-Status "[OK] Scan" $successColor;Flush-LogBuffer;Pump-UI }
function Do-UnlockCPU { if($script:isClosing -or(Test-Cancel)){return};if(-not $isAdmin){Log "[X] Admin.";Update-Status "[!] Admin" $warningColor;Flush-LogBuffer;return};Update-Status "[...] CPU..." $cpuColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] CPU Unlock";Log "===============================================================================================";$cat="54533251-82be-4824-96c1-47b60b740d00";$ss=@("be337238-0d82-4146-a960-4f3749d470c7","5d76a2ca-e8c0-402f-a133-2158492d58ad","893dee8e-2bef-41e0-89c6-b55d0929964c","bc5038f7-23e0-4960-96da-33abaf5935ec","0cc5b647-c1df-4637-891a-dec35c318583","ea062031-0e34-4ff1-9b6d-eb1059334028","68dd2f27-a4ce-4e11-8487-3794e4135dfa","2ddd5a84-5a71-437e-912a-db0b8c788732","4b92d758-5a24-4851-a470-815d78aee119","d6ba4903-386f-4c2c-8adb-5c21b3328d25","45bcc044-d885-43e2-8605-ee0ec6e96b59","36687f9e-e3a5-4dbf-b1dc-15eb381c6863","cfeda3d0-7697-4566-a922-a9086cd49dfa","fddc842b-8364-4edc-94cf-c17f60de1c80");$ok=0;foreach($g in $ss){$p="HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$cat\$g";if(Test-Path $p){try{Set-ItemProperty -Path $p -Name "Attributes" -Value 2 -ErrorAction Stop;$ok++}catch{}};Pump-UI};Log "[OK] $ok/$($ss.Count) sbloccate.";Log "===============================================================================================";Log "";Update-Status "[OK] CPU ($ok)" $successColor;Flush-LogBuffer;Pump-UI }
function Do-RemoteAssist { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] RustDesk..." $remoteColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Assistenza Remota";Log "===============================================================================================";$url="https://github.com/rustdesk/rustdesk/releases/download/1.2.2/rustdesk-1.2.2-x86_64.exe";$tp="C:\Temp\RustDeskPortable";$ep=Join-Path $tp "rustdesk.exe";if(!(Test-Path $tp)){New-Item -ItemType Directory -Force -Path $tp|Out-Null};if(!(Test-Path $ep)){Log " [DL] Download...";Flush-LogBuffer;Pump-UI;try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;Invoke-WebRequest $url -OutFile $ep -UseBasicParsing -ErrorAction Stop}catch{Log " [X] $($_.Exception.Message)";Update-Status "[X]" $exitColor;Flush-LogBuffer;Pump-UI;return}};try{Start-Process $ep;Start-Sleep 4;Pump-UI;$id=& $ep --get-id 2>$null;$pw=& $ep --get-password 2>$null;if($id){Log " ID: $id"};if($pw){Log " PW: $pw"}}catch{Log " [X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Status "[OK] RustDesk" $successColor;Flush-LogBuffer;Pump-UI }
function Do-SystemInfo { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Sistema..." $infoColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Info Sistema";Log "===============================================================================================";try{$os=Get-CimInstance Win32_OperatingSystem;$cpu=Get-CimInstance Win32_Processor|Select-Object -First 1;$ram=Get-CimInstance Win32_PhysicalMemory;$gpu=Get-CimInstance Win32_VideoController|Select-Object -First 1;$disk=Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3";Pump-UI;Log " OS: $($os.Caption)";Log " CPU: $($cpu.Name)";Log " Cores: $($cpu.NumberOfCores)/$($cpu.NumberOfLogicalProcessors)";$tr=[Math]::Round(($ram|Measure-Object Capacity -Sum).Sum/1GB,1);Log " RAM: ${tr}GB";Log " GPU: $($gpu.Name)";Log "";foreach($d in $disk){$f=[Math]::Round($d.FreeSpace/1GB,1);$t=[Math]::Round($d.Size/1GB,1);Log " $($d.DeviceID) $([Math]::Round($t-$f,1))/${t}GB"}}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Status "[OK] Sistema" $successColor;Flush-LogBuffer;Pump-UI }
function Do-BatteryReport { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Batteria..." $infoColor;Flush-LogBuffer;Pump-UI;try{$rp=Join-Path $tempDir "battery-report.html";& powercfg /batteryreport /output "$rp" 2>&1|Out-Null;if(Test-Path $rp){Log "[OK] $rp";Start-Process $rp}else{Log "[!] Nessuna batteria."}}catch{Log "[X] $($_.Exception.Message)"};Update-Status "[OK] Batteria" $successColor;Flush-LogBuffer;Pump-UI }
function Do-Uptime { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Uptime..." $infoColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Uptime";Log "===============================================================================================";try{$os=Get-CimInstance Win32_OperatingSystem;$b=$os.LastBootUpTime;$u=(Get-Date)-$b;Log " Boot: $($b.ToString('dd/MM/yyyy HH:mm'))";Log " Up: $($u.Days)g $($u.Hours)h";if($u.Days -gt 7){Log " [!] Riavvio consigliato."}}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Status "[OK] Uptime" $successColor;Flush-LogBuffer;Pump-UI }
function Do-TopProcesses { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Processi..." $cpuColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Top CPU";Log "===============================================================================================";try{$procs=Get-Process|Where-Object{$_.CPU -gt 0}|Sort-Object CPU -Descending|Select-Object -First 12;foreach($p in $procs){Log(" {0,-28} {1,6}s {2,5}MB" -f $p.ProcessName,[Math]::Round($p.CPU,1),[Math]::Round($p.WorkingSet64/1MB,0))}}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Status "[OK] Processi" $successColor;Flush-LogBuffer;Pump-UI }
function Do-StartupPrograms { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Startup..." $cpuColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Startup";Log "===============================================================================================";try{$r=Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue;if($r){$r.PSObject.Properties|Where-Object{$_.Name -notmatch '^PS'}|ForEach-Object{Log " $($_.Name)"}};$ru=Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue;if($ru){$ru.PSObject.Properties|Where-Object{$_.Name -notmatch '^PS'}|ForEach-Object{Log " $($_.Name)"}}}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Status "[OK] Startup" $successColor;Flush-LogBuffer;Pump-UI }
function Do-DiskSpace { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Disco..." $maintColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Spazio disco";Log "===============================================================================================";try{$up=$env:USERPROFILE;$fl=@("$up\Downloads","$up\Desktop","$up\Documents","$up\AppData\Local","${env:SystemDrive}\Program Files");$res=@();foreach($f in $fl){if(Test-Cancel){return};if(Test-Path $f){try{$sz=(Get-ChildItem $f -Recurse -Force -ErrorAction SilentlyContinue|Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum;if(-not $sz){$sz=0};$res+=@{P=$f;S=$sz}}catch{}};Pump-UI};$res=$res|Sort-Object{$_.S} -Descending;foreach($r in $res){$d=if($r.S -ge 1GB){"$([Math]::Round($r.S/1GB,1))GB"}else{"$([Math]::Round($r.S/1MB,0))MB"};Log(" {0,-40} {1,7}" -f $r.P.Replace($up,"~"),$d)}}catch{Log "[X] $($_.Exception.Message)"};Log "===============================================================================================";Log "";Update-Status "[OK] Disco" $successColor;Flush-LogBuffer;Pump-UI }
function Do-EventLogErrors { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] EventLog..." $securityColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Errori (7gg)";Log "===============================================================================================";try{$ev=Get-WinEvent -FilterHashtable @{LogName='System';Level=1,2;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 10 -ErrorAction Stop;if($ev){foreach($e in $ev){$m=($e.Message -split "`n")[0];if($m.Length -gt 60){$m=$m.Substring(0,57)+"..."};Log " $($e.TimeCreated.ToString('dd/MM HH:mm')) $m";Pump-UI}}else{Log " [OK] Nessun errore."}}catch{if($_.Exception.Message -match "No events"){Log " [OK] Nessun errore."}else{Log "[X] $($_.Exception.Message)"}};Log "===============================================================================================";Log "";Update-Status "[OK] EventLog" $successColor;Flush-LogBuffer;Pump-UI }
function Do-ServiceStatus { if($script:isClosing -or(Test-Cancel)){return};Update-Status "[...] Servizi..." $infoColor;Flush-LogBuffer;Pump-UI;Log "";Log "===============================================================================================";Log "[>] Servizi";Log "===============================================================================================";$svcs=@(@{N="wuauserv";D="WinUpdate"},@{N="WinDefend";D="Defender"},@{N="mpssvc";D="Firewall"},@{N="BITS";D="BITS"},@{N="Dnscache";D="DNS"});foreach($svc in $svcs){try{$s=Get-Service -Name $svc.N -ErrorAction Stop;$st=if($s.Status -eq "Running"){"OK"}else{"--"};Log " [$st] $($svc.D)"}catch{Log " [??] $($svc.D)"};Pump-UI};Log "===============================================================================================";Log "";Update-Status "[OK] Servizi" $successColor;Flush-LogBuffer;Pump-UI }
function Do-ExportReport { if($script:isClosing -or(Test-Cancel)){return};try{$rf=Join-Path([Environment]::GetFolderPath("Desktop")) "Manutenzione_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt";if($script:logBox){$script:logBox.Text|Out-File -FilePath $rf -Encoding UTF8;Log "[OK] $rf";Start-Process explorer.exe -ArgumentList "/select,`"$rf`""}}catch{Log "[X] $($_.Exception.Message)"};Update-Status "[OK] Export" $successColor;Flush-LogBuffer;Pump-UI }

# === SHUTDOWN SCHEDULATO ===
function Do-ScheduleShutdown {
    if($script:isClosing){return}
    $taskName = "ShutdownGiornalieroForzato"
    Log "";Log "===============================================================================================";Log "[>] SHUTDOWN SCHEDULATO";Log "==============================================================================================="
    Update-Status "[...] Shutdown schedulato..." $warningColor;Flush-LogBuffer;Pump-UI
    if(-not $isAdmin){Log "[X] Servono privilegi admin.";Update-Status "[!] Admin richiesto" $warningColor;Flush-LogBuffer;return}

    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = "Imposta Ora Shutdown"
    $inputForm.Size = New-Object System.Drawing.Size(320,180)
    $inputForm.StartPosition = "CenterParent"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.BackColor = $bgColor
    $inputForm.ForeColor = $fgColor

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

    $result = $inputForm.ShowDialog()
    if($result -ne [System.Windows.Forms.DialogResult]::OK){Log "[i] Annullato.";Update-Status "Annullato" $fgDim;Flush-LogBuffer;return}

    $timeInput = $txtTime.Text.Trim()
    if($timeInput -notmatch '^\d{1,2}:\d{2}$'){
        Log "[X] Formato ora non valido. Usa HH:mm (es. 22:30)"
        Update-Status "[X] Formato non valido" $exitColor;Flush-LogBuffer;return
    }
    try{[datetime]::ParseExact($timeInput,"H:mm",[System.Globalization.CultureInfo]::InvariantCulture)|Out-Null}catch{
        Log "[X] Ora non valida: $timeInput";Update-Status "[X] Ora non valida" $exitColor;Flush-LogBuffer;return
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
    Flush-LogBuffer;Pump-UI
}

function Do-RemoveShutdown {
    if($script:isClosing){return}
    $taskName = "ShutdownGiornalieroForzato"
    Log "";Log "===============================================================================================";Log "[>] RIMOZIONE SHUTDOWN SCHEDULATO";Log "==============================================================================================="
    Update-Status "[...] Rimozione task..." $warningColor;Flush-LogBuffer;Pump-UI
    if(-not $isAdmin){Log "[X] Servono privilegi admin.";Update-Status "[!] Admin richiesto" $warningColor;Flush-LogBuffer;return}
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
    Flush-LogBuffer;Pump-UI
}

# === OTTIMIZZA EFFETTI VISIVI ===
function Do-OptimizeVisual {
    if($script:isClosing -or(Test-Cancel)){return}
    Log "";Log "===============================================================================================";Log "[>] OTTIMIZZAZIONE EFFETTI VISIVI";Log "==============================================================================================="
    Update-Status "[...] Ottimizzazione visiva..." $cpuColor;Flush-LogBuffer;Pump-UI

    try{
        # Imposta modalita Custom (3 = personalizzata)
        $vfxPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if(!(Test-Path $vfxPath)){New-Item -Path $vfxPath -Force|Out-Null}
        Set-ItemProperty -Path $vfxPath -Name "VisualFXSetting" -Value 3 -Force
        Log " [OK] Modalita effetti visivi: Personalizzata"

        # Disabilita animazioni e effetti non richiesti
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value "0" -Force
        $wmPath = "HKCU:\Control Panel\Desktop\WindowMetrics"
        if(!(Test-Path $wmPath)){New-Item -Path $wmPath -Force|Out-Null}
        Set-ItemProperty -Path $wmPath -Name "MinAnimate" -Value "0" -Force
        $advPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $advPath -Name "TaskbarAnimations" -Value 0 -Force
        Set-ItemProperty -Path $advPath -Name "ListviewAlphaSelect" -Value 0 -Force
        Log " [OK] Animazioni e trasparenze disabilitate"

        # === ABILITA SOLO GLI EFFETTI RICHIESTI ===

        # 1. Attiva Peek
        $dwmPath = "HKCU:\Software\Microsoft\Windows\DWM"
        if(!(Test-Path $dwmPath)){New-Item -Path $dwmPath -Force|Out-Null}
        Set-ItemProperty -Path $dwmPath -Name "EnableAeroPeek" -Value 1 -Force
        Log " [OK] Attiva Peek: SI"

        # 2. Mostra anteprime anziche icone
        Set-ItemProperty -Path $advPath -Name "IconsOnly" -Value 0 -Force
        Log " [OK] Anteprime anziche icone: SI"

        # 3. Mostra ombreggiatura delle finestre
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 1 -Force -ErrorAction SilentlyContinue
        $upm = [byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value $upm -Type Binary -Force
        Log " [OK] Ombreggiatura finestre: SI"

        # 4. Smussa gli angoli dei caratteri (ClearType/Font Smoothing)
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value "2" -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothingType" -Value 2 -Force
        Log " [OK] Smussatura caratteri (ClearType): SI"

        # 5. Sposta in modo uniforme le caselle di riepilogo (SmoothScroll)
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "SmoothScroll" -Value 1 -Force -ErrorAction SilentlyContinue
        Log " [OK] Scorrimento uniforme caselle: SI"

        # 6. Ombreggiatura etichette icone desktop
        Set-ItemProperty -Path $advPath -Name "ListviewShadow" -Value 1 -Force
        Log " [OK] Ombreggiatura etichette icone: SI"

        # Riavvia Explorer per applicare
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
    Flush-LogBuffer;Pump-UI
}

function Do-RunAll {
if($script:isClosing -or(Test-Cancel)){return}
Log "";Log "##################################################################################################";Log "# UPGRADE PROGRAMMI #";Log "##################################################################################################";Log ""
Update-Progress 0;Flush-LogBuffer;Pump-UI
Do-Winget;if(Test-Cancel){return};Do-StoreUpdate;if(Test-Cancel){return};Do-SearchWU;if(Test-Cancel){return};Do-InstallWU;if(Test-Cancel){return};Do-CleanTemp;if(Test-Cancel){return};Do-FlushDNS;if(Test-Cancel){return}
Update-Progress 100;Log "";Log "##################################################################################################";Log "# COMPLETATO #";Log "##################################################################################################";Log ""
Update-Status "[OK] Completato!" $successColor;Flush-LogBuffer;Pump-UI
}

# ============================
# GUI
# ============================
function Build-GUI {
[System.Windows.Forms.Application]::EnableVisualStyles()
$script:form=New-Object System.Windows.Forms.Form;$script:form.Text="Manutenzione PRO MAX v3.0 Peters";$script:form.Size=New-Object System.Drawing.Size(1100,720)
$script:form.MinimumSize=New-Object System.Drawing.Size(1100,720);$script:form.MaximumSize=New-Object System.Drawing.Size(1100,720)
$script:form.StartPosition="CenterScreen";$script:form.BackColor=$bgColor;$script:form.ForeColor=$fgColor
$script:form.FormBorderStyle="FixedSingle";$script:form.MaximizeBox=$false;$script:form.Font=New-Object System.Drawing.Font("Segoe UI",9)
$dbProp=$script:form.GetType().GetProperty("DoubleBuffered",[System.Reflection.BindingFlags]"Instance,NonPublic");if($dbProp){$dbProp.SetValue($script:form,$true)}

$headerPanel=New-Object System.Windows.Forms.Panel;$headerPanel.Dock="Top";$headerPanel.Height=36;$headerPanel.BackColor=$bgPanel
$titleLabel=New-Object System.Windows.Forms.Label;$titleLabel.Text=[char]0x26A1+" MANUTENZIONE PRO MAX";$titleLabel.Font=New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Bold);$titleLabel.ForeColor=$fgColor;$titleLabel.AutoSize=$true;$titleLabel.Location=New-Object System.Drawing.Point(10,8);$headerPanel.Controls.Add($titleLabel)
$adminBadge=New-Object System.Windows.Forms.Label;$adminBadge.Font=New-Object System.Drawing.Font("Segoe UI",7,[System.Drawing.FontStyle]::Bold);$adminBadge.AutoSize=$true;$adminBadge.Location=New-Object System.Drawing.Point(250,12);if($isAdmin){$adminBadge.Text="ADMIN";$adminBadge.ForeColor=$successColor}else{$adminBadge.Text="UTENTE";$adminBadge.ForeColor=$warningColor};$headerPanel.Controls.Add($adminBadge)
$psVer="PS$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)";$verLabel=New-Object System.Windows.Forms.Label;$verLabel.Text="v3.0|$psVer";$verLabel.Font=New-Object System.Drawing.Font("Segoe UI",6.5);$verLabel.ForeColor=$fgDim;$verLabel.AutoSize=$true;$verLabel.Location=New-Object System.Drawing.Point(1010,12);$headerPanel.Controls.Add($verLabel)
$script:form.Controls.Add($headerPanel)

# SIDEBAR compatta
$sideW=280;$sidePanel=New-Object System.Windows.Forms.Panel;$sidePanel.Location=New-Object System.Drawing.Point(0,36);$sidePanel.Size=New-Object System.Drawing.Size($sideW,654);$sidePanel.BackColor=$bgPanel;$sidePanel.AutoScroll=$true
$pad=4;$gap=2;$colW=[int](($sideW-$pad*2-$gap)/2);$btnH=22;$rowGap=2;$script:btnRow=3;$script:btnCol=0

function Add-SectionLabel{param([string]$text,[System.Windows.Forms.Panel]$panel)
if($script:btnCol -eq 1){$script:btnRow+=($btnH+$rowGap);$script:btnCol=0}
if($script:btnRow -gt 5){$sep=New-Object System.Windows.Forms.Label;$sep.Size=New-Object System.Drawing.Size(($sideW-$pad*2),1);$sep.Location=New-Object System.Drawing.Point($pad,$script:btnRow);$sep.BackColor=$separatorColor;$panel.Controls.Add($sep);$script:btnRow+=2}
$lbl=New-Object System.Windows.Forms.Label;$lbl.Text=$text.ToUpper()
$lbl.Font=New-Object System.Drawing.Font("Segoe UI",6.5,[System.Drawing.FontStyle]"Bold,Underline")
$lbl.ForeColor=$sectionColor;$lbl.Size=New-Object System.Drawing.Size(($sideW-$pad*2),13)
$lbl.Location=New-Object System.Drawing.Point($pad,$script:btnRow);$lbl.TextAlign="BottomLeft"
$panel.Controls.Add($lbl);$script:btnRow+=(13+1);$script:btnCol=0
}
function Add-Button2Col{param([string]$text,[System.Drawing.Color]$color,[ScriptBlock]$action,[System.Windows.Forms.Panel]$panel,[string]$tooltip=$null);$x=if($script:btnCol -eq 0){$pad}else{$pad+$colW+$gap};$btn=New-Object System.Windows.Forms.Button;$btn.Text=$text;$btn.Size=New-Object System.Drawing.Size($colW,$btnH);$btn.Location=New-Object System.Drawing.Point($x,$script:btnRow);$btn.FlatStyle="Flat";$btn.FlatAppearance.BorderSize=0;$btn.FlatAppearance.MouseOverBackColor=$btnHover;$btn.BackColor=$bgCard;$btn.ForeColor=$color;$btn.Font=New-Object System.Drawing.Font("Segoe UI Semibold",7);$btn.Cursor=[System.Windows.Forms.Cursors]::Hand;$btn.TextAlign="MiddleCenter";$btn.Add_Click($action);if($tooltip){$tt=New-Object System.Windows.Forms.ToolTip;$tt.SetToolTip($btn,$tooltip)};$panel.Controls.Add($btn);if($script:btnCol -eq 0){$script:btnCol=1}else{$script:btnCol=0;$script:btnRow+=($btnH+$rowGap)}}
function Add-ButtonMain{param([string]$text,[System.Drawing.Color]$color,[ScriptBlock]$action,[System.Windows.Forms.Panel]$panel,[string]$tooltip=$null)
if($script:btnCol -eq 1){$script:btnRow+=($btnH+$rowGap);$script:btnCol=0}
$fullW=$sideW-$pad*2;$btn=New-Object System.Windows.Forms.Button;$btn.Text=$text;$btn.Size=New-Object System.Drawing.Size($fullW,26)
$btn.Location=New-Object System.Drawing.Point($pad,$script:btnRow);$btn.FlatStyle="Flat"
$btn.FlatAppearance.BorderSize=1;$btn.FlatAppearance.BorderColor=$runAllColor;$btn.FlatAppearance.MouseOverBackColor=[System.Drawing.Color]::FromArgb(35,80,50)
$btn.BackColor=$runAllBg;$btn.ForeColor=$color;$btn.Font=New-Object System.Drawing.Font("Segoe UI Bold",7.5)
$btn.Cursor=[System.Windows.Forms.Cursors]::Hand;$btn.TextAlign="MiddleCenter";$btn.Add_Click($action);if($tooltip){$tt=New-Object System.Windows.Forms.ToolTip;$tt.SetToolTip($btn,$tooltip)};$panel.Controls.Add($btn)
$script:btnRow+=(26+$rowGap);$script:btnCol=0
}
function Add-ButtonFull{param([string]$text,[System.Drawing.Color]$color,[ScriptBlock]$action,[System.Windows.Forms.Panel]$panel,[string]$tooltip=$null);if($script:btnCol -eq 1){$script:btnRow+=($btnH+$rowGap);$script:btnCol=0};$fullW=$sideW-$pad*2;$btn=New-Object System.Windows.Forms.Button;$btn.Text=$text;$btn.Size=New-Object System.Drawing.Size($fullW,$btnH);$btn.Location=New-Object System.Drawing.Point($pad,$script:btnRow);$btn.FlatStyle="Flat";$btn.FlatAppearance.BorderSize=0;$btn.FlatAppearance.MouseOverBackColor=$btnHover;$btn.BackColor=$bgCard;$btn.ForeColor=$color;$btn.Font=New-Object System.Drawing.Font("Segoe UI Semibold",7);$btn.Cursor=[System.Windows.Forms.Cursors]::Hand;$btn.TextAlign="MiddleCenter";$btn.Add_Click($action);if($tooltip){$tt=New-Object System.Windows.Forms.ToolTip;$tt.SetToolTip($btn,$tooltip)};$panel.Controls.Add($btn);$script:btnRow+=($btnH+$rowGap);$script:btnCol=0}

# AGGIORNAMENTI
Add-SectionLabel "Aggiornamenti" $sidePanel
Add-ButtonMain "$([char]0x25B6) UPGRADE PROGRAMMI" $runAllColor {Do-RunAll} $sidePanel "Avvia la sequenza completa di aggiornamenti: Winget, Store, Windows Update, Pulizia temp e Flush DNS"
Add-Button2Col "Winget" $accentColor {Do-Winget} $sidePanel "Aggiorna tutti i programmi installati tramite Winget (gestore pacchetti Windows)"
Add-Button2Col "Store" $accentColor {Do-StoreUpdate} $sidePanel "Aggiorna tutte le app del Microsoft Store"
Add-Button2Col "Cerca WU" $infoColor {Do-SearchWU} $sidePanel "Cerca gli aggiornamenti disponibili per Windows Update"
Add-Button2Col "Installa WU" $infoColor {Do-InstallWU} $sidePanel "Scarica e installa tutti gli aggiornamenti di Windows in sospeso"
# PULIZIA
Add-SectionLabel "Pulizia" $sidePanel
Add-Button2Col "Temp" $maintColor {Do-CleanTemp} $sidePanel "Pulisce le cartelle temporanee del sistema e dell'utente liberando spazio su disco"
Add-Button2Col "Disk Cleanup" $maintColor {Do-DiskCleanup} $sidePanel "Avvia lo strumento di pulizia disco di Windows (richiede privilegi admin)"
# RETE
Add-SectionLabel "Rete" $sidePanel
Add-Button2Col "Flush DNS" $networkColor {Do-FlushDNS} $sidePanel "Svuota la cache DNS per risolvere problemi di risoluzione dei nomi"
Add-Button2Col "Renew IP" $networkColor {Do-RenewIP} $sidePanel "Rinnova l'indirizzo IP della scheda di rete"
Add-Button2Col "Info IP" $infoColor {Do-InfoIP} $sidePanel "Mostra tutte le informazioni di configurazione di rete (ipconfig /all)"
Add-Button2Col "Winsock" $networkColor {Do-ResetWinsock} $sidePanel "Resetta lo stack Winsock e il protocollo IP (utile per problemi di rete)"
Add-Button2Col "Wi-Fi Pass" $networkColor {Do-WifiPasswords} $sidePanel "Visualizza le password salvate delle reti Wi-Fi conosciute"
Add-Button2Col "Ping Test" $networkColor {Do-SpeedTest} $sidePanel "Esegue un test di latenza verso i server DNS principali (Google, Cloudflare, OpenDNS)"
# RIPARAZIONE
Add-SectionLabel "Riparazione" $sidePanel
Add-Button2Col "SFC + DISM" $repairColor {Do-RepairSystem} $sidePanel "Esegue SFC /scannow e DISM per riparare i file di sistema danneggiati"
Add-Button2Col "Pt. Ripristino" $repairColor {Do-RestorePoint} $sidePanel "Crea un punto di ripristino del sistema (limite 24 ore)"
# SICUREZZA
Add-SectionLabel "Sicurezza" $sidePanel
Add-Button2Col "Scan Defender" $securityColor {Do-SecurityScan} $sidePanel "Avvia una scansione rapida con Windows Defender"
Add-Button2Col "Event Log" $securityColor {Do-EventLogErrors} $sidePanel "Mostra gli ultimi errori critici del registro eventi di sistema (ultimi 7 giorni)"
# DIAGNOSTICA
Add-SectionLabel "Diagnostica" $sidePanel
Add-Button2Col "Info Sistema" $infoColor {Do-SystemInfo} $sidePanel "Mostra informazioni dettagliate su hardware e sistema operativo"
Add-Button2Col "Batteria" $infoColor {Do-BatteryReport} $sidePanel "Genera un report sulla salute della batteria (solo su portatili)"
Add-Button2Col "Uptime" $infoColor {Do-Uptime} $sidePanel "Visualizza da quanto tempo il sistema è in esecuzione senza riavvii"
Add-Button2Col "Top Processi" $cpuColor {Do-TopProcesses} $sidePanel "Elenca i processi che consumano piu CPU in tempo reale"
Add-Button2Col "Startup" $cpuColor {Do-StartupPrograms} $sidePanel "Elenca i programmi avviati automaticamente all'avvio del sistema"
Add-Button2Col "Spazio Disco" $maintColor {Do-DiskSpace} $sidePanel "Analizza e mostra lo spazio occupato dalle cartelle principali dell'utente"
Add-Button2Col "Servizi" $infoColor {Do-ServiceStatus} $sidePanel "Controlla lo stato dei servizi di sistema principali (Windows Update, Defender, Firewall, BITS, DNS)"
Add-Button2Col "Speed Internet" $networkColor {Do-SpeedInternet} $sidePanel "Esegue un test della velocita di connessione utilizzando i server Cloudflare (ping, download, upload)"
Add-Button2Col "CPU Unlock" $cpuColor {Do-UnlockCPU} $sidePanel "Sblocca le opzioni avanzate di gestione energia della CPU nel Pannello di Controllo"
Add-Button2Col "Assist. Remota" $remoteColor {Do-RemoteAssist} $sidePanel "Scarica e avvia RustDesk per assistenza remota (portatile) mostrando ID e password"
# SISTEMA
Add-SectionLabel "Sistema" $sidePanel
Add-Button2Col "Shutdown Sched." $warningColor {Do-ScheduleShutdown} $sidePanel "Programma lo spegnimento forzato del PC ogni giorno all'ora impostata (attivita pianificata)"
Add-Button2Col "Rimuovi Shutdown" $exitColor {Do-RemoveShutdown} $sidePanel "Rimuove il task di spegnimento programmato creato in precedenza"
Add-Button2Col "Ottimizza Visivi" $cpuColor {Do-OptimizeVisual} $sidePanel "Ottimizza gli effetti visivi di Windows: disabilita animazioni inutili, mantiene Peek, anteprime e ombre"
Add-Button2Col "Annulla" $exitColor {$script:cancelRequested=$true} $sidePanel "Annulla l'operazione in corso in modo sicuro"
Add-Button2Col "Export Report" $infoColor {Do-ExportReport} $sidePanel "Esporta il contenuto del log in un file di testo sul desktop"
Add-Button2Col "Eleva Admin" $elevateColor {Restart-AsAdmin} $sidePanel "Riavvia lo script con privilegi amministrativi per sbloccare tutte le funzionalita"
Add-Button2Col "Riavvia PC" $restartColor {$r=[System.Windows.Forms.MessageBox]::Show("Riavviare?","Conferma","YesNo","Warning");if($r -eq "Yes"){shutdown /r /t 5 /c "Riavvio"}} $sidePanel "Riavvia il sistema dopo 5 secondi con un messaggio di avviso"
Add-ButtonFull "Esci" $exitColor {$script:isClosing=$true;$script:form.Close()} $sidePanel "Chiude l'applicazione di manutenzione"
$script:form.Controls.Add($sidePanel)

# CONTENT
$contentX=$sideW;$contentW=1100-$sideW;$contentPanel=New-Object System.Windows.Forms.Panel;$contentPanel.Location=New-Object System.Drawing.Point($contentX,36);$contentPanel.Size=New-Object System.Drawing.Size($contentW,654);$contentPanel.BackColor=$bgColor
$script:statusLabel=New-Object System.Windows.Forms.Label;$script:statusLabel.Text="Pronto";$script:statusLabel.Font=New-Object System.Drawing.Font("Segoe UI Semibold",9);$script:statusLabel.ForeColor=$fgDim;$script:statusLabel.Location=New-Object System.Drawing.Point(8,4);$script:statusLabel.Size=New-Object System.Drawing.Size(($contentW-50),18);$contentPanel.Controls.Add($script:statusLabel)
$script:progressBar=New-Object System.Windows.Forms.ProgressBar;$script:progressBar.Location=New-Object System.Drawing.Point(8,24);$script:progressBar.Size=New-Object System.Drawing.Size(($contentW-50),7);$script:progressBar.Style="Continuous";$script:progressBar.Value=0;$script:progressBar.Minimum=0;$script:progressBar.Maximum=100;$contentPanel.Controls.Add($script:progressBar)
$script:progressLabel=New-Object System.Windows.Forms.Label;$script:progressLabel.Text="0%";$script:progressLabel.Font=New-Object System.Drawing.Font("Segoe UI",6.5);$script:progressLabel.ForeColor=$fgDim;$script:progressLabel.Location=New-Object System.Drawing.Point(($contentW-40),22);$script:progressLabel.Size=New-Object System.Drawing.Size(34,12);$script:progressLabel.TextAlign="MiddleRight";$contentPanel.Controls.Add($script:progressLabel)
$script:logBox=New-Object System.Windows.Forms.RichTextBox;$script:logBox.Location=New-Object System.Drawing.Point(8,36);$script:logBox.Size=New-Object System.Drawing.Size(($contentW-16),608);$script:logBox.BackColor=$logBg;$script:logBox.ForeColor=[System.Drawing.Color]::FromArgb(200,200,210);$script:logBox.Font=New-Object System.Drawing.Font("Consolas",9);$script:logBox.ReadOnly=$true;$script:logBox.BorderStyle="None";$script:logBox.ScrollBars="ForcedVertical";$script:logBox.WordWrap=$false;$script:logBox.DetectUrls=$false;$script:logBox.ShortcutsEnabled=$true;$contentPanel.Controls.Add($script:logBox)
$script:form.Controls.Add($contentPanel)

$script:uiTimer=New-Object System.Windows.Forms.Timer;$script:uiTimer.Interval=100;$script:uiTimer.Add_Tick({Flush-LogBuffer});$script:uiTimer.Start()
$script:form.Add_Shown({Log "";Log " $([char]0x26A1) Manutenzione PRO MAX v3.0 Peters";Log " $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $psVer";Log " Log: $logFile";Log "";if(-not $isAdmin){Log " [!] Utente standard. 'Eleva Admin' per sbloccare tutto.";Log ""};Flush-LogBuffer})
$script:form.Add_FormClosing({$script:isClosing=$true;$script:cancelRequested=$true;if($script:uiTimer){$script:uiTimer.Stop();$script:uiTimer.Dispose()}})
[System.Windows.Forms.Application]::Run($script:form)
}

Build-GUI
