# Notas técnicas — SW Air Link

## Filosofia

O aplicativo Android deve ser simples. Ele existe para conectar, pedir permissões necessárias e enviar dados ao navegador.

O navegador é o painel principal, onde a pessoa vê a tela, baixa arquivos e usa recursos futuros.

## Camadas planejadas

1. Flutter/Dart para app Android.
2. Ponte nativa Android/Kotlin para MediaProjection futuramente.
3. Web/PWA para painel no navegador.
4. Servidor WebSocket para pareamento e sinalização.
5. WebRTC futuramente para vídeo/espelhamento.

## Drive de artefatos

A automação local tenta enviar APKs e logs via rclone para o Drive configurado no Termux. Conta indicada para o projeto: vlacostens@gmail.com.

## Atenção

Esta versão ainda não espelha tela. Ela cria a fundação real para próximas versões.
