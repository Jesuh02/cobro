ALTER TABLE public.tbl_creditos
  ADD COLUMN IF NOT EXISTS cre_plazo_dias INTEGER;

UPDATE public.tbl_creditos cr
SET cre_plazo_dias = COALESCE(
  (
    SELECT (COUNT(*)::int * MAX(
      CASE pc.pcr_frecuencia::text
        WHEN 'SEMANAL' THEN 7
        WHEN 'QUINCENAL' THEN 15
        WHEN 'MENSUAL' THEN 30
        ELSE 1
      END
    ))
    FROM public.tbl_cuotas cu
    JOIN public.tbl_productos_creditos pc ON pc.id_pcr = cr.pcr_id
    WHERE cu.cre_id = cr.id_cre
      AND UPPER(cu.cuo_estado::text) != 'ANULADA'
  ),
  30
)
WHERE cr.cre_plazo_dias IS NULL;
