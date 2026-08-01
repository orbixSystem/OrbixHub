# Ambientes do app (dart-define-from-file)

Cada arquivo aqui é um **conjunto de configurações de build**, aplicado com
`--dart-define-from-file`. São só URLs públicas e flags — **nunca coloque
segredo aqui** (token, senha, chave): tudo neste diretório é compilado dentro
do binário e vai junto com o app para o dispositivo do usuário.

| Chave | O que faz |
|---|---|
| `API_BASE_URL` | Base da API (com `/api`). Sem ela, o app cai no default de dev (`localhost:4400`, ou `10.0.2.2:4400` no emulador Android). |
| `APP_PUBLIC_URL` | Origem pública do app web — usada para montar o link de acompanhamento que o cliente recebe. |
| `DEV_TOOLS` | Liga o dev-inbox e afins. Em `--release` já é `false` por padrão; deixamos explícito em `prod.json` como segunda barreira. |

## Como usar

```bash
# produção
flutter build apk     --release --dart-define-from-file=env/prod.json
flutter build windows --release --dart-define-from-file=env/prod.json
flutter build web     --release --dart-define-from-file=env/prod.json

# desenvolvimento
flutter run -d chrome --dart-define-from-file=env/dev.json
```

Ou use os scripts em `../scripts/`, que já fazem `pub get`, geração de código e
verificação antes de empacotar.

## Antes de publicar

- **Android**: `android/app/build.gradle.kts` ainda assina o release com a
  **chave de debug** (TODO do template do Flutter). Serve para instalar e
  testar; para a Play Store — e para conseguir publicar atualizações depois —
  gere um keystore e configure `android/key.properties`.
- O backend em produção precisa de `hub.orbixsystem.com` em `CORS_ORIGINS`, e
  de `STORAGE_PUBLIC_URL` apontando para o domínio público (senão as fotos
  saem com URL de `localhost`; o app corrige loopback, mas o certo é o
  servidor devolver a URL final).
