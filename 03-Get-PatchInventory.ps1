# Partie 3 - Inventaire des correctifs -> output\PatchesInventory.csv + output\PatchSummary.csv
[CmdletBinding()]
param([pscredential]$Credential)
. (Join-Path $PSScriptRoot 'Common.ps1')

# 3.1 / 3.2 : en local (a montrer dans la video)
Write-Host '--- Correctifs de la machine locale ---'
Get-HotFix | Sort-Object InstalledOn -Descending |
    Select-Object HotFixID, Description, InstalledOn, InstalledBy | Format-Table -AutoSize

if (-not $Credential) { $Credential = Get-PMCredential }

$remote = {
    Get-HotFix | ForEach-Object {
        [pscustomobject]@{
            KB          = $_.HotFixID
            Description = $_.Description
            Date        = if ($_.InstalledOn) { $_.InstalledOn.ToString('yyyy-MM-dd') } else { '' }
            InstalledBy = $_.InstalledBy
        }
    }
}

# Avec JEA (partie 7) : seule la fonction autorisee Get-PMHotFix est appelable
if (Test-PMJea) { $remote = { Get-PMHotFix } }

$patches = @(); $summary = @()
foreach ($c in Read-PMComputers) {
    $s = [ordered]@{ Poste = $c.Name; 'Adresse IP' = $c.IP; Etat = 'Inaccessible'; NbPatchs = 0; DernierePatchDate = ''; DerniereKB = ''; Erreur = '' }
    $t = Test-PMHost -IP $c.IP
    if (-not $t.Reachable) {
        $s.Erreur = $t.Error
        Write-PMLog "$($c.Name) ; $($t.Error)"
    } else {
        try {
            $rp = Get-PMRemoteParams -IP $c.IP -Credential $Credential
            $list = @(Invoke-Command @rp -ScriptBlock $remote)
            foreach ($p in $list) {
                $patches += [pscustomobject]@{
                    Poste = $c.Name; 'Adresse IP' = $c.IP; KB = $p.KB; Description = $p.Description
                    'Date d''installation' = $p.Date; 'Installe par' = $p.InstalledBy
                }
            }
            $last = $list | Where-Object Date | Sort-Object Date -Descending | Select-Object -First 1
            $s.Etat = 'Accessible'; $s.NbPatchs = $list.Count
            if ($last) { $s.DernierePatchDate = $last.Date; $s.DerniereKB = $last.KB }
            Write-PMLog "$($c.Name) ; $($list.Count) correctifs recenses"
        } catch {
            $s.Erreur = $_.Exception.Message
            Write-PMLog "$($c.Name) ; ERREUR recuperation correctifs ; $($_.Exception.Message)"
        }
    }
    $summary += [pscustomobject]$s
}

# tri : poste, puis date d'installation decroissante
$patches = $patches | Sort-Object Poste, @{ Expression = { $_.'Date d''installation' }; Descending = $true }
$patches | Export-PMCsv -FileName 'PatchesInventory.csv'
$summary | Export-PMCsv -FileName 'PatchSummary.csv'

$summary | Format-Table Poste, Etat, NbPatchs, DernierePatchDate, DerniereKB -AutoSize
Write-Host "Exporte : $(Get-PMOutputPath 'PatchesInventory.csv')"
