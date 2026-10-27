# New-PatchServiceAccount.ps1 - Partie 7.3 : compte dedie au Patch Management (moindre privilege)
# - mot de passe aleatoire genere ici, jamais affiche ni ecrit en clair
# - compte NON administrateur, seulement membre de "Utilisateurs de gestion a distance" (S-1-5-32-580)
# - credential exporte chiffre (DPAPI) dans config\svcpatch.cred.xml
param(
    [string[]]$Computers = @('172.16.26.11', '172.16.26.12'),
    [string]$UserName = 'svc-patch',
    [pscredential]$AdminCredential = (Import-Clixml (Join-Path (Split-Path $PSScriptRoot) 'config\psremote.cred.xml'))
)

$chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!#%*+-=?'
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 24; $rng.GetBytes($bytes)
$secure = New-Object System.Security.SecureString
foreach ($b in $bytes) { $secure.AppendChar($chars[$b % $chars.Length]) }
$secure.MakeReadOnly()

Invoke-Command -ComputerName $Computers -Credential $AdminCredential -ArgumentList $UserName, $secure -ScriptBlock {
    param($u, $pw)
    if (Get-LocalUser -Name $u -ErrorAction SilentlyContinue) { Set-LocalUser -Name $u -Password $pw }
    else { New-LocalUser -Name $u -Password $pw -Description 'Service Patch Management (audit seul)' -PasswordNeverExpires -UserMayNotChangePassword | Out-Null }
    Add-LocalGroupMember -SID 'S-1-5-32-580' -Member $u -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Poste          = $env:COMPUTERNAME
        Compte         = $u
        Administrateur = [bool](Get-LocalGroupMember -SID 'S-1-5-32-544' | Where-Object Name -like "*\$u")
        GestionDistance= [bool](Get-LocalGroupMember -SID 'S-1-5-32-580' | Where-Object Name -like "*\$u")
    }
} | Select-Object Poste, Compte, Administrateur, GestionDistance | Format-Table -AutoSize

$out = Join-Path (Split-Path $PSScriptRoot) 'config\svcpatch.cred.xml'
New-Object System.Management.Automation.PSCredential($UserName, $secure) | Export-Clixml $out
"Credential chiffre (DPAPI) : $out"
