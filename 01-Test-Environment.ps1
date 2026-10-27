# Partie 1 - Verification de l'environnement : lecture de computers.txt + disponibilite
. (Join-Path $PSScriptRoot 'Common.ps1')

$rows = foreach ($c in Read-PMComputers) {
    $t = Test-PMHost -IP $c.IP
    [pscustomobject]@{
        Poste        = $c.Name
        'Adresse IP' = $c.IP
        Ping         = $t.Ping
        WinRM        = $t.WinRM
        Etat         = if ($t.Reachable) { 'Accessible' } else { 'Inaccessible' }
    }
}
$rows | Format-Table -AutoSize
