# Partie 5 - Rapport de securite -> output\SecurityReport.csv + output\SecurityReport.html
[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'Common.ps1')
function ConvertTo-PMHtml($t) { [System.Net.WebUtility]::HtmlEncode([string]$t) }

$inv  = Import-PMCsv 'Inventory.csv'
$comp = Import-PMCsv 'ComplianceReport.csv'

$rows = foreach ($c in $comp) {
    $i = $inv | Where-Object Poste -eq $c.Poste | Select-Object -First 1
    $acc = if ($c.Etat -eq 'INACCESSIBLE') { 'Inaccessible' } else { 'Accessible' }
    [pscustomobject]@{
        Poste           = $c.Poste
        'Adresse IP'    = $c.'Adresse IP'
        Accessibilite   = $acc
        Windows         = if ($i -and $i.Windows) { $i.Windows } else { '-' }
        DernierDemarr   = if ($i -and $i.DernierDemarr) { $i.DernierDemarr } else { '-' }
        WindowsUpdate   = if ($i -and $i.WindowsUpdate) { $i.WindowsUpdate } else { '-' }
        KBRequises      = $c.KBRequises
        KBManquantes    = $c.KBManquantes
        ListeKBManquantes = $c.ListeKBManquantes
        Etat            = $c.Etat
        DateControle    = $c.DateControle
    }
}
$rows | Export-PMCsv -FileName 'SecurityReport.csv'

# Synthese globale
$total = @($rows).Count
$acc   = @($rows | Where-Object Accessibilite -eq 'Accessible').Count
$inacc = $total - $acc
$ok    = @($rows | Where-Object Etat -eq 'CONFORME').Count
$nok   = @($rows | Where-Object Etat -eq 'NON CONFORME').Count
$kbMiss = 0
foreach ($r in $rows) { if ($r.KBManquantes -match '^\d+$') { $kbMiss += [int]$r.KBManquantes } }
$rate  = if (($ok + $nok) -gt 0) { [math]::Round(100 * $ok / ($ok + $nok), 1) } else { 0 }
$now   = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'
$todo  = @($rows | Where-Object Etat -ne 'CONFORME')

function Row($r) {
    $cls = switch ($r.Etat) { 'CONFORME' {'ok'} 'NON CONFORME' {'bad'} default {'off'} }
    "<tr><td>$(ConvertTo-PMHtml $r.Poste)</td><td>$(ConvertTo-PMHtml $r.'Adresse IP')</td><td>$(ConvertTo-PMHtml $r.Accessibilite)</td><td>$(ConvertTo-PMHtml $r.Windows)</td>" +
    "<td>$(ConvertTo-PMHtml $r.DernierDemarr)</td><td>$(ConvertTo-PMHtml $r.WindowsUpdate)</td><td>$(ConvertTo-PMHtml $r.KBRequises)</td><td>$(ConvertTo-PMHtml $r.KBManquantes)</td>" +
    "<td>$(ConvertTo-PMHtml $r.ListeKBManquantes)</td><td class='$cls'>$(ConvertTo-PMHtml $r.Etat)</td><td>$(ConvertTo-PMHtml $r.DateControle)</td></tr>"
}
$head = '<tr><th>Poste</th><th>IP</th><th>Accessibilité</th><th>Windows</th><th>Dernier démarrage</th><th>Windows Update</th><th>KB requises</th><th>KB manquantes</th><th>Liste KB manquantes</th><th>État</th><th>Contrôle</th></tr>'
$todoHtml = if ($todo.Count) {
    '<ul>' + (($todo | ForEach-Object {
        $d = if ($_.Etat -eq 'INACCESSIBLE') { 'poste injoignable (ping/WinRM) : vérifier réseau, pare-feu, service WinRM' } else { "installer : $(ConvertTo-PMHtml $_.ListeKBManquantes)" }
        "<li><b>$(ConvertTo-PMHtml $_.Poste)</b> ($(ConvertTo-PMHtml $_.Etat)) - $d</li>" }) -join '') + '</ul>'
} else { '<p>Aucune intervention nécessaire.</p>' }

$html = @"
<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><title>Rapport Patch Management</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:2rem;color:#222}
table{border-collapse:collapse;width:100%;font-size:.9rem}th,td{border:1px solid #ccc;padding:6px 8px;text-align:left}
th{background:#1f3a5f;color:#fff}.ok{background:#d4edda;font-weight:bold}.bad{background:#f8d7da;font-weight:bold}.off{background:#fff3cd;font-weight:bold}
.kpi span{display:inline-block;margin:0 1.5rem .5rem 0}
</style></head><body>
<h1>Rapport de sécurité - Patch Management</h1><p>Généré le $now</p>
<h2>Synthèse globale</h2>
<div class="kpi"><span>Postes : <b>$total</b></span><span>Accessibles : <b>$acc</b></span><span>Inaccessibles : <b>$inacc</b></span>
<span>Conformes : <b>$ok</b></span><span>Non conformes : <b>$nok</b></span><span>KB manquantes (total) : <b>$kbMiss</b></span>
<span>Taux de conformité : <b>$rate %</b></span></div>
<h2>Postes nécessitant une intervention</h2>$todoHtml
<h2>Détail par poste</h2><table>$head$(($rows | ForEach-Object { Row $_ }) -join '')</table>
</body></html>
"@
$out = Get-PMOutputPath 'SecurityReport.html'
Set-Content -Path $out -Value $html -Encoding UTF8
Write-PMLog 'Rapport genere'
Write-Host "Rapport HTML : $out"
Write-Host "Synthese : $total postes | $acc acc. | $inacc inacc. | $ok conformes | $nok non conformes | $kbMiss KB manquantes | $rate %"
