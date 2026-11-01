// VSL Host - correcao 1 (player VTurb por script, link de compra de exemplo, presell que e pagina de VSL)
// Uso: node vslhost-correcao.js <pasta do VSL_HOST> <pasta de backup>
'use strict';
const fs = require('fs');
const path = require('path');
const R = process.argv[2], BK = process.argv[3];
const out = [];
const mask = (s) => String(s).replace(/((token|key|secret|senha|password|bearer|authorization)[^\r\n]{0,8}?[:=]\s*["']?)[^"'\s,;]{8,}/gi, '$1***').replace(/[A-Za-z0-9_\-]{36,}/g, '***');
const W = (s) => out.push(mask(s));

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

// ---------------- 1. correcoes no codigo ----------------
W('=== 1. CORRECOES NO CODIGO');
const funil = aplicar('painel/lib/funil.js', [
  ['link de compra de exemplo (SEU_LINK_DE_COMPRA_AQUI) vira checkout',
   "const CHECKOUT = /checkout|hop\\.clickbank|clickbank\\.net|pay\\.|buygoods|digistore|hotmart|kiwify|eduzz|monetizze|braip|stripe|paypal|cart|order|buy|shop|maxweb|clkbank|bemob|voluum|redtrack/i;",
   "const CHECKOUT = /checkout|hop\\.clickbank|clickbank\\.net|pay\\.|buygoods|digistore|hotmart|kiwify|eduzz|monetizze|braip|stripe|paypal|cart|order|buy|shop|maxweb|clkbank|bemob|voluum|redtrack/i;\n// vslfix1: links de exemplo que paginas de afiliado trazem no lugar do link de compra\nconst LINK_EXEMPLO = /^\\[?\\s*(SEU[_-]|YOUR[_-]|LINK[_-]?(DE[_-]?)?COMPRA|CHECKOUT[_-]?(LINK|URL|AQUI|HERE)|BUY[_-]?(LINK|URL)|AFF(ILIATE)?[_-]?(LINK|URL)|\\[?CHECKOUT\\]?$)/i;",
   'vslfix1'],
  ['sugere "Checkout" para o link de exemplo',
   "sugestao: legal(l) ? 'manter' : tipo === 'presell' ? 'proxima' : (kits ? 'manter' : /^https?:/i.test(l.url) ? 'checkout' : 'manter')",
   "sugestao: legal(l) ? 'manter' : tipo === 'presell' ? 'proxima' : (kits ? 'manter' : (/^https?:/i.test(l.url) || LINK_EXEMPLO.test(l.url)) ? 'checkout' : 'manter') /*vslfix2*/",
   'vslfix2'],
  ['reconhece player VTurb com id "vid-" (novo) alem de "vid_"',
   "i = html.search(/<div\\b[^>]*\\bid\\s*=\\s*[\"']vid_[^\"']+[\"']/i);",
   "i = html.search(/<div\\b[^>]*\\bid\\s*=\\s*[\"']vid[_-][^\"']+[\"']/i); /*vslfix3*/",
   'vslfix3'],
  ['reconhece player VTurb v4 montado por <script>',
   "  if (mk) return { tipo: 'marcador', bloco: [mk.index, mk.index + mk[0].length] };\n  return null;\n}",
   "  if (mk) return { tipo: 'marcador', bloco: [mk.index, mk.index + mk[0].length] };\n  const sp = acharScriptPlayer(html);\n  if (sp) return { tipo: 'VTurb (script)', bloco: sp };\n  return null;\n}\n\n// vslfix4: embed VTurb v4 sem a tag no HTML (o <script> cria o player): acha esse <script> dentro do <body>\nfunction acharScriptPlayer(html) {\n  const ini = html.search(/<body\\b/i);\n  if (ini < 0) return null;\n  const re = /<script\\b([^>]*)>([\\s\\S]*?)<\\/script>/gi;\n  re.lastIndex = ini;\n  let m, reserva = null;\n  while ((m = re.exec(html))) {\n    const t = m[1] + ' ' + m[2];\n    if (/delaySeconds|displayHiddenElements|SECONDS_TO_DISPLAY/i.test(t)) continue;\n    if (/converteai|pandavideo/i.test(t)) return [m.index, re.lastIndex];\n    if (!reserva && /smartplayer|vturb/i.test(t)) reserva = [m.index, re.lastIndex];\n  }\n  return reserva;\n}",
   'vslfix4'],
  ['aviso quando a presell e na verdade a pagina da VSL',
   "  a.relativos = assetsRelativos(html)",
   "  if (tipo === 'presell') { const pp = acharPlayer(html); if (pp && pp.tipo !== 'marcador') a.avisos.push('Esta presell tem um player de video (' + pp.tipo + '): parece a pagina da VSL, nao uma presell. O lead veria o player do produtor. Cole a presell certa ou use o modelo \"VSL + Checkout\".'); } /*vslfix5*/\n  a.relativos = assetsRelativos(html)",
   'vslfix5'],
  ['marca o lugar do player antes de apagar os scripts do VTurb',
   "  const compat = /displayHiddenElements/.test(html);",
   "  { const p0 = acharPlayer(html); if (p0 && p0.tipo === 'VTurb (script)') html = html.slice(0, p0.bloco[0]) + '<!-- VSL -->' + html.slice(p0.bloco[1]); } /*vslfix6*/\n  const compat = /displayHiddenElements/.test(html);",
   'vslfix6'],
  ['nao publica presell com player de video',
   "      if (analise.vazio) return { caminho: cams[i], html: null, avisos: ['Cole o HTML da presell.'], erro: true };",
   "      if (analise.vazio) return { caminho: cams[i], html: null, avisos: ['Cole o HTML da presell.'], erro: true };\n      { const pp = acharPlayer(etapa.html); if (pp && pp.tipo !== 'marcador') return { caminho: cams[i], html: null, avisos: ['Esta presell tem um player de video (' + pp.tipo + '): parece a pagina da VSL. Cole a presell certa ou mude o modelo para \"VSL + Checkout\".'], erro: true }; } /*vslfix7*/",
   'vslfix7'],
  ['status do painel avisa presell com player',
   "    if (tipo === 'presell' && !(e.html || '').trim()) falta.push('colar o HTML');",
   "    if (tipo === 'presell' && !(e.html || '').trim()) falta.push('colar o HTML');\n    if (tipo === 'presell' && (e.html || '').trim()) { const pp = acharPlayer(e.html); if (pp && pp.tipo !== 'marcador') falta.push('trocar o HTML: esta presell e a pagina da VSL'); } /*vslfix8*/",
   'vslfix8']
]);
const teste = aplicar('painel/lib/teste.js', [
  ['teste acusa presell com player do produtor',
   "    if (tipo === 'presell') {\n      const prox = cams[i + 1];",
   "    if (tipo === 'presell') {\n      if (/scripts\\.converteai\\.net|<vturb-smartplayer|player\\.pandavideo/i.test(html)) add(et, 'erro', 'Esta presell tem o player de video do produtor (VTurb/Panda): no seu dominio aparece \"dominio nao permitido\". Use a presell certa ou o modelo \"VSL + Checkout\".'); /*vslfix9*/\n      const prox = cams[i + 1];",
   'vslfix9'],
  ['teste acusa botao com link de exemplo',
   "    if (!checkouts.length && !temFunil) add(et, 'erro',",
   "    if (/href\\s*=\\s*[\"']\\s*(SEU[_-]|YOUR[_-]|LINK[_-]?(DE[_-]?)?COMPRA)/i.test(html)) add(et, 'erro', 'Ha botoes com link de exemplo (SEU_LINK_DE_COMPRA_AQUI) na pagina: publique de novo para trocar pelo seu checkout.'); /*vslfix10*/\n    if (!checkouts.length && !temFunil) add(et, 'erro',",
   'vslfix10']
]);
// so grava se os dois arquivos aceitaram todas as correcoes
for (const x of [funil, teste]) {
  if (!x.n) continue;
  fs.mkdirSync(BK, { recursive: true });
  fs.copyFileSync(x.arq, path.join(BK, path.basename(x.arq)));
  fs.writeFileSync(x.arq, x.texto);
}
W(`  Codigo: ${funil.n + teste.n} correcao(oes) gravada(s). Backup em ${BK}`);

// ---------------- 2. funil Kings: a "presell" era a pagina da VSL -> modelo VSL + Checkout ----------------
W('\n=== 2. FUNIL KINGS CODE');
const arqF = path.join(R, 'dados', 'funis.json');
const bruto = JSON.parse(fs.readFileSync(arqF, 'utf8'));
const lista = Array.isArray(bruto) ? bruto : (bruto.funis || []);
const F = require(path.join(R, 'painel', 'lib', 'funil.js'));
let mudou = false;
for (const f of lista) {
  if (f.modelo !== 'presell-vsl' || !f.etapas || f.etapas.length < 2) continue;
  const pre = f.etapas[0], vsl = f.etapas[1];
  const pp = pre.html ? F.analisarPagina(pre.html, 'presell', { pasta: pre.pasta }) : null;
  const ehVsl = pp && pp.avisos.some((a) => /player de video/.test(a));
  if (!ehVsl) continue;
  f.modelo = 'vsl';
  f.etapas = [vsl];
  if (f.ultimoTeste) f.ultimoTeste.desatualizado = true;
  mudou = true;
  W(`  "${f.nome}": a presell era a pagina da VSL (com o player do produtor). Modelo trocado para "VSL + Checkout": a VSL abre direto na raiz do site.`);
}
if (mudou) { fs.copyFileSync(arqF, path.join(BK, 'funis.json')); fs.writeFileSync(arqF, JSON.stringify(bruto, null, Array.isArray(bruto) ? 2 : 2)); }
else W('  Nenhum funil com presell duplicada.');

// ---------------- 3. montagem de teste (nao publica nada) ----------------
W('\n=== 3. MONTAGEM DE TESTE (nada foi publicado)');
let videos = {};
try { const v = JSON.parse(fs.readFileSync(path.join(R, 'dados', 'videos.json'), 'utf8')); videos = Array.isArray(v) ? Object.fromEntries(v.map((x) => [x.nome, x])) : (v.videos || v); } catch (e) { /* sem info */ }
let baseVideos = 'https://media.boldhabitco.cloud/';
try { const c = JSON.stringify(JSON.parse(fs.readFileSync(path.join(R, 'dados', 'config.json'), 'utf8'))); const m = c.match(/"(https?:\/\/media\.[^"]+)"/); if (m) baseVideos = m[1].replace(/\/?$/, '/'); } catch (e) { /* padrao */ }
const ctx = { raiz: R, baseVideos, versaoPlayer: (() => { try { return F.versaoPlayer(R); } catch (e) { return 'x'; } })(), videos, analytics: null };
for (const f of lista) {
  if (!/kings/i.test(f.slug || f.nome || '')) continue;
  W(`--- ${f.nome} (modelo ${f.modelo})`);
  const st = F.statusFunil(f, videos, true);
  for (const p of F.montarFunil(f, ctx)) {
    W(`  pagina ${p.caminho}: ${p.erro ? 'NAO MONTOU' : 'montou'}`);
    p.avisos.forEach((a) => W(`     aviso: ${a}`));
    if (!p.html) continue;
    const h = p.html;
    if (h.includes('class="vsl-player"')) W(`     player novo: ${p.avisos.some((a) => /Nao achei o player antigo/.test(a)) ? 'NO TOPO (lugar original nao achado)' : 'no lugar do player antigo'}`);
    W(`     restos do VTurb do produtor (converteai): ${(h.match(/converteai/gi) || []).length}`);
    W(`     botoes com link de exemplo (SEU_LINK...): ${(h.match(/SEU_LINK_DE_COMPRA/gi) || []).length}`);
    if (f.checkout) W(`     botoes levando ao SEU checkout: ${h.split(f.checkout).length - 1}`);
    const cfg = (h.match(/<script type="application\/json">(\{[\s\S]*?\})<\/script>/) || [])[1];
    if (cfg) W(`     config do player: ${cfg}`);
    W(`     script da pagina com delaySeconds mantido: ${/delaySeconds/.test(h) ? 'sim' : 'nao'} | main/.hide na pagina: ${/class\s*=\s*["'][^"']*\bhide\b/i.test(h) ? 'sim' : 'nao'}`);
  }
}
console.log(out.join('\n'));
