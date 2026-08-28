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
    VALUES ('SUPER_ADMIN'::public.rol_tipo_enum, 1)
    ON CONFLICT (rol_tip) DO UPDATE
    SET rol_nivel = EXCLUDED.rol_nivel;
  END IF;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.tbl_organizaciones') IS NOT NULL
    AND to_regclass('public.tbl_usuarios') IS NOT NULL
    AND to_regclass('public.tbl_roles') IS NOT NULL
    AND to_regclass('public.tbl_usuarios_organizaciones') IS NOT NULL THEN
    WITH soporte_org AS (
      INSERT INTO public.tbl_organizaciones (
        org_nombre,
        org_email,
        org_activo,
        org_es_sistema
      )
      VALUES (
        'Cobro Soporte',
        'soporte@cobro.local',
        TRUE,
        TRUE
      )
      ON CONFLICT (org_nombre) DO UPDATE
      SET
        org_activo = TRUE,
        org_es_sistema = TRUE
      RETURNING id_org
    ),
    soporte_usuario AS (
      SELECT id_usu
      FROM public.tbl_usuarios
      WHERE lower(usu_usuario) = 'soporte'
      LIMIT 1
    ),
    super_admin_rol AS (
      SELECT id_rol
      FROM public.tbl_roles
      WHERE rol_tip::text = 'SUPER_ADMIN'
      LIMIT 1
    )
    INSERT INTO public.tbl_usuarios_organizaciones (rol_id, usu_id, org_id)
    SELECT super_admin_rol.id_rol, soporte_usuario.id_usu, soporte_org.id_org
    FROM soporte_org
    CROSS JOIN soporte_usuario
    CROSS JOIN super_admin_rol
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.tbl_usuarios_organizaciones existente
      WHERE existente.rol_id = super_admin_rol.id_rol
        AND existente.usu_id = soporte_usuario.id_usu
        AND existente.org_id = soporte_org.id_org
    );

    WITH soporte_org AS (
      SELECT id_org
      FROM public.tbl_organizaciones
      WHERE org_nombre = 'Cobro Soporte'
      LIMIT 1
    ),
    soporte_usuario AS (
      SELECT id_usu
      FROM public.tbl_usuarios
      WHERE lower(usu_usuario) = 'soporte'
      LIMIT 1
    ),
    super_admin_rol AS (
      SELECT id_rol
      FROM public.tbl_roles
      WHERE rol_tip::text = 'SUPER_ADMIN'
      LIMIT 1
    )
    UPDATE public.tbl_usuarios_organizaciones uo
    SET urg_activo = TRUE
    FROM soporte_org, soporte_usuario, super_admin_rol
    WHERE uo.rol_id = super_admin_rol.id_rol
      AND uo.usu_id = soporte_usuario.id_usu
      AND uo.org_id = soporte_org.id_org;
  END IF;
END;
$$;
