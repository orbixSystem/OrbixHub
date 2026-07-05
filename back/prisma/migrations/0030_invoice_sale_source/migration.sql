-- 0030 — NF pode ser emitida a partir de uma VENDA (além da OS). Aditivo.
-- invoice.sale_id = ponteiro puro (sem FK) para a venda de origem, análogo ao
-- order_id. Exatamente um dos dois é preenchido por nota.
ALTER TABLE invoice
  ADD COLUMN IF NOT EXISTS sale_id uuid;

CREATE INDEX IF NOT EXISTS idx_invoice_tenant_sale
  ON invoice (tenant_id, sale_id) WHERE sale_id IS NOT NULL;
