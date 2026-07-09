# Notas técnicas

## App

Flutter será usado para a interface simples do Android.
A captura real da tela, quando implementada, precisará de camada nativa Android com MediaProjection.

## Web

O navegador será o painel principal do produto.

## Server

O servidor inicial é apenas uma base WebSocket para pareamento e sinalização futura.

## Logs

O comando `airful` deve salvar logs de erro diretamente em:

/storage/emulated/0/Download/

com nome parecido com:

SW-Air-Link_BUILD_ERROR_<run_id>_<data>.txt
