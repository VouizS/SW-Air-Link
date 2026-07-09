# SW Air Link

SW Air Link é um projeto experimental para conectar um celular Android ao navegador de outro dispositivo, com foco em espelhamento de tela, transferência de arquivos e pareamento simples por código/QR.

## Filosofia

- O app Android deve ser simples.
- O navegador é o painel principal.
- Não fingir função que ainda não existe.
- Não pedir permissões sem necessidade.
- Priorizar modo local/grátis antes de recursos premium/remotos.

## Estrutura

- `mobile/` — app Flutter Android
- `web/` — painel web/PWA
- `server/` — servidor de pareamento
- `docs/` — documentação técnica
- `.github/workflows/` — build automático do APK

## Status

v0.1-r5 — base Flutter simples com build Android via GitHub Actions.
