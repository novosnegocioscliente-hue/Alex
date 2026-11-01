// VSL Host - correcao 3: o player revela o que a pagina esconde + esqueleto da pagina
// Uso: node vslhost-correcao3.js <pasta do VSL_HOST> <pasta de backup>
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
  ['o player tambem revela o que a pagina esconde (.hide, .esconder...) no tempo do pitch',
   "  const seletores = (/displayHiddenElements/.test(html || '') ? [] : analise.delay.seletores).concat('.vsl-hide');",
   "  // vslfix17: o player revela sozinho o que a pagina esconde (nao depende do script da pagina achar o player)\n  const seletores = analise.delay.seletores.concat('.vsl-hide');",
   'vslfix17']
]);
if (funil.n) { fs.mkdirSync(BK, { recursive: true }); fs.copyFileSync(funil.arq, path.join(BK, 'funil.js')); fs.writeFileSync(funil.arq, funil.texto); }
W(`  Codigo: ${funil.n} correcao(oes) gravada(s). Backup em ${BK}`);

W('\n=== 2. MONTAGEM DE TESTE + ESQUELETO DA PAGINA');
const F = require(path.join(R, 'painel', 'lib', 'funil.js'));
const bruto = JSON.parse(fs.readFileSync(path.join(R, 'dados', 'funis.json'), 'utf8'));
const lista = Array.isArray(bruto) ? bruto : (bruto.funis || []);
let videos = {};
try { const v = JSON.parse(fs.readFileSync(path.join(R, 'dados', 'videos.json'), 'utf8')); videos = Array.isArray(v) ? Object.fromEntries(v.map((x) => [x.nome, x])) : (v.videos || v); } catch (e) { /* sem info */ }
const ctx = { raiz: R, baseVideos: 'https://media.boldhabitco.cloud/', versaoPlayer: 'x', videos, analytics: null };
for (const f of lista) {
  if (!/kings/i.test(f.slug || '')) continue;
  const p = F.montarFunil(f, ctx)[0];
  if (!p || !p.html) { W('  NAO MONTOU: ' + (p ? p.avisos.join(' | ') : '')); continue; }
  const cfg = (p.html.match(/<script type="application\/json">(\{[\s\S]*?\})<\/script>/) || [])[1];
  W('  config do player: ' + cfg);
  // esqueleto: tags de estrutura, com classe/id, texto dos titulos; marca o player
  const h = p.html.replace(/<!--[\s\S]*?-->/g, '').replace(/<style\b[\s\S]*?<\/style>/gi, '');
  const corpo = h.slice(Math.max(0, h.search(/<body\b/i)));
  const ESTR = /^(div|section|main|header|footer|article|aside|nav|h1|h2|h3|script|video|iframe|form|button)$/i;
  const re = /<(\/?)([a-zA-Z][\w-]*)([^>]*)>/g; let m, prof = 0, linhas = 0;
  while ((m = re.exec(corpo)) && linhas < 260) {
    const [, fecha, tag, attrs] = m; const t = tag.toLowerCase();
    if (/^(br|img|input|meta|link|hr|source|path|svg|circle|rect|polygon|g|use)$/.test(t)) continue;
    if (fecha) { prof = Math.max(0, prof - 1); continue; }
    const auto = /\/\s*$/.test(attrs);
    if (ESTR.test(t) || /class\s*=\s*["'][^"']*vsl-player/.test(attrs)) {
      const cls = (attrs.match(/\bclass\s*=\s*["']([^"']*)["']/i) || [])[1];
      const id = (attrs.match(/\bid\s*=\s*["']([^"']*)["']/i) || [])[1];
      let extra = '';
      if (/^h[1-3]$/.test(t)) { const fim = corpo.indexOf('</' + t, re.lastIndex); extra = ' "' + corpo.slice(re.lastIndex, fim).replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim().slice(0, 70) + '"'; }
      if (t === 'script') { const fim = corpo.indexOf('</script>', re.lastIndex); extra = ' ' + (attrs.match(/src\s*=\s*["']([^"']+)/i) || [, ''])[1] + ' {' + corpo.slice(re.lastIndex, fim).replace(/\s+/g, ' ').trim().slice(0, 60) + '}'; }
      W('  ' + '  '.repeat(Math.min(prof, 12)) + '<' + t + (id ? '#' + id : '') + (cls ? '.' + cls.trim().replace(/\s+/g, '.') : '') + '>' + extra + (/class\s*=\s*["'][^"']*vsl-player/.test(attrs) ? '   <<<<<<<<<< PLAYER NOVO' : ''));
      linhas++;
    }
    if (!auto && t !== 'script') prof++;
    if (t === 'script') { const fim = corpo.indexOf('</script>', re.lastIndex); if (fim > 0) re.lastIndex = fim + 9; }
  }
}
console.log(out.join('\n'));
