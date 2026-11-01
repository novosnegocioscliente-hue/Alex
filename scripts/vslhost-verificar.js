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
        escondidos: [...document.querySelectorAll('.hide,.vsl-hide,.esconder,.hidden')].filter((e) => !vis(e)).length
      };
    });
    await pg.goto(URLP + '?vsl_seek=1230&utm_source=teste_robo', { waitUntil: 'networkidle2', timeout: 60000 });
    W('\n1) Pagina carregada (antes do play): ' + JSON.stringify(await estado()));
    try { await pg.click('.vsl-player'); } catch (e) { W('   (nao consegui clicar no player: ' + e.message + ')'); }
    await espera(9000);
    W('2) 9s depois do play (o video deveria estar em ~20:30): ' + JSON.stringify(await estado()));
    await pg.evaluate(() => { const v = document.querySelector('video'); if (v) { v.muted = true; v.currentTime = 1235; v.play().catch(() => {}); } });
    await espera(8000);
    const fim = await estado();
    W('3) Forcando o video para 20:35 e tocando 8s: ' + JSON.stringify(fim));
    await pg.screenshot({ path: SHOT });
    W('\nRESULTADO: ' + (fim.main && fim.main.visivel && fim.botoesVisiveis > 0 ? 'OFERTA APARECE no tempo certo (' + fim.botoesVisiveis + ' botao(oes) de compra visiveis).'
      : fim.botoesVisiveis > 0 ? 'So o botao do player aparece; a oferta da pagina (<main>) continua ESCONDIDA.' : 'A OFERTA NAO APARECEU: nenhum botao de compra visivel.'));
    if (erros.length) { W('\nErros na pagina:'); erros.slice(0, 15).forEach((e) => W('  ' + e.slice(0, 300))); }
    // trechos para a correcao: como a pagina publicada esconde/revela e como o player revela
    const html = await pg.content();
    W('\n=== SCRIPTS DA PAGINA PUBLICADA QUE MEXEM COM hide/delay');
    (html.match(/<script\b[^>]*>[\s\S]*?<\/script>/gi) || []).filter((s) => /delaySeconds|\bhide\b|classList|vsl_seek|vturb|smartplayer/i.test(s) && !/application\/json/.test(s)).slice(0, 4)
      .forEach((s, i) => W(`--- script ${i + 1} (${s.length} caracteres): ${s.slice(0, 2500).replace(/\s+/g, ' ')}`));
    (html.match(/[^{}]*\.hide\b[^{]*\{[^}]*\}/g) || []).slice(0, 4).forEach((c) => W('  CSS: ' + c.trim().slice(0, 200)));
    W('\n=== vsl-player.js: onde ele revela os elementos (delay/seletor)');
    const pj = fs.readFileSync(path.join(R, 'player', 'vsl-player.js'), 'utf8');
    const ini = pj.indexOf('].join(') > 0 ? pj.indexOf('].join(') : 0;   // pula o bloco de CSS
    const re = /seletor|\.delay\b|vsl_seek/g; re.lastIndex = ini; let m, n = 0, ult = -9999;
    while ((m = re.exec(pj)) && n < 6) { if (m.index - ult < 500) continue; ult = m.index; n++; W(`--- posicao ${m.index}: ${pj.slice(Math.max(0, m.index - 300), m.index + 700).replace(/\s+/g, ' ')}`); }
  } finally { await b.close(); }
})().catch((e) => W('ERRO: ' + e.message)).finally(() => console.log(out.join('\n')));
