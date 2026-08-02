# Atualização automática do app (Android e Windows)

O app instalado se atualiza sozinho. O fluxo é:

```
push na main
   └─ CI (release.yml) → builda APK + instalador Windows (scripts/installer.iss)
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

> **Hoje toda atualização é obrigatória.** `front/release.json` está com
> `forceAll: true`: o CI publica `minSupported` igual à versão/build que está
> saindo, então qualquer app anterior fica bloqueado. É o certo no começo do
> produto — parque pequeno, mudanças rápidas, ninguém preso a uma versão velha.
> Quando a base crescer, troque para `false` e o banner adiável volta a valer.
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

## Windows: assinatura digital

Sem assinar, o Windows 11 com **Smart App Control** recusa o instalador com
_"an application control policy has blocked this file"_. Não é bug do
instalador: essa política bloqueia todo executável sem assinatura e **não aceita
exceção por arquivo** — ou o binário é assinado, ou não roda. Em máquinas com
Smart App Control desligado (a maioria das que vieram de upgrade) o instalador
funciona normalmente.

A solução é um certificado de **code signing** (Authenticode):

| Tipo | Custo/ano | Reputação |
|---|---|---|
| OV (validação da empresa) | ~US$ 200-400 | Ganha reputação com o tempo; SmartScreen ainda pode avisar no começo |
| EV (validação estendida) | ~US$ 300-600 | Reputação imediata, sem aviso |

Com o certificado em mãos, basta cadastrar dois secrets — o passo de assinatura
já existe no workflow e liga sozinho:

| Secret | Conteúdo |
|---|---|
| `WINDOWS_CERT_PFX_BASE64` | `base64 -i certificado.pfx \| tr -d '\n'` |
| `WINDOWS_CERT_PASSWORD` | senha do .pfx |

Sem eles o build continua funcionando e apenas emite um aviso no log.

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

## Quando parar de forçar

Enquanto `forceAll` for `true`, o `minSupported` do arquivo é ignorado (o CI usa
a própria versão publicada). Ao trocar para `false`, ele volta a valer: suba
esse valor **apenas** quando
uma mudança do servidor quebrar de fato os apps antigos — por exemplo, quando
uma rota passa a exigir um campo que a versão anterior não envia. É o que evita
o erro "property X should not exist" chegando ao usuário: em vez de falhar no
meio do uso, o app pede a atualização de cara.

Fora esse caso, deixe como está: atualização forçada interrompe a oficina no
meio do expediente.

## Numeração das versões

A versão publicada é montada assim:

```
major.minor  ← do front/pubspec.yaml (você controla)
      .patch ← número da execução do workflow (automático)
```

| pubspec | execução | versão publicada |
|---|---|---|
| `1.0.0` | #1 | **1.0.1** |
| `1.0.0` | #2 | **1.0.2** |
| `1.1.0` (você editou) | #4 | **1.1.4** |

O patch é automático para que **cada release tenha um número diferente**: com a
versão parada, o aviso dizia "Versão 1.0.0 disponível" para quem já tinha a
1.0.0 — parecia defeito. Para subir major ou minor, edite o pubspec; **deixe o
patch em `.0`**, porque ele é ignorado (o CI avisa se estiver diferente).

Além da versão, cada publicação tem um **build**: `10000 + número da execução`.

O offset de 10000 não é enfeite: no Android o build reportado é o `versionCode`,
e um APK gerado localmente com `--split-per-abi` já nasce em 1001/2001/4001
(o Flutter soma um prefixo por arquitetura). Sem o offset, a primeira publicação
do CI sairia com build `1` e o aparelho a trataria como mais antiga que a
instalada — nenhuma atualização apareceria. **Mantenha builds locais abaixo de
10000.**

Como a comparação é por `(versão, build)`, publicar sem mexer no pubspec já
conta como versão nova. Suba a `version` quando a mudança for relevante para o
usuário — é o número que ele vê no aviso.

## Publicando

Merge/push na `main` já dispara. Para publicar sem alterar código:
Actions → "Release app" → Run workflow.
