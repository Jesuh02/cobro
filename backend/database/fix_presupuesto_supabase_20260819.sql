BEGIN;

CREATE OR REPLACE VIEW public.vista_presupuesto_actual AS
WITH caja_recaudo AS (
  SELECT DISTINCT ON (cm.responsable_usuario_id, cm.moneda_codigo)
    cm.caja_menor_id,
    cm.responsable_usuario_id,
    cm.moneda_codigo
  FROM public.caja_menor cm
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
FROM public.caja_menor cm
JOIN public.vista_saldo_caja_menor vscm
  ON vscm.caja_menor_id = cm.caja_menor_id
LEFT JOIN caja_recaudo cr
  ON cr.responsable_usuario_id = cm.responsable_usuario_id
 AND cr.moneda_codigo = cm.moneda_codigo
LEFT JOIN LATERAL (
  SELECT SUM(p.total_pagado) AS total_recaudado
  FROM public.pago p
  JOIN public.ruta r ON r.ruta_id = p.ruta_id
  WHERE r.responsable_usuario_id = cm.responsable_usuario_id
    AND p.moneda_codigo = cm.moneda_codigo
) pagos ON TRUE
LEFT JOIN LATERAL (
  SELECT SUM(g.monto) AS total_gastos
  FROM public.gasto g
  WHERE g.caja_menor_id = cm.caja_menor_id
    AND g.moneda_codigo = cm.moneda_codigo
) gastos ON TRUE
LEFT JOIN LATERAL (
  SELECT SUM(cd.monto) AS total_creditos
  FROM public.credito_desembolso cd
  JOIN public.caja_menor_movimiento cmm
    ON cmm.caja_menor_movimiento_id = cd.caja_menor_movimiento_id
  JOIN public.credito c ON c.credito_id = cd.credito_id
  JOIN public.ruta r ON r.ruta_id = c.ruta_id
  WHERE r.responsable_usuario_id = cm.responsable_usuario_id
    AND c.moneda_codigo = cm.moneda_codigo
    AND cmm.caja_menor_id = cm.caja_menor_id
) desembolsos ON TRUE;

COMMENT ON VIEW public.vista_presupuesto_actual IS
  'Calcula PRESUPUESTO = CAJA MENOR + RECAUDADO - GASTOS sin duplicar recaudos por caja ni volver a restar creditos ya reflejados en caja menor.';

WITH clientes_objetivo AS (
  SELECT *
  FROM (
    VALUES
      ('bb1ceb86-4a43-421e-982c-e6c7a5e27088'::uuid, 'jesus', 2),
      ('e51eabe5-fd57-4a66-a56e-6391d8e94744'::uuid, 'carmen', 1)
  ) AS objetivo(cliente_id, nombre, creditos_esperados)
),
resumen_creditos AS (
  SELECT
    o.nombre,
    o.creditos_esperados,
    COUNT(c.credito_id) AS creditos_encontrados,
    COALESCE(SUM(c.valor_principal), 0) AS capital,
    COALESCE(SUM(cpp.valor_total), 0) AS total_a_recaudar
  FROM clientes_objetivo o
  LEFT JOIN public.credito c
    ON c.cliente_id = o.cliente_id
   AND c.valor_principal = 20
  LEFT JOIN public.credito_plan_pago cpp
    ON cpp.credito_id = c.credito_id
  GROUP BY o.nombre, o.creditos_esperados
),
resumen_pagos AS (
  SELECT
    o.nombre,
    COUNT(p.pago_id) AS pagos_encontrados,
    COALESCE(SUM(p.total_pagado), 0) AS recaudado
  FROM clientes_objetivo o
  LEFT JOIN public.pago p
    ON p.cliente_id = o.cliente_id
  GROUP BY o.nombre
)
SELECT
  rc.nombre,
  rc.creditos_esperados,
  rc.creditos_encontrados,
  rc.capital,
  rc.total_a_recaudar,
  rp.pagos_encontrados,
  rp.recaudado
FROM resumen_creditos rc
JOIN resumen_pagos rp
  ON rp.nombre = rc.nombre
ORDER BY rc.nombre;

SELECT
  caja_menor_id,
  responsable_usuario_id,
  moneda_codigo,
  caja_menor,
  recaudado,
  gastos,
  creditos,
  presupuesto
FROM public.vista_presupuesto_actual
WHERE responsable_usuario_id = 'de86884c-5ed9-45c9-9634-ed4a11bb03e0'::uuid
ORDER BY moneda_codigo, caja_menor_id;

COMMIT;
