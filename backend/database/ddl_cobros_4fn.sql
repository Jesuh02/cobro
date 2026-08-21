-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.moneda (
  codigo_moneda character NOT NULL CHECK (codigo_moneda::text = upper(codigo_moneda::text)),
  nombre character varying NOT NULL,
  simbolo character varying NOT NULL,
  decimales smallint NOT NULL DEFAULT 2 CHECK (decimales >= 0 AND decimales <= 6),
  CONSTRAINT moneda_pkey PRIMARY KEY (codigo_moneda)
);
CREATE TABLE public.estado_usuario (
  estado_usuario_id smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
  codigo character varying NOT NULL UNIQUE,
  nombre character varying NOT NULL,
  CONSTRAINT estado_usuario_pkey PRIMARY KEY (estado_usuario_id)
);
CREATE TABLE public.rol (
  rol_id smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
  codigo character varying NOT NULL UNIQUE,
  nombre character varying NOT NULL,
  CONSTRAINT rol_pkey PRIMARY KEY (rol_id)
);
CREATE TABLE public.estado_cliente (
  estado_cliente_id smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
  codigo character varying NOT NULL UNIQUE,
  nombre character varying NOT NULL,
  CONSTRAINT estado_cliente_pkey PRIMARY KEY (estado_cliente_id)
);
CREATE TABLE public.tipo_documento (
  tipo_documento_id smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
  codigo character varying NOT NULL UNIQUE,
  nombre character varying NOT NULL,
  CONSTRAINT tipo_documento_pkey PRIMARY KEY (tipo_documento_id)
);
CREATE TABLE public.tipo_contacto (
  tipo_contacto_id smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
  codigo character varying NOT NULL UNIQUE,
  nombre character varying NOT NULL,
  CONSTRAINT tipo_contacto_pkey PRIMARY KEY (tipo_contacto_id)
);
CREATE TABLE public.tipo_direccion (
  tipo_direccion_id smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
  codigo character varying NOT NULL UNIQUE,
  nombre character varying NOT NULL,
  CONSTRAINT tipo_direccion_pkey PRIMARY KEY (tipo_direccion_id)
);
CREATE TABLE public.estado_ruta (
  estado_ruta_id smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
  codigo character varying NOT NULL UNIQUE,
  nombre character varying NOT NULL,
  CONSTRAINT estado_ruta_pkey PRIMARY KEY (estado_ruta_id)
);
CREATE TABLE public.frecuencia_pago (
  frecuencia_pago_id smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
  codigo character varying NOT NULL UNIQUE,
  nombre character varying NOT NULL,
  dias_intervalo smallint NOT NULL CHECK (dias_intervalo > 0),
  CONSTRAINT frecuencia_pago_pkey PRIMARY KEY (frecuencia_pago_id)
);
CREATE TABLE public.estado_credito (
  estado_credito_id smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
  codigo character varying NOT NULL UNIQUE,
  nombre character varying NOT NULL,
  CONSTRAINT estado_credito_pkey PRIMARY KEY (estado_credito_id)
);
CREATE TABLE public.estado_cuota (
  estado_cuota_id smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
  codigo character varying NOT NULL UNIQUE,
  nombre character varying NOT NULL,
  CONSTRAINT estado_cuota_pkey PRIMARY KEY (estado_cuota_id)
);
CREATE TABLE public.medio_pago (
  medio_pago_id smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
  codigo character varying NOT NULL UNIQUE,
  nombre character varying NOT NULL,
  CONSTRAINT medio_pago_pkey PRIMARY KEY (medio_pago_id)
);
CREATE TABLE public.tipo_movimiento_caja (
  tipo_movimiento_caja_id smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
  codigo character varying NOT NULL UNIQUE,
  nombre character varying NOT NULL,
  naturaleza character NOT NULL CHECK (naturaleza = ANY (ARRAY['E'::bpchar, 'S'::bpchar])),
  CONSTRAINT tipo_movimiento_caja_pkey PRIMARY KEY (tipo_movimiento_caja_id)
);
CREATE TABLE public.categoria_gasto (
  categoria_gasto_id smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
  codigo character varying NOT NULL UNIQUE,
  nombre character varying NOT NULL,
  activa boolean NOT NULL DEFAULT true,
  CONSTRAINT categoria_gasto_pkey PRIMARY KEY (categoria_gasto_id)
);
CREATE TABLE public.usuario (
  usuario_id uuid NOT NULL DEFAULT gen_random_uuid(),
  estado_usuario_id smallint NOT NULL,
  nombres character varying NOT NULL,
  apellidos character varying NOT NULL,
  correo character varying NOT NULL CHECK (POSITION(('@'::text) IN (correo)) > 1),
  telefono character varying,
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  actualizado_en timestamp with time zone NOT NULL DEFAULT now(),
  nombre_usuario character varying NOT NULL UNIQUE,
  password_hash character varying NOT NULL,
  CONSTRAINT usuario_pkey PRIMARY KEY (usuario_id),
  CONSTRAINT usuario_estado_usuario_id_fkey FOREIGN KEY (estado_usuario_id) REFERENCES public.estado_usuario(estado_usuario_id)
);
CREATE TABLE public.usuario_rol (
  usuario_id uuid NOT NULL,
  rol_id smallint NOT NULL,
  asignado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT usuario_rol_pkey PRIMARY KEY (usuario_id, rol_id),
  CONSTRAINT usuario_rol_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(usuario_id),
  CONSTRAINT usuario_rol_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.rol(rol_id)
);
CREATE TABLE public.cliente (
  cliente_id uuid NOT NULL DEFAULT gen_random_uuid(),
  estado_cliente_id smallint NOT NULL,
  creado_por_usuario_id uuid,
  nombre_completo character varying NOT NULL,
  nombre_comercial character varying,
  notas text,
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  actualizado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT cliente_pkey PRIMARY KEY (cliente_id),
  CONSTRAINT cliente_estado_cliente_id_fkey FOREIGN KEY (estado_cliente_id) REFERENCES public.estado_cliente(estado_cliente_id),
  CONSTRAINT cliente_creado_por_usuario_id_fkey FOREIGN KEY (creado_por_usuario_id) REFERENCES public.usuario(usuario_id)
);
CREATE TABLE public.cliente_documento (
  cliente_documento_id uuid NOT NULL DEFAULT gen_random_uuid(),
  cliente_id uuid NOT NULL,
  tipo_documento_id smallint NOT NULL,
  numero_documento character varying NOT NULL,
  expedido_en character varying,
  CONSTRAINT cliente_documento_pkey PRIMARY KEY (cliente_documento_id),
  CONSTRAINT cliente_documento_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.cliente(cliente_id),
  CONSTRAINT cliente_documento_tipo_documento_id_fkey FOREIGN KEY (tipo_documento_id) REFERENCES public.tipo_documento(tipo_documento_id)
);
CREATE TABLE public.cliente_contacto (
  cliente_contacto_id uuid NOT NULL DEFAULT gen_random_uuid(),
  cliente_id uuid NOT NULL,
  tipo_contacto_id smallint NOT NULL,
  valor character varying NOT NULL,
  es_principal boolean NOT NULL DEFAULT false,
  verificado_en timestamp with time zone,
  CONSTRAINT cliente_contacto_pkey PRIMARY KEY (cliente_contacto_id),
  CONSTRAINT cliente_contacto_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.cliente(cliente_id),
  CONSTRAINT cliente_contacto_tipo_contacto_id_fkey FOREIGN KEY (tipo_contacto_id) REFERENCES public.tipo_contacto(tipo_contacto_id)
);
CREATE TABLE public.cliente_direccion (
  cliente_direccion_id uuid NOT NULL DEFAULT gen_random_uuid(),
  cliente_id uuid NOT NULL,
  tipo_direccion_id smallint NOT NULL,
  direccion character varying NOT NULL,
  barrio character varying,
  municipio character varying NOT NULL,
  departamento character varying NOT NULL,
  pais character varying NOT NULL DEFAULT 'Colombia'::character varying,
  referencia text,
  latitud numeric,
  longitud numeric,
  es_principal boolean NOT NULL DEFAULT false,
  CONSTRAINT cliente_direccion_pkey PRIMARY KEY (cliente_direccion_id),
  CONSTRAINT cliente_direccion_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.cliente(cliente_id),
  CONSTRAINT cliente_direccion_tipo_direccion_id_fkey FOREIGN KEY (tipo_direccion_id) REFERENCES public.tipo_direccion(tipo_direccion_id)
);
CREATE TABLE public.ruta (
  ruta_id uuid NOT NULL DEFAULT gen_random_uuid(),
  responsable_usuario_id uuid NOT NULL,
  estado_ruta_id smallint NOT NULL,
  nombre character varying NOT NULL,
  descripcion text,
  es_principal boolean NOT NULL DEFAULT false,
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  actualizado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ruta_pkey PRIMARY KEY (ruta_id),
  CONSTRAINT ruta_responsable_usuario_id_fkey FOREIGN KEY (responsable_usuario_id) REFERENCES public.usuario(usuario_id),
  CONSTRAINT ruta_estado_ruta_id_fkey FOREIGN KEY (estado_ruta_id) REFERENCES public.estado_ruta(estado_ruta_id)
);
CREATE TABLE public.ruta_cliente (
  ruta_id uuid NOT NULL,
  cliente_id uuid NOT NULL,
  orden_visita integer NOT NULL CHECK (orden_visita > 0),
  activo boolean NOT NULL DEFAULT true,
  asignado_en date NOT NULL DEFAULT CURRENT_DATE,
  CONSTRAINT ruta_cliente_pkey PRIMARY KEY (ruta_id, cliente_id),
  CONSTRAINT ruta_cliente_ruta_id_fkey FOREIGN KEY (ruta_id) REFERENCES public.ruta(ruta_id),
  CONSTRAINT ruta_cliente_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.cliente(cliente_id)
);
CREATE TABLE public.credito (
  credito_id uuid NOT NULL DEFAULT gen_random_uuid(),
  cliente_id uuid NOT NULL,
  ruta_id uuid NOT NULL,
  moneda_codigo character NOT NULL,
  frecuencia_pago_id smallint NOT NULL,
  estado_credito_id smallint NOT NULL,
  creado_por_usuario_id uuid,
  fecha_inicio date NOT NULL,
  valor_principal numeric NOT NULL CHECK (valor_principal > 0::numeric),
  porcentaje_interes numeric NOT NULL CHECK (porcentaje_interes >= 0::numeric),
  plazo_dias integer NOT NULL CHECK (plazo_dias > 0),
  omitir_domingos boolean NOT NULL DEFAULT true,
  observacion text,
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  actualizado_en timestamp with time zone NOT NULL DEFAULT now(),
  refinanciado_en timestamp with time zone,
  valor_principal_anterior numeric,
  valor_principal_refinanciado numeric,
  CONSTRAINT credito_pkey PRIMARY KEY (credito_id),
  CONSTRAINT credito_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.cliente(cliente_id),
  CONSTRAINT credito_ruta_id_fkey FOREIGN KEY (ruta_id) REFERENCES public.ruta(ruta_id),
  CONSTRAINT credito_moneda_codigo_fkey FOREIGN KEY (moneda_codigo) REFERENCES public.moneda(codigo_moneda),
  CONSTRAINT credito_frecuencia_pago_id_fkey FOREIGN KEY (frecuencia_pago_id) REFERENCES public.frecuencia_pago(frecuencia_pago_id),
  CONSTRAINT credito_estado_credito_id_fkey FOREIGN KEY (estado_credito_id) REFERENCES public.estado_credito(estado_credito_id),
  CONSTRAINT credito_creado_por_usuario_id_fkey FOREIGN KEY (creado_por_usuario_id) REFERENCES public.usuario(usuario_id)
);
CREATE TABLE public.credito_plan_pago (
  credito_plan_pago_id uuid NOT NULL DEFAULT gen_random_uuid(),
  credito_id uuid NOT NULL UNIQUE,
  numero_cuotas integer NOT NULL CHECK (numero_cuotas > 0),
  valor_cuota numeric NOT NULL,
  valor_total numeric NOT NULL,
  fecha_maxima date NOT NULL,
  domingos_omitidos integer NOT NULL DEFAULT 0 CHECK (domingos_omitidos >= 0),
  generado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT credito_plan_pago_pkey PRIMARY KEY (credito_plan_pago_id),
  CONSTRAINT credito_plan_pago_credito_id_fkey FOREIGN KEY (credito_id) REFERENCES public.credito(credito_id)
);
CREATE TABLE public.credito_cuota (
  credito_cuota_id uuid NOT NULL DEFAULT gen_random_uuid(),
  credito_plan_pago_id uuid NOT NULL,
  estado_cuota_id smallint NOT NULL,
  numero_cuota integer NOT NULL CHECK (numero_cuota > 0),
  fecha_vencimiento date NOT NULL,
  valor_capital numeric NOT NULL DEFAULT 0,
  valor_interes numeric NOT NULL DEFAULT 0,
  valor_total numeric DEFAULT (valor_capital + valor_interes),
  CONSTRAINT credito_cuota_pkey PRIMARY KEY (credito_cuota_id),
  CONSTRAINT credito_cuota_credito_plan_pago_id_fkey FOREIGN KEY (credito_plan_pago_id) REFERENCES public.credito_plan_pago(credito_plan_pago_id),
  CONSTRAINT credito_cuota_estado_cuota_id_fkey FOREIGN KEY (estado_cuota_id) REFERENCES public.estado_cuota(estado_cuota_id)
);
CREATE TABLE public.caja_menor (
  caja_menor_id uuid NOT NULL DEFAULT gen_random_uuid(),
  responsable_usuario_id uuid NOT NULL,
  moneda_codigo character NOT NULL,
  nombre character varying NOT NULL,
  activa boolean NOT NULL DEFAULT true,
  creada_en timestamp with time zone NOT NULL DEFAULT now(),
  actualizado_en timestamp with time zone NOT NULL DEFAULT now(),
  fecha_apertura timestamp with time zone NOT NULL DEFAULT now(),
  fecha_cierre timestamp with time zone,
  CONSTRAINT caja_menor_pkey PRIMARY KEY (caja_menor_id),
  CONSTRAINT caja_menor_responsable_usuario_id_fkey FOREIGN KEY (responsable_usuario_id) REFERENCES public.usuario(usuario_id),
  CONSTRAINT caja_menor_moneda_codigo_fkey FOREIGN KEY (moneda_codigo) REFERENCES public.moneda(codigo_moneda)
);
CREATE TABLE public.caja_menor_movimiento (
  caja_menor_movimiento_id uuid NOT NULL DEFAULT gen_random_uuid(),
  caja_menor_id uuid NOT NULL,
  tipo_movimiento_caja_id smallint NOT NULL,
  usuario_id uuid,
  fecha_movimiento date NOT NULL,
  monto numeric NOT NULL CHECK (monto > 0::numeric),
  motivo text NOT NULL,
  referencia_tabla character varying,
  referencia_id uuid,
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT caja_menor_movimiento_pkey PRIMARY KEY (caja_menor_movimiento_id),
  CONSTRAINT caja_menor_movimiento_caja_menor_id_fkey FOREIGN KEY (caja_menor_id) REFERENCES public.caja_menor(caja_menor_id),
  CONSTRAINT caja_menor_movimiento_tipo_movimiento_caja_id_fkey FOREIGN KEY (tipo_movimiento_caja_id) REFERENCES public.tipo_movimiento_caja(tipo_movimiento_caja_id),
  CONSTRAINT caja_menor_movimiento_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(usuario_id)
);
CREATE TABLE public.credito_desembolso (
  credito_desembolso_id uuid NOT NULL DEFAULT gen_random_uuid(),
  credito_id uuid NOT NULL UNIQUE,
  caja_menor_movimiento_id uuid UNIQUE,
  fecha_desembolso date NOT NULL,
  monto numeric NOT NULL CHECK (monto > 0::numeric),
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT credito_desembolso_pkey PRIMARY KEY (credito_desembolso_id),
  CONSTRAINT credito_desembolso_credito_id_fkey FOREIGN KEY (credito_id) REFERENCES public.credito(credito_id),
  CONSTRAINT credito_desembolso_caja_menor_movimiento_id_fkey FOREIGN KEY (caja_menor_movimiento_id) REFERENCES public.caja_menor_movimiento(caja_menor_movimiento_id)
);
CREATE TABLE public.gasto (
  gasto_id uuid NOT NULL DEFAULT gen_random_uuid(),
  caja_menor_id uuid,
  categoria_gasto_id smallint NOT NULL,
  moneda_codigo character NOT NULL,
  registrado_por_usuario_id uuid,
  fecha_gasto date NOT NULL,
  monto numeric NOT NULL CHECK (monto > 0::numeric),
  concepto text NOT NULL,
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  actualizado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT gasto_pkey PRIMARY KEY (gasto_id),
  CONSTRAINT gasto_registrado_por_usuario_id_fkey FOREIGN KEY (registrado_por_usuario_id) REFERENCES public.usuario(usuario_id),
  CONSTRAINT gasto_caja_menor_id_fkey FOREIGN KEY (caja_menor_id) REFERENCES public.caja_menor(caja_menor_id),
  CONSTRAINT gasto_categoria_gasto_id_fkey FOREIGN KEY (categoria_gasto_id) REFERENCES public.categoria_gasto(categoria_gasto_id),
  CONSTRAINT gasto_moneda_codigo_fkey FOREIGN KEY (moneda_codigo) REFERENCES public.moneda(codigo_moneda)
);
CREATE TABLE public.pago (
  pago_id uuid NOT NULL DEFAULT gen_random_uuid(),
  cliente_id uuid NOT NULL,
  ruta_id uuid NOT NULL,
  cobrador_usuario_id uuid,
  medio_pago_id smallint NOT NULL,
  moneda_codigo character NOT NULL,
  fecha_pago timestamp with time zone NOT NULL DEFAULT now(),
  total_pagado numeric NOT NULL CHECK (total_pagado > 0::numeric),
  referencia_externa character varying,
  observacion text,
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT pago_pkey PRIMARY KEY (pago_id),
  CONSTRAINT pago_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.cliente(cliente_id),
  CONSTRAINT pago_ruta_id_fkey FOREIGN KEY (ruta_id) REFERENCES public.ruta(ruta_id),
  CONSTRAINT pago_cobrador_usuario_id_fkey FOREIGN KEY (cobrador_usuario_id) REFERENCES public.usuario(usuario_id),
  CONSTRAINT pago_medio_pago_id_fkey FOREIGN KEY (medio_pago_id) REFERENCES public.medio_pago(medio_pago_id),
  CONSTRAINT pago_moneda_codigo_fkey FOREIGN KEY (moneda_codigo) REFERENCES public.moneda(codigo_moneda)
);
CREATE TABLE public.pago_aplicacion (
  pago_aplicacion_id uuid NOT NULL DEFAULT gen_random_uuid(),
  pago_id uuid NOT NULL,
  credito_cuota_id uuid NOT NULL,
  monto_capital numeric NOT NULL DEFAULT 0,
  monto_interes numeric NOT NULL DEFAULT 0,
  monto_mora numeric NOT NULL DEFAULT 0,
  monto_descuento numeric NOT NULL DEFAULT 0,
  CONSTRAINT pago_aplicacion_pkey PRIMARY KEY (pago_aplicacion_id),
  CONSTRAINT pago_aplicacion_pago_id_fkey FOREIGN KEY (pago_id) REFERENCES public.pago(pago_id),
  CONSTRAINT pago_aplicacion_credito_cuota_id_fkey FOREIGN KEY (credito_cuota_id) REFERENCES public.credito_cuota(credito_cuota_id)
);
CREATE TABLE public.presupuesto_periodo (
  presupuesto_periodo_id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid,
  moneda_codigo character NOT NULL,
  fecha_inicio date NOT NULL,
  fecha_fin date NOT NULL,
  nombre character varying NOT NULL,
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT presupuesto_periodo_pkey PRIMARY KEY (presupuesto_periodo_id),
  CONSTRAINT presupuesto_periodo_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(usuario_id),
  CONSTRAINT presupuesto_periodo_moneda_codigo_fkey FOREIGN KEY (moneda_codigo) REFERENCES public.moneda(codigo_moneda)
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
CREATE TABLE public.tbl_personas (
  id_per bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  per_primer_nombre character varying NOT NULL,
  per_apellido character varying NOT NULL,
  per_documento character varying NOT NULL UNIQUE CHECK (length(TRIM(BOTH FROM per_documento)) > 0),
  per_direccion character varying,
  per_num_celular character varying,
  per_creacion timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT tbl_personas_pkey PRIMARY KEY (id_per)
);
CREATE TABLE public.tbl_usuarios (
  id_usu bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  usu_usuario character varying NOT NULL UNIQUE,
  usu_password character varying NOT NULL,
  usu_creacion timestamp with time zone NOT NULL DEFAULT now(),
  usu_email character varying NOT NULL CHECK (POSITION(('@'::text) IN (usu_email)) > 1),
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
  CONSTRAINT tbl_cajas_pkey PRIMARY KEY (id_caj),
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
  usu_id bigint NOT NULL,
  pcr_id bigint NOT NULL,
  cli_id bigint NOT NULL,
  CONSTRAINT tbl_creditos_pkey PRIMARY KEY (id_cre),
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
  CONSTRAINT tbl_pagos_pkey PRIMARY KEY (id_pag),
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
CREATE TABLE public.auditoria (
  auditoria_id uuid NOT NULL DEFAULT gen_random_uuid(),
  usuario_id uuid,
  tabla character varying NOT NULL CHECK (length(TRIM(BOTH FROM tabla)) > 0),
  registro_id character varying,
  accion character varying NOT NULL CHECK (length(TRIM(BOTH FROM accion)) > 0),
  descripcion text NOT NULL,
  valores_anteriores jsonb,
  valores_nuevos jsonb,
  metadata jsonb,
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT auditoria_pkey PRIMARY KEY (auditoria_id),
  CONSTRAINT auditoria_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(usuario_id)
);
CREATE TABLE public.caja_menor_movimiento_auditoria (
  caja_menor_movimiento_auditoria_id uuid NOT NULL DEFAULT gen_random_uuid(),
  caja_menor_id uuid NOT NULL,
  caja_menor_movimiento_id uuid,
  usuario_id uuid,
  accion character varying NOT NULL CHECK (accion::text = ANY (ARRAY['MODIFICAR'::character varying, 'ELIMINAR'::character varying]::text[])),
  detalle text NOT NULL,
  creado_en timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT caja_menor_movimiento_auditoria_pkey PRIMARY KEY (caja_menor_movimiento_auditoria_id),
  CONSTRAINT caja_menor_movimiento_auditoria_caja_menor_id_fkey FOREIGN KEY (caja_menor_id) REFERENCES public.caja_menor(caja_menor_id),
  CONSTRAINT caja_menor_movimiento_auditoria_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(usuario_id)
);