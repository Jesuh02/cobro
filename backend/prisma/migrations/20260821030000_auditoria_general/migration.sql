CREATE TABLE IF NOT EXISTS public.auditoria (
  auditoria_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID REFERENCES public.usuario (usuario_id),
  tabla VARCHAR(80) NOT NULL,
  registro_id VARCHAR(120),
  accion VARCHAR(40) NOT NULL,
  descripcion TEXT NOT NULL,
  valores_anteriores JSONB,
  valores_nuevos JSONB,
  metadata JSONB,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_auditoria_tabla
    CHECK (length(trim(tabla)) > 0),
  CONSTRAINT chk_auditoria_accion
    CHECK (length(trim(accion)) > 0)
);

CREATE INDEX IF NOT EXISTS ix_auditoria_registro_fecha
  ON public.auditoria (tabla, registro_id, creado_en DESC);

CREATE INDEX IF NOT EXISTS ix_auditoria_usuario_fecha
  ON public.auditoria (usuario_id, creado_en DESC);
