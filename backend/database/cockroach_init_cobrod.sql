-- Script inicial para probar CobroD en CockroachDB.
--
-- Uso recomendado:
-- 1. Crear una base vacia en CockroachDB.
-- 2. Conectarse a esa base.
-- 3. Ejecutar este archivo completo.
--
-- Este archivo es intencionalmente separado del script de Supabase. Esta
-- pensado para una base vacia de POC, no para actualizar una base existente.
-- Evita bloques PL/pgSQL de compatibilidad con Supabase/PostgreSQL y usa
-- unique_rowid() para llaves numericas distribuidas.

CREATE SCHEMA IF NOT EXISTS public;

CREATE TABLE IF NOT EXISTS public._prisma_migrations (
  id VARCHAR(36) PRIMARY KEY,
  checksum VARCHAR(64) NOT NULL,
  finished_at TIMESTAMPTZ,
  migration_name VARCHAR(255) NOT NULL,
  logs STRING,
  rolled_back_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  applied_steps_count INT8 NOT NULL DEFAULT 0
);

CREATE TYPE IF NOT EXISTS rol_tipo_enum AS ENUM (
  'SUPER_ADMIN',
  'ADMINISTRADOR',
  'COBRADOR',
  'AUDITOR'
);

CREATE TYPE IF NOT EXISTS recurso_interface_enum AS ENUM (
  'WEB',
  'MOBILE',
  'API',
  'BACKOFFICE'
);

CREATE TYPE IF NOT EXISTS producto_credito_frecuencia_enum AS ENUM (
  'DIARIO',
  'SEMANAL',
  'QUINCENAL',
  'MENSUAL'
);

CREATE TYPE IF NOT EXISTS caja_tipo_enum AS ENUM (
  'PRINCIPAL',
  'MENOR',
  'RECAUDO',
  'OPERATIVA'
);

CREATE TYPE IF NOT EXISTS sesion_caja_estado_enum AS ENUM (
  'ABIERTA',
  'CERRADA',
  'ANULADA'
);

CREATE TYPE IF NOT EXISTS movimiento_caja_tipo_enum AS ENUM (
  'APERTURA',
  'RECAUDO',
  'GASTO',
  'DESEMBOLSO_CREDITO',
  'AJUSTE_ENTRADA',
  'AJUSTE_SALIDA',
  'CIERRE'
);

CREATE TYPE IF NOT EXISTS movimiento_referencia_tipo_enum AS ENUM (
  'CREDITO',
  'PAGO',
  'GASTO',
  'SESION_CAJA',
  'AJUSTE'
);

CREATE TYPE IF NOT EXISTS credito_estado_enum AS ENUM (
  'CONFIGURADO',
  'ACTIVO',
  'PAGADO',
  'VENCIDO',
  'ANULADO'
);

CREATE TYPE IF NOT EXISTS cuota_estado_enum AS ENUM (
  'PENDIENTE',
  'PAGADA',
  'VENCIDA',
  'ANULADA'
);

CREATE TYPE IF NOT EXISTS pago_estado_enum AS ENUM (
  'REGISTRADO',
  'CONFIRMADO',
  'ANULADO'
);

CREATE TYPE IF NOT EXISTS medio_pago_tipo_enum AS ENUM (
  'EFECTIVO',
  'TRANSFERENCIA',
  'TARJETA',
  'BILLETERA',
  'OTRO'
);

CREATE TYPE IF NOT EXISTS wompi_tipo_pago_enum AS ENUM (
  'ORGANIZACION_PLAN',
  'ORGANIZACION_RENOVACION',
  'CLIENTE_CREDITO'
);

CREATE TYPE IF NOT EXISTS wompi_estado_enum AS ENUM (
  'PENDIENTE',
  'APROBADA',
  'RECHAZADA',
  'EXPIRADA',
  'ANULADA'
);

CREATE TYPE IF NOT EXISTS notificacion_tipo_enum AS ENUM (
  'CREDITO_APROBADO',
  'PAGO_RECIBIDO',
  'CREDITO_FINALIZADO'
);

CREATE TYPE IF NOT EXISTS notificacion_canal_enum AS ENUM (
  'CORREO',
  'WHATSAPP'
);

CREATE TYPE IF NOT EXISTS notificacion_estado_enum AS ENUM (
  'PENDIENTE',
  'ENVIADA',
  'FALLIDA'
);

CREATE TABLE IF NOT EXISTS tbl_personas (
  id_per INT8 PRIMARY KEY DEFAULT unique_rowid(),
  per_primer_nombre VARCHAR(120) NOT NULL,
  per_apellido VARCHAR(120) NOT NULL,
  per_documento VARCHAR(60) NOT NULL,
  per_direccion VARCHAR(220),
  per_num_celular VARCHAR(40),
  per_email VARCHAR(180),
  per_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  per_latitud DECIMAL(10, 7),
  per_longitud DECIMAL(10, 7),
  CONSTRAINT ux_tbl_personas_documento UNIQUE (per_documento),
  CONSTRAINT chk_tbl_personas_documento
    CHECK (length(trim(per_documento)) > 0),
  CONSTRAINT chk_tbl_personas_email
    CHECK (per_email IS NULL OR position('@' IN per_email) > 1)
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_tbl_personas_email_normalizado
  ON tbl_personas (lower(per_email))
  WHERE per_email IS NOT NULL;

CREATE TABLE IF NOT EXISTS tbl_usuarios (
  id_usu INT8 PRIMARY KEY DEFAULT unique_rowid(),
  usu_usuario VARCHAR(80) NOT NULL,
  usu_password VARCHAR(255) NOT NULL,
  usu_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  usu_activo BOOL NOT NULL DEFAULT true,
  persona_id INT8 NOT NULL REFERENCES tbl_personas (id_per) ON DELETE RESTRICT,
  CONSTRAINT ux_tbl_usuarios_usuario UNIQUE (usu_usuario),
  CONSTRAINT ux_tbl_usuarios_persona UNIQUE (persona_id)
);

CREATE TABLE IF NOT EXISTS tbl_roles (
  id_rol INT8 PRIMARY KEY DEFAULT unique_rowid(),
  rol_tip rol_tipo_enum NOT NULL,
  rol_nivel INT8 NOT NULL,
  rol_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ux_tbl_roles_tipo UNIQUE (rol_tip),
  CONSTRAINT chk_tbl_roles_nivel CHECK (rol_nivel > 0)
);

CREATE TABLE IF NOT EXISTS tbl_recursos (
  id_rec INT8 PRIMARY KEY DEFAULT unique_rowid(),
  nom VARCHAR(120) NOT NULL,
  rec_icono VARCHAR(80),
  rec_orden INT8 NOT NULL DEFAULT 0,
  rec_interface recurso_interface_enum NOT NULL DEFAULT 'WEB',
  CONSTRAINT ux_tbl_recursos_interface_nombre UNIQUE (rec_interface, nom),
  CONSTRAINT chk_tbl_recursos_orden CHECK (rec_orden >= 0)
);

CREATE TABLE IF NOT EXISTS tbl_roles_recursos (
  id_ror INT8 PRIMARY KEY DEFAULT unique_rowid(),
  rec_id INT8 NOT NULL REFERENCES tbl_recursos (id_rec) ON DELETE CASCADE,
  rol_id INT8 NOT NULL REFERENCES tbl_roles (id_rol) ON DELETE CASCADE,
  CONSTRAINT ux_tbl_roles_recursos UNIQUE (rec_id, rol_id)
);

CREATE TABLE IF NOT EXISTS tbl_organizaciones (
  id_org INT8 PRIMARY KEY DEFAULT unique_rowid(),
  org_nombre VARCHAR(160) NOT NULL,
  org_telefono VARCHAR(40),
  org_email VARCHAR(180),
  org_activo BOOL NOT NULL DEFAULT true,
  org_monto_plan DECIMAL(14, 2) NOT NULL DEFAULT 0,
  org_moneda_plan CHAR(3) NOT NULL DEFAULT 'COP',
  org_acceso_hasta DATE,
  org_suspendida_en TIMESTAMPTZ,
  org_motivo_suspension VARCHAR(220),
  org_es_sistema BOOL NOT NULL DEFAULT false,
  org_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ux_tbl_organizaciones_nombre UNIQUE (org_nombre),
  CONSTRAINT chk_tbl_organizaciones_email
    CHECK (org_email IS NULL OR position('@' IN org_email) > 1),
  CONSTRAINT chk_tbl_organizaciones_monto_plan CHECK (org_monto_plan >= 0),
  CONSTRAINT chk_tbl_organizaciones_moneda_plan
    CHECK (org_moneda_plan = upper(org_moneda_plan))
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_organizaciones_email_normalizado
  ON tbl_organizaciones (lower(org_email))
  WHERE org_email IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_tbl_organizaciones_acceso
  ON tbl_organizaciones (org_activo, org_acceso_hasta)
  WHERE NOT org_es_sistema;

CREATE TABLE IF NOT EXISTS tbl_usuarios_organizaciones (
  id_urg INT8 PRIMARY KEY DEFAULT unique_rowid(),
  urg_activo BOOL NOT NULL DEFAULT true,
  rol_id INT8 NOT NULL REFERENCES tbl_roles (id_rol) ON DELETE RESTRICT,
  usu_id INT8 NOT NULL REFERENCES tbl_usuarios (id_usu) ON DELETE CASCADE,
  org_id INT8 NOT NULL REFERENCES tbl_organizaciones (id_org) ON DELETE CASCADE,
  CONSTRAINT ux_tbl_usuarios_organizaciones UNIQUE (usu_id, org_id, rol_id)
);

CREATE TABLE IF NOT EXISTS tbl_clientes (
  id_cli INT8 PRIMARY KEY DEFAULT unique_rowid(),
  cli_referencia VARCHAR(120),
  cli_activo BOOL NOT NULL DEFAULT true,
  cli_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  org_id INT8 NOT NULL REFERENCES tbl_organizaciones (id_org) ON DELETE CASCADE,
  cli_persona INT8 NOT NULL REFERENCES tbl_personas (id_per) ON DELETE RESTRICT,
  CONSTRAINT ux_tbl_clientes_org_persona UNIQUE (org_id, cli_persona),
  CONSTRAINT ux_tbl_clientes_org_referencia UNIQUE (org_id, cli_referencia)
);

CREATE TABLE IF NOT EXISTS tbl_rutas (
  id_rut INT8 PRIMARY KEY DEFAULT unique_rowid(),
  rut_nombre VARCHAR(120) NOT NULL,
  rut_descripcion VARCHAR(500),
  rut_activa BOOL NOT NULL DEFAULT true,
  rut_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  usu_id INT8 NOT NULL REFERENCES tbl_usuarios (id_usu) ON DELETE RESTRICT,
  org_id INT8 NOT NULL REFERENCES tbl_organizaciones (id_org) ON DELETE CASCADE,
  CONSTRAINT ux_tbl_rutas_org_nombre UNIQUE (org_id, rut_nombre)
);

CREATE INDEX IF NOT EXISTS ix_tbl_rutas_usuario
  ON tbl_rutas (usu_id);

CREATE TABLE IF NOT EXISTS tbl_rutas_clientes (
  id_rcl INT8 PRIMARY KEY DEFAULT unique_rowid(),
  rcl_activo BOOL NOT NULL DEFAULT true,
  rcl_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  rut_id INT8 NOT NULL REFERENCES tbl_rutas (id_rut) ON DELETE CASCADE,
  cli_id INT8 NOT NULL REFERENCES tbl_clientes (id_cli) ON DELETE CASCADE,
  CONSTRAINT ux_tbl_rutas_clientes UNIQUE (rut_id, cli_id)
);

CREATE INDEX IF NOT EXISTS ix_tbl_rutas_clientes_cliente
  ON tbl_rutas_clientes (cli_id);

CREATE TABLE IF NOT EXISTS tbl_productos_creditos (
  id_pcr INT8 PRIMARY KEY DEFAULT unique_rowid(),
  pcr_nombre VARCHAR(120) NOT NULL,
  pcr_frecuencia producto_credito_frecuencia_enum NOT NULL,
  pcr_tasa_interes DECIMAL(7, 4) NOT NULL,
  CONSTRAINT ux_tbl_productos_creditos_nombre UNIQUE (pcr_nombre),
  CONSTRAINT chk_tbl_productos_creditos_tasa CHECK (pcr_tasa_interes >= 0)
);

CREATE TABLE IF NOT EXISTS tbl_categorias_gastos (
  id_cga INT8 PRIMARY KEY DEFAULT unique_rowid(),
  cga_nombre VARCHAR(120) NOT NULL,
  cga_descripcion VARCHAR(500),
  CONSTRAINT ux_tbl_categorias_gastos_nombre UNIQUE (cga_nombre)
);

CREATE TABLE IF NOT EXISTS tbl_monedas (
  id_mon INT8 PRIMARY KEY DEFAULT unique_rowid(),
  mon_codigo CHAR(3) NOT NULL,
  mon_nombre VARCHAR(80) NOT NULL,
  mon_simbolo VARCHAR(8) NOT NULL,
  mon_decimales INT8 NOT NULL DEFAULT 2,
  mon_activa BOOL NOT NULL DEFAULT true,
  mon_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ux_tbl_monedas_codigo UNIQUE (mon_codigo),
  CONSTRAINT chk_tbl_monedas_codigo_mayuscula
    CHECK (mon_codigo = upper(mon_codigo)),
  CONSTRAINT chk_tbl_monedas_decimales CHECK (mon_decimales BETWEEN 0 AND 6)
);

CREATE TABLE IF NOT EXISTS tbl_cajas (
  id_caj INT8 PRIMARY KEY DEFAULT unique_rowid(),
  caj_nombre VARCHAR(120) NOT NULL,
  caj_tipo caja_tipo_enum NOT NULL DEFAULT 'MENOR',
  caj_activa BOOL NOT NULL DEFAULT true,
  caj_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  org_id INT8 NOT NULL REFERENCES tbl_organizaciones (id_org) ON DELETE CASCADE,
  mon_id INT8 NOT NULL REFERENCES tbl_monedas (id_mon) ON DELETE RESTRICT,
  gas_id INT8,
  CONSTRAINT ux_tbl_cajas_org_nombre UNIQUE (org_id, caj_nombre)
);

CREATE TABLE IF NOT EXISTS tbl_gastos (
  id_gas INT8 PRIMARY KEY DEFAULT unique_rowid(),
  gas_fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
  gas_monto DECIMAL(14, 2) NOT NULL,
  caj_id INT8 NOT NULL REFERENCES tbl_cajas (id_caj) ON DELETE RESTRICT,
  usu_id INT8 NOT NULL REFERENCES tbl_usuarios (id_usu) ON DELETE RESTRICT,
  cga_id INT8 NOT NULL REFERENCES tbl_categorias_gastos (id_cga) ON DELETE RESTRICT,
  CONSTRAINT chk_tbl_gastos_monto CHECK (gas_monto > 0)
);

ALTER TABLE tbl_cajas
  ADD CONSTRAINT IF NOT EXISTS fk_tbl_cajas_gasto
  FOREIGN KEY (gas_id) REFERENCES tbl_gastos (id_gas) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS tbl_sesiones_cajas (
  id_sca INT8 PRIMARY KEY DEFAULT unique_rowid(),
  sca_fecha_apertura TIMESTAMPTZ NOT NULL DEFAULT now(),
  sca_fecha_cierre TIMESTAMPTZ,
  sca_monto_inicial DECIMAL(14, 2) NOT NULL DEFAULT 0,
  sca_total_cobrado DECIMAL(14, 2) NOT NULL DEFAULT 0,
  sca_total_gasto DECIMAL(14, 2) NOT NULL DEFAULT 0,
  sca_estado sesion_caja_estado_enum NOT NULL DEFAULT 'ABIERTA',
  caj_id INT8 NOT NULL REFERENCES tbl_cajas (id_caj) ON DELETE RESTRICT,
  usu_id INT8 NOT NULL REFERENCES tbl_usuarios (id_usu) ON DELETE RESTRICT,
  CONSTRAINT chk_tbl_sesiones_cajas_montos
    CHECK (
      sca_monto_inicial >= 0
      AND sca_total_cobrado >= 0
      AND sca_total_gasto >= 0
    ),
  CONSTRAINT chk_tbl_sesiones_cajas_fechas
    CHECK (sca_fecha_cierre IS NULL OR sca_fecha_cierre >= sca_fecha_apertura)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_sesiones_cajas_abierta
  ON tbl_sesiones_cajas (caj_id)
  WHERE sca_estado = 'ABIERTA';

CREATE TABLE IF NOT EXISTS tbl_movimientos_cajas (
  id_mca INT8 PRIMARY KEY DEFAULT unique_rowid(),
  mca_tipo movimiento_caja_tipo_enum NOT NULL,
  mca_monto DECIMAL(14, 2) NOT NULL,
  mca_referencia_id INT8,
  mca_referencia_tipo movimiento_referencia_tipo_enum,
  mca_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  org_id INT8 NOT NULL REFERENCES tbl_organizaciones (id_org) ON DELETE CASCADE,
  usu_id INT8 NOT NULL REFERENCES tbl_usuarios (id_usu) ON DELETE RESTRICT,
  sca_id INT8 REFERENCES tbl_sesiones_cajas (id_sca) ON DELETE SET NULL,
  CONSTRAINT chk_tbl_movimientos_cajas_monto CHECK (mca_monto > 0),
  CONSTRAINT chk_tbl_movimientos_cajas_referencia
    CHECK (
      (mca_referencia_id IS NULL AND mca_referencia_tipo IS NULL)
      OR (mca_referencia_id IS NOT NULL AND mca_referencia_tipo IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS ix_tbl_movimientos_cajas_org_fecha
  ON tbl_movimientos_cajas (org_id, mca_creacion DESC);

CREATE TABLE IF NOT EXISTS tbl_creditos (
  id_cre INT8 PRIMARY KEY DEFAULT unique_rowid(),
  cre_total DECIMAL(14, 2) NOT NULL,
  cre_estado credito_estado_enum NOT NULL DEFAULT 'ACTIVO',
  cre_tasa_interes DECIMAL(7, 4) NOT NULL,
  cre_interes_total DECIMAL(14, 2) NOT NULL,
  cre_total_pagar DECIMAL(14, 2) NOT NULL,
  cre_fecha_inicio DATE NOT NULL,
  cre_fecha_fin DATE NOT NULL,
  usu_id INT8 NOT NULL REFERENCES tbl_usuarios (id_usu) ON DELETE RESTRICT,
  pcr_id INT8 NOT NULL REFERENCES tbl_productos_creditos (id_pcr) ON DELETE RESTRICT,
  cli_id INT8 NOT NULL REFERENCES tbl_clientes (id_cli) ON DELETE RESTRICT,
  mon_id INT8 NOT NULL REFERENCES tbl_monedas (id_mon) ON DELETE RESTRICT,
  CONSTRAINT chk_tbl_creditos_valores
    CHECK (
      cre_total > 0
      AND cre_tasa_interes >= 0
      AND cre_interes_total >= 0
      AND cre_total_pagar >= cre_total
    ),
  CONSTRAINT chk_tbl_creditos_fechas CHECK (cre_fecha_fin >= cre_fecha_inicio)
);

CREATE INDEX IF NOT EXISTS ix_tbl_creditos_cliente_estado
  ON tbl_creditos (cli_id, cre_estado);

CREATE INDEX IF NOT EXISTS ix_tbl_creditos_usuario_estado
  ON tbl_creditos (usu_id, cre_estado);

CREATE TABLE IF NOT EXISTS tbl_cuotas (
  id_cuo INT8 PRIMARY KEY DEFAULT unique_rowid(),
  cuo_numero INT8 NOT NULL,
  cuo_valor DECIMAL(14, 2) NOT NULL,
  cuo_total_pagado DECIMAL(14, 2) NOT NULL DEFAULT 0,
  cuo_estado cuota_estado_enum NOT NULL DEFAULT 'PENDIENTE',
  cuo_fecha_vencimiento DATE NOT NULL,
  cre_id INT8 NOT NULL REFERENCES tbl_creditos (id_cre) ON DELETE CASCADE,
  CONSTRAINT ux_tbl_cuotas_credito_numero UNIQUE (cre_id, cuo_numero),
  CONSTRAINT chk_tbl_cuotas_valores
    CHECK (
      cuo_numero > 0
      AND cuo_valor > 0
      AND cuo_total_pagado >= 0
      AND cuo_total_pagado <= cuo_valor
    )
);

CREATE INDEX IF NOT EXISTS ix_tbl_cuotas_vencimiento_estado
  ON tbl_cuotas (cuo_fecha_vencimiento, cuo_estado);

CREATE TABLE IF NOT EXISTS tbl_medios_pagos (
  id_med INT8 PRIMARY KEY DEFAULT unique_rowid(),
  med_nombre VARCHAR(120) NOT NULL,
  med_tipo medio_pago_tipo_enum NOT NULL,
  med_proveedor VARCHAR(120),
  med_referencia_cuenta VARCHAR(120),
  med_titular VARCHAR(180),
  med_activo BOOL NOT NULL DEFAULT true,
  med_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  med_actualizacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ux_tbl_medios_pagos_med_tipo UNIQUE (med_tipo),
  CONSTRAINT ux_tbl_medios_pagos_nombre UNIQUE (med_nombre)
);

CREATE TABLE IF NOT EXISTS tbl_pagos (
  id_pag INT8 PRIMARY KEY DEFAULT unique_rowid(),
  pag_monto DECIMAL(14, 2) NOT NULL,
  pag_fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
  pag_referencia VARCHAR(120),
  pag_idempotency_llave UUID NOT NULL DEFAULT gen_random_uuid(),
  pag_estado pago_estado_enum NOT NULL DEFAULT 'REGISTRADO',
  med_id INT8 NOT NULL REFERENCES tbl_medios_pagos (id_med) ON DELETE RESTRICT,
  mon_id INT8 NOT NULL REFERENCES tbl_monedas (id_mon) ON DELETE RESTRICT,
  CONSTRAINT ux_tbl_pagos_idempotency UNIQUE (pag_idempotency_llave),
  CONSTRAINT chk_tbl_pagos_monto CHECK (pag_monto > 0)
);

CREATE INDEX IF NOT EXISTS ix_tbl_pagos_fecha
  ON tbl_pagos (pag_fecha DESC);

CREATE TABLE IF NOT EXISTS tbl_cuotas_pagos (
  id_cpa INT8 PRIMARY KEY DEFAULT unique_rowid(),
  cpa_numero INT8,
  cpa_capital DECIMAL(14, 2) NOT NULL DEFAULT 0,
  cpa_interes DECIMAL(14, 2) NOT NULL DEFAULT 0,
  cpa_total DECIMAL(14, 2) AS (cpa_capital + cpa_interes) STORED,
  cuo_id INT8 NOT NULL REFERENCES tbl_cuotas (id_cuo) ON DELETE RESTRICT,
  pagos_id INT8 NOT NULL REFERENCES tbl_pagos (id_pag) ON DELETE CASCADE,
  CONSTRAINT ux_tbl_cuotas_pagos UNIQUE (cuo_id, pagos_id),
  CONSTRAINT chk_tbl_cuotas_pagos_montos
    CHECK (cpa_capital >= 0 AND cpa_interes >= 0 AND cpa_total > 0)
);

CREATE INDEX IF NOT EXISTS ix_tbl_cuotas_pagos_pago
  ON tbl_cuotas_pagos (pagos_id);

CREATE TABLE IF NOT EXISTS tbl_wompi_transacciones (
  id_wtr INT8 PRIMARY KEY DEFAULT unique_rowid(),
  org_id INT8 NOT NULL REFERENCES tbl_organizaciones (id_org) ON DELETE CASCADE,
  pag_id INT8 REFERENCES tbl_pagos (id_pag) ON DELETE SET NULL,
  mon_id INT8 NOT NULL REFERENCES tbl_monedas (id_mon) ON DELETE RESTRICT,
  wtr_tipo_pago wompi_tipo_pago_enum NOT NULL,
  wtr_estado wompi_estado_enum NOT NULL DEFAULT 'PENDIENTE',
  wtr_monto DECIMAL(14, 2) NOT NULL,
  wtr_monto_centavos INT8 NOT NULL,
  wtr_referencia VARCHAR(120) NOT NULL,
  wtr_wompi_transaction_id VARCHAR(120),
  wtr_periodo_inicio DATE,
  wtr_periodo_fin DATE,
  wtr_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ux_tbl_wompi_transacciones_referencia UNIQUE (wtr_referencia),
  CONSTRAINT ux_tbl_wompi_transacciones_transaction
    UNIQUE (wtr_wompi_transaction_id),
  CONSTRAINT ux_tbl_wompi_transacciones_pago UNIQUE (pag_id),
  CONSTRAINT chk_tbl_wompi_transacciones_monto
    CHECK (wtr_monto > 0 AND wtr_monto_centavos > 0),
  CONSTRAINT chk_tbl_wompi_transacciones_periodo
    CHECK (
      wtr_periodo_inicio IS NULL
      OR wtr_periodo_fin IS NULL
      OR wtr_periodo_fin >= wtr_periodo_inicio
    )
);

CREATE INDEX IF NOT EXISTS ix_tbl_wompi_transacciones_org_creacion
  ON tbl_wompi_transacciones (org_id, wtr_creacion DESC);

CREATE INDEX IF NOT EXISTS ix_tbl_wompi_transacciones_estado
  ON tbl_wompi_transacciones (wtr_estado);

CREATE TABLE IF NOT EXISTS tbl_notificaciones (
  id_not INT8 PRIMARY KEY DEFAULT unique_rowid(),
  org_id INT8 NOT NULL REFERENCES tbl_organizaciones (id_org) ON DELETE CASCADE,
  cli_id INT8 NOT NULL REFERENCES tbl_clientes (id_cli) ON DELETE CASCADE,
  cre_id INT8 REFERENCES tbl_creditos (id_cre) ON DELETE CASCADE,
  pag_id INT8 REFERENCES tbl_pagos (id_pag) ON DELETE CASCADE,
  not_tipo notificacion_tipo_enum NOT NULL,
  not_canal notificacion_canal_enum NOT NULL,
  not_estado notificacion_estado_enum NOT NULL DEFAULT 'PENDIENTE',
  not_destinatario VARCHAR(180) NOT NULL,
  not_referencia_externa VARCHAR(255),
  not_error STRING,
  not_creacion TIMESTAMPTZ NOT NULL DEFAULT now(),
  not_envio TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_tbl_notificaciones_org
  ON tbl_notificaciones (org_id);

CREATE INDEX IF NOT EXISTS idx_tbl_notificaciones_cli
  ON tbl_notificaciones (cli_id);

CREATE INDEX IF NOT EXISTS idx_tbl_notificaciones_cre
  ON tbl_notificaciones (cre_id);

CREATE INDEX IF NOT EXISTS idx_tbl_notificaciones_estado
  ON tbl_notificaciones (not_estado);

CREATE OR REPLACE VIEW vista_creditos_saldos AS
SELECT
  cr.id_cre,
  cr.cli_id,
  cr.usu_id,
  cr.cre_estado,
  cr.cre_total,
  cr.cre_interes_total,
  cr.cre_total_pagar,
  COALESCE(SUM(cp.cpa_total), 0) AS total_pagado,
  GREATEST(cr.cre_total_pagar - COALESCE(SUM(cp.cpa_total), 0), 0) AS saldo,
  cr.mon_id,
  m.mon_codigo
FROM tbl_creditos cr
JOIN tbl_monedas m
  ON m.id_mon = cr.mon_id
LEFT JOIN tbl_cuotas cu
  ON cu.cre_id = cr.id_cre
LEFT JOIN tbl_cuotas_pagos cp
  ON cp.cuo_id = cu.id_cuo
GROUP BY
  cr.id_cre,
  cr.cli_id,
  cr.usu_id,
  cr.mon_id,
  m.mon_codigo,
  cr.cre_estado,
  cr.cre_total,
  cr.cre_interes_total,
  cr.cre_total_pagar;

CREATE OR REPLACE VIEW vista_saldo_caja_menor AS
SELECT
  c.id_caj AS caja_menor_id,
  MIN(sc.usu_id) AS responsable_usuario_id,
  c.org_id AS organizacion_id,
  c.mon_id AS moneda_id,
  m.mon_codigo AS moneda_codigo,
  COALESCE(
    SUM(
      CASE
        WHEN mc.mca_tipo IN ('APERTURA', 'RECAUDO', 'AJUSTE_ENTRADA') THEN mc.mca_monto
        WHEN mc.mca_tipo IN ('GASTO', 'DESEMBOLSO_CREDITO', 'AJUSTE_SALIDA') THEN -mc.mca_monto
        ELSE 0
      END
    ),
    0
  ) AS saldo_caja_menor
FROM tbl_cajas c
JOIN tbl_monedas m
  ON m.id_mon = c.mon_id
LEFT JOIN tbl_sesiones_cajas sc
  ON sc.caj_id = c.id_caj
LEFT JOIN tbl_movimientos_cajas mc
  ON mc.sca_id = sc.id_sca
GROUP BY
  c.id_caj,
  c.org_id,
  c.mon_id,
  m.mon_codigo;

CREATE OR REPLACE VIEW vista_presupuesto_actual AS
WITH movimientos_por_caja AS (
  SELECT
    c.id_caj,
    COALESCE(
      SUM(mc.mca_monto) FILTER (
        WHERE mc.mca_tipo IN ('APERTURA', 'RECAUDO', 'AJUSTE_ENTRADA')
      ),
      0
    ) AS recaudado,
    COALESCE(
      SUM(mc.mca_monto) FILTER (WHERE mc.mca_tipo = 'GASTO'),
      0
    ) AS gastos_movimientos,
    COALESCE(
      SUM(mc.mca_monto) FILTER (WHERE mc.mca_tipo = 'DESEMBOLSO_CREDITO'),
      0
    ) AS creditos
  FROM tbl_cajas c
  LEFT JOIN tbl_sesiones_cajas sc
    ON sc.caj_id = c.id_caj
  LEFT JOIN tbl_movimientos_cajas mc
    ON mc.sca_id = sc.id_sca
  GROUP BY c.id_caj
),
gastos_por_caja AS (
  SELECT
    caj_id,
    COALESCE(SUM(gas_monto), 0) AS gastos
  FROM tbl_gastos
  GROUP BY caj_id
)
SELECT
  v.caja_menor_id,
  v.responsable_usuario_id,
  v.organizacion_id,
  v.moneda_id,
  v.moneda_codigo,
  v.saldo_caja_menor AS caja_menor,
  COALESCE(mpc.recaudado, 0) AS recaudado,
  COALESCE(gpc.gastos, 0) + COALESCE(mpc.gastos_movimientos, 0) AS gastos,
  COALESCE(mpc.creditos, 0) AS creditos,
  v.saldo_caja_menor
    + COALESCE(mpc.recaudado, 0)
    - COALESCE(gpc.gastos, 0)
    - COALESCE(mpc.gastos_movimientos, 0)
    - COALESCE(mpc.creditos, 0) AS presupuesto
FROM vista_saldo_caja_menor v
LEFT JOIN movimientos_por_caja mpc
  ON mpc.id_caj = v.caja_menor_id
LEFT JOIN gastos_por_caja gpc
  ON gpc.caj_id = v.caja_menor_id;

INSERT INTO tbl_monedas (mon_codigo, mon_nombre, mon_simbolo, mon_decimales)
VALUES
  ('COP', 'Peso colombiano', '$', 2),
  ('USD', 'Dolar estadounidense', '$', 2)
ON CONFLICT (mon_codigo) DO NOTHING;

INSERT INTO tbl_roles (id_rol, rol_tip, rol_nivel)
VALUES
  (1, 'ADMINISTRADOR'::rol_tipo_enum, 1),
  (2, 'COBRADOR'::rol_tipo_enum, 2),
  (3, 'AUDITOR'::rol_tipo_enum, 3),
  (4, 'SUPER_ADMIN'::rol_tipo_enum, 4)
ON CONFLICT (rol_tip) DO UPDATE
SET rol_nivel = excluded.rol_nivel;

INSERT INTO tbl_recursos (nom, rec_orden, rec_interface)
VALUES
  ('VER_EMPLEADOS', 10, 'WEB'),
  ('CREAR_CAJA_MENOR', 20, 'WEB'),
  ('REGISTRAR_FLUJO_CAJA', 30, 'WEB'),
  ('CREAR_CREDITOS', 40, 'WEB'),
  ('REFINANCIAR_CREDITOS', 50, 'WEB'),
  ('MODIFICAR_CREDITOS', 60, 'WEB'),
  ('ELIMINAR_CREDITOS', 70, 'WEB'),
  ('AGREGAR_CUOTA', 80, 'WEB'),
  ('MODIFICAR_MOVIMIENTOS', 90, 'WEB'),
  ('ELIMINAR_MOVIMIENTOS', 100, 'WEB')
ON CONFLICT (rec_interface, nom) DO UPDATE
SET rec_orden = excluded.rec_orden;

INSERT INTO tbl_roles_recursos (rol_id, rec_id)
SELECT rol.id_rol, recurso.id_rec
FROM tbl_roles rol
JOIN tbl_recursos recurso
  ON recurso.rec_interface = 'WEB'
WHERE rol.rol_tip = 'ADMINISTRADOR'::rol_tipo_enum
  AND recurso.nom IN (
    'VER_EMPLEADOS',
    'CREAR_CAJA_MENOR',
    'REGISTRAR_FLUJO_CAJA',
    'CREAR_CREDITOS',
    'REFINANCIAR_CREDITOS',
    'MODIFICAR_CREDITOS',
    'ELIMINAR_CREDITOS',
    'AGREGAR_CUOTA',
    'MODIFICAR_MOVIMIENTOS',
    'ELIMINAR_MOVIMIENTOS'
  )
ON CONFLICT (rec_id, rol_id) DO NOTHING;

INSERT INTO tbl_roles_recursos (rol_id, rec_id)
SELECT rol.id_rol, recurso.id_rec
FROM tbl_roles rol
JOIN tbl_recursos recurso
  ON recurso.rec_interface = 'WEB'
WHERE rol.rol_tip = 'AUDITOR'::rol_tipo_enum
  AND recurso.nom = 'VER_EMPLEADOS'
ON CONFLICT (rec_id, rol_id) DO NOTHING;

INSERT INTO tbl_roles_recursos (rol_id, rec_id)
SELECT rol.id_rol, recurso.id_rec
FROM tbl_roles rol
JOIN tbl_recursos recurso
  ON recurso.rec_interface = 'WEB'
WHERE rol.rol_tip = 'COBRADOR'::rol_tipo_enum
  AND recurso.nom IN (
    'CREAR_CAJA_MENOR',
    'REGISTRAR_FLUJO_CAJA',
    'CREAR_CREDITOS',
    'REFINANCIAR_CREDITOS',
    'MODIFICAR_CREDITOS',
    'ELIMINAR_CREDITOS',
    'AGREGAR_CUOTA',
    'MODIFICAR_MOVIMIENTOS',
    'ELIMINAR_MOVIMIENTOS'
  )
ON CONFLICT (rec_id, rol_id) DO NOTHING;

-- Estos seeds dependen de que existan organizaciones. Si este script se
-- ejecuta antes de crear la primera organizacion, puede ejecutarse de nuevo
-- despues del bootstrap para poblar productos y medios base.
INSERT INTO tbl_productos_creditos (
  pcr_nombre,
  pcr_frecuencia,
  pcr_tasa_interes
)
SELECT
  producto.nombre,
  producto.frecuencia::producto_credito_frecuencia_enum,
  producto.tasa_interes
FROM (
  VALUES
    ('Credito diario', 'DIARIO', 20.0000),
    ('Credito semanal', 'SEMANAL', 20.0000),
    ('Credito quincenal', 'QUINCENAL', 20.0000),
    ('Credito mensual', 'MENSUAL', 20.0000)
) AS producto(nombre, frecuencia, tasa_interes)
ON CONFLICT (pcr_nombre) DO UPDATE
SET
  pcr_frecuencia = excluded.pcr_frecuencia,
  pcr_tasa_interes = excluded.pcr_tasa_interes;

INSERT INTO tbl_medios_pagos (
  med_nombre,
  med_tipo
)
SELECT
  medio.nombre,
  medio.tipo::medio_pago_tipo_enum
FROM (
  VALUES
    ('Efectivo', 'EFECTIVO'),
    ('Transferencia', 'TRANSFERENCIA'),
    ('Tarjeta', 'TARJETA'),
    ('Billetera', 'BILLETERA'),
    ('Otro', 'OTRO')
) AS medio(nombre, tipo)
ON CONFLICT (med_tipo) DO UPDATE
SET
  med_nombre = excluded.med_nombre,
  med_activo = TRUE;

INSERT INTO tbl_categorias_gastos (cga_nombre, cga_descripcion)
VALUES
  ('TRANSPORTE', 'Gastos de transporte'),
  ('PAPELERIA', 'Papeleria e insumos'),
  ('COMISION', 'Comisiones operativas'),
  ('OTRO', 'Otros gastos')
ON CONFLICT (cga_nombre) DO NOTHING;
