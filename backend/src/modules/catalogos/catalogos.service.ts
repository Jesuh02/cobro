import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../common/prisma/prisma.service';
import { TenantScopeService } from '../../common/tenancy/tenant-scope.service';
import { AuthenticatedUser } from '../auth/auth.types';

type CatalogoTblRow = {
  tipo: string;
  id: string;
  codigo: string;
  nombre: string;
  extra: string | null;
  activo: boolean | null;
};

type MonedaTblRow = {
  codigo: string;
  nombre: string;
  simbolo: string;
  decimales: number | bigint;
};

type UsuarioTblRow = {
  id: string;
  usuario: string;
  nombres: string;
  apellidos: string;
  correo: string;
  telefono: string | null;
};

type CajaMenorCatalogoTblRow = {
  id: string;
  nombre: string;
  extra: string | null;
  activo: boolean | null;
  fecha_apertura: Date | null;
  fecha_cierre: Date | null;
};

type RutaTblRow = {
  id: string;
  nombre: string;
  descripcion: string | null;
  activa: boolean;
  responsable_id: string;
  responsable_usuario: string;
  responsable_nombres: string;
  responsable_apellidos: string;
  responsable_correo: string;
  responsable_telefono: string | null;
  clientes: number;
  creditos: number;
};

const tiposMovimientoCajaTblBase = [
  {
    id: 1,
    codigo: 'APERTURA',
    nombre: 'Apertura',
    naturaleza: 'E',
    referenciaTipo: 'SESION_CAJA',
  },
  {
    id: 2,
    codigo: 'RECAUDO',
    nombre: 'Recaudo',
    naturaleza: 'E',
    referenciaTipo: 'PAGO',
  },
  {
    id: 3,
    codigo: 'GASTO',
    nombre: 'Gasto',
    naturaleza: 'S',
    referenciaTipo: 'GASTO',
  },
  {
    id: 4,
    codigo: 'DESEMBOLSO_CREDITO',
    nombre: 'Desembolso de credito',
    naturaleza: 'S',
    referenciaTipo: 'CREDITO',
  },
  {
    id: 5,
    codigo: 'AJUSTE_ENTRADA',
    nombre: 'Ajuste de entrada',
    naturaleza: 'E',
    referenciaTipo: 'AJUSTE',
  },
  {
    id: 6,
    codigo: 'AJUSTE_SALIDA',
    nombre: 'Ajuste de salida',
    naturaleza: 'S',
    referenciaTipo: 'AJUSTE',
  },
  {
    id: 7,
    codigo: 'CIERRE',
    nombre: 'Cierre',
    naturaleza: 'N',
    referenciaTipo: 'SESION_CAJA',
  },
] as const;

const codigosMovimientoCajaTblBase = tiposMovimientoCajaTblBase.map(
  (tipo) => tipo.codigo,
);

@Injectable()
export class CatalogosService {

  constructor(
    private readonly prisma: PrismaService,
    private readonly tenantScope: TenantScopeService,
  ) {}

  async obtenerCatalogos(usuario: AuthenticatedUser) {
    return this.obtenerCatalogosTbl(usuario);
  }

  private async obtenerCatalogosTbl(usuario: AuthenticatedUser) {
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);
    const puedeVerTodo = this.tenantScope.puedeVerDatosOrganizacion(usuario);

    const [monedas, catalogos, rutas, cajasMenores, usuarios] =
      await Promise.all([
        this.obtenerMonedasTbl(),
        this.prisma.$queryRaw<CatalogoTblRow[]>(Prisma.sql`
          SELECT *
          FROM (
            SELECT
              'frecuencia_pago' AS tipo,
              CASE pcr_frecuencia::text
                WHEN 'DIARIO' THEN '1'
                WHEN 'SEMANAL' THEN '2'
                WHEN 'QUINCENAL' THEN '3'
                WHEN 'MENSUAL' THEN '4'
                ELSE '1'
              END AS id,
              pcr_frecuencia::text AS codigo,
              INITCAP(REPLACE(pcr_frecuencia::text, '_', ' ')) AS nombre,
              CASE pcr_frecuencia::text
                WHEN 'DIARIO' THEN '1'
                WHEN 'SEMANAL' THEN '7'
                WHEN 'QUINCENAL' THEN '15'
                WHEN 'MENSUAL' THEN '30'
                ELSE '1'
              END AS extra,
              TRUE AS activo
            FROM (
              SELECT DISTINCT pcr_frecuencia::text AS pcr_frecuencia
              FROM public.tbl_productos_creditos
              UNION
              SELECT UNNEST(ARRAY['DIARIO', 'SEMANAL', 'QUINCENAL', 'MENSUAL'])
            ) frecuencias
            UNION ALL
            SELECT
              'medio_pago',
              id_med::text,
              med_tipo::text,
              med_nombre,
              NULL,
              med_activo
            FROM public.tbl_medios_pagos
            WHERE med_activo
            UNION ALL
            SELECT
              'medio_pago',
              base.id::text,
              base.codigo,
              base.nombre,
              NULL,
              TRUE
            FROM (
              VALUES
                (10001, 'EFECTIVO', 'Efectivo'),
                (10002, 'TRANSFERENCIA', 'Transferencia'),
                (10003, 'TARJETA', 'Tarjeta'),
                (10004, 'BILLETERA', 'Billetera'),
                (10005, 'OTRO', 'Otro')
            ) AS base(id, codigo, nombre)
            UNION ALL
            SELECT
              'categoria_gasto',
              id_cga::text,
              UPPER(REGEXP_REPLACE(cga_nombre, '\\s+', '_', 'g')),
              cga_nombre,
              cga_descripcion,
              TRUE
            FROM public.tbl_categorias_gastos
            UNION ALL
            SELECT
              'tipo_movimiento_caja',
              base.id::text,
              base.codigo,
              base.nombre,
              base.naturaleza,
              TRUE
            FROM (
              VALUES
                (1, 'APERTURA', 'Apertura', 'E'),
                (2, 'RECAUDO', 'Recaudo', 'E'),
                (3, 'GASTO', 'Gasto', 'S'),
                (4, 'DESEMBOLSO_CREDITO', 'Desembolso de credito', 'S'),
                (5, 'AJUSTE_ENTRADA', 'Ajuste de entrada', 'E'),
                (6, 'AJUSTE_SALIDA', 'Ajuste de salida', 'S'),
                (7, 'CIERRE', 'Cierre', 'N')
            ) AS base(id, codigo, nombre, naturaleza)
            UNION ALL
            SELECT
              'tipo_movimiento_caja',
              (100 + ROW_NUMBER() OVER (ORDER BY existentes.codigo))::text,
              existentes.codigo,
              INITCAP(REPLACE(existentes.codigo, '_', ' ')),
              CASE
                WHEN existentes.codigo IN ('SALIDA', 'EGRESO', 'GASTO', 'DESEMBOLSO', 'DESEMBOLSO_CREDITO', 'AJUSTE_SALIDA') THEN 'S'
                ELSE 'E'
              END,
              TRUE
            FROM (
              SELECT DISTINCT UPPER(mca_tipo::text) AS codigo
              FROM public.tbl_movimientos_cajas
              WHERE org_id = ${scope.organizacionId}::uuid
                AND UPPER(mca_tipo::text) NOT IN (${Prisma.join(
                  codigosMovimientoCajaTblBase,
                )})
            ) existentes
          ) catalogos
          ORDER BY tipo ASC, id ASC
        `),
        this.listarRutasTbl(usuario),
        this.prisma.$queryRaw<CajaMenorCatalogoTblRow[]>(Prisma.sql`
          SELECT
            c.id_caj::text AS id,
            c.caj_nombre AS nombre,
            sc.usu_id::text AS extra,
            sc.sca_fecha_apertura AS fecha_apertura,
            sc.sca_fecha_cierre AS fecha_cierre,
            (
              c.caj_activa
              AND sc.sca_estado::text = 'ABIERTA'
              AND (sc.sca_fecha_cierre IS NULL OR sc.sca_fecha_cierre > now())
            ) AS activo
          FROM public.tbl_cajas c
          LEFT JOIN LATERAL (
            SELECT
              sca.usu_id,
              sca.sca_fecha_apertura,
              sca.sca_fecha_cierre,
              sca.sca_estado
            FROM public.tbl_sesiones_cajas sca
            WHERE sca.caj_id = c.id_caj
            ORDER BY
              (sca.sca_estado::text = 'ABIERTA') DESC,
              sca.sca_fecha_apertura DESC,
              sca.id_sca DESC
            LIMIT 1
          ) sc ON TRUE
          WHERE c.caj_tipo::text = 'MENOR'
            AND c.org_id = ${scope.organizacionId}::uuid
            AND ${
              puedeVerTodo
                ? Prisma.sql`TRUE`
                : Prisma.sql`sc.usu_id = ${scope.usuarioId}::uuid`
            }
          ORDER BY activo DESC, c.caj_nombre ASC
        `),
        this.prisma.$queryRaw<UsuarioTblRow[]>(Prisma.sql`
          SELECT
            tu.id_usu::text AS id,
            tu.usu_usuario AS usuario,
            p.per_primer_nombre AS nombres,
            p.per_apellido AS apellidos,
            COALESCE(p.per_email, '') AS correo,
            p.per_num_celular AS telefono
          FROM public.tbl_usuarios tu
          JOIN public.tbl_personas p ON p.id_per = tu.persona_id
          JOIN public.tbl_usuarios_organizaciones uo
            ON uo.usu_id = tu.id_usu
           AND uo.urg_activo
           AND uo.org_id = ${scope.organizacionId}::uuid
          WHERE tu.usu_activo
            AND ${
              puedeVerTodo
                ? Prisma.sql`TRUE`
                : Prisma.sql`tu.id_usu = ${scope.usuarioId}::uuid`
            }
          ORDER BY p.per_primer_nombre ASC, p.per_apellido ASC
        `),
      ]);

    const frecuenciasPago = catalogos.filter(
      (catalogo) => catalogo.tipo === 'frecuencia_pago',
    );
    let medioPagoSeq = 1;
    const mediosPago = new Map(
      catalogos
        .filter((catalogo) => catalogo.tipo === 'medio_pago' && catalogo.activo)
        .map((medio) => [
          medio.codigo,
          {
            id:
              Number.isFinite(Number(medio.id)) && Number(medio.id) > 0
                ? Number(medio.id)
                : medioPagoSeq++,
            codigo: medio.codigo,
            nombre: medio.nombre,
          },
        ]),
    );
    const tiposMovimientoCaja = catalogos.filter(
      (catalogo) => catalogo.tipo === 'tipo_movimiento_caja',
    );
    const categoriasGasto = catalogos.filter(
      (catalogo) => catalogo.tipo === 'categoria_gasto',
    );

    return {
      monedas:
        monedas.length > 0
          ? monedas.map((moneda) => ({
              codigo: moneda.codigo,
              nombre: moneda.nombre,
              simbolo: moneda.simbolo,
              decimales: Number(moneda.decimales),
            }))
          : [
              {
                codigo: 'COP',
                nombre: 'Peso colombiano',
                simbolo: '$',
                decimales: 0,
              },
            ],
      frecuenciasPago: frecuenciasPago.map((frecuencia) => ({
        id:
          Number.isFinite(Number(frecuencia.id)) && Number(frecuencia.id) > 0
            ? Number(frecuencia.id)
            : 0,
        codigo: frecuencia.codigo,
        nombre: frecuencia.nombre,
        diasIntervalo: frecuencia.extra ? Number(frecuencia.extra) : 1,
      })),
      mediosPago: Array.from(mediosPago.values()),
      tiposMovimientoCaja: tiposMovimientoCaja.map((tipo) => ({
        id:
          Number.isFinite(Number(tipo.id)) && Number(tipo.id) > 0
            ? Number(tipo.id)
            : 0,
        codigo: tipo.codigo,
        nombre: tipo.nombre,
        naturaleza: tipo.extra ?? 'E',
      })),
      categoriasGasto: categoriasGasto.map((categoria) => ({
        id:
          Number.isFinite(Number(categoria.id)) && Number(categoria.id) > 0
            ? Number(categoria.id)
            : 0,
        codigo: categoria.codigo,
        nombre: categoria.nombre,
        activa: categoria.activo ?? true,
      })),
      rutas,
      cajasMenores: cajasMenores.map((caja) => {
        const responsable =
          usuarios.find((item) => item.id === caja.extra) ??
          usuarios[0] ??
          null;

        return {
          id: caja.id,
          nombre: caja.nombre,
          activa: Boolean(caja.activo),
          monedaCodigo: 'COP',
          fechaApertura: caja.fecha_apertura
            ? caja.fecha_apertura.toISOString()
            : null,
          fechaCierre: caja.fecha_cierre
            ? caja.fecha_cierre.toISOString()
            : null,
          responsable: responsable
            ? this.formatearUsuarioTbl(responsable)
            : this.formatearUsuarioAutenticado(usuario),
        };
      }),
      usuarios:
        usuarios.length > 0
          ? usuarios.map((item) => this.formatearUsuarioTbl(item))
          : [this.formatearUsuarioAutenticado(usuario)],
    };
  }

  private async obtenerMonedasTbl(): Promise<MonedaTblRow[]> {
    try {
      return await this.prisma.$queryRaw<MonedaTblRow[]>(Prisma.sql`
        SELECT
          mon_codigo::text AS codigo,
          mon_nombre AS nombre,
          mon_simbolo AS simbolo,
          mon_decimales AS decimales
        FROM public.tbl_monedas
        WHERE mon_activa
        ORDER BY mon_codigo ASC
      `);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        ['P2021', 'P2022'].includes(error.code)
      ) {
        return [];
      }
      throw error;
    }
  }

  private async listarRutasTbl(usuario: AuthenticatedUser) {
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);
    const rows = await this.prisma.$queryRaw<RutaTblRow[]>(Prisma.sql`
      SELECT
        r.id_rut::text AS id,
        r.rut_nombre AS nombre,
        r.rut_descripcion AS descripcion,
        r.rut_activa AS activa,
        tu.id_usu::text AS responsable_id,
        tu.usu_usuario AS responsable_usuario,
        p.per_primer_nombre AS responsable_nombres,
        p.per_apellido AS responsable_apellidos,
        COALESCE(p.per_email, '') AS responsable_correo,
        p.per_num_celular AS responsable_telefono,
        COUNT(DISTINCT rc.cli_id)::int AS clientes,
        COUNT(DISTINCT cr.id_cre)::int AS creditos
      FROM public.tbl_rutas r
      JOIN public.tbl_usuarios tu ON tu.id_usu = r.usu_id
      JOIN public.tbl_personas p ON p.id_per = tu.persona_id
      LEFT JOIN public.tbl_rutas_clientes rc
        ON rc.rut_id = r.id_rut
        AND rc.rcl_activo
      LEFT JOIN public.tbl_creditos cr
        ON cr.cli_id = rc.cli_id
        AND cr.usu_id = r.usu_id
      WHERE r.org_id = ${scope.organizacionId}::uuid
        AND ${
          this.tenantScope.puedeVerDatosOrganizacion(usuario)
            ? Prisma.sql`TRUE`
            : Prisma.sql`tu.id_usu = ${scope.usuarioId}::uuid`
        }
      GROUP BY r.id_rut, tu.id_usu, p.id_per
      ORDER BY r.rut_activa DESC, r.rut_nombre ASC
    `);

    return rows.map((ruta) => ({
      id: ruta.id,
      nombre: ruta.nombre,
      descripcion: ruta.descripcion,
      esPrincipal: false,
      estado: {
        codigo: ruta.activa ? 'ABIERTA' : 'CERRADA',
        nombre: ruta.activa ? 'Abierta' : 'Cerrada',
      },
      responsable: this.formatearUsuarioTbl({
        id: ruta.responsable_id,
        usuario: ruta.responsable_usuario,
        nombres: ruta.responsable_nombres,
        apellidos: ruta.responsable_apellidos,
        correo: ruta.responsable_correo,
        telefono: ruta.responsable_telefono,
      }),
      clientes: Number(ruta.clientes),
      creditos: Number(ruta.creditos),
    }));
  }

  private formatearUsuarioTbl(usuario: UsuarioTblRow) {
    return {
      id: usuario.id,
      usuario: usuario.usuario,
      nombres: usuario.nombres,
      apellidos: usuario.apellidos,
      nombreCompleto: `${usuario.nombres} ${usuario.apellidos}`.trim(),
      correo: usuario.correo,
      telefono: usuario.telefono,
    };
  }

  private formatearUsuarioAutenticado(usuario: AuthenticatedUser) {
    return {
      id: usuario.usuarioId,
      usuario: usuario.usuario,
      nombres: usuario.usuario,
      apellidos: '',
      nombreCompleto: usuario.usuario,
      correo: '',
      telefono: null,
    };
  }
}
