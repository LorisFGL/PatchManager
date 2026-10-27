@{
    # Dossiers (relatifs a la racine du projet)
    OutputDir      = 'output'
    LogFile        = 'logs\PatchManager.log'

    # Fichiers de configuration
    ComputersFile  = 'config\computers.txt'
    RequiredFile   = 'config\required-patches.txt'

    # Partie 7 (moindre privilege) : compte de service svc-patch (non administrateur)
    # + point de terminaison JEA "PatchAudit" (tools\Install-PatchAuditJEA.ps1).
    # Credential chiffre DPAPI ; sans fichier, l'identite de la session courante est utilisee.
    CredentialFile       = 'config\svcpatch.cred.xml'
    JEAConfigurationName = 'PatchAudit'
    # Mode administrateur (avant la partie 7) : CredentialFile = 'config\psremote.cred.xml' et JEAConfigurationName = ''

    # Notification SMTP (aucun mot de passe en clair : voir smtp.cred.xml)
    # LABO : serveur de test local (tools\Start-SmtpSink.ps1) -> 127.0.0.1:25 sans TLS.
    # PRODUCTION : Server = 'smtp.entreprise.local', Port = 587, UseSsl = $true + smtp.cred.xml
    Smtp = @{
        Server         = '127.0.0.1'
        Port           = 25
        UseSsl         = $false
        From           = 'patchmanager@entreprise.local'
        To             = 'admin@entreprise.local'
        CredentialFile = 'config\smtp.cred.xml'
    }
}
