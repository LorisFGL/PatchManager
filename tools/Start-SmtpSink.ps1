# Start-SmtpSink.ps1 - serveur SMTP de TEST (labo uniquement) : accepte les messages
# sur 127.0.0.1:25 et les enregistre en .eml dans output\mailbox. Ne relaie rien.
param([int]$Port = 25, [string]$MailDir = (Join-Path (Split-Path $PSScriptRoot) 'output\mailbox'))

if (-not (Test-Path $MailDir)) { New-Item -ItemType Directory -Path $MailDir | Out-Null }
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Host "SMTP de test en ecoute sur 127.0.0.1:$Port -> $MailDir (Ctrl+C pour arreter)" -ForegroundColor Green

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = [System.IO.StreamReader]::new($stream)
        $writer = [System.IO.StreamWriter]::new($stream); $writer.NewLine = "`r`n"; $writer.AutoFlush = $true
        $writer.WriteLine('220 smtp-test.lab ESMTP')
        $from = ''; $to = @()
        while ($null -ne ($line = $reader.ReadLine())) {
            switch -Regex ($line) {
                '^(EHLO|HELO)' { $writer.WriteLine('250 smtp-test.lab') }
                '^MAIL FROM:'  { $from = $line.Substring(10); $writer.WriteLine('250 OK') }
                '^RCPT TO:'    { $to += $line.Substring(8); $writer.WriteLine('250 OK') }
                '^DATA'        {
                    $writer.WriteLine('354 Fin avec <CRLF>.<CRLF>')
                    $sb = [System.Text.StringBuilder]::new()
                    while (($l = $reader.ReadLine()) -ne '.') { [void]$sb.AppendLine($l) }
                    $file = Join-Path $MailDir ('{0:yyyyMMdd-HHmmss}.eml' -f (Get-Date))
                    Set-Content -Path $file -Value $sb.ToString() -Encoding ASCII
                    Write-Host ("{0:HH:mm:ss} message recu de {1} pour {2} -> {3}" -f (Get-Date), $from, ($to -join ','), $file) -ForegroundColor Cyan
                    $writer.WriteLine('250 OK message enregistre')
                }
                '^QUIT'        { $writer.WriteLine('221 Bye'); break }
                default        { $writer.WriteLine('250 OK') }
            }
        }
        $client.Close()
    }
} finally { $listener.Stop() }
