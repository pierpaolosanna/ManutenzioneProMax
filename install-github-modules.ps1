[CmdletBinding()]
param(
    [string]$Scope = 'CurrentUser',
    [string]$BasePath = $(if ($Scope -eq 'AllUsers') { Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules' } else { Join-Path $HOME 'Documents\WindowsPowerShell\Modules' }),
    [switch]$ForceReinstall,
    [switch]$SkipTlsCheck
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $SkipTlsCheck) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    } catch {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
    }
}

# ----- LISTA DEI MODULI CON LE LORO DIPENDENZE -----
$Modules = @(
    [pscustomobject]@{ Name = 'PSWriteColor'; Repo = 'https://github.com/EvotecIT/PSWriteColor'; Zip = 'https://github.com/EvotecIT/PSWriteColor/archive/refs/heads/master.zip'; Dependencies = @() },
    [pscustomobject]@{ Name = 'PSSharedGoods'; Repo = 'https://github.com/EvotecIT/PSSharedGoods'; Zip = 'https://github.com/EvotecIT/PSSharedGoods/archive/refs/heads/master.zip'; Dependencies = @('PSWriteColor') },
    [pscustomobject]@{ Name = 'PSTeams'; Repo = 'https://github.com/EvotecIT/PSTeams'; Zip = 'https://github.com/EvotecIT/PSTeams/archive/refs/heads/master.zip'; Dependencies = @('PSSharedGoods') },
    [pscustomobject]@{ Name = 'PSSlack'; Repo = 'https://github.com/RamblingCookieMonster/PSSlack'; Zip = 'https://github.com/RamblingCookieMonster/PSSlack/archive/refs/heads/master.zip'; Dependencies = @() },
    [pscustomobject]@{ Name = 'PSDiscord'; Repo = 'https://github.com/EvotecIT/PSDiscord'; Zip = 'https://github.com/EvotecIT/PSDiscord/archive/refs/heads/master.zip'; Dependencies = @('PSSharedGoods') },
    [pscustomobject]@{ Name = 'PSBlackListChecker'; Repo = 'https://github.com/EvotecIT/PSBlackListChecker'; Zip = 'https://github.com/EvotecIT/PSBlackListChecker/archive/refs/heads/master.zip'; Dependencies = @('PSSharedGoods','PSTeams','PSSlack','PSDiscord') }
)

# ----- FUNZIONI DI UTILITY -----
function Write-Log {
    param([string]$Message,[ValidateSet('INFO','OK','WARN','ERR')] [string]$Level = 'INFO')
    $prefix = switch ($Level) {
        'INFO' { '[i]' }
        'OK'   { '[+]' }
        'WARN' { '[!]' }
        'ERR'  { '[X]' }
    }
    Write-Host "$prefix $Message"
}

function Test-ModuleInstalled {
    param([string]$Name)
    $available = Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue
    return [bool]$available
}

function Get-ModuleRoot {
    param([string]$Name)
    $module = Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if ($module) {
        return Split-Path -Parent $module.Path
    }
    return $null
}

function Get-ManifestVersion {
    param([string]$ManifestPath)
    try {
        $data = Import-PowerShellDataFile -Path $ManifestPath
        if ($data.ModuleVersion) { return [string]$data.ModuleVersion }
    } catch {}
    return '0.0.0'
}

function Invoke-FileDownload {
    param(
        [string]$Uri,
        [string]$OutFile,
        [int]$Retries = 3
    )

    for ($i = 1; $i -le $Retries; $i++) {
        try {
            Write-Log "Download tentativo ${i}: ${Uri}" 'INFO'
            if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
                & curl.exe -L --fail --connect-timeout 30 --retry 2 --retry-delay 2 -o $OutFile $Uri 2>&1 | Out-Null
                if (-not (Test-Path $OutFile) -or ((Get-Item $OutFile).Length -eq 0)) {
                    throw 'File ZIP non valido o vuoto.'
                }
            } else {
                Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -TimeoutSec 120
            }
            return
        } catch {
            Write-Log "Tentativo ${i} fallito: $($_.Exception.Message)" 'WARN'
            if ($i -ge $Retries) { throw }
            Start-Sleep -Seconds (2 * $i)
        }
    }
}

function Install-ModuleFromGitHubZip {
    param(
        [Parameter(Mandatory)] [pscustomobject]$ModuleInfo,
        [Parameter(Mandatory)] [string]$InstallRoot
    )

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("ghmod_" + [guid]::NewGuid().ToString('N'))
    $zipPath = Join-Path $tempRoot ($ModuleInfo.Name + '.zip')
    $extractPath = Join-Path $tempRoot 'extract'
    New-Item -ItemType Directory -Force -Path $tempRoot,$extractPath | Out-Null

    try {
        Invoke-FileDownload -Uri $ModuleInfo.Zip -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        $repoRoot = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
        if (-not $repoRoot) { throw 'Cartella estratta non trovata.' }

        # Cerca il file manifest ovunque (ricorsivo)
        $manifest = Get-ChildItem -Path $repoRoot.FullName -Filter "$($ModuleInfo.Name).psd1" -Recurse -File | Select-Object -First 1
        if (-not $manifest) {
            $manifest = Get-ChildItem -Path $repoRoot.FullName -Filter '*.psd1' -Recurse -File | Select-Object -First 1
        }
        if (-not $manifest) { 
            Write-Log "Contenuto della cartella estratta (prime 20 voci):" 'INFO'
            Get-ChildItem -Path $repoRoot.FullName -Recurse -File | Select-Object -First 20 | ForEach-Object {
                Write-Log "  $($_.FullName)" 'INFO'
            }
            throw "Manifest PSD1 non trovato per il modulo $($ModuleInfo.Name)."
        }

        Write-Log "Manifest trovato: $($manifest.FullName)" 'OK'

        $moduleRoot = $manifest.Directory.FullName
        $version = Get-ManifestVersion -ManifestPath $manifest.FullName
        
        $targetModuleRoot = Join-Path $InstallRoot $ModuleInfo.Name
        $targetVersionRoot = Join-Path $targetModuleRoot $version

        if (Test-Path $targetVersionRoot) {
            Remove-Item -Path $targetVersionRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        New-Item -ItemType Directory -Force -Path $targetVersionRoot | Out-Null
        Copy-Item -Path "$moduleRoot\*" -Destination $targetVersionRoot -Recurse -Force

        $importManifest = Join-Path $targetVersionRoot ($ModuleInfo.Name + '.psd1')
        if (-not (Test-Path $importManifest)) {
            $foundManifest = Get-ChildItem -Path $targetVersionRoot -Filter '*.psd1' -Recurse -File | Select-Object -First 1
            if (-not $foundManifest) { 
                throw "Manifest finale non trovato dopo la copia in $targetVersionRoot"
            }
            $importManifest = $foundManifest.FullName
        }

        Write-Log "Importazione da: $importManifest" 'INFO'
        Import-Module -Name $importManifest -Force -ErrorAction Stop | Out-Null
        
        Write-Log "$($ModuleInfo.Name) installato in $targetVersionRoot" 'OK'
        return $targetVersionRoot
    } finally {
        Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Ensure-Module {
    param([pscustomobject]$ModuleInfo)

    # Installa prima le dipendenze
    foreach ($dep in $ModuleInfo.Dependencies) {
        $depInfo = $Modules | Where-Object Name -eq $dep | Select-Object -First 1
        if (-not $depInfo) { throw "Dipendenza non definita: ${dep}" }
        Ensure-Module -ModuleInfo $depInfo
    }

    # Se il modulo è già installato e non forziamo la reinstallazione
    if (-not $ForceReinstall -and (Test-ModuleInstalled -Name $ModuleInfo.Name)) {
        $root = Get-ModuleRoot -Name $ModuleInfo.Name
        Write-Log "$($ModuleInfo.Name) già presente in $root" 'OK'
        try {
            Import-Module -Name $ModuleInfo.Name -Force -ErrorAction Stop | Out-Null
            Write-Log "$($ModuleInfo.Name) importato correttamente" 'OK'
            return
        } catch {
            Write-Log "Modulo presente ma import fallito, reinstallo: $($ModuleInfo.Name)" 'WARN'
        }
    } else {
        Write-Log "$($ModuleInfo.Name) non trovato. Installazione da GitHub..." 'WARN'
    }

    New-Item -ItemType Directory -Force -Path $BasePath | Out-Null
    $installedPath = Install-ModuleFromGitHubZip -ModuleInfo $ModuleInfo -InstallRoot $BasePath

    if (-not (Test-ModuleInstalled -Name $ModuleInfo.Name)) {
        $env:PSModulePath = "${BasePath};$env:PSModulePath"
    }

    # Importa il modulo appena installato
    try {
        Import-Module -Name $ModuleInfo.Name -Force -ErrorAction Stop | Out-Null
        Write-Log "$($ModuleInfo.Name) importato con successo" 'OK'
    } catch {
        Write-Log "Errore importazione $($ModuleInfo.Name): $($_.Exception.Message)" 'WARN'
        $manifestPath = Join-Path $installedPath "$($ModuleInfo.Name).psd1"
        if (Test-Path $manifestPath) {
            Import-Module -Name $manifestPath -Force -ErrorAction Stop | Out-Null
            Write-Log "$($ModuleInfo.Name) importato da percorso diretto" 'OK'
        } else {
            throw "Impossibile importare $($ModuleInfo.Name) dopo l'installazione"
        }
    }

    if (Test-ModuleInstalled -Name $ModuleInfo.Name) {
        Write-Log "$($ModuleInfo.Name) installato correttamente in $installedPath" 'OK'
    } else {
        throw "Installazione non verificata per $($ModuleInfo.Name)"
    }
}

# ----- AVVIO INSTALLAZIONE -----
Write-Log "Percorso moduli: ${BasePath}" 'INFO'
Write-Log 'Avvio verifica/installazione moduli GitHub richiesti...' 'INFO'

foreach ($moduleInfo in $Modules) {
    Ensure-Module -ModuleInfo $moduleInfo
}

Write-Log 'Verifica finale moduli installati:' 'INFO'
foreach ($moduleInfo in $Modules) {
    $m = Get-Module -ListAvailable -Name $moduleInfo.Name -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1 Name, Version, Path
    if ($m) {
        Write-Host (' - {0} | v{1} | {2}' -f $m.Name, $m.Version, $m.Path)
    } else {
        throw "Modulo mancante dopo installazione: $($moduleInfo.Name)"
    }
}

Write-Log 'Installazione completata senza errori.' 'OK'