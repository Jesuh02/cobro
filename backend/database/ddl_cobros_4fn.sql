-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.tbl_personas (
  id_per bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  per_primer_nombre character varying NOT NULL,
  per_apellido character varying NOT NULL,
  per_documento character varying NOT NULL UNIQUE CHECK (length(TRIM(BOTH FROM per_documento)) > 0),
  per_direccion character varying,
  per_num_celular character varying,
  per_email character varying CHECK (per_email IS NULL OR POSITION(('@'::text) IN (per_email)) > 1),
  per_creacion timestamp with time zone NOT NULL DEFAULT now(),
  per_latitud numeric,
  per_longitud numeric,
  CONSTRAINT tbl_personas_pkey PRIMARY KEY (id_per)
);
CREATE TABLE public.tbl_usuarios (
  id_usu bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  usu_usuario character varying NOT NULL UNIQUE,
  usu_password character varying NOT NULL,
  usu_creacion timestamp with time zone NOT NULL DEFAULT now(),
  usu_activo boolean NOT NULL DEFAULT true,
  persona_id bigint NOT NULL UNIQUE,
  CONSTRAINT tbl_usuarios_pkey PRIMARY KEY (id_usu),
  CONSTRAINT tbl_usuarios_persona_id_fkey FOREIGN KEY (persona_id) REFERENCES public.tbl_personas(id_per)
);
CREATE TABLE public.tbl_roles (
  id_rol bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  rol_tip USER-DEFINED NOT NULL UNIQUE,
  rol_nivel bigint NOT NULL CHECK (rol_nivel > 0),
  rol_creacion timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT tbl_roles_pkey PRIMARY KEY (id_rol)
);
CREATE TABLE public.tbl_recursos (
  id_rec bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  nom character varying NOT NULL,
  rec_icono character varying,
  rec_orden bigint NOT NULL DEFAULT 0 CHECK (rec_orden >= 0),
  rec_interface USER-DEFINED NOT NULL DEFAULT 'WEB'::recurso_interface_enum,
  CONSTRAINT tbl_recursos_pkey PRIMARY KEY (id_rec)
);
CREATE TABLE public.tbl_roles_recursos (
  id_ror bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  rec_id bigint NOT NULL,
  rol_id bigint NOT NULL,
  CONSTRAINT tbl_roles_recursos_pkey PRIMARY KEY (id_ror),
  CONSTRAINT tbl_roles_recursos_rec_id_fkey FOREIGN KEY (rec_id) REFERENCES public.tbl_recursos(id_rec),
  CONSTRAINT tbl_roles_recursos_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.tbl_roles(id_rol)
);
CREATE TABLE public.tbl_organizaciones (
  id_org bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  org_nombre character varying NOT NULL UNIQUE,
  org_telefono character varying,
  org_email character varying CHECK (org_email IS NULL OR POSITION(('@'::text) IN (org_email)) > 1),
  org_activo boolean NOT NULL DEFAULT true,
  org_monto_plan numeric NOT NULL DEFAULT 0 CHECK (org_monto_plan >= 0::numeric),
  org_moneda_plan character(3) NOT NULL DEFAULT 'COP'::bpchar CHECK (org_moneda_plan::text = upper(org_moneda_plan::text)),
  org_acceso_hasta date,
  org_suspendida_en timestamp with time zone,
  org_motivo_suspension character varying,
  org_es_sistema boolean NOT NULL DEFAULT false,
  org_creacion timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT tbl_organizaciones_pkey PRIMARY KEY (id_org)
);
CREATE TABLE public.tbl_usuarios_organizaciones (
  id_urg bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  urg_activo boolean NOT NULL DEFAULT true,
  rol_id bigint NOT NULL,
  usu_id bigint NOT NULL,
  org_id bigint NOT NULL,
  CONSTRAINT tbl_usuarios_organizaciones_pkey PRIMARY KEY (id_urg),
  CONSTRAINT tbl_usuarios_organizaciones_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.tbl_roles(id_rol),
  CONSTRAINT tbl_usuarios_organizaciones_usu_id_fkey FOREIGN KEY (usu_id) REFERENCES public.tbl_usuarios(id_usu),
  CONSTRAINT tbl_usuarios_organizaciones_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.tbl_organizaciones(id_org)
);
CREATE TABLE public.tbl_clientes (
  id_cli bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  cli_referencia character varying,
  cli_activo boolean NOT NULL DEFAULT true,
  cli_creacion timestamp with time zone NOT NULL DEFAULT now(),
  org_id bigint NOT NULL,
  cli_persona bigint NOT NULL,
  CONSTRAINT tbl_clientes_pkey PRIMARY KEY (id_cli),
  CONSTRAINT tbl_clientes_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.tbl_organizaciones(id_org),
  CONSTRAINT tbl_clientes_cli_persona_fkey FOREIGN KEY (cli_persona) REFERENCES public.tbl_personas(id_per)
);
CREATE TABLE public.tbl_rutas (
  id_rut bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  rut_nombre character varying NOT NULL,
  rut_descripcion character varying,
  rut_activa boolean NOT NULL DEFAULT true,
  rut_creacion timestamp with time zone NOT NULL DEFAULT now(),
  usu_id bigint NOT NULL,
  org_id bigint NOT NULL,
  CONSTRAINT tbl_rutas_pkey PRIMARY KEY (id_rut),
  CONSTRAINT tbl_rutas_usu_id_fkey FOREIGN KEY (usu_id) REFERENCES public.tbl_usuarios(id_usu),
  CONSTRAINT tbl_rutas_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.tbl_organizaciones(id_org)
);
CREATE TABLE public.tbl_rutas_clientes (
  id_rcl bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  rcl_activo boolean NOT NULL DEFAULT true,
  rcl_creacion timestamp with time zone NOT NULL DEFAULT now(),
  rut_id bigint NOT NULL,
  cli_id bigint NOT NULL,
  CONSTRAINT tbl_rutas_clientes_pkey PRIMARY KEY (id_rcl),
  CONSTRAINT tbl_rutas_clientes_rut_id_fkey FOREIGN KEY (rut_id) REFERENCES public.tbl_rutas(id_rut),
  CONSTRAINT tbl_rutas_clientes_cli_id_fkey FOREIGN KEY (cli_id) REFERENCES public.tbl_clientes(id_cli)
);
CREATE TABLE public.tbl_productos_creditos (
  id_pcr bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  pcr_nombre character varying NOT NULL,
  pcr_frecuencia USER-DEFINED NOT NULL,
  pcr_tasa_interes numeric NOT NULL CHECK (pcr_tasa_interes >= 0::numeric),
  org_id bigint NOT NULL,
  CONSTRAINT tbl_productos_creditos_pkey PRIMARY KEY (id_pcr),
  CONSTRAINT tbl_productos_creditos_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.tbl_organizaciones(id_org)
);
CREATE TABLE public.tbl_categorias_gastos (
  id_cga bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  cga_nombre character varying NOT NULL UNIQUE,
  cga_descripcion character varying,
  CONSTRAINT tbl_categorias_gastos_pkey PRIMARY KEY (id_cga)
);
CREATE TABLE public.tbl_cajas (
  id_caj bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  caj_nombre character varying NOT NULL,
  caj_tipo USER-DEFINED NOT NULL DEFAULT 'MENOR'::caja_tipo_enum,
  caj_activa boolean NOT NULL DEFAULT true,
  caj_creacion timestamp with time zone NOT NULL DEFAULT now(),
  org_id bigint NOT NULL,
  gas_id bigint,
  mon_id bigint NOT NULL,
  CONSTRAINT tbl_cajas_pkey PRIMARY KEY (id_caj),
  CONSTRAINT fk_tbl_cajas_moneda FOREIGN KEY (mon_id) REFERENCES public.tbl_monedas(id_mon),
  CONSTRAINT tbl_cajas_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.tbl_organizaciones(id_org),
  CONSTRAINT fk_tbl_cajas_gasto FOREIGN KEY (gas_id) REFERENCES public.tbl_gastos(id_gas)
);
CREATE TABLE public.tbl_gastos (
  id_gas bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  gas_fecha timestamp with time zone NOT NULL DEFAULT now(),
  gas_monto numeric NOT NULL CHECK (gas_monto > 0::numeric),
  caj_id bigint NOT NULL,
  usu_id bigint NOT NULL,
  cga_id bigint NOT NULL,
  CONSTRAINT tbl_gastos_pkey PRIMARY KEY (id_gas),
  CONSTRAINT tbl_gastos_caj_id_fkey FOREIGN KEY (caj_id) REFERENCES public.tbl_cajas(id_caj),
  CONSTRAINT tbl_gastos_usu_id_fkey FOREIGN KEY (usu_id) REFERENCES public.tbl_usuarios(id_usu),
  CONSTRAINT tbl_gastos_cga_id_fkey FOREIGN KEY (cga_id) REFERENCES public.tbl_categorias_gastos(id_cga)
);
CREATE TABLE public.tbl_sesiones_cajas (
  id_sca bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  sca_fecha_apertura timestamp with time zone NOT NULL DEFAULT now(),
  sca_fecha_cierre timestamp with time zone,
  sca_monto_inicial numeric NOT NULL DEFAULT 0,
  sca_total_cobrado numeric NOT NULL DEFAULT 0,
  sca_total_gasto numeric NOT NULL DEFAULT 0,
  sca_estado USER-DEFINED NOT NULL DEFAULT 'ABIERTA'::sesion_caja_estado_enum,
  caj_id bigint NOT NULL,
  usu_id bigint NOT NULL,
  CONSTRAINT tbl_sesiones_cajas_pkey PRIMARY KEY (id_sca),
  CONSTRAINT tbl_sesiones_cajas_caj_id_fkey FOREIGN KEY (caj_id) REFERENCES public.tbl_cajas(id_caj),
  CONSTRAINT tbl_sesiones_cajas_usu_id_fkey FOREIGN KEY (usu_id) REFERENCES public.tbl_usuarios(id_usu)
);
CREATE TABLE public.tbl_movimientos_cajas (
  id_mca bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  mca_tipo USER-DEFINED NOT NULL,
  mca_monto numeric NOT NULL CHECK (mca_monto > 0::numeric),
  mca_referencia_id bigint,
  mca_referencia_tipo USER-DEFINED,
  mca_creacion timestamp with time zone NOT NULL DEFAULT now(),
  org_id bigint NOT NULL,
  usu_id bigint NOT NULL,
  sca_id bigint,
  CONSTRAINT tbl_movimientos_cajas_pkey PRIMARY KEY (id_mca),
  CONSTRAINT tbl_movimientos_cajas_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.tbl_organizaciones(id_org),
  CONSTRAINT tbl_movimientos_cajas_usu_id_fkey FOREIGN KEY (usu_id) REFERENCES public.tbl_usuarios(id_usu),
  CONSTRAINT tbl_movimientos_cajas_sca_id_fkey FOREIGN KEY (sca_id) REFERENCES public.tbl_sesiones_cajas(id_sca)
);
CREATE TABLE public.tbl_creditos (
  id_cre bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  cre_total numeric NOT NULL,
  cre_estado USER-DEFINED NOT NULL DEFAULT 'ACTIVO'::credito_estado_enum,
  cre_tasa_interes numeric NOT NULL,
  cre_interes_total numeric NOT NULL,
  cre_total_pagar numeric NOT NULL,
  cre_fecha_inicio date NOT NULL,
  cre_fecha_fin date NOT NULL,
  cre_refinanciado_en timestamp with time zone,
  cre_valor_principal_anterior numeric,
  cre_valor_principal_refinanciado numeric,
  usu_id bigint NOT NULL,
  pcr_id bigint NOT NULL,
  cli_id bigint NOT NULL,
  mon_id bigint NOT NULL,
  CONSTRAINT tbl_creditos_pkey PRIMARY KEY (id_cre),
  CONSTRAINT fk_tbl_creditos_moneda FOREIGN KEY (mon_id) REFERENCES public.tbl_monedas(id_mon),
  CONSTRAINT tbl_creditos_usu_id_fkey FOREIGN KEY (usu_id) REFERENCES public.tbl_usuarios(id_usu),
  CONSTRAINT tbl_creditos_pcr_id_fkey FOREIGN KEY (pcr_id) REFERENCES public.tbl_productos_creditos(id_pcr),
  CONSTRAINT tbl_creditos_cli_id_fkey FOREIGN KEY (cli_id) REFERENCES public.tbl_clientes(id_cli)
);
CREATE TABLE public.tbl_cuotas (
  id_cuo bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  cuo_numero bigint NOT NULL,
  cuo_valor numeric NOT NULL,
  cuo_total_pagado numeric NOT NULL DEFAULT 0,
  cuo_estado USER-DEFINED NOT NULL DEFAULT 'PENDIENTE'::cuota_estado_enum,
  cuo_fecha_vencimiento date NOT NULL,
  cre_id bigint NOT NULL,
  CONSTRAINT tbl_cuotas_pkey PRIMARY KEY (id_cuo),
  CONSTRAINT tbl_cuotas_cre_id_fkey FOREIGN KEY (cre_id) REFERENCES public.tbl_creditos(id_cre)
);
CREATE TABLE public.tbl_medios_pagos (
  id_med bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  med_nombre character varying NOT NULL,
  med_tipo USER-DEFINED NOT NULL,
  med_proveedor character varying,
  med_referencia_cuenta character varying,
  med_titular character varying,
  med_activo boolean NOT NULL DEFAULT true,
  med_creacion timestamp with time zone NOT NULL DEFAULT now(),
  med_actualizacion timestamp with time zone NOT NULL DEFAULT now(),
  org_id bigint NOT NULL,
  CONSTRAINT tbl_medios_pagos_pkey PRIMARY KEY (id_med),
  CONSTRAINT tbl_medios_pagos_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.tbl_organizaciones(id_org)
);
CREATE TABLE public.tbl_pagos (
  id_pag bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  pag_monto numeric NOT NULL CHECK (pag_monto > 0::numeric),
  pag_fecha timestamp with time zone NOT NULL DEFAULT now(),
  pag_referencia character varying,
  pag_idempotency_llave uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  pag_estado USER-DEFINED NOT NULL DEFAULT 'REGISTRADO'::pago_estado_enum,
  med_id bigint NOT NULL,
  cre_id bigint NOT NULL,
  mon_id bigint NOT NULL,
  CONSTRAINT tbl_pagos_pkey PRIMARY KEY (id_pag),
  CONSTRAINT fk_tbl_pagos_moneda FOREIGN KEY (mon_id) REFERENCES public.tbl_monedas(id_mon),
  CONSTRAINT tbl_pagos_med_id_fkey FOREIGN KEY (med_id) REFERENCES public.tbl_medios_pagos(id_med),
  CONSTRAINT tbl_pagos_cre_id_fkey FOREIGN KEY (cre_id) REFERENCES public.tbl_creditos(id_cre)
);
CREATE TABLE public.tbl_cuotas_pagos (
  id_cpa bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  cpa_numero bigint,
  cpa_capital numeric NOT NULL DEFAULT 0,
  cpa_interes numeric NOT NULL DEFAULT 0,
  cpa_total numeric DEFAULT (cpa_capital + cpa_interes),
  cuo_id bigint NOT NULL,
  pagos_id bigint NOT NULL,
  CONSTRAINT tbl_cuotas_pagos_pkey PRIMARY KEY (id_cpa),
  CONSTRAINT tbl_cuotas_pagos_cuo_id_fkey FOREIGN KEY (cuo_id) REFERENCES public.tbl_cuotas(id_cuo),
  CONSTRAINT tbl_cuotas_pagos_pagos_id_fkey FOREIGN KEY (pagos_id) REFERENCES public.tbl_pagos(id_pag)
);
CREATE TABLE public._prisma_migrations (
  id character varying NOT NULL,
  checksum character varying NOT NULL,
  finished_at timestamp with time zone,
  migration_name character varying NOT NULL,
  logs text,
  rolled_back_at timestamp with time zone,
  started_at timestamp with time zone NOT NULL DEFAULT now(),
  applied_steps_count integer NOT NULL DEFAULT 0,
  CONSTRAINT _prisma_migrations_pkey PRIMARY KEY (id)
);
CREATE TABLE public.tbl_monedas (
  id_mon bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  mon_codigo character NOT NULL UNIQUE CHECK (mon_codigo::text = upper(mon_codigo::text)),
  mon_nombre character varying NOT NULL,
  mon_simbolo character varying NOT NULL,
  mon_decimales bigint NOT NULL DEFAULT 2 CHECK (mon_decimales >= 0 AND mon_decimales <= 6),
  mon_activa boolean NOT NULL DEFAULT true,
  mon_creacion timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT tbl_monedas_pkey PRIMARY KEY (id_mon)
);
