CREATE TABLE IF NOT EXISTS caja_menor_movimiento_auditoria (
  caja_menor_movimiento_auditoria_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  caja_menor_id UUID NOT NULL REFERENCES caja_menor (caja_menor_id),
  caja_menor_movimiento_id UUID,
  usuario_id UUID REFERENCES usuario (usuario_id),
  accion VARCHAR(20) NOT NULL,
  detalle TEXT NOT NULL,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_caja_menor_movimiento_auditoria_accion
    CHECK (accion IN ('MODIFICAR', 'ELIMINAR'))
);

CREATE INDEX IF NOT EXISTS ix_caja_menor_movimiento_auditoria_fecha
  ON caja_menor_movimiento_auditoria (caja_menor_id, creado_en DESC);
