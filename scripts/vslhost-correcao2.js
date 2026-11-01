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
