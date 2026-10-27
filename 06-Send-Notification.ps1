# Partie 6 - Notification (uniquement si anomalie)
[CmdletBinding()]
param()
. (Join-Path $PSScriptRoot 'Common.ps1')

$rows    = Import-PMCsv 'SecurityReport.csv'
$anomaly = @($rows | Where-Object Etat -in 'NON CONFORME', 'INACCESSIBLE')

if ($anomaly.Count -eq 0) {
    Write-PMLog 'Aucune anomalie : pas de notification'
    Write-Host 'Aucune anomalie, aucune notification envoyee.'
    return
}

$smtp   = $script:Settings.Smtp
$nonConf = @($anomaly | Where-Object Etat -eq 'NON CONFORME')
$inacc   = @($anomaly | Where-Object Etat -eq 'INACCESSIBLE')

$lines = @(
    "Date du contrôle : $((Get-Date).ToString('dd/MM/yyyy'))"
    "Postes contrôlés : $(@($rows).Count)"
    "Postes non conformes : $($nonConf.Count)"
    "Postes inaccessibles : $($inacc.Count)"
    ''
)
foreach ($a in $anomaly) {
    $lines += "$($a.Poste) : $($a.Etat)"
    if ($a.Etat -eq 'NON CONFORME') { foreach ($kb in $a.ListeKBManquantes -split ',\s*') { $lines += "$kb manquante" } }
    $lines += ''
}
$body = $lines -join "`r`n"

$params = @{
    SmtpServer = $smtp.Server; Port = $smtp.Port; UseSsl = $smtp.UseSsl
    From = $smtp.From; To = $smtp.To
    Subject = '[PATCH MANAGEMENT] Anomalies détectées'
    Body = $body; Encoding = [System.Text.Encoding]::UTF8
    Attachments = (Get-PMOutputPath 'SecurityReport.html')
}
$credFile = Get-PMPath $smtp.CredentialFile
if (Test-Path $credFile) { $params.Credential = Import-Clixml $credFile }   # jamais de mot de passe en clair

try {
    Send-MailMessage @params -ErrorAction Stop
    Write-PMLog "Notification envoyee a $($smtp.To)"
    Write-Host "Notification envoyee a $($smtp.To)"
} catch {
    Write-PMLog "ERREUR ; Notification non envoyee ; $($_.Exception.Message)"
    Write-Warning "Notification non envoyee : $($_.Exception.Message)"
}
