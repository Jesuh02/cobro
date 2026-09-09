import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { DomainError } from '../../common/domain/domain-error';
import { PrismaService } from '../../common/prisma/prisma.service';
import {
  PrismaExecutor,
  TenantScopeService,
} from '../../common/tenancy/tenant-scope.service';
import { AuthenticatedUser } from '../auth/auth.types';
import {
  ExportacionesService,
  maxExportRows,
} from '../exportaciones/exportaciones.service';
import {
  ColumnaExportacion,
  ExportacionExcel,
  FilaExportacion,
} from '../exportaciones/exportaciones.types';
import { Workbook } from 'exceljs';
import { ListarCobrosRutaQueryDto } from './dto';

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

type CobroRutaTblRow = {
  credito_id: string;
  cliente_id: string;
  cliente: string;
  cedula: string | null;
  negocio: string | null;
  direccion: string | null;
  latitud: Prisma.Decimal | null;
  longitud: Prisma.Decimal | null;
  ruta_id: string;
  ruta: string;
  moneda_codigo: string;
  valor_principal: Prisma.Decimal;
  valor_total: Prisma.Decimal;
  valor_cuota: Prisma.Decimal;
  total_abonado: Prisma.Decimal;
  saldo: Prisma.Decimal;
  numero_cuotas: number;
  cuotas_restantes: number;
  fecha_inicio: Date;
  fecha_maxima: Date;
  proxima_cuota_id: string | null;
  proxima_numero_cuota: number | null;
  proxima_fecha_pago: Date | null;
  proximo_valor_cuota: Prisma.Decimal | null;
  proximo_saldo_cuota: Prisma.Decimal | null;
  estado_cobro: string;
};

type UsuarioTblRow = {
  id: string;
  usuario: string;
  nombres: string;
  apellidos: string;
  correo: string;
  telefono: string | null;
};

@Injectable()
export class RutasService {

  constructor(
    private readonly prisma: PrismaService,
    private readonly tenantScope: TenantScopeService,
    private readonly exportaciones: ExportacionesService,
  ) {}

  async listarRutas(usuario: AuthenticatedUser) {
    return this.listarRutasTbl(usuario);
  }

  async listarRutasTbl(usuario: AuthenticatedUser) {
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

  async exportarCobrosRuta(
    query: ListarCobrosRutaQueryDto,
    usuario: AuthenticatedUser,
  ): Promise<ExportacionExcel> {
    const cobros = (await this.listarCobrosRuta(
      query,
      usuario,
      maxExportRows + 1,
    )) as Array<{
      cliente: string;
      cedula: string | null;
      negocio: string | null;
      direccion: string | null;
      ruta: string;
      monedaCodigo: string;
      valorPrincipal: number;
      valorTotal: number;
      valorCuota: number;
      totalAbonado: number;
      saldo: number;
      numeroCuotas: number;
      cuotasRestantes: number;
      fechaInicio: string;
      fechaMaxima: string;
      proximaNumeroCuota: number | null;
      proximaFechaPago: string | null;
      proximoSaldoCuota: number | null;
      estadoCobro: string;
    }>;
    this.exportaciones.asegurarTamanoExportacion(cobros.length);
    const workbook = new Workbook();
    workbook.creator = 'Cobro';
    workbook.created = new Date();

    const sheet = workbook.addWorksheet('Ruta activa');
    const columnas: ColumnaExportacion[] = [
      { header: 'Cliente', key: 'cliente', width: 30 },
      { header: 'Cedula', key: 'cedula', width: 18 },
      { header: 'Negocio', key: 'negocio', width: 24 },
      { header: 'Direccion', key: 'direccion', width: 32 },
      { header: 'Ruta', key: 'ruta', width: 22 },
      { header: 'Moneda', key: 'monedaCodigo', width: 10 },
      { header: 'Valor principal', key: 'valorPrincipal', width: 16 },
      { header: 'Valor total', key: 'valorTotal', width: 16 },
      { header: 'Valor cuota', key: 'valorCuota', width: 16 },
      { header: 'Total abonado', key: 'totalAbonado', width: 16 },
      { header: 'Saldo', key: 'saldo', width: 16 },
      { header: 'Cuotas', key: 'cuotas', width: 12 },
      { header: 'Cuotas restantes', key: 'cuotasRestantes', width: 16 },
      { header: 'Fecha inicio', key: 'fechaInicio', width: 14 },
      { header: 'Fecha maxima', key: 'fechaMaxima', width: 14 },
      { header: 'Proxima cuota', key: 'proximaNumeroCuota', width: 14 },
      { header: 'Proxima fecha pago', key: 'proximaFechaPago', width: 18 },
      { header: 'Saldo proxima cuota', key: 'proximoSaldoCuota', width: 18 },
      { header: 'Estado', key: 'estadoCobro', width: 14 },
    ];
    sheet.columns = columnas;
    const filasExcel: FilaExportacion[] = cobros.map((cobro) => ({
      cliente: cobro.cliente,
      cedula: cobro.cedula ?? '',
      negocio: cobro.negocio ?? '',
      direccion: cobro.direccion ?? '',
      ruta: cobro.ruta,
      monedaCodigo: cobro.monedaCodigo,
      valorPrincipal: cobro.valorPrincipal,
      valorTotal: cobro.valorTotal,
      valorCuota: cobro.valorCuota,
      totalAbonado: cobro.totalAbonado,
      saldo: cobro.saldo,
      cuotas: `${cobro.cuotasRestantes} / ${cobro.numeroCuotas}`,
      cuotasRestantes: cobro.cuotasRestantes,
      fechaInicio: cobro.fechaInicio,
      fechaMaxima: cobro.fechaMaxima,
      proximaNumeroCuota: cobro.proximaNumeroCuota ?? '',
      proximaFechaPago: cobro.proximaFechaPago ?? '',
      proximoSaldoCuota: cobro.proximoSaldoCuota,
      estadoCobro: cobro.estadoCobro,
    }));
    sheet.addRows(filasExcel);

    this.exportaciones.formatearHojaExportacion(sheet, [
      'valorPrincipal',
      'valorTotal',
      'valorCuota',
      'totalAbonado',
      'saldo',
      'proximoSaldoCuota',
    ]);

    return this.exportaciones.subirWorkbookExportacion({
      workbook,
      carpeta: 'cobros-ruta',
      nombreBase: 'cobros-ruta',
      filas: cobros.length,
      vistaPrevia: this.exportaciones.crearVistaPreviaExportacion(
        columnas,
        filasExcel,
      ),
    });
  }

  async listarCobrosRuta(
    query: ListarCobrosRutaQueryDto,
    usuario: AuthenticatedUser,
    limit?: number,
  ) {
    return this.listarCobrosRutaTbl(query, usuario, limit);
  }

  async listarCobrosRutaTbl(
    query: ListarCobrosRutaQueryDto,
    usuario: AuthenticatedUser,
    limit?: number,
  ) {
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);
    const search = this.normalizarTextoOpcional(query.search);
    const conditions: Prisma.Sql[] = [
      Prisma.sql`cl.org_id = ${scope.organizacionId}::uuid`,
      Prisma.sql`UPPER(cr.cre_estado::text) <> 'ANULADO'`,
    ];

    if (!this.tenantScope.puedeVerDatosOrganizacion(usuario)) {
      conditions.push(Prisma.sql`tu.id_usu = ${scope.usuarioId}::uuid`);
    }

    if (query.rutaId) {
      conditions.push(Prisma.sql`ruta_credito.ruta_id = ${query.rutaId}::uuid`);
    }

    if (query.estadoCobro === 'PAGADO') {
      conditions.push(Prisma.sql`(
        UPPER(cr.cre_estado::text) = 'PAGADO'
        OR COALESCE(rc.cuotas_restantes, 0) <= 0
        OR (cr.cre_total_pagar - COALESCE(rc.total_abonado, 0)) <= 0
      )`);
    } else if (query.estadoCobro === 'ATRASADO') {
      conditions.push(Prisma.sql`
        UPPER(cr.cre_estado::text) <> 'PAGADO'
        AND
        COALESCE(rc.cuotas_restantes, 0) > 0
        AND
        (cr.cre_total_pagar - COALESCE(rc.total_abonado, 0)) > 0
        AND prox.cuo_fecha_vencimiento < CURRENT_DATE
      `);
    } else if (query.estadoCobro === 'PENDIENTE') {
      conditions.push(Prisma.sql`
        UPPER(cr.cre_estado::text) <> 'PAGADO'
        AND
        COALESCE(rc.cuotas_restantes, 0) > 0
        AND
        (cr.cre_total_pagar - COALESCE(rc.total_abonado, 0)) > 0
        AND prox.cuo_fecha_vencimiento = CURRENT_DATE
      `);
    } else if (query.estadoCobro === 'AL_DIA') {
      conditions.push(Prisma.sql`
        UPPER(cr.cre_estado::text) <> 'PAGADO'
        AND
        COALESCE(rc.cuotas_restantes, 0) > 0
        AND
        (cr.cre_total_pagar - COALESCE(rc.total_abonado, 0)) > 0
        AND prox.cuo_fecha_vencimiento > CURRENT_DATE
      `);
    }

    if (search) {
      const pattern = `%${search}%`;
      conditions.push(Prisma.sql`(
        TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) ILIKE ${pattern}
        OR p.per_documento ILIKE ${pattern}
        OR p.per_direccion ILIKE ${pattern}
        OR cl.cli_referencia ILIKE ${pattern}
        OR ruta_credito.ruta ILIKE ${pattern}
      )`);
    }

    const rows = await this.prisma.$queryRaw<CobroRutaTblRow[]>(Prisma.sql`
      WITH abonos_cuota AS (
        SELECT
          cu.id_cuo,
          GREATEST(
            COALESCE(cu.cuo_total_pagado, 0),
            COALESCE(SUM(cp.cpa_total), 0)
          ) AS abonado
        FROM public.tbl_cuotas cu
        LEFT JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
        GROUP BY cu.id_cuo, cu.cuo_total_pagado
      ),
      resumen_credito AS (
        SELECT
          cu.cre_id,
          COALESCE(SUM(ac.abonado), 0) AS total_abonado,
          COUNT(*)::int AS numero_cuotas,
          COUNT(*) FILTER (
            WHERE UPPER(cu.cuo_estado::text) NOT IN ('PAGADA', 'ANULADA')
              AND (cu.cuo_valor - COALESCE(ac.abonado, 0)) > 0
          )::int AS cuotas_restantes,
          COALESCE(MAX(cu.cuo_valor), 0) AS valor_cuota
        FROM public.tbl_cuotas cu
        LEFT JOIN abonos_cuota ac ON ac.id_cuo = cu.id_cuo
        GROUP BY cu.cre_id
      )
      SELECT
        cr.id_cre::text AS credito_id,
        cl.id_cli::text AS cliente_id,
        TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS cliente,
        p.per_documento AS cedula,
        cl.cli_referencia AS negocio,
        p.per_direccion AS direccion,
        p.per_latitud AS latitud,
        p.per_longitud AS longitud,
        COALESCE(ruta_credito.ruta_id::text, '') AS ruta_id,
        COALESCE(ruta_credito.ruta, 'Sin ruta') AS ruta,
        'COP' AS moneda_codigo,
        cr.cre_total AS valor_principal,
        cr.cre_total_pagar AS valor_total,
        COALESCE(rc.valor_cuota, 0) AS valor_cuota,
        COALESCE(rc.total_abonado, 0) AS total_abonado,
        GREATEST(cr.cre_total_pagar - COALESCE(rc.total_abonado, 0), 0) AS saldo,
        COALESCE(rc.numero_cuotas, 0) AS numero_cuotas,
        COALESCE(rc.cuotas_restantes, 0) AS cuotas_restantes,
        cr.cre_fecha_inicio AS fecha_inicio,
        cr.cre_fecha_fin AS fecha_maxima,
        prox.id_cuo::text AS proxima_cuota_id,
        prox.cuo_numero::int AS proxima_numero_cuota,
        prox.cuo_fecha_vencimiento AS proxima_fecha_pago,
        prox.cuo_valor AS proximo_valor_cuota,
        prox.saldo_cuota AS proximo_saldo_cuota,
        CASE
          WHEN UPPER(cr.cre_estado::text) = 'PAGADO'
            OR COALESCE(rc.cuotas_restantes, 0) <= 0
            OR (cr.cre_total_pagar - COALESCE(rc.total_abonado, 0)) <= 0
            THEN 'PAGADO'
          WHEN prox.cuo_fecha_vencimiento < CURRENT_DATE THEN 'ATRASADO'
          WHEN prox.cuo_fecha_vencimiento = CURRENT_DATE THEN 'PENDIENTE'
          ELSE 'AL_DIA'
        END AS estado_cobro
      FROM public.tbl_creditos cr
      JOIN public.tbl_usuarios tu ON tu.id_usu = cr.usu_id
      JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
      JOIN public.tbl_personas p ON p.id_per = cl.cli_persona
      LEFT JOIN LATERAL (
        SELECT r.id_rut AS ruta_id, r.rut_nombre AS ruta
        FROM public.tbl_rutas_clientes rc
        JOIN public.tbl_rutas r ON r.id_rut = rc.rut_id
        WHERE rc.cli_id = cl.id_cli
          AND r.org_id = cl.org_id
          AND rc.rcl_activo
        ORDER BY (r.usu_id = cr.usu_id) DESC, r.rut_activa DESC, r.rut_nombre ASC
        LIMIT 1
      ) ruta_credito ON TRUE
      LEFT JOIN resumen_credito rc ON rc.cre_id = cr.id_cre
      LEFT JOIN LATERAL (
        SELECT
          cu.id_cuo,
          cu.cuo_numero,
          cu.cuo_fecha_vencimiento,
          cu.cuo_valor,
          GREATEST(cu.cuo_valor - COALESCE(ac.abonado, 0), 0) AS saldo_cuota
        FROM public.tbl_cuotas cu
        LEFT JOIN abonos_cuota ac ON ac.id_cuo = cu.id_cuo
        WHERE cu.cre_id = cr.id_cre
          AND UPPER(cu.cuo_estado::text) NOT IN ('PAGADA', 'ANULADA')
          AND (cu.cuo_valor - COALESCE(ac.abonado, 0)) > 0
        ORDER BY cu.cuo_fecha_vencimiento ASC, cu.cuo_numero ASC
        LIMIT 1
      ) prox ON TRUE
      WHERE ${Prisma.join(conditions, ' AND ')}
      ORDER BY ruta_credito.ruta ASC NULLS LAST, prox.cuo_fecha_vencimiento ASC NULLS LAST, cliente ASC
      ${limit ? Prisma.sql`LIMIT ${limit}` : Prisma.empty}
    `);

    return rows.map((row) => this.formatearCobroRutaTbl(row));
  }

  async obtenerOCrearRutaCreditoTbl(
    tx: PrismaExecutor,
    rutaId: string | undefined,
    organizacionId: string,
    usuarioId: string,
    usuarioNombre: string,
  ): Promise<string> {
    if (rutaId) {
      const [ruta] = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        SELECT id_rut::text AS id
        FROM public.tbl_rutas
        WHERE id_rut = ${rutaId}::uuid
          AND org_id = ${organizacionId}::uuid
          AND rut_activa
        LIMIT 1
      `);

      if (!ruta) {
        throw DomainError.notFound('Ruta no encontrada', 'RUTA_NO_ENCONTRADA');
      }

      return ruta.id;
    }

    const [existente] = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
      SELECT id_rut::text AS id
      FROM public.tbl_rutas
      WHERE org_id = ${organizacionId}::uuid
        AND usu_id = ${usuarioId}::uuid
        AND rut_activa
      ORDER BY id_rut ASC
      LIMIT 1
    `);

    if (existente) {
      return existente.id;
    }

    const nombre = `Ruta ${usuarioNombre}`;
    const [creada] = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
      INSERT INTO public.tbl_rutas (
        rut_nombre,
        rut_descripcion,
        usu_id,
        org_id
      )
      VALUES (
        ${nombre},
        'Creada automaticamente al registrar un credito',
        ${usuarioId}::uuid,
        ${organizacionId}::uuid
      )
      ON CONFLICT (org_id, rut_nombre) DO UPDATE
      SET
        rut_activa = TRUE,
        usu_id = EXCLUDED.usu_id
      RETURNING id_rut::text AS id
    `);

    return creada.id;
  }

  asegurarResponsableRuta(
    responsableUsuarioId: string,
    usuario: AuthenticatedUser,
  ): void {
    if (this.tenantScope.puedeVerDatosOrganizacion(usuario)) {
      return;
    }

    if (responsableUsuarioId !== usuario.usuarioId) {
      throw new ForbiddenException('No tienes acceso a esta ruta');
    }
  }

  private formatearCobroRutaTbl(row: CobroRutaTblRow) {
    return {
      id: row.credito_id,
      creditoId: row.credito_id,
      clienteId: row.cliente_id,
      cliente: row.cliente,
      cedula: row.cedula,
      negocio: row.negocio,
      direccion: row.direccion,
      latitud: row.latitud === null ? null : this.decimalANumero(row.latitud),
      longitud:
        row.longitud === null ? null : this.decimalANumero(row.longitud),
      rutaId: row.ruta_id,
      ruta: row.ruta,
      monedaCodigo: row.moneda_codigo,
      valorPrincipal: this.decimalANumero(row.valor_principal),
      valorTotal: this.decimalANumero(row.valor_total),
      valorCuota: this.decimalANumero(row.valor_cuota),
      totalAbonado: this.decimalANumero(row.total_abonado),
      saldo: this.decimalANumero(row.saldo),
      numeroCuotas: Number(row.numero_cuotas),
      cuotasRestantes: Number(row.cuotas_restantes),
      fechaInicio: this.fechaIso(row.fecha_inicio),
      fechaMaxima: this.fechaIso(row.fecha_maxima),
      proximaCuotaId: row.proxima_cuota_id,
      proximaNumeroCuota:
        row.proxima_numero_cuota !== null &&
        row.proxima_numero_cuota !== undefined
          ? Number(row.proxima_numero_cuota)
          : null,
      proximaFechaPago: row.proxima_fecha_pago
        ? this.fechaIso(row.proxima_fecha_pago)
        : null,
      proximoValorCuota: this.decimalANumero(row.proximo_valor_cuota),
      proximoSaldoCuota: this.decimalANumero(row.proximo_saldo_cuota),
      estadoCobro: row.estado_cobro,
    };
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

  private decimalANumero(value: Prisma.Decimal | null): number {
    if (value === null) {
      return 0;
    }
    return Number(value.toString());
  }

  private fechaUtc(value: Date): Date {
    return new Date(
      Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()),
    );
  }

  private fechaIso(value: Date): string {
    return this.fechaUtc(value).toISOString().slice(0, 10);
  }

  private normalizarTextoOpcional(value?: string | null): string | null {
    if (value === undefined || value === null) {
      return null;
    }
    const normalized = value.trim();
    return normalized.length > 0 ? normalized : null;
  }
}
