CREATE OR REPLACE VIEW vista_presupuesto_actual AS
WITH caja_recaudo AS (
  SELECT DISTINCT ON (cm.responsable_usuario_id, cm.moneda_codigo)
    cm.caja_menor_id,
    cm.responsable_usuario_id,
    cm.moneda_codigo
  FROM caja_menor cm
  WHERE cm.activa = TRUE
  ORDER BY
    cm.responsable_usuario_id,
    cm.moneda_codigo,
    cm.creada_en ASC,
    cm.caja_menor_id ASC
)
SELECT
  cm.caja_menor_id,
  cm.responsable_usuario_id,
  cm.moneda_codigo,
  vscm.saldo_caja_menor AS caja_menor,
  CASE
    WHEN cr.caja_menor_id = cm.caja_menor_id THEN COALESCE(pagos.total_recaudado, 0)
    ELSE 0
  END AS recaudado,
  COALESCE(gastos.total_gastos, 0) AS gastos,
  COALESCE(desembolsos.total_creditos, 0) AS creditos,
  (
    vscm.saldo_caja_menor
    + CASE
        WHEN cr.caja_menor_id = cm.caja_menor_id THEN COALESCE(pagos.total_recaudado, 0)
        ELSE 0
      END
    - COALESCE(gastos.total_gastos, 0)
  ) AS presupuesto
FROM caja_menor cm
JOIN vista_saldo_caja_menor vscm
  ON vscm.caja_menor_id = cm.caja_menor_id
LEFT JOIN caja_recaudo cr
  ON cr.responsable_usuario_id = cm.responsable_usuario_id
 AND cr.moneda_codigo = cm.moneda_codigo
LEFT JOIN LATERAL (
  SELECT SUM(p.total_pagado) AS total_recaudado
  FROM pago p
  JOIN ruta r ON r.ruta_id = p.ruta_id
  WHERE r.responsable_usuario_id = cm.responsable_usuario_id
    AND p.moneda_codigo = cm.moneda_codigo
) pagos ON TRUE
LEFT JOIN LATERAL (
  SELECT SUM(g.monto) AS total_gastos
  FROM gasto g
  WHERE g.caja_menor_id = cm.caja_menor_id
    AND g.moneda_codigo = cm.moneda_codigo
) gastos ON TRUE
LEFT JOIN LATERAL (
  SELECT SUM(cd.monto) AS total_creditos
  FROM credito_desembolso cd
  JOIN caja_menor_movimiento cmm
    ON cmm.caja_menor_movimiento_id = cd.caja_menor_movimiento_id
  JOIN credito c ON c.credito_id = cd.credito_id
  JOIN ruta r ON r.ruta_id = c.ruta_id
  WHERE r.responsable_usuario_id = cm.responsable_usuario_id
    AND c.moneda_codigo = cm.moneda_codigo
    AND cmm.caja_menor_id = cm.caja_menor_id
) desembolsos ON TRUE;

COMMENT ON VIEW vista_presupuesto_actual IS
  'Calcula PRESUPUESTO = CAJA MENOR + RECAUDADO - GASTOS sin duplicar recaudos por caja ni volver a restar creditos ya reflejados en caja menor.';
