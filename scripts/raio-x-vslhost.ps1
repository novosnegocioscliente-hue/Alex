& { param($R = "C:\FABRICA\VSL_HOST")
$S = [regex]::Escape([IO.Path]::DirectorySeparatorChar); $o = New-Object Collections.Generic.List[string]
function W($t) { $o.Add(([string]$t -replace '(?i)((token|key|secret|senha|password|bearer|authorization)[^\r\n]{0,8}?[:=]\s*["'']?)[^"''\s,;]{8,}', '$1***' -replace '[A-Za-z0-9_\-]{36,}', '***')) }
$fora = "$S(node_modules|\.git|venv|\.venv|__pycache__|dist|build|\.wrangler|\.next|\.cache)$S"
$dados = "$S(entrada|saida|anexos|paginas|uploads|media|videos|publicado|output)$S"
$todos = Get-ChildItem $R -Recurse -File -Force -EA SilentlyContinue | ? { $_.FullName -notmatch $fora }
$cod = $todos | ? { $_.Extension -match '^\.(js|mjs|cjs|ts|tsx|jsx|py|ps1|bat|cmd|json|toml|yml|yaml|html|css)$' -and $_.FullName -notmatch $dados -and $_.Name -notlike '.env*' -and $_.Name -ne 'package-lock.json' -and $_.Length -lt 1.5MB }
W "##### RAIO-X VSL HOST $(Get-Date -f s) #####"
W "`n=== 1. ARQUIVOS DE CODIGO (bytes / caminho)"; $cod | % { W ("{0,8}  {1}" -f $_.Length, $_.FullName.Substring($R.Length + 1)) }
W "`n=== 2. PASTAS"; Get-ChildItem $R -Directory -Force | % { $m = Get-ChildItem $_.FullName -Recurse -File -EA SilentlyContinue | Measure-Object Length -Sum; W ("{0,6} arqs {1,10:N0} KB  {2}" -f $m.Count, ($m.Sum / 1KB), $_.Name) }
W "`n=== 3. package.json / requirements"; $cod | ? { $_.Name -in 'package.json', 'requirements.txt', 'pyproject.toml' } | % { W "--- $($_.Name)"; Get-Content $_.FullName | % { W $_ } }
W "`n=== 4. TRECHOS-CHAVE"
$termos = 'Nenhum botao de compra', 'Nenhum player', '\[VSL\]', 'vsl-hide', 'Botao de compra abaixo', 'caminho local', 'Testando o funil', 'pages\.dev|wrangler|pages/projects', 'marque links como checkout', 'Proxima etapa|proxima etapa'
foreach ($t in $termos) { W "`n##### busca: $t"
  $cod | Select-String -Pattern $t -EA SilentlyContinue | Select -First 3 | % {
    W ">> $($_.Path.Substring($R.Length + 1)):$($_.LineNumber)"
    $l = Get-Content $_.Path; $a = [Math]::Max(0, $_.LineNumber - 6); $b = [Math]::Min($l.Count - 1, $_.LineNumber + 25)
    for ($i = $a; $i -le $b; $i++) { W ("{0,5}| {1}" -f ($i + 1), $l[$i]) } } }
W "`n=== 5. PLAYER VTURB/CONVERTEAI NOS DADOS (paginas salvas)"
$todos | ? { $_.Length -lt 20MB -and $_.Extension -match '^\.(html|htm|json|txt|js|db|sqlite)$' } | Select-String -Pattern 'converteai|vturb-smartplayer|vturb' -List -EA SilentlyContinue | % { W ("{0}  ({1:N0} KB)" -f $_.Path.Substring($R.Length + 1), ((Get-Item $_.Path).Length / 1KB)) }
$txt = $o -join "`r`n"; $d = [Environment]::GetFolderPath('Desktop'); if (-not $d) { $d = $HOME }; $arq = Join-Path $d 'raio-x-vslhost.txt'
$txt | Set-Content $arq -Encoding UTF8; try { $txt | Set-Clipboard; $c = 'e JA COPIADO' } catch { $c = '' }
Write-Host "`nPRONTO: $($o.Count) linhas salvas em $arq $c. Agora e so colar (Ctrl+V) na conversa." -ForegroundColor Green
}
