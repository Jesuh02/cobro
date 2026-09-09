import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { DomainError } from '../../common/domain/domain-error';
import { PrismaService } from '../../common/prisma/prisma.service';
import { TenantScopeService } from '../../common/tenancy/tenant-scope.service';
import { AuthenticatedUser } from '../auth/auth.types';
import { ObtenerPresupuestoQueryDto } from './dto';
import {
  PresupuestoItem,
  PresupuestoRespuesta,
  PresupuestoTblRow,
} from './presupuesto.types';

@Injectable()
export class PresupuestoService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenantScope: TenantScopeService,
  ) {}

  async obtenerPresupuesto(
    query: ObtenerPresupuestoQueryDto,
    usuario: AuthenticatedUser,
  ): Promise<PresupuestoRespuesta> {
    return this.obtenerPresupuestoTbl(query, usuario);
  }

  private async obtenerPresupuestoTbl(
    query: ObtenerPresupuestoQueryDto,
    usuario: AuthenticatedUser,
  ): Promise<PresupuestoRespuesta> {
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);
    const puedeVerTodo =
      this.tenantScope.puedeVerDatosOrganizacion(usuario) &&
      query.alcance !== 'cobrador';
    const search = this.normalizarTextoOpcional(query.search);
    const fechaDesde = query.fechaDesde
      ? this.parsearFecha(query.fechaDesde, 'fechaDesde')
      : null;
    const fechaHasta = query.fechaHasta
      ? this.finDia(this.parsearFecha(query.fechaHasta, 'fechaHasta'))
      : null;
    const fechaDesdeColombia = query.fechaDesde
      ? this.inicioDiaColombia(
          this.parsearFecha(query.fechaDesde, 'fechaDesde'),
        )
      : null;
    const fechaHastaColombia = query.fechaHasta
      ? this.finDiaColombia(this.parsearFecha(query.fechaHasta, 'fechaHasta'))
      : null;
    const condicionesCajas: Prisma.Sql[] = [
      Prisma.sql`c.caj_tipo::text = 'MENOR'`,
      Prisma.sql`c.caj_activa`,
      Prisma.sql`c.org_id = ${scope.organizacionId}::uuid`,
    ];
    const filtrosFechaPagos: Prisma.Sql[] = [];
    const filtrosFechaGastos: Prisma.Sql[] = [];
    const filtrosFechaCreditos: Prisma.Sql[] = [];

    if (query.cajaMenorId) {
      condicionesCajas.push(Prisma.sql`c.id_caj::text = ${query.cajaMenorId}`);
    }

    if (!puedeVerTodo) {
      condicionesCajas.push(Prisma.sql`EXISTS (
        SELECT 1
        FROM public.tbl_sesiones_cajas sc_acl
        WHERE sc_acl.caj_id = c.id_caj
          AND sc_acl.usu_id = ${scope.usuarioId}::uuid
      )`);
    }

    if (search) {
      const pattern = `%${search}%`;
      condicionesCajas.push(Prisma.sql`c.caj_nombre ILIKE ${pattern}`);
    }

    if (fechaDesdeColombia) {
      filtrosFechaPagos.push(Prisma.sql`pa.pag_fecha >= ${fechaDesdeColombia}`);
      filtrosFechaGastos.push(Prisma.sql`g.gas_fecha >= ${fechaDesdeColombia}`);
    }

    if (fechaDesde) {
      filtrosFechaCreditos.push(
        Prisma.sql`cr.cre_fecha_inicio >= ${fechaDesde}`,
      );
    }

    if (fechaHastaColombia) {
      filtrosFechaPagos.push(Prisma.sql`pa.pag_fecha <= ${fechaHastaColombia}`);
      filtrosFechaGastos.push(Prisma.sql`g.gas_fecha <= ${fechaHastaColombia}`);
    }

    if (fechaHasta) {
      filtrosFechaCreditos.push(
        Prisma.sql`cr.cre_fecha_inicio <= ${fechaHasta}`,
      );
    }

    const fechaSaldoMovimientosWhere = fechaDesde
      ? Prisma.sql`AND m.mca_creacion < ${fechaDesdeColombia}`
      : Prisma.empty;
    const usuarioMovimientosWhere = puedeVerTodo
      ? Prisma.empty
      : Prisma.sql`AND m.usu_id = ${scope.usuarioId}::uuid`;
    const usuarioPagosWhere = puedeVerTodo
      ? Prisma.empty
      : Prisma.sql`AND cr.usu_id = ${scope.usuarioId}::uuid`;
    const usuarioGastosWhere = puedeVerTodo
      ? Prisma.empty
      : Prisma.sql`AND g.usu_id = ${scope.usuarioId}::uuid`;
    const usuarioCreditosWhere = puedeVerTodo
      ? Prisma.empty
      : Prisma.sql`AND cr.usu_id = ${scope.usuarioId}::uuid`;
    const fechaPagosWhere =
      filtrosFechaPagos.length > 0
        ? Prisma.sql`AND ${Prisma.join(filtrosFechaPagos, ' AND ')}`
        : Prisma.empty;
    const fechaGastosWhere =
      filtrosFechaGastos.length > 0
        ? Prisma.sql`AND ${Prisma.join(filtrosFechaGastos, ' AND ')}`
        : Prisma.empty;
    const fechaCreditosWhere =
      filtrosFechaCreditos.length > 0
        ? Prisma.sql`AND ${Prisma.join(filtrosFechaCreditos, ' AND ')}`
        : Prisma.empty;

    const rows = await this.prisma.$queryRaw<PresupuestoTblRow[]>(Prisma.sql`
      WITH cajas AS (
        SELECT
          c.id_caj,
          c.caj_nombre,
          c.org_id,
          ${
            puedeVerTodo
              ? Prisma.sql`COALESCE(tu.id_usu, responsable.id_usu)`
              : Prisma.sql`${scope.usuarioId}::uuid`
          } AS responsable_id
        FROM public.tbl_cajas c
        LEFT JOIN LATERAL (
          SELECT tu.id_usu
          FROM public.tbl_sesiones_cajas sc
          JOIN public.tbl_usuarios tu ON tu.id_usu = sc.usu_id
          WHERE sc.caj_id = c.id_caj
          ORDER BY sc.sca_fecha_apertura DESC
          LIMIT 1
        ) tu ON TRUE
        LEFT JOIN LATERAL (
          SELECT tu.id_usu
          FROM public.tbl_usuarios_organizaciones uo
          JOIN public.tbl_usuarios tu ON tu.id_usu = uo.usu_id
          WHERE uo.org_id = c.org_id
            AND uo.urg_activo
          ORDER BY tu.id_usu ASC
          LIMIT 1
        ) responsable ON TRUE
        WHERE ${Prisma.join(condicionesCajas, ' AND ')}
      ),
      resumen AS (
        SELECT
          c.id_caj::text AS caja_menor_id,
          c.caj_nombre AS caja_menor_nombre,
          c.responsable_id::text AS responsable_usuario_id,
          'COP' AS moneda_codigo,
          COALESCE(MAX(sc.sca_monto_inicial), 0)
            + COALESCE(SUM(
              CASE
                WHEN UPPER(m.mca_tipo::text) IN ('APERTURA', 'RECAUDO', 'AJUSTE_ENTRADA') THEN m.mca_monto
                WHEN UPPER(m.mca_tipo::text) IN ('GASTO', 'DESEMBOLSO_CREDITO', 'AJUSTE_SALIDA') THEN -m.mca_monto
                ELSE 0
              END
            ), 0) AS caja_menor,
          COALESCE(pagos.recaudado, 0) AS recaudado,
          COALESCE(gastos.gastos, 0) AS gastos,
          COALESCE(creditos.creditos, 0) AS creditos
        FROM cajas c
        LEFT JOIN public.tbl_sesiones_cajas sc ON sc.caj_id = c.id_caj
        LEFT JOIN public.tbl_movimientos_cajas m
          ON m.sca_id = sc.id_sca
          ${fechaSaldoMovimientosWhere}
          ${usuarioMovimientosWhere}
        LEFT JOIN LATERAL (
          SELECT SUM(pa.pag_monto) AS recaudado
          FROM (
            SELECT DISTINCT ON (pa.id_pag)
              pa.id_pag,
              pa.pag_monto,
              pa.pag_fecha,
              cu.cre_id AS credito_id
            FROM public.tbl_pagos pa
            JOIN public.tbl_cuotas_pagos cp ON cp.pagos_id = pa.id_pag
            JOIN public.tbl_cuotas cu ON cu.id_cuo = cp.cuo_id
            ORDER BY pa.id_pag, cu.cre_id
          ) pa
          JOIN public.tbl_creditos cr ON cr.id_cre = pa.credito_id
          JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
          WHERE cl.org_id = c.org_id
            ${usuarioPagosWhere}
            ${fechaPagosWhere}
        ) pagos ON TRUE
        LEFT JOIN LATERAL (
          SELECT SUM(g.gas_monto) AS gastos
          FROM public.tbl_gastos g
          WHERE g.caj_id = c.id_caj
            ${usuarioGastosWhere}
            ${fechaGastosWhere}
        ) gastos ON TRUE
        LEFT JOIN LATERAL (
          SELECT SUM(cr.cre_total) AS creditos
          FROM public.tbl_creditos cr
          JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
          WHERE cl.org_id = c.org_id
            AND UPPER(cr.cre_estado::text) NOT IN ('ANULADO')
            ${usuarioCreditosWhere}
            ${fechaCreditosWhere}
        ) creditos ON TRUE
        WHERE TRUE
        GROUP BY c.id_caj, c.caj_nombre, c.responsable_id, pagos.recaudado, gastos.gastos, creditos.creditos
      )
      SELECT
        caja_menor_id,
        caja_menor_nombre,
        responsable_usuario_id,
        moneda_codigo,
        caja_menor,
        recaudado,
        gastos,
        creditos,
        caja_menor + recaudado - gastos AS presupuesto
      FROM resumen
      ORDER BY moneda_codigo ASC, caja_menor_id ASC
    `);

    const items: PresupuestoItem[] = rows.map((row) => ({
      cajaMenorId: row.caja_menor_id,
      cajaMenorNombre: row.caja_menor_nombre,
      responsableUsuarioId: row.responsable_usuario_id,
      monedaCodigo: row.moneda_codigo,
      cajaMenor: this.decimalANumero(row.caja_menor),
      recaudado: this.decimalANumero(row.recaudado),
      gastos: this.decimalANumero(row.gastos),
      creditos: this.decimalANumero(row.creditos),
      presupuesto: this.decimalANumero(row.presupuesto),
    }));

    return {
      items,
      totales: {
        cajaMenor: this.redondear(
          items.reduce((total, item) => total + item.cajaMenor, 0),
        ),
        recaudado: this.redondear(
          items.reduce((total, item) => total + item.recaudado, 0),
        ),
        gastos: this.redondear(
          items.reduce((total, item) => total + item.gastos, 0),
        ),
        creditos: this.redondear(
          items.reduce((total, item) => total + item.creditos, 0),
        ),
        presupuesto: this.redondear(
          items.reduce((total, item) => total + item.presupuesto, 0),
        ),
      },
    };
  }

  // ==========================================
  // HELPERS PRIVADOS DE FORMATEO Y FECHAS
  // ==========================================

  private decimalANumero(valor: Prisma.Decimal | number | null | undefined): number {
    if (valor === null || valor === undefined) return 0;
    return Number(valor);
  }

  private redondear(valor: number, decimales = 2): number {
    const factor = 10 ** decimales;
    return Math.round((valor + Number.EPSILON) * factor) / factor;
  }

  private parsearFecha(valor: string, campo: string): Date {
    const fecha = new Date(valor);
    if (Number.isNaN(fecha.getTime())) {
      throw DomainError.validation(
        `La fecha enviada en ${campo} no es valida`,
        'FECHA_INVALIDA',
      );
    }
    return fecha;
  }

  private normalizarTextoOpcional(valor?: string | null): string | null {
    if (!valor) return null;
    const trimmed = valor.trim();
    return trimmed.length > 0 ? trimmed : null;
  }

  private fechaUtc(fecha: Date): Date {
    return new Date(
      Date.UTC(fecha.getUTCFullYear(), fecha.getUTCMonth(), fecha.getUTCDate()),
    );
  }

  private finDia(fecha: Date): Date {
    const next = this.fechaUtc(fecha);
    next.setUTCHours(23, 59, 59, 999);
    return next;
  }

  private inicioDiaColombia(fecha: Date): Date {
    const next = this.fechaUtc(fecha);
    next.setUTCHours(5, 0, 0, 0);
    return next;
  }

  private finDiaColombia(fecha: Date): Date {
    const next = this.inicioDiaColombia(fecha);
    next.setUTCDate(next.getUTCDate() + 1);
    next.setUTCMilliseconds(next.getUTCMilliseconds() - 1);
    return next;
  }
}

