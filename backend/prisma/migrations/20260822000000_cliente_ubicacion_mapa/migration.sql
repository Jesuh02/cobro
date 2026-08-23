ALTER TABLE public.tbl_personas
  ADD COLUMN IF NOT EXISTS per_latitud numeric(10, 7),
  ADD COLUMN IF NOT EXISTS per_longitud numeric(10, 7);

ALTER TABLE public.tbl_personas
  DROP CONSTRAINT IF EXISTS ck_tbl_personas_coordenadas_completas;

ALTER TABLE public.tbl_personas
  ADD CONSTRAINT ck_tbl_personas_coordenadas_completas CHECK (
    (per_latitud IS NULL AND per_longitud IS NULL)
    OR (
      per_latitud IS NOT NULL
      AND per_longitud IS NOT NULL
      AND per_latitud BETWEEN -90 AND 90
      AND per_longitud BETWEEN -180 AND 180
    )
  );

ALTER TABLE public.cliente_direccion
  DROP CONSTRAINT IF EXISTS ck_cliente_direccion_coordenadas_completas;

-- NOT VALID preserves any historical rows with incomplete coordinates while
-- enforcing the invariant for every new or updated address from this release.
ALTER TABLE public.cliente_direccion
  ADD CONSTRAINT ck_cliente_direccion_coordenadas_completas CHECK (
    (latitud IS NULL AND longitud IS NULL)
    OR (
      latitud IS NOT NULL
      AND longitud IS NOT NULL
      AND latitud BETWEEN -90 AND 90
      AND longitud BETWEEN -180 AND 180
    )
  ) NOT VALID;
