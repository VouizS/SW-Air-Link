# Roadmap — SW Air Link

## v0.1-r5 — Foundation Build Fix
- Corrigir erro do Flutter Analyze causado por teste padrão chamando `MyApp` sem classe correspondente.
- Manter app Android simples.
- Gerar APK debug real pelo GitHub Actions.
- Salvar logs de erro na raiz do Download e também na pasta `SW-Air-Link/Logs`.

## v0.2 — Pairing Prototype
- Navegador gera código de sala.
- App Android digita código.
- Servidor registra presença do navegador e do telefone.

## v0.3 — File Transfer
- Enviar arquivos do celular para navegador.
- Enviar arquivos do navegador para celular.

## v0.4 — Screen Mirror Experimental
- MediaProjection no Android.
- Captura de tela real, com confirmação do sistema.
- Transmissão para navegador.

## Regras
- Sem espelhamento falso.
- Sem controle remoto falso.
- Interface simples no app.
- Navegador como tela principal.
