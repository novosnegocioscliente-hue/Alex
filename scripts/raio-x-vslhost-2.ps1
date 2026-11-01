& { param($R = "C:\FABRICA\VSL_HOST")
$o = New-Object Collections.Generic.List[string]
function W($t) { $s = [string]$t -replace '(?i)((token|key|secret|senha|password|bearer|authorization)[^\r\n]{0,8}?[:=]\s*["'']?)[^"''\s,;]{8,}', '$1***' -replace '[A-Za-z0-9_\-]{36,}', '***'; if ($s.Length -gt 700) { $s = $s.Substring(0, 700) + ' [...]' }; $o.Add($s) }
function G($x, $k) { if ($x -is [Collections.IDictionary]) { $x[$k] } else { $x.$k } }
function Arq($rel) { $p = Join-Path $R $rel; W "`n######## ARQUIVO: $rel"; if (Test-Path $p) { $i = 0; Get-Content $p -Encoding UTF8 | % { $i++; W ("{0,5}| {1}" -f $i, $_) } } else { W '(nao existe)' } }
function Perto($rel, $padrao, $max = 8) { $p = Join-Path $R $rel; W "`n######## TRECHOS ($padrao) EM: $rel"; if (-not (Test-Path $p)) { W '(nao existe)'; return }
  $h = Get-Content $p -Raw -Encoding UTF8; $ms = [regex]::Matches($h, $padrao, 'IgnoreCase'); W "  ocorrencias: $($ms.Count)"
  $ms | Select -First $max | % { $a = [Math]::Max(0, $_.Index - 220); $n = [Math]::Min($h.Length - $a, 520); W ('  >> ' + ($h.Substring($a, $n) -replace '\s+', ' ')) } }
function Links($rel) { $p = Join-Path $R $rel; W "`n######## LINKS <a href> EM: $rel"; if (-not (Test-Path $p)) { W '(nao existe)'; return }
  $h = Get-Content $p -Raw -Encoding UTF8; [regex]::Matches($h, '<a\b[^>]*?href\s*=\s*["'']([^"'']+)["''][^>]*>(.{0,80}?)</a>', 'IgnoreCase,Singleline') | % { '{0}  <=  {1}' -f $_.Groups[1].Value, (($_.Groups[2].Value -replace '<[^>]+>', '' -replace '\s+', ' ').Trim()) } | Select -Unique -First 40 | % { W "  $_" } }
W "##### RAIO-X 2 VSL HOST $(Get-Date -f s) #####"
Arq 'painel\lib\teste.js'
Arq 'painel\lib\funil.js'
Arq 'entrada\anexos\lmvx94qo54j0b\Kings_code_page.zip_x\LEIA-ME.txt'
W "`n######## FUNIS SALVOS (dados\funis.json)"
try {
  $txt = Get-Content (Join-Path $R 'dados\funis.json') -Raw -Encoding UTF8
  try { Add-Type -AssemblyName System.Web.Extensions; $js = New-Object Web.Script.Serialization.JavaScriptSerializer; $js.MaxJsonLength = [int]::MaxValue; $fj = $js.DeserializeObject($txt) } catch { $fj = $txt | ConvertFrom-Json }
  $fs = if ((G $fj 'funis')) { G $fj 'funis' } else { $fj }
  foreach ($f in @($fs)) {
    W ("--- {0} | slug={1} | modelo={2} | dominios={3}" -f (G $f 'nome'), (G $f 'slug'), (G $f 'modelo'), ((G $f 'dominios') -join ','))
    W ("    checkout={0}" -f (G $f 'checkout'))
    $k = 0; foreach ($e in @(G $f 'etapas')) { $k++; $h = [string](G $e 'html')
      W ("    etapa {0}: pasta={1} | video={2} | ctaEm={3} | botao={4} | html={5:N0}KB | vturb={6} | titulo={7}" -f $k, (G $e 'pasta'), (G $e 'video'), (G $e 'ctaEm'), (G $e 'mostrarBotao'), ($h.Length / 1KB), ([regex]::IsMatch($h, '(?i)vturb|converteai')), ([regex]::Match($h, '(?is)<title>(.*?)</title>').Groups[1].Value.Trim()))
      $l = G $e 'links'; if ($l) { if ($l -is [Collections.IDictionary]) { $l.Keys | % { W "        link: $_ -> $($l[$_])" } } else { $l.PSObject.Properties | % { W "        link: $($_.Name) -> $($_.Value)" } } } }
    $pub = G $f 'publicado'; if ($pub) { W ("    publicado em: {0}" -f (@(if ($pub -is [Collections.IDictionary]) { $pub.Keys } else { $pub.PSObject.Properties.Name }) -join ', ')) }
  }
} catch { W "ERRO lendo funis.json: $($_.Exception.Message)" }
Perto 'entrada\anexos\lmvx94qo54j0b\Kings_code_page.zip_x\index.html' 'vturb|converteai|smartplayer'
Links 'entrada\anexos\lmvx94qo54j0b\Kings_code_page.zip_x\index.html'
Perto 'sites\oferta-kings-code-page\index.html' 'vturb|converteai|smartplayer|vsl-player|<title'
Perto 'sites\oferta-kings-code-page\vsl\index.html' 'vturb|converteai|smartplayer|vsl-player|"botoes"|<title'
Links 'sites\oferta-kings-code-page\vsl\index.html'
$txt = $o -join "`r`n"; $d = [Environment]::GetFolderPath('Desktop'); if (-not $d) { $d = $HOME }; $arq = Join-Path $d 'raio-x-vslhost-2.txt'
$txt | Set-Content $arq -Encoding UTF8
Write-Host "`nPRONTO: $($o.Count) linhas em $arq" -ForegroundColor Green
notepad $arq
}
