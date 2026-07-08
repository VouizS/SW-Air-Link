# SW Air Link

SW Air Link é um projeto experimental para conectar um celular Android ao navegador de outro dispositivo, permitindo espelhamento de tela, transferência de arquivos e pareamento por QR Code/código.

## Direção do produto

A primeira versão deve ser simples. O app Android funciona como ponte, enquanto o navegador é o painel principal.

## Objetivo

Criar uma alternativa acessível e transparente para espelhar a tela do telefone no navegador, útil especialmente quando o celular ainda funciona, mas a tela está danificada, com toque ruim ou difícil de usar.

## Estrutura

- `mobile/` — aplicativo Flutter Android
- `web/` — painel web/PWA para navegador
- `server/` — servidor de pareamento por WebSocket
- `docs/` — documentação técnica
- `.github/workflows/` — build automático do APK

## Status

v0.1-r2 — Project Foundation + Termux safe directory fix.

## Regras

- Não fingir espelhamento.
- Não mostrar controle remoto se ele ainda não existir.
- Não pedir permissões desnecessárias.
- Priorizar app simples e navegador funcional.
- Ser transparente com o usuário.
