& { $R = "C:\FABRICA\VSL_HOST"; $API = "http://localhost:8091"
$BK = Join-Path $R ("backup\correcao2-" + (Get-Date -f 'yyyyMMdd-HHmmss'))
$d = [Environment]::GetFolderPath('Desktop'); if (-not $d) { $d = $HOME }
$o = New-Object Collections.Generic.List[string]
function W($t) { $s = [string]$t -replace '[A-Za-z0-9_\-]{36,}', '***'; if ($s.Length -gt 500) { $s = $s.Substring(0, 500) + ' [...]' }; $o.Add($s) }
W "##### CORRECAO 2 + PUBLICAR + VERIFICAR $(Get-Date -f s) #####"
# 1) fecha o painel
$procs = @(Get-CimInstance Win32_Process -Filter "Name='node.exe'" | ? { $_.CommandLine -match 'servidor\.js' })
$node = if ($procs) { $procs[0].ExecutablePath } else { (Get-Command node -EA SilentlyContinue).Source }
if (-not $node) { $node = 'C:\Program Files\nodejs\node.exe' }
$procs | % { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }
Start-Sleep 1
# 2) correcao 2
$js = Join-Path $env:TEMP 'vslhost-correcao2.js'
[IO.File]::WriteAllText($js, @'
// VSL Host - correcao 2: player/scripts dentro de <!-- comentarios --> nao contam (o player ia parar dentro de um comentario)
// Uso: node vslhost-correcao2.js <pasta do VSL_HOST> <pasta de backup>
'use strict';
const fs = require('fs');
const path = require('path');
const R = process.argv[2], BK = process.argv[3];
const out = [];
const W = (s) => out.push(String(s).replace(/[A-Za-z0-9_\-]{36,}/g, '***'));
function aplicar(rel, pares) {
  const arq = path.join(R, rel);
  let t = fs.readFileSync(arq, 'utf8');
  const crlf = t.includes('\r\n');
  t = t.replace(/\r\n/g, '\n');
  let n = 0;
  for (const [nome, de, para, marca] of pares) {
    if (t.includes(marca)) { W(`  = ${rel}: "${nome}" ja estava aplicada`); continue; }
    if (!t.includes(de)) throw new Error(`${rel}: nao achei o trecho de "${nome}". NADA foi alterado neste arquivo.`);
    t = t.replace(de, () => para); n++;
    W(`  + ${rel}: ${nome}`);
  }
  return { arq, texto: crlf ? t.replace(/\n/g, '\r\n') : t, n };
}
W('=== 1. CORRECOES NO CODIGO');
const funil = aplicar('painel/lib/funil.js', [
  ['funcoes que ignoram comentarios HTML',
   'function acharPlayer(html) {',
   "// vslfix11: o que esta dentro de <!-- comentario --> nao existe para o navegador: nao pode servir de lugar do player\nfunction dentroDeComentario(html, idx) { const a = html.lastIndexOf('<!--', idx); if (a < 0) return false; const f = html.indexOf('-->', a + 4); return f < 0 || f > idx; }\nfunction buscaFora(html, re) { re.lastIndex = 0; let m; while ((m = re.exec(html))) { if (!dentroDeComentario(html, m.index)) return m.index; if (m[0].length === 0) re.lastIndex++; } return -1; }\n\nfunction acharPlayer(html) {",
   'vslfix11'],
  ['tag <vturb-smartplayer> fora de comentario',
   '  let i = html.search(/<vturb-smartplayer\\b/i);',
   '  let i = buscaFora(html, /<vturb-smartplayer\\b/gi); /*vslfix12*/',
   'vslfix12'],
  ['div vid_ fora de comentario',
   "  i = html.search(/<div\\b[^>]*\\bid\\s*=\\s*[\"']vid[_-][^\"']+[\"']/i); /*vslfix3*/",
   "  i = buscaFora(html, /<div\\b[^>]*\\bid\\s*=\\s*[\"']vid[_-][^\"']+[\"']/gi); /*vslfix3*/ /*vslfix13*/",
   'vslfix13'],
  ['iframe do player fora de comentario',
   '  i = html.search(/<iframe\\b[^>]*(pandavideo|converteai|vturb)/i);',
   '  i = buscaFora(html, /<iframe\\b[^>]*(pandavideo|converteai|vturb)/gi); /*vslfix14*/',
   'vslfix14'],
  ['script do player fora de comentario',
   "    const t = m[1] + ' ' + m[2];\n    if (/delaySeconds|displayHiddenElements|SECONDS_TO_DISPLAY/i.test(t)) continue;",
   "    if (dentroDeComentario(html, m.index)) continue; /*vslfix15*/\n    const t = m[1] + ' ' + m[2];\n    if (/delaySeconds|displayHiddenElements|SECONDS_TO_DISPLAY/i.test(t)) continue;",
   'vslfix15']
]);
const teste = aplicar('painel/lib/teste.js', [
  ['teste exige o player FORA de comentario HTML',
   "    if (!/class=\"vsl-player\"/.test(html)) { add(et, 'erro', 'O player da VSL nao esta na pagina.'); continue; }",
   "    if (!/class=\"vsl-player\"/.test(html.replace(/<!--[\\s\\S]*?-->/g, ''))) { add(et, 'erro', /class=\"vsl-player\"/.test(html) ? 'O player da VSL ficou DENTRO de um comentario HTML (<!-- -->): o navegador nao mostra. Publique de novo.' : 'O player da VSL nao esta na pagina.'); continue; } /*vslfix16*/",
   'vslfix16']
]);
for (const x of [funil, teste]) {
  if (!x.n) continue;
  fs.mkdirSync(BK, { recursive: true });
  fs.copyFileSync(x.arq, path.join(BK, path.basename(x.arq)));
  fs.writeFileSync(x.arq, x.texto);
}
W(`  Codigo: ${funil.n + teste.n} correcao(oes) gravada(s). Backup em ${BK}`);

W('\n=== 2. MONTAGEM DE TESTE (antes de publicar)');
const F = require(path.join(R, 'painel', 'lib', 'funil.js'));
const bruto = JSON.parse(fs.readFileSync(path.join(R, 'dados', 'funis.json'), 'utf8'));
const lista = Array.isArray(bruto) ? bruto : (bruto.funis || []);
let videos = {};
try { const v = JSON.parse(fs.readFileSync(path.join(R, 'dados', 'videos.json'), 'utf8')); videos = Array.isArray(v) ? Object.fromEntries(v.map((x) => [x.nome, x])) : (v.videos || v); } catch (e) { /* sem info */ }
const ctx = { raiz: R, baseVideos: 'https://media.boldhabitco.cloud/', versaoPlayer: (() => { try { return F.versaoPlayer(R); } catch (e) { return 'x'; } })(), videos, analytics: null };
let pronto = true;
for (const f of lista) {
  if (!/kings/i.test(f.slug || '')) continue;
  for (const p of F.montarFunil(f, ctx)) {
    W(`  pagina ${p.caminho}: ${p.erro ? 'NAO MONTOU' : 'montou'}`);
    p.avisos.forEach((a) => W(`     aviso: ${a}`));
    if (!p.html) { pronto = false; continue; }
    const semComent = p.html.replace(/<!--[\s\S]*?-->/g, '');
    const fora = /class="vsl-player"/.test(semComent);
    const topo = p.avisos.some((a) => /Nao achei o player antigo/.test(a));
    W(`     player: ${fora ? (topo ? 'VISIVEL, no topo da pagina' : 'VISIVEL, no lugar do player antigo') : 'NAO VISIVEL (dentro de comentario ou ausente)'}`);
    if (fora) { const i = semComent.indexOf('class="vsl-player"'); W('     em volta do player: ' + semComent.slice(Math.max(0, i - 220), i).replace(/\s+/g, ' ').slice(-220)); }
    else pronto = false;
    W(`     botoes levando ao SEU checkout: ${f.checkout ? p.html.split(f.checkout).length - 1 : 0}`);
  }
  // onde estavam os scripts do VTurb na pagina original (dentro ou fora de comentario)
  const orig = (f.etapas[0] || {}).html || '';
  const re = /<script\b[^>]*>[\s\S]*?<\/script>/gi; let m;
  const corpo = orig.search(/<body\b/i);
  while ((m = re.exec(orig))) if (m.index > corpo && /converteai|smartplayer|vturb/i.test(m[0])) W(`     script do VTurb na pagina original em ${m.index}: ${/<!--/.test(orig.slice(orig.lastIndexOf('<!--', m.index), m.index)) && orig.indexOf('-->', orig.lastIndexOf('<!--', m.index)) > m.index ? 'DENTRO de comentario (ignorado)' : 'fora de comentario'}`);
}
W(pronto ? 'MONTAGEM OK' : 'MONTAGEM COM PROBLEMA');
console.log(out.join('\n'));
'@, (New-Object Text.UTF8Encoding $false))
(& $node $js $R $BK 2>&1 | Out-String) -split "`r?`n" | % { W $_ }
# 3) reabre o painel ja com o codigo novo
Start-Process -FilePath $node -ArgumentList "`"$R\painel\servidor.js`"" -WorkingDirectory $R -WindowStyle Minimized
$ok = $false; for ($i = 0; $i -lt 20 -and -not $ok; $i++) { Start-Sleep 2; try { Invoke-RestMethod "$API/api/estado" -TimeoutSec 5 | Out-Null; $ok = $true } catch { } }
W "`n=== 3. PUBLICACAO"
if (-not $ok) { W "ERRO: o painel nao voltou em $API" } else {
  W "Painel reaberto com o codigo novo."
  Add-Type -AssemblyName System.Web.Extensions; $ser = New-Object Web.Script.Serialization.JavaScriptSerializer; $ser.MaxJsonLength = [int]::MaxValue
  $fj = $ser.DeserializeObject((Get-Content "$R\dados\funis.json" -Raw -Encoding UTF8)); $lista = if ($fj -is [Collections.IDictionary]) { $fj['funis'] } else { $fj }
  $f = @($lista) | ? { $_['slug'] -eq 'kings-code-page' } | Select -First 1
  try { Invoke-RestMethod "$API/api/funis/publicar" -Method Post -ContentType 'application/json' -Body (@{ id = $f['id'] } | ConvertTo-Json) -TimeoutSec 30 | Out-Null; W "Publicando o funil $($f['nome'])..." } catch { W "ERRO ao publicar: $($_.Exception.Message)" }
  $vistos = New-Object Collections.Generic.HashSet[string]; $fim = (Get-Date).AddMinutes(6)
  while ((Get-Date) -lt $fim) {
    Start-Sleep 5
    try { $txt = (Invoke-WebRequest "$API/api/estado" -UseBasicParsing -TimeoutSec 15).Content } catch { continue }
    $msgs = [regex]::Matches($txt, '"((?:[^"\\]|\\.){0,400}?(?:\[(?:OK|ERRO|ATENCAO)\]|Etapa \d|FUNIL COMPLETO|NAO se completou)(?:[^"\\]|\\.){0,400}?)"') | % { $_.Groups[1].Value -replace '\\"', '"' }
    foreach ($m in $msgs) { if ($vistos.Add($m)) { W "  $m" } }
    if ($msgs | ? { $_ -match 'FUNIL COMPLETO|NAO se completou' }) { break }
  }
  Start-Sleep 5
  # 4) abre a pagina no Chrome como um lead e confere a oferta
  W "`n=== 4. NAVEGADOR (como um lead no celular)"
  $vj = Join-Path $env:TEMP 'vslhost-verificar.js'
  [IO.File]::WriteAllText($vj, @'
// VSL Host - abre o funil como um lead (celular), pula para o pitch e confere se a oferta aparece.
// Uso: node vslhost-verificar.js <pasta VSL_HOST> <url> <arquivo-print.png>
'use strict';
const fs = require('fs'), path = require('path');
const [R, URLP, SHOT] = process.argv.slice(2);
const out = []; const W = (s) => out.push(String(s).replace(/[A-Za-z0-9_\-]{36,}/g, '***'));
const espera = (ms) => new Promise((r) => setTimeout(r, ms));
(async () => {
  let puppeteer;
  try { puppeteer = require(path.join(R, 'painel', 'node_modules', 'puppeteer-core')); } catch (e) { W('ERRO: puppeteer-core nao encontrado no painel: ' + e.message); return; }
  const env = process.env;
  const exe = [env['PROGRAMFILES'] + '\\Google\\Chrome\\Application\\chrome.exe', env['PROGRAMFILES(X86)'] + '\\Google\\Chrome\\Application\\chrome.exe',
    env.LOCALAPPDATA + '\\Google\\Chrome\\Application\\chrome.exe', env['PROGRAMFILES(X86)'] + '\\Microsoft\\Edge\\Application\\msedge.exe',
    env['PROGRAMFILES'] + '\\Microsoft\\Edge\\Application\\msedge.exe'].find((p) => p && fs.existsSync(p));
  if (!exe) { W('ERRO: nao achei Chrome nem Edge instalado.'); return; }
  W('Navegador: ' + exe);
  const b = await puppeteer.launch({ executablePath: exe, headless: true, args: ['--autoplay-policy=no-user-gesture-required', '--mute-audio'] });
  try {
    const pg = await b.newPage();
    await pg.setViewport({ width: 414, height: 896, isMobile: true, hasTouch: true });
    const erros = [];
    pg.on('pageerror', (e) => erros.push('JS: ' + e.message));
    pg.on('console', (m) => { if (m.type() === 'error') erros.push('console: ' + m.text()); });
    const estado = () => pg.evaluate(() => {
      const vis = (e) => { if (!e) return false; const s = getComputedStyle(e); const r = e.getBoundingClientRect(); return s.display !== 'none' && s.visibility !== 'hidden' && s.opacity !== '0' && r.height > 0; };
      const main = document.querySelector('main');
      const compra = [...document.querySelectorAll('a[href]')].filter((a) => /usethekingscode|checkout|buygoods|clickbank/i.test(a.href));
      const v = document.querySelector('video');
      return {
        main: main ? { classe: main.className, visivel: vis(main) } : 'sem <main>',
        botoesDeCompra: compra.length, botoesVisiveis: compra.filter(vis).length,
        textosVisiveis: compra.filter(vis).map((a) => (a.textContent || '').trim().slice(0, 30)),
        video: v ? { tempo: Math.round(v.currentTime), pausado: v.paused, pronto: v.readyState } : 'sem <video>',
        botaoDoPlayer: [...document.querySelectorAll('a,button')].filter((a) => /I WANT IT NOW/i.test(a.textContent || '') && vis(a)).length,
        escondidos: [...document.querySelectorAll('.hide,.vsl-hide,.esconder,.hidden')].filter((e) => !vis(e)).length
      };
    });
    await pg.goto(URLP + '?vsl_seek=1230&utm_source=teste_robo', { waitUntil: 'networkidle2', timeout: 60000 });
    await espera(2000);
    W('\n1) Pagina carregada (antes do play): ' + JSON.stringify(await estado()));
    // o player troca a marcacao ao carregar (.vsl-player vira .vslp): clica no centro da caixa do player
    const alvo = await pg.evaluate(() => {
      const c = document.querySelector('.vslp-bplay') || document.querySelector('.vslp-ov.on') || document.querySelector('.vslp') || document.querySelector('[class*="vslp"]') || document.querySelector('.vsl-player');
      if (!c) return null; c.scrollIntoView({ block: 'center' }); const r = c.getBoundingClientRect();
      return { x: r.left + r.width / 2, y: r.top + r.height / 2, cls: String(c.className) };
    });
    if (alvo) { await pg.mouse.click(alvo.x, alvo.y); W('   clique no player: ' + alvo.cls); } else W('   player nao encontrado na tela');
    await espera(12000);
    W('2) 12s depois do play (com ?vsl_seek=1230 o video deve estar em ~20:30): ' + JSON.stringify(await estado()));
    let fim = await estado();
    if (!(fim.main && fim.main.visivel)) {
      await pg.evaluate(() => { const v = document.querySelector('video'); if (v) { v.muted = true; if (v.currentTime < 1200) v.currentTime = 1235; v.play().catch(() => {}); } });
      await espera(10000);
      fim = await estado();
      W('3) Garantindo o video em 20:35 tocando por 10s: ' + JSON.stringify(fim));
    }
    await pg.screenshot({ path: SHOT });
    W('\nRESULTADO: ' + (fim.main && fim.main.visivel && fim.botoesVisiveis > 0 ? 'OFERTA APARECE no tempo certo (' + fim.botoesVisiveis + ' botao(oes) de compra visiveis).'
      : fim.botoesVisiveis > 0 ? 'So o botao do player aparece; a oferta da pagina (<main>) continua ESCONDIDA.' : 'A OFERTA NAO APARECEU: nenhum botao de compra visivel.'));
    if (erros.length) { W('\nErros na pagina:'); erros.slice(0, 15).forEach((e) => W('  ' + e.slice(0, 300))); }
    // trechos para a correcao: como a pagina publicada esconde/revela e como o player revela
  } finally { await b.close(); }
})().catch((e) => W('ERRO: ' + e.message)).finally(() => console.log(out.join('\n')));
'@, (New-Object Text.UTF8Encoding $false))
  (& $node $vj $R 'https://kings-code-page.boldhabitco.cloud/' (Join-Path $d 'kings-teste-20m30.png') 2>&1 | Out-String) -split "`r?`n" | % { W $_ }
}
W "`nPara DESFAZER a correcao 2: copie funil.js e teste.js de $BK para painel\lib."
$arq = Join-Path $d 'correcao2-vslhost.txt'
($o -join "`r`n") | Set-Content $arq -Encoding UTF8
Write-Host "`nPRONTO. Resultado em $arq" -ForegroundColor Green
notepad $arq
}
