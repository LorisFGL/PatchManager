# Common.ps1 - fonctions partagees (a dot-sourcer : . .\Common.ps1)
Set-StrictMode -Version 2.0

$script:Root     = $PSScriptRoot
$script:Settings = Import-PowerShellDataFile (Join-Path $script:Root 'config\settings.psd1')

function Get-PMPath {
    param([Parameter(Mandatory)][string]$Relative)
    Join-Path $script:Root $Relative
}

function Get-PMOutputPath {
    param([Parameter(Mandatory)][string]$FileName)
    $dir = Get-PMPath $script:Settings.OutputDir
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Join-Path $dir $FileName
}

function Write-PMLog {
    # Format : 06/09/2026 09:00:01 ; message
    param([Parameter(Mandatory)][string]$Message)
    $file = Get-PMPath $script:Settings.LogFile
    $dir  = Split-Path $file
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $line = '{0} ; {1}' -f (Get-Date -Format 'dd/MM/yyyy HH:mm:ss'), $Message
    Add-Content -Path $file -Value $line -Encoding UTF8
    Write-Verbose $line
}

function Read-PMComputers {
    $file = Get-PMPath $script:Settings.ComputersFile
    if (-not (Test-Path $file)) { throw "Fichier introuvable : $file" }
    Get-Content $file -Encoding UTF8 |
        Where-Object { $_.Trim() -and $_.Trim() -notmatch '^#' } |
        ForEach-Object {
            $name, $ip = $_ -split ';', 2
            if (-not $ip) { Write-PMLog "AVERTISSEMENT ; ligne ignoree : $_"; return }
            [pscustomobject]@{ Name = $name.Trim(); IP = $ip.Trim() }
        }
}

function Read-PMRequiredPatches {
    $file = Get-PMPath $script:Settings.RequiredFile
    if (-not (Test-Path $file)) { throw "Fichier introuvable : $file" }
    Get-Content $file -Encoding UTF8 |
        Where-Object { $_.Trim() -and $_.Trim() -notmatch '^#' } |
        ForEach-Object { $_.Trim().ToUpper() } |
        Select-Object -Unique
}

function Get-PMCredential {
    # Credential chiffre (DPAPI) s'il existe ; sinon $null = identite de la session courante
    $file = Get-PMPath $script:Settings.CredentialFile
    if (Test-Path $file) { return Import-Clixml $file }
    $null
}

function Get-PMRemoteParams {
    # Parametres communs pour Invoke-Command (credential optionnel)
    param([Parameter(Mandatory)][string]$IP, [pscredential]$Credential)
    $p = @{ ComputerName = $IP; ErrorAction = 'Stop' }
    if ($Credential) { $p.Credential = $Credential }
    if (Test-PMJea) { $p.ConfigurationName = $script:Settings.JEAConfigurationName }
    $p
}

function Test-PMJea {
    # Vrai si un point de terminaison JEA est configure (settings.psd1 : JEAConfigurationName)
    [bool]($script:Settings.ContainsKey('JEAConfigurationName') -and $script:Settings.JEAConfigurationName)
}

function Test-PMHost {
    <# Retourne un objet : Ping / WinRM / Reachable / Error #>
    param([Parameter(Mandatory)][string]$IP)
    $ping = Test-Connection -ComputerName $IP -Count 1 -Quiet -ErrorAction SilentlyContinue
    $winrm = $false; $err = $null
    if ($ping) {
        try   { Test-WSMan -ComputerName $IP -ErrorAction Stop | Out-Null; $winrm = $true }
        catch { $err = "WinRM inaccessible : $($_.Exception.Message)" }
    } else { $err = 'Ping sans reponse' }
    [pscustomobject]@{ Ping = $ping; WinRM = $winrm; Reachable = ($ping -and $winrm); Error = $err }
}

function Import-PMCsv {
    param([Parameter(Mandatory)][string]$FileName)
    $p = Get-PMOutputPath $FileName
    if (-not (Test-Path $p)) { throw "Fichier $p absent : lancez d'abord l'etape precedente." }
    Import-Csv -Path $p -Delimiter ';' -Encoding UTF8
}

function Export-PMCsv {
    param([Parameter(Mandatory, ValueFromPipeline)]$InputObject, [Parameter(Mandatory)][string]$FileName)
    begin   { $all = @() }
    process { $all += $InputObject }
    end     { $all | Export-Csv -Path (Get-PMOutputPath $FileName) -Delimiter ';' -NoTypeInformation -Encoding UTF8 }
}
