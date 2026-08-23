ALTER TABLE credito
  ADD COLUMN IF NOT EXISTS refinanciado_en TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS valor_principal_anterior NUMERIC(14, 2),
  ADD COLUMN IF NOT EXISTS valor_principal_refinanciado NUMERIC(14, 2);

CREATE INDEX IF NOT EXISTS ix_credito_refinanciado
  ON credito (refinanciado_en DESC)
  WHERE refinanciado_en IS NOT NULL;
