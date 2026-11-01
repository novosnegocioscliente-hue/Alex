# Empacota SO o codigo do VSL Host para analise.
# Deixa de fora: videos, paginas importadas (entrada), node_modules, .env e arquivos com senha/token.
# Uso: powershell -ExecutionPolicy Bypass -File .\empacotar-codigo-vslhost.ps1
param(
  [string]$Origem  = "C:\FABRICA\VSL_HOST",
  [string]$Destino = (Join-Path ([Environment]::GetFolderPath("Desktop")) "VSL_HOST_codigo.zip")
)
$Sep = [IO.Path]::DirectorySeparatorChar
$Origem = (Resolve-Path $Origem).Path.TrimEnd($Sep)
$Tmp = Join-Path ([IO.Path]::GetTempPath()) "vslhost_codigo"
$PastasFora = 'node_modules','entrada','saida','dist','build','.git','__pycache__','venv','.venv',
              'cache','.cache','logs','tmp','uploads','media','videos','anexos','paginas','.wrangler','.next'
$Exts = '.js','.mjs','.cjs','.ts','.tsx','.jsx','.py','.ps1','.bat','.cmd','.html','.htm','.css',
        '.json','.md','.txt','.yml','.yaml','.toml','.ini','.sql','.sh'
$Senha = '(?i)(api[_-]?key|token|secret|password|senha|bearer)["'']?\s*[:=]\s*["''][A-Za-z0-9_\-\.]{16,}'

if (Test-Path $Tmp) { Remove-Item $Tmp -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
$copiados = 0; $fora = @()
Get-ChildItem $Origem -Recurse -File -Force | ForEach-Object {
  $rel = $_.FullName.Substring($Origem.Length + 1)
  $pastas = $rel.Split($Sep) | Select-Object -SkipLast 1
  if ($pastas | Where-Object { $PastasFora -contains $_.ToLower() }) { return }
  if ($Exts -notcontains $_.Extension.ToLower()) { return }
  if ($_.Name -like '.env*' -or $_.Name -eq 'package-lock.json' -or $_.Length -gt 2MB) { return }
  $txt = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
  if ($txt -and $txt -match $Senha) { $script:fora += $rel; return }
  $alvo = Join-Path $Tmp $rel
  New-Item -ItemType Directory -Force -Path (Split-Path $alvo) | Out-Null
  Copy-Item $_.FullName $alvo
  $script:copiados++
}
if ($copiados -eq 0) { Write-Host "Nenhum arquivo de codigo encontrado em $Origem" -ForegroundColor Red; exit 1 }
Compress-Archive -Path (Join-Path $Tmp '*') -DestinationPath $Destino -Force
Remove-Item $Tmp -Recurse -Force
Write-Host "PRONTO: $Destino ($copiados arquivos)" -ForegroundColor Green
if ($fora.Count) {
  Write-Host "`nFicaram DE FORA por parecer ter senha/token (me diga so os nomes):" -ForegroundColor Yellow
  $fora | ForEach-Object { Write-Host "  $_" }
}
