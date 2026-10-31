# VSL Host - contexto e histórico

## Regra
- Testar sempre pela tela (o resultado que vale é o que a ferramenta mostra).

## Caso resolvido (31/10/2026): "Validar script" -> "Não foi possível abrir a página"
- Landing: https://alkaburn-presell.boldhabitco.cloud/ (atrás da Cloudflare, zona boldhabitco.cloud)
- Diagnóstico (scripts/diagnostico-landing.ps1, rodado no PC do usuário):
  DNS ok, SSL válido (Google Trust Services), 200 como navegador e como robô,
  pixel BuyGoods presente (@beworke/pixel ... pixel.hwaffiliate-landing.global.js),
  todos os caminhos 200 (o 404 em https://media.boldhabitco.cloud/ é só a raiz do domínio de mídia, normal).
- Causa: Cloudflare **Bot Fight Mode** ligado bloqueava o validador (que acessa de IP de data center).
- Correção: Bot Fight Mode desligado via scripts/cloudflare-validador.ps1 (API com token).
- Resultado na tela: "Script encontrado - O pixel BuyGoods está na página".

## Checklist para novas landings neste domínio (ou outro na Cloudflare)
1. Subdomínio criado e com proxy da Cloudflare; aguardar o SSL ser emitido.
2. Bot Fight Mode DESLIGADO na zona (senão validador e robôs de revisão de anúncios são bloqueados).
3. Security Level diferente de "I'm Under Attack".
4. Rodar scripts/diagnostico-landing.ps1 -Url "<url>" e conferir tudo verde.
5. Validar na ferramenta.

## Scripts (Windows PowerShell, sem Git necessário)
- scripts/diagnostico-landing.ps1  -> DNS, SSL, HTTP navegador x robô, pixel, todos os caminhos.
- scripts/cloudflare-validador.ps1 -> lê configs/bloqueios da Cloudflare e desliga Bot Fight Mode (pede confirmação).
