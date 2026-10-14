# NFS-e direto na API Nacional (gov.br) — decisão e design

> **Status:** DECIDIDO pelo dono em 2026-10-08. Substitui a escolha de provedor da
> spec `2026-07-16-nf-servico-produto-design.md` (Nuvem Fiscal). O que ela definiu
> de classificação fiscal e fronteira de config continua valendo.
> Branch: `feat/nf-emissao-govbr`.

## Decisão

Emitir **NFS-e (nota de serviço) direto na API NFS-e Nacional**, sem provedor pago.

- **Custo zero por nota** para a Orbix. O único custo é o certificado A1 de cada
  cliente, pago por ele.
- **Cada tenant usa o próprio certificado e-CNPJ A1.** A API exige o certificado do
  contribuinte. Não existe procuração eletrônica: a Fenacon pediu em jun/2026 e o
  pedido segue pendente. Um certificado da Orbix ou de um sócio **não** assina nota
  de outra empresa.
- Cobertura: desde jan/2026 todos os municípios são obrigados ao padrão nacional
  (LC 214/2025), e desde set/2026 as empresas do Simples também.
- **Nota de produto (NFC-e/NF-e) fica fora** desta fase. Ela vai para a Sefaz de cada
  UF. Uma OS mista emite NFS-e **só dos serviços**.
- O código da Nuvem Fiscal (cliente OAuth + cadastro) continua no repo, desligado.
  Trocar de provedor = outra implementação do contrato `FiscalGateway`.

## Como funciona

```
issue() ─► pendências? ─► 400 com a lista
        ─► tx: reserva nº da DPS (lock por tenant/ambiente/série) + rascunho
        ─► FORA de tx: GovBrNfseGateway
              monta DPS (leiaute 1.01) ─► assina XMLDSig com o A1 ─► gzip+base64
              POST {Sefin}/nfse  (mTLS com o mesmo A1)
              201 → chave de acesso + XML da NFS-e  │ 4xx → rejeitada (erros da Sefin)
              queda de conexão/5xx → GET /dps/{id}: se a nota existe, recupera
        ─► tx: grava status, chave, nº da NFS-e, XML autorizado (invoice.nfse_xml)
```

| Peça | Arquivo |
|---|---|
| XML da DPS e do evento de cancelamento (funções puras, ordem do XSD) | `invoice/fiscal/govbr/dps-xml.ts` |
| Assinatura XMLDSig (RSA-SHA1, C14N, enveloped) | `invoice/fiscal/govbr/xml-signer.ts` |
| Leitura do .pfx (node-forge: RC2/3DES legados) + CNPJ do titular | `invoice/fiscal/govbr/a1-certificate.ts` |
| Cofre AES-256-GCM | `invoice/fiscal/govbr/cert-cipher.ts` + `invoice-certificate.service.ts` |
| Transporte mTLS | `invoice/fiscal/govbr/nfse-http.ts` |
| Gateway | `invoice/fiscal/govbr/govbr-nfse-gateway.ts` |

**Banco (migration `0063_invoice_govbr_nfse`, aditiva, nos 3 lugares):**
- tabela `invoice_certificate` (RLS + FORCE, uma linha por tenant, .pfx e senha cifrados);
- `invoice.dps_series`, `invoice.dps_number` (único por tenant+ambiente+série) e `invoice.nfse_xml`.

**API:**
- `GET /invoices/config` passa a devolver `provider` e `pendencias`;
- `POST /invoices/config/certificate` valida e guarda o certificado no cofre;
- `GET /invoices/:id/xml` devolve o XML autorizado;
- `GET /invoices/:id/pdf` devolve o DANFSe, buscado no ADN com o certificado.

**Config:**
- núcleo: `codigoIbge` (o front preenche pelo CEP);
- módulo: `codigoServicoNacional` (cTribNac, 6 díg.), `codigoNbs` (9 díg., obrigatório
  no leiaute atual), `aliquotaIss` e `percentualTributosSimples` (opcionais).

**Env:**
- `FISCAL_PROVIDER=govbr`;
- `FISCAL_CERT_KEY`: 32 bytes em base64. Sem ela o servidor não sobe com govbr;
- `FISCAL_ENVIRONMENT`: é o **teto**. Com `homologacao`, nada vai para produção;
- `NFSE_*_URL`: endpoints oficiais, ajustáveis sem deploy.

**Segurança:**
- a chave privada só existe em memória durante a emissão;
- o .pfx nunca volta pela API;
- o upload confere a senha, a validade e se o CNPJ do certificado é o CNPJ da empresa;
- upload e emissão são auditados.

## O que está validado e o que não está

Validado sem certificado real:
- o XML gerado (DPS, DPS sem tomador, evento de cancelamento), já assinado, passa nos
  **XSDs oficiais v1.01**;
- a assinatura verifica;
- 12 testes do gateway contra uma Sefin simulada: autorizada, rejeitada, queda com
  recuperação, 5xx e cancelamento;
- 7 e2e contra o banco real: cofre, RLS entre tenants, prontidão, numeração e
  emissão→XML→PDF→cancelamento.

**Só o primeiro teste em homologação com certificado real confirma:**
1. o caminho exato da URL. A documentação diverge sobre o prefixo `/API/`; se vier
   404/E999, ajuste `NFSE_SEFIN_URL_HOMOLOGACAO`;
2. o algoritmo da assinatura. Usamos SHA-1, como os emissores open-source em
   produção. Se a Sefin recusar, troque as 2 constantes em `xml-signer.ts` para SHA-256;
3. as regras de negócio do município: alíquota, código de serviço aceito e se exige IM;
4. o formato do JSON de erro (o parser já aceita variações de caixa).

## Roteiro do primeiro teste (homologação, com o certificado do sócio)

1. Gerar a chave do cofre:
   `node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"`.
2. No `back/.env` local: `FISCAL_PROVIDER=govbr`, `FISCAL_ENVIRONMENT=homologacao` e
   `FISCAL_CERT_KEY=<a chave>`. Subir o back.
3. Entrar com um tenant cujo **CNPJ seja o do certificado**.
4. Configurações › Empresa: regime tributário, CEP (preenche o código IBGE), e-mail.
5. Configurações › Nota Fiscal: código de tributação nacional e NBS (confirmar com o
   contador). Enviar o `.pfx` e a senha. O card "Pronto para emitir?" deve ficar verde.
6. Criar uma OS com um serviço de valor baixo e emitir a nota.
7. Se for rejeitada, a mensagem da Sefin aparece na nota (`E0xxx: …`). Ajuste a
   config ou um dos pontos 1–4 acima e emita de novo. A numeração avança sozinha.
8. Autorizada: abra o PDF e o XML pela tela da nota e teste o cancelamento.

> Homologação ("produção restrita") não tem valor fiscal. Produção exige
> `FISCAL_ENVIRONMENT=producao` no servidor **e** o tenant escolher produção na tela.

## Pendências

- Nota de produto (NFC-e/NF-e) direto na Sefaz da UF, ou por um provedor só para produto.
- Código de serviço por item: hoje vale um código padrão por tenant, que atende a
  oficina típica. O snapshot por linha (`invoice_line.codigo_servico`) já existe.
- Grupo IBS/CBS da reforma tributária: é opcional no leiaute 1.01. Acompanhar as NTs.
- Consultar a NFS-e por chave para notas que ficaram em `error` com resposta ambígua.
  Hoje a recuperação acontece no próprio envio.
