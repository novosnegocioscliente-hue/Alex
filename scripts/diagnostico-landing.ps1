# Diagnostico de landing - VSL Host
# Uso: powershell -ExecutionPolicy Bypass -File .\diagnostico-landing.ps1 -Url "https://seu-dominio/"
param([string]$Url = "https://alkaburn-presell.boldhabitco.cloud/")

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$UaNavegador = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
$UaRobo      = "VSLHost-Validator/1.0"
$Hostname    = ([Uri]$Url).Host

Write-Host "`n== 1. DNS (seu provedor)" -ForegroundColor Cyan
try { Resolve-DnsName $Hostname -ErrorAction Stop | Format-Table Name,Type,IPAddress,NameHost -AutoSize | Out-String | Write-Host }
catch { Write-Host "FALHOU DNS: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "== 1b. DNS publico (Google 8.8.8.8 - o que o validador enxerga)" -ForegroundColor Cyan
try { Resolve-DnsName $Hostname -Server 8.8.8.8 -ErrorAction Stop | Format-Table Name,Type,IPAddress,NameHost -AutoSize | Out-String | Write-Host }
catch { Write-Host "FALHOU DNS PUBLICO: $($_.Exception.Message)" -ForegroundColor Red }

Write-Host "== 2. Porta 443" -ForegroundColor Cyan
Test-NetConnection $Hostname -Port 443 -WarningAction SilentlyContinue |
  Select-Object ComputerName,RemoteAddress,TcpTestSucceeded | Format-List | Out-String | Write-Host

Write-Host "== 3. Certificado SSL" -ForegroundColor Cyan
try {
  $global:ErroSsl = "None"
  $cb  = [Net.Security.RemoteCertificateValidationCallback]{ $global:ErroSsl = $args[3]; $true }
  $tcp = New-Object Net.Sockets.TcpClient($Hostname, 443)
  $ssl = New-Object Net.Security.SslStream($tcp.GetStream(), $false, $cb)
  $ssl.AuthenticateAsClient($Hostname)
  $c = New-Object Security.Cryptography.X509Certificates.X509Certificate2($ssl.RemoteCertificate)
  Write-Host "Emitido para : $($c.Subject)"
  Write-Host "Emissor      : $($c.Issuer)"
  Write-Host "Validade     : $($c.NotBefore) ate $($c.NotAfter)"
  $san = $c.Extensions | Where-Object { $_.Oid.Value -eq "2.5.29.17" } | ForEach-Object { $_.Format($false) }
  Write-Host "Nomes (SAN)  : $san"
  if ("$global:ErroSsl" -eq "None") { Write-Host "SSL VALIDO" -ForegroundColor Green }
  else { Write-Host "SSL INVALIDO: $global:ErroSsl" -ForegroundColor Red }
  $ssl.Dispose(); $tcp.Dispose()
} catch { Write-Host "FALHOU SSL: $($_.Exception.Message)" -ForegroundColor Red }

function Buscar([string]$u, [string]$ua) {
  for ($i = 0; $i -lt 8; $i++) {
    $r = [Net.HttpWebRequest]::Create($u)
    $r.AllowAutoRedirect = $false; $r.UserAgent = $ua; $r.Timeout = 20000
    try { $resp = $r.GetResponse() }
    catch [Net.WebException] {
      $resp = $_.Exception.Response
      if (-not $resp) { Write-Host "  ERRO: $($_.Exception.Status) - $($_.Exception.Message)" -ForegroundColor Red; return $null }
    }
    $code = [int]$resp.StatusCode
    $cor = if ($code -lt 300) { "Green" } elseif ($code -lt 400) { "Yellow" } else { "Red" }
    Write-Host "  $code  $u" -ForegroundColor $cor
    if ($code -ge 300 -and $code -lt 400) {
      $loc = $resp.Headers["Location"]; $resp.Close()
      $u = ([Uri]::new([Uri]$u, $loc)).AbsoluteUri; continue
    }
    $html = (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd()
    Write-Host "  Server: $($resp.Headers['Server']) | Tamanho: $($html.Length) chars"
    $resp.Close()
    if ($html -match "(?is)<title>(.*?)</title>") { Write-Host "  Titulo: $($matches[1].Trim())" }
    return @{ Url = $u; Html = $html; Code = $code }
  }
  Write-Host "  Redirecionamentos demais (loop?)" -ForegroundColor Red
}

Write-Host "`n== 4. Acesso como NAVEGADOR" -ForegroundColor Cyan
$nav = Buscar $Url $UaNavegador
Write-Host "== 5. Acesso como ROBO (como o validador do servidor)" -ForegroundColor Cyan
$bot = Buscar $Url $UaRobo
if ($nav -and $bot -and ($nav.Html.Length -ne $bot.Html.Length)) {
  Write-Host "  ATENCAO: robo recebe pagina diferente do navegador (cloaker/firewall?)" -ForegroundColor Yellow
}

if ($nav) {
  Write-Host "`n== 6. Script / pixel instalado?" -ForegroundColor Cyan
  $scripts = [regex]::Matches($nav.Html, '(?is)<script[^>]+src\s*=\s*["'']([^"'']+)') | ForEach-Object { $_.Groups[1].Value }
  $scripts | ForEach-Object { Write-Host "  script: $_" }
  if ($nav.Html -match "(?i)pixel") { Write-Host "  Palavra 'pixel' encontrada no HTML" -ForegroundColor Green }
  else { Write-Host "  Nenhum 'pixel' no HTML (script pode nao estar instalado)" -ForegroundColor Red }

  Write-Host "`n== 7. Todos os caminhos/links da pagina" -ForegroundColor Cyan
  $base = [Uri]$nav.Url
  $links = [regex]::Matches($nav.Html, '(?is)(?:href|src|action)\s*=\s*["'']([^"''#]+)') |
    ForEach-Object { $_.Groups[1].Value } |
    Where-Object { $_ -notmatch '^(mailto:|tel:|javascript:|data:)' } | Sort-Object -Unique
  foreach ($l in $links) {
    try { $abs = ([Uri]::new($base, $l)).AbsoluteUri } catch { continue }
    $r = [Net.HttpWebRequest]::Create($abs); $r.UserAgent = $UaNavegador; $r.Timeout = 15000
    try { $resp = $r.GetResponse(); $code = [int]$resp.StatusCode; $resp.Close() }
    catch [Net.WebException] { $code = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { "ERRO:" + $_.Exception.Status } }
    $cor = if ("$code" -match '^2') { "Green" } else { "Red" }
    Write-Host ("  {0,-12} {1}" -f $code, $abs) -ForegroundColor $cor
  }
}
Write-Host "`nFim. Copie TODA a saida e cole na conversa." -ForegroundColor Cyan
