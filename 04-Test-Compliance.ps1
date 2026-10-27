# Partie 4 - Controle de conformite -> output\ComplianceReport.csv
[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'Common.ps1')

$required = @(Read-PMRequiredPatches)
$summary  = Import-PMCsv 'PatchSummary.csv'
$patches  = Import-PMCsv 'PatchesInventory.csv'
$checkAt  = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'

$report = foreach ($s in $summary) {
    if ($s.Etat -ne 'Accessible') {
        Write-PMLog "$($s.Poste) ; INACCESSIBLE"
        [pscustomobject]@{
            Poste = $s.Poste; 'Adresse IP' = $s.'Adresse IP'; KBRequises = $required.Count
            KBManquantes = '-'; ListeKBManquantes = ''; Etat = 'INACCESSIBLE'; DateControle = $checkAt
        }
        continue
    }
    $installed = @($patches | Where-Object Poste -eq $s.Poste | ForEach-Object { $_.KB.Trim().ToUpper() })
    $missing   = @($required | Where-Object { $_ -notin $installed })
    $etat      = if ($missing.Count -eq 0) { 'CONFORME' } else { 'NON CONFORME' }
    if ($missing.Count) { Write-PMLog "$($s.Poste) ; NON CONFORME ; $($missing -join ',')" }
    else                { Write-PMLog "$($s.Poste) ; CONFORME" }
    [pscustomobject]@{
        Poste = $s.Poste; 'Adresse IP' = $s.'Adresse IP'; KBRequises = $required.Count
        KBManquantes = $missing.Count; ListeKBManquantes = ($missing -join ', '); Etat = $etat; DateControle = $checkAt
    }
}

$report | Export-PMCsv -FileName 'ComplianceReport.csv'
$report | Format-Table Poste, KBRequises, KBManquantes, ListeKBManquantes, Etat, DateControle -AutoSize

# Details des postes non conformes
foreach ($r in $report | Where-Object Etat -eq 'NON CONFORME') {
    Write-Host "$($r.Poste) : KB manquantes -> $($r.ListeKBManquantes)" -ForegroundColor Yellow
}

# Taux global (postes inaccessibles exclus)
$ok  = @($report | Where-Object Etat -eq 'CONFORME').Count
$nok = @($report | Where-Object Etat -eq 'NON CONFORME').Count
$rate = if (($ok + $nok) -gt 0) { [math]::Round(100 * $ok / ($ok + $nok), 1) } else { 0 }
Write-Host ("Taux global de conformite : {0} % ({1}/{2} postes controles)" -f $rate, $ok, ($ok + $nok)) -ForegroundColor Cyan
