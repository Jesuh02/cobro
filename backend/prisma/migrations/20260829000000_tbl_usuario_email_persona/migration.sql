ALTER TABLE public.tbl_personas
  ADD COLUMN IF NOT EXISTS per_email character varying(180);

DO $$
BEGIN
  ALTER TABLE public.tbl_personas
    ADD CONSTRAINT chk_tbl_personas_email
    CHECK (per_email IS NULL OR position('@' in per_email) > 1);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;

CREATE INDEX IF NOT EXISTS ix_tbl_personas_email_normalizado
  ON public.tbl_personas (lower(per_email))
  WHERE per_email IS NOT NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'tbl_usuarios'
      AND column_name = 'usu_email'
  ) THEN
    EXECUTE $migrar_usu_email$
      UPDATE public.tbl_personas persona
      SET per_email = lower(usuario.usu_email)
      FROM public.tbl_usuarios usuario
      WHERE usuario.persona_id = persona.id_per
        AND persona.per_email IS NULL
        AND usuario.usu_email IS NOT NULL
    $migrar_usu_email$;
  END IF;
END;
$$;

DROP INDEX IF EXISTS public.ux_tbl_usuarios_email_normalizado;

ALTER TABLE public.tbl_usuarios
  DROP CONSTRAINT IF EXISTS chk_tbl_usuarios_email,
  DROP COLUMN IF EXISTS usu_email;
