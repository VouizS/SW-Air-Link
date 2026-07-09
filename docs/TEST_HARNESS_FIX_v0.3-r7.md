# v0.3-r7 — Test Harness Fix + Crash Guard

Correção focada na build: o teste automático ainda procurava o texto antigo "espelhamento experimental real", mas a interface da linha r5/r6 mudou para Crash Guard. Esta versão troca o teste para validar elementos estáveis da tela, sem bloquear a build por rodapé/texto de versão.

Mantido:
- Foreground Service de MediaProjection
- notification channel
- foregroundServiceType mediaProjection
- frames reais por WebSocket
- modo Claro/AMOLED
- comandos airful server-bg e airserver
