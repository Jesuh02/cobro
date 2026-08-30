DO $$
BEGIN
  IF to_regtype('public.rol_tipo_enum') IS NOT NULL THEN
    ALTER TYPE public.rol_tipo_enum ADD VALUE IF NOT EXISTS 'SUPER_ADMIN';
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.tbl_organizaciones') IS NOT NULL THEN
    ALTER TABLE public.tbl_organizaciones
      ADD COLUMN IF NOT EXISTS org_monto_plan numeric NOT NULL DEFAULT 0,
      ADD COLUMN IF NOT EXISTS org_moneda_plan character(3) NOT NULL DEFAULT 'COP',
      ADD COLUMN IF NOT EXISTS org_acceso_hasta date,
      ADD COLUMN IF NOT EXISTS org_suspendida_en timestamp with time zone,
      ADD COLUMN IF NOT EXISTS org_motivo_suspension character varying(220),
      ADD COLUMN IF NOT EXISTS org_es_sistema boolean NOT NULL DEFAULT false;
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.tbl_organizaciones') IS NOT NULL THEN
    ALTER TABLE public.tbl_organizaciones
      ADD CONSTRAINT chk_tbl_organizaciones_monto_plan
      CHECK (org_monto_plan >= 0);
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.tbl_organizaciones') IS NOT NULL THEN
    ALTER TABLE public.tbl_organizaciones
      ADD CONSTRAINT chk_tbl_organizaciones_moneda_plan
      CHECK (org_moneda_plan = upper(org_moneda_plan));
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.tbl_organizaciones') IS NOT NULL THEN
    CREATE INDEX IF NOT EXISTS ix_tbl_organizaciones_acceso
      ON public.tbl_organizaciones (org_activo, org_acceso_hasta)
      WHERE NOT org_es_sistema;
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regtype('public.rol_tipo_enum') IS NOT NULL
    AND to_regclass('public.tbl_roles') IS NOT NULL THEN
    INSERT INTO public.tbl_roles (rol_tip, rol_nivel)
    VALUES ('SUPER_ADMIN'::public.rol_tipo_enum, 4)
    ON CONFLICT (rol_tip) DO UPDATE
    SET rol_nivel = EXCLUDED.rol_nivel;
  END IF;
END;
$$;
