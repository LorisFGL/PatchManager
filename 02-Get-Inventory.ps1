# Partie 2 - Inventaire du parc -> output\Inventory.csv
[CmdletBinding()]
param([pscredential]$Credential)
. (Join-Path $PSScriptRoot 'Common.ps1')

if (-not $Credential) { $Credential = Get-PMCredential }

# Bloc execute A DISTANCE sur chaque poste
$remote = {
    $os   = Get-CimInstance Win32_OperatingSystem
    $cs   = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $hf   = @(Get-HotFix -ErrorAction SilentlyContinue | Where-Object InstalledOn | Sort-Object InstalledOn -Descending)
    $wu   = Get-Service -Name wuauserv
    [pscustomobject]@{
        NomPoste       = $env:COMPUTERNAME
        Modele         = "$($cs.Manufacturer) $($cs.Model)"
        BiosVersion    = $bios.SMBIOSBIOSVersion
        Windows        = "$($os.Caption) (build $($os.BuildNumber), v$($os.Version))"
        Architecture   = $os.OSArchitecture
        DernierDemarr  = $os.LastBootUpTime
        RAM_Go         = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        DisqueLibre_Go = [math]::Round($disk.FreeSpace / 1GB, 1)
        DernierePatch  = if ($hf) { $hf[0].InstalledOn.ToString('yyyy-MM-dd') } else { '' }
        NbPatchs       = @(Get-HotFix -ErrorAction SilentlyContinue).Count
        WindowsUpdate  = [string]$wu.Status
    }
}

# Avec JEA (partie 7) : seule la fonction autorisee Get-PMInventoryData est appelable
if (Test-PMJea) { $remote = { Get-PMInventoryData } }

Write-PMLog "Debut de l'inventaire"
$inventory = foreach ($c in Read-PMComputers) {
    $row = [ordered]@{
        Poste = $c.Name; 'Adresse IP' = $c.IP; Etat = 'Inaccessible'
        NomPoste = ''; Modele = ''; BiosVersion = ''; Windows = ''; Architecture = ''
        DernierDemarr = ''; RAM_Go = ''; DisqueLibre_Go = ''
        DernierePatch = ''; NbPatchs = ''; WindowsUpdate = ''; Erreur = ''
    }
    $t = Test-PMHost -IP $c.IP
    if (-not $t.Reachable) {
        $row.Erreur = $t.Error
        Write-PMLog "$($c.Name) ; $($t.Error)"
    } else {
        try {
            $rp = Get-PMRemoteParams -IP $c.IP -Credential $Credential
            $r = Invoke-Command @rp -ScriptBlock $remote
            foreach ($p in 'NomPoste','Modele','BiosVersion','Windows','Architecture','RAM_Go','DisqueLibre_Go','DernierePatch','NbPatchs','WindowsUpdate') { $row[$p] = $r.$p }
            $row.DernierDemarr = $r.DernierDemarr.ToString('dd/MM/yyyy HH:mm')
            $row.Etat = 'Accessible'
            Write-PMLog "$($c.Name) ; Accessible"
        } catch {
            $row.Erreur = $_.Exception.Message
            Write-PMLog "$($c.Name) ; ERREUR commande distante ; $($_.Exception.Message)"
        }
    }
    [pscustomobject]$row
}

$inventory | Export-PMCsv -FileName 'Inventory.csv'
$inventory | Format-Table Poste, 'Adresse IP', Windows, Architecture, DernierDemarr, WindowsUpdate, Etat -AutoSize
Write-Host "Inventaire exporte : $(Get-PMOutputPath 'Inventory.csv')"
