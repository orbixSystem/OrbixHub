-- 0063 — emissão real de NFS-e pela API Nacional (gov.br). Aditivo.
--
-- 1) Cofre do certificado A1 de cada tenant. Sem provedor intermediário, quem
--    assina a DPS e abre o mTLS com a Sefin Nacional somos nós — então o .pfx
--    precisa ficar guardado. Fica CIFRADO (AES-256-GCM, chave só no env do
--    servidor: FISCAL_CERT_KEY); o banco sozinho não abre o certificado.
--    Um certificado por tenant: trocar = sobrescrever (sem hard delete de nota,
--    mas o certificado vencido não tem histórico a preservar).
CREATE TABLE IF NOT EXISTS invoice_certificate (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  pfx_encrypted      text NOT NULL,
  password_encrypted text NOT NULL,
  cnpj               text,
  subject            text,
  not_before         timestamptz,
  not_after          timestamptz,
  uploaded_by        uuid,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_invoice_certificate_tenant ON invoice_certificate(tenant_id);

ALTER TABLE invoice_certificate ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_certificate FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'invoice_certificate' AND policyname = 'tenant_isolation') THEN
    CREATE POLICY tenant_isolation ON invoice_certificate
      USING (tenant_id = current_tenant_id())
      WITH CHECK (tenant_id = current_tenant_id());
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE ON invoice_certificate TO app_user;

-- 2) Numeração da DPS. A série/número da DPS é do CONTRIBUINTE (nós) e não pode
--    repetir por emitente+série; o número da NFS-e quem dá é a Sefin (coluna
--    `number`). Numeração separada por ambiente: homologação não consome produção.
--    `nfse_xml` guarda o XML autorizado devolvido pela Sefin (é o documento fiscal).
ALTER TABLE invoice ADD COLUMN IF NOT EXISTS dps_series text;
ALTER TABLE invoice ADD COLUMN IF NOT EXISTS dps_number integer;
ALTER TABLE invoice ADD COLUMN IF NOT EXISTS nfse_xml   text;
CREATE UNIQUE INDEX IF NOT EXISTS uq_invoice_dps_number
  ON invoice(tenant_id, environment, dps_series, dps_number)
  WHERE dps_number IS NOT NULL;
