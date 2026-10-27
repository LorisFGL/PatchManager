# Orchestrateur : enchaine toutes les etapes. Usage : .\PatchManager.ps1 [-NoNotify]
[CmdletBinding()]
param([switch]$NoNotify)
. (Join-Path $PSScriptRoot 'Common.ps1')

$cred = Get-PMCredential
Write-PMLog "Début de l'audit"
try {
    & (Join-Path $PSScriptRoot '02-Get-Inventory.ps1')      -Credential $cred
    & (Join-Path $PSScriptRoot '03-Get-PatchInventory.ps1') -Credential $cred
    & (Join-Path $PSScriptRoot '04-Test-Compliance.ps1')
    & (Join-Path $PSScriptRoot '05-New-Report.ps1')
    if (-not $NoNotify) { & (Join-Path $PSScriptRoot '06-Send-Notification.ps1') }
} catch {
    Write-PMLog "ERREUR ; $($_.Exception.Message)"
    throw
} finally {
    Write-PMLog "Fin de l'audit"
}
