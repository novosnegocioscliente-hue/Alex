# VSL Host — arquitetura alvo ("ingredientes entram, link publicado sai")

Data: 01/11/2026. Base: raio-x do código real (painel/servidor.js, lib/funil.js, lib/teste.js,
player/vsl-player.js), testes no navegador do funil Kings Code, documentação VTurb/Panda/Cloudflare,
skills modo-clone (o que TRAVA × o que TROCA), replica-recon (mapa antes de construir) e system-design.

## 1. Requisito do usuário (não negociável)
O usuário só entrega ingredientes. A ferramenta faz toda a arquitetura e devolve **só o link publicado**,
com a VSL já hospedada e tocando dentro da página. Nenhuma decisão técnica na tela.

## 2. Por que a versão atual quebra
| Causa raiz | Sintomas vistos |
|---|---|
| Lê o HTML como **texto** (regex), não como página | player dentro de comentário; script do timer confundido com o do VTurb; link de exemplo não trocado |
| Teste do painel só faz **download do HTML** | "FUNIL COMPLETO" com player invisível e oferta que nunca aparecia |
| Decisões deixadas para o usuário (marcar links, [VSL], caixa do botão, modelo do funil) | presell igual à VSL; botão desligado; publicar antes de testar |

## 3. O que TRAVA × o que TROCA (regra de clone de página)
- **TRAVA (fica igual ao original):** layout, textos, imagens, ordem das seções, script de delay da página
  (displayHiddenElements / delaySeconds), timer e escassez, FAQ, garantia.
- **TROCA (sempre):**
  1. player do produtor (VTurb/Panda — bloqueiam domínio de terceiros) → vídeo hospedado no R2, **no mesmo lugar**;
  2. todos os botões de compra (inclusive links de exemplo e kits) → checkout do afiliado + UTMs;
  3. pixels/rastreadores do produtor → removidos; pixel do afiliado instalado;
  4. imagens/arquivos locais → hospedados junto com a página.

## 4. Pipeline (cada etapa tem verificação; falha = conserto automático ou 1 pergunta objetiva)
```
INGREDIENTES ─► E1 Coleta ─► E2 Análise no navegador ─► E3 Montagem (DOM) ─► E4 Vídeo HLS→R2
                                                                                  │
            LINK ◄── E7 Entrega ◄── E6 Verificação em navegador real ◄── E5 Publicação (Pages)
```
- **E1 Coleta:** link/zip/HTML viram uma pasta local com todos os arquivos (imagens baixadas e reescritas).
- **E2 Análise renderizada (Chrome headless, já instalado via puppeteer-core):** abre a página com JS desligado
  e descobre no DOM real (comentários não existem para o navegador):
  - onde está o player (tag `vturb-smartplayer`, iframe Panda/converteai, `div#vid-*`, ou slot vazio `.vsl/.video/.player` abaixo do H1);
  - o tempo do pitch (`displayHiddenElements(N…)`, `delaySeconds`, config do player);
  - os blocos escondidos (`.hide`, `.esconder`, display:none) e os botões de compra dentro deles;
  - pixels do produtor; se a página é VSL (tem player) ou presell (não tem).
- **E3 Montagem no DOM** (não em texto): troca o nó do player, remove só os scripts que carregam o player do produtor,
  mantém o script de delay (o player novo responde à API do VTurb) **e** configura o player para revelar os
  blocos escondidos no pitch (redundância), troca botões, remove pixels do produtor, instala o do afiliado.
- **E4 Vídeo:** conversão HLS e envio ao R2 (já existe).
- **E5 Publicação:** Cloudflare Pages + domínio (já existe).
- **E6 Verificação real (portão):** celular e desktop. Player visível na primeira tela; vídeo toca; avança até o
  pitch; oferta aparece; todos os botões levam ao checkout com o ID de afiliado e as UTMs; nenhum resto do
  player/pixel do produtor; pixel do afiliado presente; prints em 0s e no pitch.
  **Só entrega o link se tudo passar.**
- **E7 Entrega:** o link + uma linha de status. Se falhar: o problema exato + 1 pergunta, nunca uma tela de opções.

## 5. Formulário mínimo
| Campo | Obrigatório | Observação |
|---|---|---|
| Nome da oferta | sim | vira o endereço `nome.dominio` |
| Página da VSL (link, zip ou HTML) | sim | |
| Vídeo de vendas (arquivo) | sim | |
| Link do checkout (com ID de afiliado) | sim | |
| Presell (link, zip ou HTML) | não | **sem presell → a ferramenta cria um advertorial automático** (skills de presell/advertorial), em inglês, baseado na VSL |
| Tempo do pitch | não | detectado da página; perguntado só se não achar |
| Pixel / scripts | não | fica salvo como padrão |
| Criativos | não | padrão: um link com `utm_content=<nome do criativo>` por criativo (usuário sem preferência) |

## 6. Migração (a partir do código atual, sem jogar fora o que funciona)
1. **M1 — Verificação real como portão** (substitui teste.js pelo teste em Chrome). Maior ganho: nunca mais "funil completo" falso.
2. **M2 — Análise e montagem pelo DOM** (Chrome com JS desligado para ler/editar; sem dependência nova).
3. **M3 — Formulário mínimo** sobre o fluxo `POST /api/oferta-rapida` que já existe no servidor.
4. **M4 — Detecção automática** de pitch, presell×VSL, pixels do produtor, kits.
5. **M5 — Limpeza da tela:** some "Links da página", "[VSL]", caixa do botão, escolha manual de modelo.

## 7. Trade-offs
- Chrome headless (já no PC) em vez de parser JS novo: zero instalação, mesmo motor do lead; custo: ~5–20 s por análise.
- Portão de verificação atrasa a entrega em ~1 min; em troca, link entregue = funil funcionando.
- Redundância no delay (script da página + player): cobre páginas cujo script não acha o player.

## 8. Decisões do usuário (01/11/2026)
- Sem presell entregue → **criar presell automática** (advertorial em inglês a partir da VSL; usuário revisa depois).
- Criativos → sem preferência; padrão adotado: link com UTM por criativo (não altera a página).
- Rastreamento → sem preferência; padrão: instalar o(s) script(s) colados no campo de pixel (hoje o pixel BuyGoods),
  salvo como padrão para as próximas ofertas, e remover sempre os pixels do produtor.
