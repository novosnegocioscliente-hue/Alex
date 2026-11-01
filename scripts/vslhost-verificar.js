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
        escondidos: [...document.querySelectorAll('.hide,.vsl-hide,.esconder,.hidden')].filter((e) => !vis(e)).length,
        posicao: (() => { const y = (q) => { const e = document.querySelector(q); return e ? Math.round(e.getBoundingClientRect().top + scrollY) : null; }; return { playerY: y('.vslp') || y('.vsl-player'), h1Y: y('h1'), mainY: y('main'), footerY: y('footer'), alturaPagina: document.documentElement.scrollHeight }; })()
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
