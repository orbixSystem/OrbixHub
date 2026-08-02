# Atualização automática do app (Android e Windows)

O app instalado se atualiza sozinho. O fluxo é:

```
push na master
   └─ CI (release.yml) → builda APK + instalador Windows
                       → publica release com manifest.json (versão, mínimo, sha256)

app abre → GET /api/app/update?platform=android|windows
        → backend lê a última release (com cache) e responde versão + link + hash
        → app compara com a versão instalada e decide
```

**Por que passa pelo backend** e não direto no GitHub: é o servidor que sabe qual
versão ele ainda atende (`minSupported`), o cache evita o limite de 60
requisições/hora da API pública do GitHub, e a indireção mantém tudo funcionando
se o repositório virar privado um dia.

## Comportamento no app

| Situação | O que acontece |
|---|---|
| Versão nova disponível | Banner discreto no topo, com "Depois" |
| Versão instalada < `minSupported` | Tela bloqueante: só sai atualizando |
| Sem release / endpoint desligado / offline | Nada — checar atualização nunca atrapalha o trabalho |

O arquivo baixado tem o **sha256 conferido antes de instalar**: se não bater, a
instalação é abortada (o app está prestes a executar um binário).

## Configuração do servidor (`back/.env`)

```bash
APP_UPDATE_ENABLED=true
GITHUB_RELEASES_REPO=orbixSystem/OrbixHub
GITHUB_RELEASES_TOKEN=   # opcional: só eleva o limite da API do GitHub
```

Lembre que `--env-file` é lido na criação do container: depois de editar o
`.env` na EC2, **recrie** o container (um `restart` mantém as variáveis antigas).

## Secrets do CI (Settings → Secrets → Actions)

Sem eles o workflow falha de propósito — um APK assinado com a chave de debug
não consegue atualizar as instalações existentes.

| Secret | Como obter |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i front/android/app/orbix-release.jks \| pbcopy` |
| `ANDROID_KEYSTORE_PASSWORD` | valor de `storePassword` em `front/android/key.properties` |
| `ANDROID_KEY_ALIAS` | `orbix` |
| `ANDROID_KEY_PASSWORD` | valor de `keyPassword` (igual ao store) |

⚠️ **Guarde `orbix-release.jks` e as senhas fora do repositório** (gerenciador de
senhas / cofre). Perder a chave significa nunca mais conseguir publicar
atualização para quem já instalou — só desinstalando e perdendo os dados locais.

## Quando forçar atualização

`front/release.json` guarda o `minSupported`. Suba esse valor **apenas** quando
uma mudança do servidor quebrar de fato os apps antigos — por exemplo, quando
uma rota passa a exigir um campo que a versão anterior não envia. É o que evita
o erro "property X should not exist" chegando ao usuário: em vez de falhar no
meio do uso, o app pede a atualização de cara.

Fora esse caso, deixe como está: atualização forçada interrompe a oficina no
meio do expediente.

## Publicando

Merge/push na `master` já dispara. Para publicar sem alterar código:
Actions → "Release app" → Run workflow.
