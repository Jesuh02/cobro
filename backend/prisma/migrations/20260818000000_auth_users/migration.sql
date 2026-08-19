ALTER TABLE public.usuario
  ADD COLUMN IF NOT EXISTS nombre_usuario VARCHAR(60),
  ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);

UPDATE public.usuario
SET nombre_usuario = lower(
  regexp_replace(
    split_part(correo, '@', 1),
    '[^a-zA-Z0-9._-]+',
    '_',
    'g'
  )
) || '_' || substr(usuario_id::text, 1, 8)
WHERE nombre_usuario IS NULL;

UPDATE public.usuario
SET password_hash = 'disabled'
WHERE password_hash IS NULL;

ALTER TABLE public.usuario
  ALTER COLUMN nombre_usuario SET NOT NULL,
  ALTER COLUMN password_hash SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'usuario_nombre_usuario_key'
      AND conrelid = 'public.usuario'::regclass
  ) THEN
    ALTER TABLE public.usuario
      ADD CONSTRAINT usuario_nombre_usuario_key UNIQUE (nombre_usuario);
  END IF;
END;
$$;
