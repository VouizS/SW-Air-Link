# SW Air Link

SW Air Link é um projeto experimental para conectar um celular Android ao navegador de outro dispositivo.

A ideia central é simples: o app no telefone funciona como ponte, enquanto o navegador vira a tela principal para pareamento, arquivos e, nas próximas versões, espelhamento real.

## Status atual

**v0.2-r3 — Pairing Real**

Esta versão inicia o pareamento real entre app, servidor local e navegador:

- servidor Node.js com salas temporárias;
- navegador gera código de conexão;
- app Flutter digita o código;
- app e navegador recebem status conectado/desconectado;
- sem espelhamento falso;
- sem controle remoto falso.

## Estrutura

- `mobile/` — aplicativo Flutter Android;
- `web/` — painel do navegador;
- `server/` — servidor local de pareamento;
- `docs/` — documentação técnica;
- `.github/workflows/` — build automático do APK.

## Como testar o pareamento local

No Termux, dentro do projeto ou usando o comando instalado:

```bash
airful server
```

Depois abra o endereço mostrado no Chromebook, PC ou outro celular.

O app Android usa o endereço WebSocket do servidor, por exemplo:

```text
ws://192.168.0.10:8080
```

O navegador cria o código, e o app entra nele.

## Regra do projeto

Este projeto não deve fingir funcionalidades. Espelhamento, controle e transferência só devem aparecer como funcionais quando existirem de verdade.
