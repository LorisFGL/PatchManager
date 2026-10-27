# Install-PatchAuditJEA.ps1 - Partie 7.7 : point de terminaison JEA "PatchAudit"
# Le compte svc-patch (non administrateur) ne peut executer QUE 2 fonctions de lecture,
# en mode NoLanguage, sous un compte virtuel temporaire, avec transcription de chaque session.
param(
    [string[]]$Computers = @('172.16.26.11', '172.16.26.12'),
    [string]$ServiceAccount = 'svc-patch',
    [pscredential]$AdminCredential = (Import-Clixml (Join-Path (Split-Path $PSScriptRoot) 'config\psremote.cred.xml'))
)

$install = {
    param($svc)
    $mod = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\PatchAuditJEA'
    New-Item -ItemType Directory -Path (Join-Path $mod 'RoleCapabilities') -Force | Out-Null
    New-ModuleManifest -Path (Join-Path $mod 'PatchAuditJEA.psd1') -ModuleVersion 1.0

    $inventory = {
        $os   = Get-CimInstance Win32_OperatingSystem
        $cs   = Get-CimInstance Win32_ComputerSystem
        $bios = Get-CimInstance Win32_BIOS
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
        $hf   = @(Get-HotFix -ErrorAction SilentlyContinue)
        # (pas de Select-Object -First : JEA restreint Select-Object a -Property)
        $sorted = @($hf | Where-Object InstalledOn | Sort-Object InstalledOn -Descending)
        $last = if ($sorted.Count) { $sorted[0] } else { $null }
        [pscustomobject]@{
            NomPoste       = $env:COMPUTERNAME
            Modele         = "$($cs.Manufacturer) $($cs.Model)"
            BiosVersion    = $bios.SMBIOSBIOSVersion
            Windows        = "$($os.Caption) (build $($os.BuildNumber), v$($os.Version))"
            Architecture   = $os.OSArchitecture
            DernierDemarr  = $os.LastBootUpTime
            RAM_Go         = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
            DisqueLibre_Go = [math]::Round($disk.FreeSpace / 1GB, 1)
            DernierePatch  = if ($last) { $last.InstalledOn.ToString('yyyy-MM-dd') } else { '' }
            NbPatchs       = $hf.Count
            WindowsUpdate  = [string](Get-Service -Name wuauserv).Status
        }
    }
    $hotfix = {
        Get-HotFix | ForEach-Object {
            [pscustomobject]@{
                KB          = $_.HotFixID
                Description = $_.Description
                Date        = if ($_.InstalledOn) { $_.InstalledOn.ToString('yyyy-MM-dd') } else { '' }
                InstalledBy = $_.InstalledBy
            }
        }
    }

    New-PSRoleCapabilityFile -Path (Join-Path $mod 'RoleCapabilities\PatchAuditor.psrc') `
        -Description 'Lecture seule : inventaire et correctifs' `
        -ModulesToImport 'CimCmdlets' `
        -VisibleFunctions 'Get-PMInventoryData', 'Get-PMHotFix' `
        -FunctionDefinitions @{ Name = 'Get-PMInventoryData'; ScriptBlock = $inventory },
                             @{ Name = 'Get-PMHotFix';        ScriptBlock = $hotfix }

    $pssc = Join-Path $env:TEMP 'PatchAudit.pssc'
    New-PSSessionConfigurationFile -Path $pssc -SessionType RestrictedRemoteServer -RunAsVirtualAccount `
        -TranscriptDirectory 'C:\ProgramData\JEA\Transcripts' `
        -RoleDefinitions @{ "$env:COMPUTERNAME\$svc" = @{ RoleCapabilities = 'PatchAuditor' } }

    if (Get-PSSessionConfiguration -Name PatchAudit -ErrorAction SilentlyContinue) {
        Unregister-PSSessionConfiguration -Name PatchAudit -NoServiceRestart -Force
    }
    Register-PSSessionConfiguration -Name PatchAudit -Path $pssc -NoServiceRestart -Force | Out-Null
    # redemarrage differe de WinRM (sinon la session distante courante serait coupee)
    $action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -Command "Start-Sleep 5; Restart-Service WinRM -Force"'
    Register-ScheduledTask -TaskName 'RestartWinRM-JEA' -Action $action -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
    Start-ScheduledTask -TaskName 'RestartWinRM-JEA'
    "$env:COMPUTERNAME : point de terminaison JEA 'PatchAudit' enregistre pour $env:COMPUTERNAME\$svc"
}

Invoke-Command -ComputerName $Computers -Credential $AdminCredential -ScriptBlock $install -ArgumentList $ServiceAccount
