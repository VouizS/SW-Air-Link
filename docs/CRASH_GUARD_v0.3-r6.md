# v0.3-r6 — Test Harness Fix + Crash Guard

Correção focada no crash ao aceitar a permissão de captura do Android.

Mudanças:
- Foreground Service para MediaProjection.
- Notification Channel.
- foregroundServiceType="mediaProjection".
- Tratamento do retorno de permissão na Activity.
- Processamento de frames dentro do Service.
- Envio de frames para Flutter por EventChannel.
