# Script de la vidéo (~15 min)

À faire **avant d'enregistrer** : démarrer PC01 et PC02, ouvrir PowerShell **administrateur** sur PC01, `cd C:\PatchManager`, agrandir la fenêtre, et lancer le serveur mail de test dans une 2e fenêtre :
`Start-Process powershell -ArgumentList '-NoExit','-File','C:\PatchManager\tools\Start-SmtpSink.ps1'`
Logiciel conseillé : OBS (déjà installé sur votre Mac) ou QuickTime (Fichier → Nouvel enregistrement de l'écran).

| Temps | Ce que vous montrez | Ce que vous dites (idée) |
|---|---|---|
| 0:00–1:30 | Le schéma du rapport (section 2) | Contexte Patch Management, 2 VM Windows 11 sur VMware, PC01 = admin, PC02 supervisé, PC03 simule un poste éteint. |
| 1:30–3:30 | `Get-Content .\config\computers.txt` puis `.\01-Test-Environment.ps1` puis `Test-WSMan 172.16.26.12` | Rôle de WinRM (port 5985), différence ping / Test-WSMan, pourquoi tester avant. |
| 3:30–4:30 | `Enter-PSSession 172.16.26.12 -Credential (Import-Clixml .\config\psremote.cred.xml)` → `hostname` → `Exit-PSSession` | Session interactive vs `Invoke-Command` (non interactive, parallèle). |
| 4:30–6:00 | `.\02-Get-Inventory.ps1` | Les infos collectées, PC03 inaccessible sans bloquer le script, export CSV. |
| 6:00–7:30 | `.\03-Get-PatchInventory.ps1` | Get-HotFix, tri par date, nombre de correctifs, dernière KB. |
| 7:30–9:00 | `Get-Content .\config\required-patches.txt` puis `.\04-Test-Compliance.ps1` | Politique, CONFORME / NON CONFORME / INACCESSIBLE, taux 50 % sans les inaccessibles. |
| 9:00–10:30 | `.\05-New-Report.ps1` puis `Start-Process .\output\SecurityReport.html` | Synthèse, postes à traiter, journal. |
| 10:30–11:30 | `.\06-Send-Notification.ps1` + montrer la fenêtre du serveur de test | Envoi seulement si anomalie, pièce jointe, pas de mot de passe en clair, alternatives (Graph, Teams, Intune…). |
| 11:30–12:30 | `.\PatchManager.ps1` puis `Get-Content .\logs\PatchManager.log -Tail 14` | Exécution complète, début/fin d'audit. |
| 12:30–14:30 | Montrer `config\settings.psd1` (svc-patch + JEA), les captures P7-4 (ACL), P7-5 (pare-feu), P7-7 (JEA) | Moindre privilège, JEA (commandes interdites refusées), pare-feu limité à PC01, Kerberos vs NTLM. |
| 14:30–15:00 | — | Bilan, limites (Get-HotFix, séquentiel), problème SID/Sysprep rencontré. |

Conseil : relisez les réponses aux questions dans le rapport avant d'enregistrer ; parlez de ce que *vous* comprenez, pas en lisant.
