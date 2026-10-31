# PatchManager — Patch Management Windows en PowerShell

Projet *Sécurité des systèmes* : audit centralisé des correctifs d'un parc Windows via PowerShell Remoting (WinRM).

`computers.txt` → disponibilité (ping + WinRM) → inventaire → correctifs → conformité → rapport CSV/HTML + journal → notification → sécurisation (compte non admin + JEA).

**Vidéo de démonstration :** https://youtu.be/YpbXMxrxyQs — **Rapport :** [rapport/Rapport_PatchManagement.pdf](rapport/Rapport_PatchManagement.pdf)

## Structure

| Fichier | Rôle |
|---|---|
| `Common.ps1` | Fonctions communes (configuration, journal, tests, credential) |
| `01-Test-Environment.ps1` | Partie 1 : lecture de `computers.txt` et disponibilité |
| `02-Get-Inventory.ps1` | Partie 2 : inventaire système → `output/Inventory.csv` |
| `03-Get-PatchInventory.ps1` | Partie 3 : correctifs → `output/PatchesInventory.csv`, `PatchSummary.csv` |
| `04-Test-Compliance.ps1` | Partie 4 : conformité → `output/ComplianceReport.csv` + taux |
| `05-New-Report.ps1` | Partie 5 : rapport → `output/SecurityReport.csv` / `.html` |
| `06-Send-Notification.ps1` | Partie 6 : notification si anomalie |
| `PatchManager.ps1` | Orchestrateur (parties 2 à 6) + journal `logs/PatchManager.log` |
| `tools/New-PatchServiceAccount.ps1` | Partie 7 : compte de service `svc-patch` non administrateur |
| `tools/Install-PatchAuditJEA.ps1` | Partie 7 : point de terminaison JEA `PatchAudit` |
| `tools/Start-SmtpSink.ps1` | Serveur SMTP de test (laboratoire uniquement) |
| `config/` | `computers.txt`, `required-patches.txt`, `settings.psd1` |
| `rapport/` | Rapport du projet (Markdown + Word) |
| `screenshots/` | Captures de l'exécution sur l'environnement de test |

## Prérequis

- Windows PowerShell 5.1, postes Windows 10/11 avec `Enable-PSRemoting -Force`
- Hors domaine : IP du parc dans `WSMan:\localhost\Client\TrustedHosts` du poste d'administration (liste explicite)

## Utilisation

```powershell
Set-ExecutionPolicy -Scope Process Bypass
Get-Credential | Export-Clixml .\config\psremote.cred.xml   # chiffré DPAPI, jamais versionné
.\tools\New-PatchServiceAccount.ps1                         # partie 7
.\tools\Install-PatchAuditJEA.ps1                           # partie 7
.\PatchManager.ps1                                          # audit complet
```

Sans la partie 7, mettre dans `config/settings.psd1` : `CredentialFile = 'config\psremote.cred.xml'` et `JEAConfigurationName = ''`.

## Sécurité

Aucun secret n'est stocké en clair : les identifiants sont des fichiers `*.cred.xml` chiffrés DPAPI, exclus du dépôt (`.gitignore`), tout comme `output/` et `logs/`.
