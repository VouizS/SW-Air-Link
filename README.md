# SW Air Link

SW Air Link é um projeto experimental para conectar um celular Android ao navegador de outro dispositivo.

O objetivo é criar uma ferramenta simples e acessível para:

- parear telefone e navegador por código/QR;
- espelhar a tela do Android no navegador em versões futuras;
- transferir arquivos entre telefone e navegador;
- ajudar em cenários onde a tela do telefone está ruim, quebrada ou difícil de usar.

## Filosofia

O aplicativo móvel deve ser simples. Ele funciona como uma ponte.
O navegador é o painel principal.

## Estado atual

v0.1-r4 — base real do projeto:

- app Flutter mínimo;
- página web inicial;
- servidor WebSocket básico para pareamento futuro;
- workflow de build Android no GitHub Actions;
- comando Termux `airful` para push, build, download de APK/log e upload via rclone.

## Regra importante

Não fingir espelhamento, controle remoto, conexão ou transferência.
Função só aparece como funcional quando existir implementação real.
