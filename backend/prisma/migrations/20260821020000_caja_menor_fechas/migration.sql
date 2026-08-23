ALTER TABLE public.caja_menor
  ADD COLUMN IF NOT EXISTS fecha_apertura TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS fecha_cierre TIMESTAMPTZ;

UPDATE public.caja_menor
SET fecha_apertura = creada_en
WHERE fecha_apertura IS NULL;

ALTER TABLE public.caja_menor
  ALTER COLUMN fecha_apertura SET DEFAULT now(),
  ALTER COLUMN fecha_apertura SET NOT NULL,
  DROP CONSTRAINT IF EXISTS chk_caja_menor_fechas,
  ADD CONSTRAINT chk_caja_menor_fechas
    CHECK (fecha_cierre IS NULL OR fecha_cierre > fecha_apertura);
