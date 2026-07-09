# Pareamento local

A v0.2-r3 usa um servidor local para aproximar o app Android e o navegador.

## Fluxo

1. Rode `airful server` no Termux.
2. Abra o endereço HTTP mostrado no navegador do Chromebook/PC/outro celular.
3. Clique em **Criar código** no navegador.
4. No app, coloque o endereço WebSocket mostrado pelo servidor.
5. Digite o código gerado no navegador.
6. Toque em **Preparar conexão**.

## Observação importante

Esta versão ainda não transmite a tela. Ela testa a ponte real de conexão. A transmissão de tela entra depois, usando MediaProjection no Android.
