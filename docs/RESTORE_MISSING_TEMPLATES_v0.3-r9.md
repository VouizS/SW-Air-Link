# v0.3-r9 — Restore Missing Templates

Erro corrigido:
- cp: cannot stat 'app_templates/main.dart': No such file or directory

A v0.3-r9 recria `mobile/app_templates/main.dart`, `pubspec.yaml`, `widget_test.dart`, servidor local e workflow robusto.

Observação:
Se `native_templates/android` estiver ausente, a build segue com APK Flutter puro. A próxima etapa pode reintroduzir o nativo de MediaProjection com mais segurança depois que a esteira voltar a gerar APK.
