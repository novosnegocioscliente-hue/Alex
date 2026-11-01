// VSL Host - correcao 4: player no espaco vazio do video (.vsl) e scripts que so citam VTurb ficam intactos
// Uso: node vslhost-correcao4.js <pasta do VSL_HOST> <pasta de backup>
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
  ['player vai para o espaco vazio do video da pagina (.vsl, .video, .player...)',
   "  const sp = acharScriptPlayer(html);\n  if (sp) return { tipo: 'VTurb (script)', bloco: sp };\n  return null;\n}",
   "  const sp = acharScriptPlayer(html);\n  if (sp) return { tipo: 'VTurb (script)', bloco: sp };\n  const sl = acharEspacoVideo(html); /*vslfix18*/\n  if (sl) return { tipo: 'espaco do video', bloco: sl };\n  return null;\n}\n\n// vslfix18: paginas de afiliado vem com o lugar do video vazio (<div class=\"vsl\">, so com um exemplo comentado)\nfunction acharEspacoVideo(html) {\n  const re = /<(div|section|figure)\\b([^>]*)>/gi; let m;\n  while ((m = re.exec(html))) {\n    if (dentroDeComentario(html, m.index)) continue;\n    const nomes = ((m[2].match(/\\bclass\\s*=\\s*[\"']([^\"']*)[\"']/i) || [])[1] || '') + ' ' + ((m[2].match(/\\bid\\s*=\\s*[\"']([^\"']*)[\"']/i) || [])[1] || '');\n    if (!nomes.split(/\\s+/).some((n) => /^(vsl|video|player|vsl[-_]?(wrap|wrapper|container|box|slot|area|holder|frame)|video[-_]?(wrap|wrapper|container|box|slot|area|holder|frame)|player[-_]?(wrap|wrapper|container|box|slot|holder))$/i.test(n))) continue;\n    const b = blocoBalanceado(html, m.index, m[1].toLowerCase()); if (!b) continue;\n    const ini = m.index + m[0].length, fim = html.lastIndexOf('<', b[1] - 1);\n    const dentro = html.slice(ini, fim).replace(/<!--[\\s\\S]*?-->/g, '').trim();\n    if (!/<(img|video|iframe|p|h[1-6]|a|button|span|ul|picture)\\b/i.test(dentro)) return [ini, fim];\n  }\n  return null;\n}",
   'vslfix18'],
  ['so troca o script que CARREGA o player (texto que so cita VTurb fica)',
   "    if (!reserva && /smartplayer|vturb/i.test(t)) reserva = [m.index, re.lastIndex];",
   "    /*vslfix20: so conta o script que carrega o player (converteai/panda); script que so cita VTurb (timer, delay) fica intacto*/",
   'vslfix20'],
  ['presell: espaco de video vazio nao e player (aviso)',
   "if (pp && pp.tipo !== 'marcador') a.avisos.push(",
   "if (pp && !/marcador|espaco/.test(pp.tipo)) /*vslfix19a*/ a.avisos.push(",
   'vslfix19a'],
  ['presell: espaco de video vazio nao e player (montagem)',
   "if (pp && pp.tipo !== 'marcador') return {",
   "if (pp && !/marcador|espaco/.test(pp.tipo)) /*vslfix19b*/ return {",
   'vslfix19b'],
  ['presell: espaco de video vazio nao e player (status)',
   "if (pp && pp.tipo !== 'marcador') falta.push(",
   "if (pp && !/marcador|espaco/.test(pp.tipo)) /*vslfix19c*/ falta.push(",
   'vslfix19c']
]);
if (funil.n) { fs.mkdirSync(BK, { recursive: true }); fs.copyFileSync(funil.arq, path.join(BK, 'funil.js')); fs.writeFileSync(funil.arq, funil.texto); }
W(`  Codigo: ${funil.n} correcao(oes) gravada(s). Backup em ${BK}`);

W('\n=== 2. MONTAGEM DE TESTE');
const F = require(path.join(R, 'painel', 'lib', 'funil.js'));
const bruto = JSON.parse(fs.readFileSync(path.join(R, 'dados', 'funis.json'), 'utf8'));
const lista = Array.isArray(bruto) ? bruto : (bruto.funis || []);
let videos = {};
try { const v = JSON.parse(fs.readFileSync(path.join(R, 'dados', 'videos.json'), 'utf8')); videos = Array.isArray(v) ? Object.fromEntries(v.map((x) => [x.nome, x])) : (v.videos || v); } catch (e) { /* sem info */ }
const ctx = { raiz: R, baseVideos: 'https://media.boldhabitco.cloud/', versaoPlayer: 'x', videos, analytics: null };
for (const f of lista) {
  if (!/kings/i.test(f.slug || '')) continue;
  const orig = (f.etapas[0] || {}).html || '';
  const p = F.montarFunil(f, ctx)[0];
  if (!p || !p.html) { W('  NAO MONTOU: ' + (p ? p.avisos.join(' | ') : '')); continue; }
  p.avisos.forEach((a) => W('  aviso: ' + a));
  const h = p.html.replace(/<!--[\s\S]*?-->/g, '');
  const iP = h.indexOf('class="vsl-player"'), iH = h.search(/<\/h1>/i), iM = h.search(/<main\b/i), iF = h.search(/<footer\b/i);
  W(`  player: ${iP < 0 ? 'NAO ESTA NA PAGINA' : iP > iH && (iM < 0 || iP < iM) ? 'LOGO ABAIXO DA MANCHETE (antes da oferta)' : iF > 0 && iP > iF ? 'DEPOIS DO RODAPE (errado)' : 'no meio da pagina'}`);
  W('  em volta: ' + h.slice(Math.max(0, iP - 160), iP).replace(/\s+/g, ' ').slice(-160));
  const nOrig = (orig.match(/<script\b/gi) || []).length, nNovo = (p.html.match(/<script\b/gi) || []).length;
  W(`  timer de 15 min (kc_timer_inicio) preservado: ${/kc_timer_inicio/.test(p.html) ? 'SIM' : (/kc_timer_inicio/.test(orig) ? 'NAO (foi apagado!)' : 'a pagina nao tem')}`);
  W(`  scripts na pagina original: ${nOrig} | na pagina montada: ${nNovo}`);
}
console.log(out.join('\n'));
