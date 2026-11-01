& { $R = "C:\FABRICA\VSL_HOST"; $API = "http://localhost:8091"
$o = New-Object Collections.Generic.List[string]
function W($t) { $s = [string]$t -replace '(?i)((token|key|secret|senha|password|bearer|authorization)[^\r\n]{0,8}?[:=]\s*["'']?)[^"''\s,;]{8,}', '$1***' -replace '[A-Za-z0-9_\-]{36,}', '***'; if ($s.Length -gt 600) { $s = $s.Substring(0, 600) + ' [...]' }; $o.Add($s) }
W "##### PUBLICAR + RAIO-X 3 VSL HOST $(Get-Date -f s) #####"
# 1) painel no ar?
$ok = $false; for ($i = 0; $i -lt 15 -and -not $ok; $i++) { try { Invoke-RestMethod "$API/api/estado" -TimeoutSec 5 | Out-Null; $ok = $true } catch { Start-Sleep 2 } }
if (-not $ok) { Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$R\PAINEL.ps1`"" -WindowStyle Minimized; Start-Sleep 8
  try { Invoke-RestMethod "$API/api/estado" -TimeoutSec 10 | Out-Null; $ok = $true } catch { } }
if (-not $ok) { W "ERRO: o painel nao respondeu em $API" } else {
  # 2) publica o funil Kings (o mesmo que clicar em Publicar)
  Add-Type -AssemblyName System.Web.Extensions; $js = New-Object Web.Script.Serialization.JavaScriptSerializer; $js.MaxJsonLength = [int]::MaxValue
  $fj = $js.DeserializeObject((Get-Content "$R\dados\funis.json" -Raw -Encoding UTF8)); $lista = if ($fj -is [Collections.IDictionary]) { $fj['funis'] } else { $fj }
  $f = @($lista) | ? { $_['slug'] -eq 'kings-code-page' } | Select -First 1
  if (-not $f) { W "ERRO: funil kings-code-page nao encontrado" } else {
    W "Funil: $($f['nome']) | modelo: $($f['modelo']) | id: $($f['id'])"
    try { $r = Invoke-RestMethod "$API/api/funis/publicar" -Method Post -ContentType 'application/json' -Body (@{ id = $f['id'] } | ConvertTo-Json) -TimeoutSec 30; W ("Publicar respondeu: " + ($r | ConvertTo-Json -Depth 4 -Compress)) } catch { W "ERRO ao publicar: $($_.Exception.Message) $($_.ErrorDetails.Message)" }
    # 3) acompanha a publicacao + teste (ate 6 min), guardando as mensagens novas
    $vistos = New-Object Collections.Generic.HashSet[string]; $fim = (Get-Date).AddMinutes(6)
    while ((Get-Date) -lt $fim) {
      Start-Sleep 5
      try { $txt = (Invoke-WebRequest "$API/api/estado" -UseBasicParsing -TimeoutSec 15).Content } catch { continue }
      $msgs = [regex]::Matches($txt, '"((?:[^"\\]|\\.){0,400}?(?:\[(?:OK|ERRO|ATENCAO)\]|Etapa \d|FUNIL COMPLETO|NAO se completou|Ligando|Enviando|Publicad|ativando|=====)(?:[^"\\]|\\.){0,400}?)"') | % { $_.Groups[1].Value -replace '\\u00e7', 'c' -replace '\\"', '"' }
      foreach ($m in $msgs) { if ($vistos.Add($m)) { W "  $m" } }
      if ($msgs | ? { $_ -match 'FUNIL COMPLETO|NAO se completou' }) { break }
    }
  }
}
# 4) raio-x do delay: como o player revela a oferta e como a pagina esconde
W "`n=== COMO O PLAYER REVELA (vsl-player.js, parte JavaScript)"
$pj = "$R\player\vsl-player.js"; $l = Get-Content $pj
$hits = Select-String -Path $pj -Pattern 'delay|seletor|smartplayer|vturb|dispatchEvent|CustomEvent|instances' | ? { $_.Line -notmatch "^\s*'" } | Select -First 12
foreach ($h in $hits) { W ">> linha $($h.LineNumber)"; $a = [Math]::Max(0, $h.LineNumber - 3); $b = [Math]::Min($l.Count - 1, $h.LineNumber + 10); for ($i = $a; $i -le $b; $i++) { W ("{0,5}| {1}" -f ($i + 1), $l[$i]) } }
W "`n=== COMO A PAGINA KINGS ESCONDE A OFERTA (index.html original)"
$hp = Get-Content "$R\entrada\anexos\lmvx94qo54j0b\Kings_code_page.zip_x\index.html" -Raw -Encoding UTF8
[regex]::Matches($hp, '\.hide\s*\{[^}]*\}|<main\b[^>]*>') | Select -First 6 | % { W "  CSS/TAG: $($_.Value)" }
[regex]::Matches($hp, '<script\b[^>]*>([\s\S]*?)</script>') | ? { $_.Groups[1].Value -match 'delaySeconds|\.hide|classList|vturb|smartplayer' } | Select -First 4 | % {
  W "  --- SCRIPT ($($_.Groups[1].Value.Length) caracteres):"; ($_.Groups[1].Value -split "`n") | % { W "    $_" } }
$txt = $o -join "`r`n"; $d = [Environment]::GetFolderPath('Desktop'); if (-not $d) { $d = $HOME }; $arq = Join-Path $d 'publicar-vslhost.txt'
$txt | Set-Content $arq -Encoding UTF8
Write-Host "`nPRONTO. Resultado em $arq" -ForegroundColor Green
notepad $arq
}
