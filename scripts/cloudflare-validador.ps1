# Cloudflare - checa e libera o acesso do validador do VSL Host
# Uso: powershell -ExecutionPolicy Bypass -File .\cloudflare-validador.ps1
param([string]$Dominio = "boldhabitco.cloud", [string]$Host_ = "alkaburn-presell.boldhabitco.cloud")
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Api = "https://api.cloudflare.com/client/v4"

$sec = Read-Host "Cole o TOKEN da Cloudflare (nao aparece na tela) e aperte Enter" -AsSecureString
$Token = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
$H = @{ Authorization = "Bearer $Token" }

function CF($metodo, $caminho, $corpo) {
  try {
    if ($corpo) { return Invoke-RestMethod -Method $metodo -Uri "$Api$caminho" -Headers $H -ContentType "application/json" -Body ($corpo | ConvertTo-Json -Depth 10) }
    return Invoke-RestMethod -Method $metodo -Uri "$Api$caminho" -Headers $H
  } catch {
    $msg = $_.ErrorDetails.Message; if (-not $msg) { $msg = $_.Exception.Message }
    Write-Host "  ERRO em $metodo $caminho : $msg" -ForegroundColor Red; return $null
  }
}

Write-Host "`n== 1. Token" -ForegroundColor Cyan
$v = CF GET "/user/tokens/verify"
if (-not $v) { Write-Host "Token invalido. Confira se copiou inteiro." -ForegroundColor Red; exit }
Write-Host "  Token OK ($($v.result.status))" -ForegroundColor Green

Write-Host "`n== 2. Zona $Dominio" -ForegroundColor Cyan
$z = CF GET "/zones?name=$Dominio"
if (-not $z -or $z.result.Count -eq 0) { Write-Host "  Zona nao encontrada. O token precisa incluir $Dominio." -ForegroundColor Red; exit }
$Zid = $z.result[0].id
Write-Host "  Plano: $($z.result[0].plan.name) | Status: $($z.result[0].status)"

Write-Host "`n== 3. Configuracoes de seguranca" -ForegroundColor Cyan
$sl = CF GET "/zones/$Zid/settings/security_level"
$bic = CF GET "/zones/$Zid/settings/browser_check"
$bm = CF GET "/zones/$Zid/bot_management"
Write-Host "  Security Level ........: $($sl.result.value)"
Write-Host "  Browser Integrity Check: $($bic.result.value)"
if ($bm) {
  Write-Host "  Bot Fight Mode ........: $($bm.result.fight_mode)"
  $bm.result.PSObject.Properties | Where-Object { $_.Name -like "sbfm_*" -or $_.Name -like "ai_bots*" } |
    ForEach-Object { Write-Host ("  {0,-23}: {1}" -f $_.Name, $_.Value) }
}

Write-Host "`n== 4. Bloqueios nas ultimas 24h em $Host_" -ForegroundColor Cyan
$ini = (Get-Date).ToUniversalTime().AddHours(-24).ToString("yyyy-MM-ddTHH:mm:ssZ")
$fim = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$q = 'query { viewer { zones(filter:{zoneTag:"' + $Zid + '"}) { firewallEventsAdaptive(filter:{datetime_geq:"' + $ini + '", datetime_leq:"' + $fim + '", clientRequestHTTPHost:"' + $Host_ + '"}, limit:25, orderBy:[datetime_DESC]) { datetime action source clientIP clientASNDescription clientCountryName userAgent clientRequestPath } } } }'
try {
  $g = Invoke-RestMethod -Method POST -Uri "$Api/graphql" -Headers $H -ContentType "application/json" -Body (@{ query = $q } | ConvertTo-Json)
  if ($g.errors) { Write-Host "  GraphQL: $($g.errors[0].message)" -ForegroundColor Yellow }
  $ev = $g.data.viewer.zones[0].firewallEventsAdaptive
  if (-not $ev -or $ev.Count -eq 0) { Write-Host "  Nenhum bloqueio registrado." -ForegroundColor Green }
  else { $ev | Format-Table datetime,action,source,clientIP,clientASNDescription,clientCountryName,clientRequestPath,userAgent -AutoSize | Out-String -Width 400 | Write-Host }
} catch { Write-Host "  Nao foi possivel ler eventos: $($_.Exception.Message)" -ForegroundColor Yellow }

Write-Host "`n== 5. Correcao" -ForegroundColor Cyan
$precisa = ($bm -and $bm.result.fight_mode -eq $true) -or ($sl -and $sl.result.value -eq "under_attack")
if (-not $precisa) { Write-Host "  Nada a mudar: Bot Fight Mode desligado e Security Level normal." -ForegroundColor Green }
else {
  $r = Read-Host "  Desligar Bot Fight Mode e tirar 'Under Attack' (se ligado)? Digite S para confirmar"
  if ($r -eq "S" -or $r -eq "s") {
    if ($bm.result.fight_mode -eq $true) {
      $x = CF PUT "/zones/$Zid/bot_management" @{ fight_mode = $false }
      if ($x) { Write-Host "  Bot Fight Mode DESLIGADO" -ForegroundColor Green }
    }
    if ($sl.result.value -eq "under_attack") {
      $x = CF PATCH "/zones/$Zid/settings/security_level" @{ value = "medium" }
      if ($x) { Write-Host "  Security Level -> medium" -ForegroundColor Green }
    }
  } else { Write-Host "  Nada foi alterado." }
}
$Token = $null
Write-Host "`nFim. Copie TODA a saida (nao tem o token nela) e cole na conversa." -ForegroundColor Cyan
