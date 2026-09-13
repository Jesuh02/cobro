import {
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  OnModuleInit,
  Optional,
  forwardRef,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Workbook } from 'exceljs';

import { cacheKeyFromCriteria } from '../../common/cache/cache-key';
import { InMemoryCacheService } from '../../common/cache/in-memory-cache.service';
import { DomainError } from '../../common/domain/domain-error';
import { PrismaService } from '../../common/prisma/prisma.service';
import { TenantScopeService } from '../../common/tenancy/tenant-scope.service';
import { AuthenticatedUser } from '../auth/auth.types';
import {
  permisosEmpleadoPorCodigo,
  type PermisoEmpleadoCodigo,
} from '../auth/permissions';
import { ExportacionesService } from '../exportaciones/exportaciones.service';
import {
  ColumnaExportacion,
  ExportacionExcel,
  FilaExportacion,
} from '../exportaciones/exportaciones.types';
import { CreditosService } from '../creditos/creditos.service';
import { PagosService } from '../creditos/pagos.service';
import {
  ActualizarMovimientoCajaDto,
  CrearCajaMenorDto,
  CrearMovimientoCajaDto,
  ExportarMovimientosCajaQueryDto,
  ListarMovimientosCajaQueryDto,
} from './dto';

export type PaginaRespuesta<T> = {
  items: T[];
  limit: number;
  offset: number;
  nextOffset: number | null;
  hasMore: boolean;
};

type UsuarioTblRow = {
  id: string;
  usuario: string;
  nombres: string;
  apellidos: string;
  correo: string;
  telefono: string | null;
};

type UsuarioOrganizacionTblRow = UsuarioTblRow & {
  organizacion_id: string;
};

type CajaMenorCreadaTblRow = {
  id: string;
  nombre: string;
  activa: boolean;
  fecha_apertura: Date;
};

type CajaMovimientoTblRow = {
  caja_menor_id: string;
  caja_menor: string;
  activa: boolean;
  org_id: string;
  sesion_id: string | null;
  fecha_cierre: Date | null;
  usuario_id: string;
  usuario: string;
  nombres: string;
  apellidos: string;
  correo: string;
  telefono: string | null;
};

type MovimientoCajaTblRow = {
  id: string;
  caja_menor_id: string | null;
  caja_menor: string;
  cliente: string | null;
  cliente_identificacion: string | null;
  tipo_codigo: string;
  tipo_nombre: string;
  naturaleza: string;
  usuario_id: string;
  usuario: string;
  nombres: string;
  apellidos: string;
  correo: string;
  telefono: string | null;
  fecha_movimiento: Date;
  monto: Prisma.Decimal;
  motivo: string;
  referencia_tabla: string | null;
  referencia_id: string | null;
  creado_en: Date;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type MovimientoCajaExportado = {
  id: string;
  cajaMenorId: string | null;
  cajaMenor: string;
  cliente: string | null;
  clienteIdentificacion: string | null;
  tipoMovimiento: {
    id: number;
    codigo: string;
    nombre: string;
    naturaleza: string;
  };
  usuario: {
    id: string;
    usuario: string | null;
    nombres: string;
    apellidos: string;
    nombreCompleto: string;
    correo: string;
    telefono: string | null;
  } | null;
  fechaMovimiento: string;
  monto: number;
  montoConNaturaleza: number;
  motivo: string;
  referenciaTabla: string | null;
  referenciaId: string | null;
  creadoEn: string;
};

export type PrismaExecutor = Pick<
  Prisma.TransactionClient,
  '$executeRaw' | '$queryRaw'
>;

export const tiposMovimientoCajaTblBase = [
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

export const codigosMovimientoCajaTblBase = tiposMovimientoCajaTblBase.map(
  (tipo) => tipo.codigo,
);

@Injectable()
export class CajaMenorService implements OnModuleInit {
  private readonly logger = new Logger(CajaMenorService.name);

  async onModuleInit() {
    try {
      await this.sincronizarMovimientosRecaudoTbl();
    } catch (error) {
      this.logger.warn(
        `No se pudo sincronizar recaudos iniciales en tbl: ${(error as Error)?.message}`,
      );
    }
  }

  constructor(
    private readonly prisma: PrismaService,
    private readonly tenantScope: TenantScopeService,
    private readonly cache: InMemoryCacheService,
    private readonly exportaciones: ExportacionesService,
    @Optional()
    @Inject(forwardRef(() => CreditosService))
    private readonly creditosService?: CreditosService,
    @Optional()
    @Inject(forwardRef(() => PagosService))
    private readonly pagosService?: PagosService,
  ) {}

  private usuarioCacheKey(usuario: AuthenticatedUser) {
    return `${usuario.usuarioId}:${usuario.organizacionId ?? 'sin-org'}:${[
      ...usuario.roles,
    ]
      .sort()
      .join(',')}`;
  }

  private invalidarCacheLecturas() {
    this.cache.deleteByPrefix('cobros:');
  }

  private async usarEsquemaTbl(): Promise<boolean> {
    return this.tenantScope.usarEsquemaTbl();
  }

  private async obtenerScopeOrganizacionTbl(
    usuario: AuthenticatedUser,
    executor: PrismaExecutor = this.prisma,
  ) {
    return this.tenantScope.obtenerScopeOrganizacionTbl(usuario, executor);
  }

  private puedeVerDatosOrganizacion(usuario: AuthenticatedUser) {
    return this.tenantScope.puedeVerDatosOrganizacion(usuario);
  }

  private esAdministrador(usuario: AuthenticatedUser) {
    return this.tenantScope.esAdministrador(usuario);
  }

  private asegurarPermiso(
    usuario: AuthenticatedUser,
    permiso: PermisoEmpleadoCodigo,
  ) {
    if (this.esAdministrador(usuario) || usuario.permisos.includes(permiso)) {
      return;
    }

    const nombrePermiso =
      permisosEmpleadoPorCodigo.get(permiso)?.nombre ?? 'esta accion';
    throw new ForbiddenException(
      `No tienes permiso para ${nombrePermiso.toLowerCase()}`,
    );
  }

  private asegurarResponsableCaja(
    responsableUsuarioId: string,
    usuario: AuthenticatedUser,
  ) {
    if (
      this.puedeVerDatosOrganizacion(usuario) ||
      responsableUsuarioId === usuario.usuarioId
    ) {
      return;
    }

    throw new ForbiddenException('No tienes acceso a esta caja menor');
  }

  private esIdPagoCaja(id: string) {
    return id.startsWith('pago-');
  }

  private idPagoDesdeMovimientoCaja(id: string) {
    return id.replace(/^pago-/, '');
  }

  private hayPaginacion(query: { limit?: number; offset?: number }) {
    return query.limit !== undefined || query.offset !== undefined;
  }

  private limitePagina(
    query: { limit?: number },
    predeterminado: number,
    maximo = 100,
  ) {
    return Math.min(Math.max(query.limit ?? predeterminado, 1), maximo);
  }

  private offsetPagina(query: { offset?: number }) {
    return Math.max(query.offset ?? 0, 0);
  }

  private paginaRespuesta<T>(
    rows: T[],
    limit: number,
    offset: number,
  ): PaginaRespuesta<T> {
    const items = rows.slice(0, limit);
    const hasMore = rows.length > limit;

    return {
      items,
      limit,
      offset,
      nextOffset: hasMore ? offset + items.length : null,
      hasMore,
    };
  }

  private fechaUtc(value: Date) {
    return new Date(
      Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()),
    );
  }

  private finDia(value: Date) {
    const next = this.fechaUtc(value);
    next.setUTCHours(23, 59, 59, 999);
    return next;
  }

  private inicioDiaColombia(value: Date) {
    const next = this.fechaUtc(value);
    next.setUTCHours(5, 0, 0, 0);
    return next;
  }

  private finDiaColombia(value: Date) {
    const next = this.inicioDiaColombia(value);
    next.setUTCDate(next.getUTCDate() + 1);
    next.setUTCMilliseconds(next.getUTCMilliseconds() - 1);
    return next;
  }

  private fechaIso(value: Date) {
    return this.fechaUtc(value).toISOString().slice(0, 10);
  }

  private fechaIsoColombia(value: Date) {
    return new Date(value.getTime() - 5 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);
  }

  private parsearFecha(value: string, field: string) {
    const date = new Date(
      value.length === 10 ? `${value}T00:00:00.000Z` : value,
    );

    if (Number.isNaN(date.getTime())) {
      throw DomainError.validation(
        `La fecha ${field} no es valida`,
        'FECHA_INVALIDA',
      );
    }

    return this.fechaUtc(date);
  }

  private parsearFechaMovimiento(
    value: string | undefined,
    field: string,
  ): Date {
    if (!value) {
      return new Date();
    }
    if (value.includes('T') || value.includes(' ')) {
      const date = new Date(value);
      if (!Number.isNaN(date.getTime())) {
        return date;
      }
    }
    if (value.length === 10) {
      const ahora = new Date();
      const fechaHoyColombia = this.fechaIso(ahora);
      if (value === fechaHoyColombia) {
        return ahora;
      }
      const date = new Date(`${value}T12:00:00.000-05:00`);
      if (!Number.isNaN(date.getTime())) {
        return date;
      }
    }
    return this.parsearFecha(value, field);
  }

  private parsearFechaHora(value: string, field: string) {
    const date = new Date(value);

    if (Number.isNaN(date.getTime())) {
      throw DomainError.validation(
        `La fecha ${field} no es valida`,
        'FECHA_INVALIDA',
      );
    }

    return date;
  }

  private decimal(value: number, decimales = 2) {
    return new Prisma.Decimal(value.toFixed(decimales));
  }

  private decimalANumero(value: Prisma.Decimal | null) {
    if (value === null) {
      return 0;
    }

    return Number(value.toString());
  }

  private redondear(value: number, decimales = 2) {
    const factor = 10 ** decimales;
    return Math.round((value + Number.EPSILON) * factor) / factor;
  }

  private normalizarTextoOpcional(value?: string | null) {
    if (value === undefined || value === null) {
      return null;
    }

    const normalized = value.trim();
    return normalized.length > 0 ? normalized : null;
  }

  private requerirTexto(value: string, message: string) {
    const normalized = this.normalizarTextoOpcional(value);
    if (!normalized) {
      throw DomainError.validation(message, 'CAMPO_REQUERIDO');
    }

    return normalized;
  }

  private naturalezaMovimientoCaja(tipo: {
    codigo: string;
    naturaleza: string;
  }) {
    if (
      ['GASTO', 'DESEMBOLSO_CREDITO', 'AJUSTE_SALIDA'].includes(tipo.codigo)
    ) {
      return 'S';
    }

    if (tipo.codigo === 'CIERRE') {
      return 'N';
    }

    if (['APERTURA', 'RECAUDO', 'AJUSTE_ENTRADA'].includes(tipo.codigo)) {
      return 'E';
    }

    return tipo.naturaleza;
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

  private formatearMovimientoCajaTbl(movimiento: MovimientoCajaTblRow) {
    const monto = this.decimalANumero(movimiento.monto);

    return {
      id: movimiento.id,
      cajaMenorId: movimiento.caja_menor_id,
      cajaMenor: movimiento.caja_menor,
      cliente: movimiento.cliente,
      clienteIdentificacion: movimiento.cliente_identificacion,
      tipoMovimiento: {
        id: 0,
        codigo: movimiento.tipo_codigo,
        nombre: movimiento.tipo_nombre,
        naturaleza: movimiento.naturaleza,
      },
      usuario: this.formatearUsuarioTbl({
        id: movimiento.usuario_id,
        usuario: movimiento.usuario,
        nombres: movimiento.nombres,
        apellidos: movimiento.apellidos,
        correo: movimiento.correo,
        telefono: movimiento.telefono,
      }),
      fechaMovimiento: this.fechaIsoColombia(movimiento.fecha_movimiento),
      monto,
      montoConNaturaleza:
        movimiento.naturaleza === 'S'
          ? -monto
          : movimiento.naturaleza === 'N'
            ? 0
            : monto,
      motivo: movimiento.motivo,
      referenciaTabla: movimiento.referencia_tabla,
      referenciaId: movimiento.referencia_id,
      creadoEn: movimiento.creado_en.toISOString(),
    };
  }

  private async obtenerMovimientoCajaTblPorId(
    tx: PrismaExecutor,
    movimientoId: string,
    motivo: string,
  ) {
    const idLimpio = movimientoId.startsWith('mov-')
      ? movimientoId.slice(4)
      : movimientoId;

    const rows = await tx.$queryRaw<MovimientoCajaTblRow[]>(Prisma.sql`
      SELECT
        CONCAT('mov-', m.id_mca::text) AS id,
        c.id_caj::text AS caja_menor_id,
        COALESCE(c.caj_nombre, o.org_nombre) AS caja_menor,
        COALESCE(pago_cli.cliente, cre_cli.cliente) AS cliente,
        COALESCE(pago_cli.documento, cre_cli.documento) AS cliente_identificacion,
        UPPER(m.mca_tipo::text) AS tipo_codigo,
        INITCAP(REPLACE(m.mca_tipo::text, '_', ' ')) AS tipo_nombre,
        CASE
          WHEN UPPER(m.mca_tipo::text) IN ('SALIDA', 'EGRESO', 'GASTO', 'DESEMBOLSO', 'DESEMBOLSO_CREDITO', 'AJUSTE_SALIDA') THEN 'S'
          WHEN UPPER(m.mca_tipo::text) = 'CIERRE' THEN 'N'
          ELSE 'E'
        END AS naturaleza,
        tu.id_usu::text AS usuario_id,
        tu.usu_usuario AS usuario,
        p.per_primer_nombre AS nombres,
        p.per_apellido AS apellidos,
        COALESCE(p.per_email, '') AS correo,
        p.per_num_celular AS telefono,
        m.mca_creacion AS fecha_movimiento,
        m.mca_monto AS monto,
        COALESCE(${motivo}, CASE
          WHEN UPPER(m.mca_tipo::text) = 'RECAUDO' AND pago_cli.cliente IS NOT NULL
            THEN CONCAT('Pago del usuario ', pago_cli.cliente)
          WHEN UPPER(m.mca_tipo::text) = 'DESEMBOLSO_CREDITO'
            THEN 'Desembolso Credito'
          ELSE COALESCE(m.mca_referencia_tipo::text, INITCAP(REPLACE(m.mca_tipo::text, '_', ' ')))
        END) AS motivo,
        m.mca_referencia_tipo::text AS referencia_tabla,
        m.mca_referencia_id::text AS referencia_id,
        m.mca_creacion AS creado_en
      FROM public.tbl_movimientos_cajas m
      JOIN public.tbl_organizaciones o ON o.id_org = m.org_id
      JOIN public.tbl_usuarios tu ON tu.id_usu = m.usu_id
      JOIN public.tbl_personas p ON p.id_per = tu.persona_id
      LEFT JOIN public.tbl_sesiones_cajas sc ON sc.id_sca = m.sca_id
      LEFT JOIN public.tbl_cajas c ON c.id_caj = sc.caj_id
      LEFT JOIN LATERAL (
        SELECT
          TRIM(CONCAT_WS(' ', per.per_primer_nombre, per.per_apellido)) AS cliente,
          per.per_documento AS documento
        FROM public.tbl_cuotas_pagos cp
        JOIN public.tbl_cuotas cu ON cu.id_cuo = cp.cuo_id
        JOIN public.tbl_creditos cr ON cr.id_cre = cu.cre_id
        JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
        JOIN public.tbl_personas per ON per.id_per = cl.cli_persona
        WHERE cp.pagos_id = m.mca_referencia_id
        LIMIT 1
      ) pago_cli ON m.mca_referencia_tipo::text = 'PAGO'
      LEFT JOIN LATERAL (
        SELECT
          TRIM(CONCAT_WS(' ', per.per_primer_nombre, per.per_apellido)) AS cliente,
          per.per_documento AS documento
        FROM public.tbl_creditos cr
        JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
        JOIN public.tbl_personas per ON per.id_per = cl.cli_persona
        WHERE cr.id_cre = m.mca_referencia_id
        LIMIT 1
      ) cre_cli ON m.mca_referencia_tipo::text = 'CREDITO'
      WHERE m.id_mca = ${idLimpio}::uuid
      LIMIT 1
    `);

    const movimiento = rows[0];
    if (!movimiento) {
      throw DomainError.notFound(
        'Movimiento de caja menor no encontrado',
        'MOVIMIENTO_CAJA_NO_ENCONTRADO',
      );
    }

    return movimiento;
  }

  async crearCajaMenor(dto: CrearCajaMenorDto, usuario: AuthenticatedUser) {
    this.asegurarPermiso(usuario, 'CREAR_CAJA_MENOR');
    return this.crearCajaMenorTbl(dto, usuario);
  }

  private async crearCajaMenorTbl(
    dto: CrearCajaMenorDto,
    usuario: AuthenticatedUser,
  ) {
    const nombre = this.requerirTexto(
      dto.nombre,
      'El nombre de la caja menor es obligatorio',
    );
    const monedaCodigo = (dto.monedaCodigo ?? 'COP').trim().toUpperCase();
    const fechaApertura = dto.fechaApertura
      ? this.parsearFechaHora(dto.fechaApertura, 'fechaApertura')
      : new Date();
    const fechaCierre = dto.fechaCierre
      ? this.parsearFechaHora(dto.fechaCierre, 'fechaCierre')
      : null;

    if (fechaCierre && fechaCierre <= fechaApertura) {
      throw DomainError.validation(
        'La fecha de cierre debe ser posterior a la fecha de apertura',
        'CAJA_MENOR_FECHA_CIERRE_INVALIDA',
      );
    }

    const caja = await this.prisma.$transaction(async (tx) => {
      const scope = await this.obtenerScopeOrganizacionTbl(usuario, tx);
      const requestedResponsableId =
        dto.responsableUsuarioId?.trim() || dto.usuarioResponsableId?.trim();
      const targetUsuarioId =
        this.esAdministrador(usuario) && requestedResponsableId
          ? requestedResponsableId
          : scope.usuarioId;

      const [responsable] = await tx.$queryRaw<UsuarioOrganizacionTblRow[]>(
        Prisma.sql`
          SELECT
            tu.id_usu::text AS id,
            tu.usu_usuario AS usuario,
            p.per_primer_nombre AS nombres,
            p.per_apellido AS apellidos,
            COALESCE(p.per_email, '') AS correo,
            p.per_num_celular AS telefono,
            uo.org_id::text AS organizacion_id
          FROM public.tbl_usuarios tu
          JOIN public.tbl_personas p ON p.id_per = tu.persona_id
          JOIN public.tbl_usuarios_organizaciones uo ON uo.usu_id = tu.id_usu
          WHERE tu.id_usu = ${targetUsuarioId}::uuid
            AND tu.usu_activo
            AND uo.urg_activo
            AND uo.org_id = ${scope.organizacionId}::uuid
          ORDER BY uo.id_urg ASC
          LIMIT 1
        `,
      );

      if (!responsable) {
        throw DomainError.notFound(
          'Responsable no encontrado',
          'RESPONSABLE_NO_ENCONTRADO',
        );
      }

      const [moneda] = await tx.$queryRaw<
        Array<{ id: string; codigo: string }>
      >(
        Prisma.sql`
          SELECT
            id_mon::text AS id,
            mon_codigo::text AS codigo
          FROM public.tbl_monedas
          WHERE mon_activa
            AND (
              UPPER(TRIM(mon_codigo::text)) = ${monedaCodigo}
              OR UPPER(TRIM(mon_codigo::text)) = LEFT(${monedaCodigo}, 1)
            )
          ORDER BY
            CASE WHEN UPPER(TRIM(mon_codigo::text)) = ${monedaCodigo} THEN 0 ELSE 1 END,
            id_mon ASC
          LIMIT 1
        `,
      );

      if (!moneda) {
        throw DomainError.notFound(
          'Moneda no encontrada',
          'MONEDA_NO_ENCONTRADA',
        );
      }

      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_sesiones_cajas
        SET sca_estado = 'CERRADA'
        WHERE sca_estado = 'ABIERTA'
          AND sca_fecha_cierre IS NOT NULL
          AND sca_fecha_cierre <= now()
      `);

      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_cajas c
        SET caj_activa = FALSE
        WHERE c.caj_tipo::text = 'MENOR'
          AND c.caj_activa
          AND NOT EXISTS (
            SELECT 1
            FROM public.tbl_sesiones_cajas sc
            WHERE sc.caj_id = c.id_caj
              AND sc.sca_estado::text = 'ABIERTA'
              AND (sc.sca_fecha_cierre IS NULL OR sc.sca_fecha_cierre > now())
          )
      `);

      const [cajaAbierta] = await tx.$queryRaw<
        Array<{ id: string; nombre: string; fecha_cierre: Date | null }>
      >(Prisma.sql`
        SELECT
          c.id_caj::text AS id,
          c.caj_nombre AS nombre,
          sc.sca_fecha_cierre AS fecha_cierre
        FROM public.tbl_cajas c
        JOIN public.tbl_sesiones_cajas sc ON sc.caj_id = c.id_caj
        WHERE c.org_id = ${responsable.organizacion_id}::uuid
          AND c.caj_tipo::text = 'MENOR'
          AND c.caj_activa
          AND sc.usu_id = ${responsable.id}::uuid
          AND sc.sca_estado::text = 'ABIERTA'
          AND (sc.sca_fecha_cierre IS NULL OR sc.sca_fecha_cierre > now())
        ORDER BY sc.sca_fecha_apertura DESC, sc.id_sca DESC
        LIMIT 1
      `);

      if (cajaAbierta) {
        const detalleFecha = cajaAbierta.fecha_cierre
          ? ` vigente hasta el ${new Date(cajaAbierta.fecha_cierre).toLocaleString('es-CO')}`
          : '';
        throw DomainError.conflict(
          `El usuario ${responsable.nombres} ${responsable.apellidos} ya tiene una caja menor abierta (${cajaAbierta.nombre})${detalleFecha}. Debe cerrarse antes de crear una nueva`,
          'CAJA_MENOR_ABIERTA_EXISTENTE',
        );
      }

      const [existente] = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        SELECT id_caj::text AS id
        FROM public.tbl_cajas
        WHERE org_id = ${responsable.organizacion_id}::uuid
          AND caj_tipo::text = 'MENOR'
          AND UPPER(TRIM(caj_nombre)) = UPPER(${nombre})
        LIMIT 1
      `);

      if (existente) {
        throw DomainError.conflict(
          'El responsable ya tiene una caja menor con ese nombre',
          'CAJA_MENOR_DUPLICADA',
        );
      }

      const [cajaCreada] = await tx.$queryRaw<CajaMenorCreadaTblRow[]>(
        Prisma.sql`
          INSERT INTO public.tbl_cajas (
            caj_nombre,
            caj_activa,
            caj_creacion,
            org_id,
            mon_id
          )
          VALUES (
            ${nombre},
            TRUE,
            ${fechaApertura},
            ${responsable.organizacion_id}::uuid,
            ${moneda.id}::uuid
          )
          RETURNING
            id_caj::text AS id,
            caj_nombre AS nombre,
            caj_activa AS activa,
            caj_creacion AS fecha_apertura
        `,
      );

      await tx.$executeRaw(Prisma.sql`
        INSERT INTO public.tbl_sesiones_cajas (
          sca_fecha_apertura,
          sca_fecha_cierre,
          sca_monto_inicial,
          caj_id,
          usu_id
        )
        VALUES (
          ${fechaApertura},
          ${fechaCierre},
          0,
          ${cajaCreada.id}::uuid,
          ${responsable.id}::uuid
        )
      `);

      return {
        caja: cajaCreada,
        responsable,
      };
    });

    this.invalidarCacheLecturas();
    return {
      id: caja.caja.id,
      nombre: caja.caja.nombre,
      activa: caja.caja.activa,
      monedaCodigo,
      fechaApertura: caja.caja.fecha_apertura.toISOString(),
      fechaCierre: fechaCierre?.toISOString() ?? null,
      responsable: this.formatearUsuarioTbl(caja.responsable),
    };
  }

  async cerrarCajaMenor(id: string, usuario: AuthenticatedUser) {
    this.asegurarPermiso(usuario, 'CREAR_CAJA_MENOR');
    return this.cerrarCajaMenorTbl(id, usuario);
  }

  private async cerrarCajaMenorTbl(id: string, usuario: AuthenticatedUser) {
    const ahora = new Date();
    const caja = await this.prisma.$transaction(async (tx) => {
      const scope = await this.obtenerScopeOrganizacionTbl(usuario, tx);
      const puedeVerTodo = this.puedeVerDatosOrganizacion(usuario);

      const [cajaRow] = await tx.$queryRaw<
        Array<{
          id: string;
          nombre: string;
          activa: boolean;
          usuario_id: string;
        }>
      >(Prisma.sql`
        SELECT
          c.id_caj::text AS id,
          c.caj_nombre AS nombre,
          c.caj_activa AS activa,
          COALESCE(
            (
              SELECT sc.usu_id::text
              FROM public.tbl_sesiones_cajas sc
              WHERE sc.caj_id = c.id_caj
              ORDER BY (sc.sca_estado::text = 'ABIERTA') DESC, sc.sca_fecha_apertura DESC, sc.id_sca DESC
              LIMIT 1
            ),
            ''
          ) AS usuario_id
        FROM public.tbl_cajas c
        WHERE c.id_caj = ${id}::uuid
          AND c.org_id = ${scope.organizacionId}::uuid
          AND c.caj_tipo::text = 'MENOR'
        LIMIT 1
      `);

      if (!cajaRow) {
        throw DomainError.notFound(
          'Caja menor no encontrada',
          'CAJA_MENOR_NO_ENCONTRADA',
        );
      }

      if (!puedeVerTodo && cajaRow.usuario_id !== scope.usuarioId) {
        throw new ForbiddenException(
          'No tienes permiso para cerrar esta caja menor',
        );
      }

      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_sesiones_cajas
        SET sca_estado = 'CERRADA',
            sca_fecha_cierre = ${ahora}
        WHERE caj_id = ${id}::uuid
          AND sca_estado = 'ABIERTA'
      `);

      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_cajas
        SET caj_activa = FALSE
        WHERE id_caj = ${id}::uuid
      `);

      return cajaRow;
    });

    this.invalidarCacheLecturas();
    return {
      id: caja.id,
      nombre: caja.nombre,
      activa: false,
      fechaCierre: ahora.toISOString(),
      mensaje: 'Caja menor cerrada exitosamente',
    };
  }

  async listarMovimientosCaja(
    query: ListarMovimientosCajaQueryDto,
    usuario: AuthenticatedUser,
  ) {
    const paginado = this.hayPaginacion(query);
    const limit = this.limitePagina(query, paginado ? 40 : 100);
    const offset = paginado ? this.offsetPagina(query) : 0;
    const cacheKey = `cobros:${this.usuarioCacheKey(
      usuario,
    )}:caja-menor:${cacheKeyFromCriteria({
      cajaMenorId: query.cajaMenorId,
      fechaDesde: query.fechaDesde,
      fechaHasta: query.fechaHasta,
      limit,
      offset,
      search: query.search,
      tipo: query.tipo,
    })}`;

    return this.cache.remember(
      cacheKey,
      async () => {
        const rows = await this.listarMovimientosCajaSinCache(
          query,
          usuario,
          paginado ? limit + 1 : limit,
          offset,
          paginado,
        );

        const pageRows: unknown[] = [...rows];
        return paginado ? this.paginaRespuesta(pageRows, limit, offset) : rows;
      },
      { ttlMs: 12_000 },
    );
  }

  private async listarMovimientosCajaSinCache(
    query: ListarMovimientosCajaQueryDto,
    usuario: AuthenticatedUser,
    limit: number,
    offset: number,
    _paginado?: boolean,
  ) {
    return this.listarMovimientosCajaTbl(query, usuario, limit, offset);
  }

  private async listarMovimientosCajaTbl(
    query: ListarMovimientosCajaQueryDto,
    usuario: AuthenticatedUser,
    limit = 100,
    offset = 0,
  ) {
    const scope = await this.obtenerScopeOrganizacionTbl(usuario);
    const search = this.normalizarTextoOpcional(query.search);
    const conditions: Prisma.Sql[] = [
      Prisma.sql`org_id = ${scope.organizacionId}`,
    ];

    if (query.cajaMenorId) {
      conditions.push(Prisma.sql`caja_menor_id = ${query.cajaMenorId}`);
    }

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      conditions.push(Prisma.sql`usuario_id = ${scope.usuarioId}`);
    }

    if (search) {
      const pattern = `%${search}%`;
      conditions.push(Prisma.sql`(
        caja_menor ILIKE ${pattern}
        OR cliente ILIKE ${pattern}
        OR cliente_identificacion ILIKE ${pattern}
        OR tipo_nombre ILIKE ${pattern}
        OR motivo ILIKE ${pattern}
      )`);
    }

    if (query.tipo === 'entradas') {
      conditions.push(Prisma.sql`naturaleza = 'E'`);
    } else if (query.tipo === 'salidas') {
      conditions.push(Prisma.sql`naturaleza = 'S'`);
    }

    if (query.fechaDesde) {
      const fechaDesde = this.inicioDiaColombia(
        this.parsearFecha(query.fechaDesde, 'fechaDesde'),
      );
      conditions.push(Prisma.sql`fecha_movimiento >= ${fechaDesde}`);
    }

    if (query.fechaHasta) {
      const fechaHasta = this.finDiaColombia(
        this.parsearFecha(query.fechaHasta, 'fechaHasta'),
      );
      conditions.push(Prisma.sql`fecha_movimiento <= ${fechaHasta}`);
    }

    const where =
      conditions.length > 0
        ? Prisma.sql`WHERE ${Prisma.join(conditions, ' AND ')}`
        : Prisma.empty;
    const rows = await this.prisma.$queryRaw<MovimientoCajaTblRow[]>(Prisma.sql`
      WITH base AS (
        SELECT
          CONCAT('mov-', m.id_mca::text) AS id,
          m.org_id::text AS org_id,
          c.id_caj::text AS caja_menor_id,
          COALESCE(c.caj_nombre, o.org_nombre) AS caja_menor,
          COALESCE(pago_cli.cliente, cre_cli.cliente) AS cliente,
          COALESCE(pago_cli.documento, cre_cli.documento) AS cliente_identificacion,
          UPPER(m.mca_tipo::text) AS tipo_codigo,
          INITCAP(REPLACE(m.mca_tipo::text, '_', ' ')) AS tipo_nombre,
          CASE
            WHEN UPPER(m.mca_tipo::text) IN ('SALIDA', 'EGRESO', 'GASTO', 'DESEMBOLSO', 'DESEMBOLSO_CREDITO', 'AJUSTE_SALIDA') THEN 'S'
            WHEN UPPER(m.mca_tipo::text) = 'CIERRE' THEN 'N'
            ELSE 'E'
          END AS naturaleza,
          tu.id_usu::text AS usuario_id,
          tu.usu_usuario AS usuario,
          p.per_primer_nombre AS nombres,
          p.per_apellido AS apellidos,
          COALESCE(p.per_email, '') AS correo,
          p.per_num_celular AS telefono,
          m.mca_creacion AS fecha_movimiento,
          m.mca_monto AS monto,
          CASE
            WHEN UPPER(m.mca_tipo::text) = 'RECAUDO' AND pago_cli.cliente IS NOT NULL
              THEN CONCAT('Pago del usuario ', pago_cli.cliente)
            WHEN UPPER(m.mca_tipo::text) = 'DESEMBOLSO_CREDITO'
              THEN 'Desembolso Credito'
            ELSE COALESCE(m.mca_referencia_tipo::text, INITCAP(REPLACE(m.mca_tipo::text, '_', ' ')))
          END AS motivo,
          m.mca_referencia_tipo::text AS referencia_tabla,
          m.mca_referencia_id::text AS referencia_id,
          m.mca_creacion AS creado_en
        FROM public.tbl_movimientos_cajas m
        JOIN public.tbl_organizaciones o ON o.id_org = m.org_id
        JOIN public.tbl_usuarios tu ON tu.id_usu = m.usu_id
        JOIN public.tbl_personas p ON p.id_per = tu.persona_id
        LEFT JOIN public.tbl_sesiones_cajas sc ON sc.id_sca = m.sca_id
        LEFT JOIN public.tbl_cajas c ON c.id_caj = sc.caj_id
        LEFT JOIN LATERAL (
          SELECT
            TRIM(CONCAT_WS(' ', per.per_primer_nombre, per.per_apellido)) AS cliente,
            per.per_documento AS documento
          FROM public.tbl_cuotas_pagos cp
          JOIN public.tbl_cuotas cu ON cu.id_cuo = cp.cuo_id
          JOIN public.tbl_creditos cr ON cr.id_cre = cu.cre_id
          JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
          JOIN public.tbl_personas per ON per.id_per = cl.cli_persona
          WHERE cp.pagos_id = m.mca_referencia_id
          LIMIT 1
        ) pago_cli ON m.mca_referencia_tipo::text = 'PAGO'
        LEFT JOIN LATERAL (
          SELECT
            TRIM(CONCAT_WS(' ', per.per_primer_nombre, per.per_apellido)) AS cliente,
            per.per_documento AS documento
          FROM public.tbl_creditos cr
          JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
          JOIN public.tbl_personas per ON per.id_per = cl.cli_persona
          WHERE cr.id_cre = m.mca_referencia_id
          LIMIT 1
        ) cre_cli ON m.mca_referencia_tipo::text = 'CREDITO'
        UNION ALL
        SELECT
          CONCAT('pago-', pa.id_pag::text),
          cl.org_id::text,
          c.id_caj::text,
          COALESCE(c.caj_nombre, r.rut_nombre, o.org_nombre),
          TRIM(CONCAT_WS(' ', per.per_primer_nombre, per.per_apellido)),
          per.per_documento,
          'RECAUDO',
          'Recaudo',
          'E',
          tu.id_usu::text,
          tu.usu_usuario,
          up.per_primer_nombre,
          up.per_apellido,
          COALESCE(up.per_email, ''),
          up.per_num_celular,
          pa.pag_fecha,
          pa.pag_monto,
          CONCAT('Pago del usuario ', TRIM(CONCAT_WS(' ', per.per_primer_nombre, per.per_apellido))),
          'pago',
          pa.id_pag::text,
          pa.pag_fecha
        FROM (
          SELECT DISTINCT ON (pa.id_pag)
            pa.id_pag,
            pa.pag_fecha,
            pa.pag_monto,
            cu.cre_id AS credito_id
          FROM public.tbl_pagos pa
          JOIN public.tbl_cuotas_pagos cp ON cp.pagos_id = pa.id_pag
          JOIN public.tbl_cuotas cu ON cu.id_cuo = cp.cuo_id
          WHERE NOT EXISTS (
            SELECT 1
            FROM public.tbl_movimientos_cajas mc
            WHERE mc.mca_referencia_tipo::text = 'PAGO'
              AND mc.mca_referencia_id = pa.id_pag
          )
          ORDER BY pa.id_pag, cu.cre_id
        ) pa
        JOIN public.tbl_creditos cr ON cr.id_cre = pa.credito_id
        JOIN public.tbl_usuarios tu ON tu.id_usu = cr.usu_id
        JOIN public.tbl_personas up ON up.id_per = tu.persona_id
        JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
        JOIN public.tbl_personas per ON per.id_per = cl.cli_persona
        JOIN public.tbl_organizaciones o ON o.id_org = cl.org_id
        LEFT JOIN LATERAL (
          SELECT r.id_rut, r.rut_nombre
          FROM public.tbl_rutas_clientes rc
          JOIN public.tbl_rutas r ON r.id_rut = rc.rut_id
          WHERE rc.cli_id = cl.id_cli
            AND r.org_id = cl.org_id
          ORDER BY (r.usu_id = cr.usu_id) DESC, r.rut_activa DESC
          LIMIT 1
        ) r ON TRUE
        LEFT JOIN LATERAL (
          SELECT c.id_caj, c.caj_nombre
          FROM public.tbl_cajas c
          WHERE c.org_id = cl.org_id
            AND c.caj_tipo::text = 'MENOR'
          ORDER BY c.caj_activa DESC, c.id_caj ASC
          LIMIT 1
        ) c ON TRUE
        UNION ALL
        SELECT
          CONCAT('gasto-', g.id_gas::text),
          c.org_id::text,
          c.id_caj::text,
          c.caj_nombre,
          NULL::text,
          NULL::text,
          'GASTO',
          cg.cga_nombre,
          'S',
          tu.id_usu::text,
          tu.usu_usuario,
          p.per_primer_nombre,
          p.per_apellido,
          COALESCE(p.per_email, ''),
          p.per_num_celular,
          g.gas_fecha,
          g.gas_monto,
          cg.cga_nombre,
          'gasto',
          g.id_gas::text,
          g.gas_fecha
        FROM public.tbl_gastos g
        JOIN public.tbl_cajas c ON c.id_caj = g.caj_id
        JOIN public.tbl_categorias_gastos cg ON cg.id_cga = g.cga_id
        JOIN public.tbl_usuarios tu ON tu.id_usu = g.usu_id
        JOIN public.tbl_personas p ON p.id_per = tu.persona_id
      )
      SELECT *
      FROM base
      ${where}
      ORDER BY creado_en DESC
      LIMIT ${limit}
      ${offset > 0 ? Prisma.sql`OFFSET ${offset}` : Prisma.empty}
    `);

    return rows.map((movimiento) =>
      this.formatearMovimientoCajaTbl(movimiento),
    );
  }

  async exportarMovimientosCaja(
    query: ExportarMovimientosCajaQueryDto,
    usuario: AuthenticatedUser,
  ): Promise<ExportacionExcel> {
    const movimientos = (await this.listarMovimientosCaja(
      query,
      usuario,
    )) as MovimientoCajaExportado[];
    const fechaDesde = query.fechaDesde
      ? this.parsearFecha(query.fechaDesde, 'fechaDesde')
      : null;
    const fechaHasta = query.fechaHasta
      ? this.finDia(this.parsearFecha(query.fechaHasta, 'fechaHasta'))
      : null;
    const tipo = query.tipo ?? 'todos';
    const filtrados = movimientos.filter((movimiento) => {
      const naturaleza = movimiento.tipoMovimiento.naturaleza.toUpperCase();
      const fechaMovimiento = this.parsearFecha(
        movimiento.fechaMovimiento,
        'fechaMovimiento',
      );

      if (tipo === 'entradas' && naturaleza !== 'E') {
        return false;
      }

      if (tipo === 'salidas' && naturaleza !== 'S') {
        return false;
      }

      if (fechaDesde && fechaMovimiento < fechaDesde) {
        return false;
      }

      if (fechaHasta && fechaMovimiento > fechaHasta) {
        return false;
      }

      return true;
    });

    this.exportaciones.asegurarTamanoExportacion(filtrados.length);

    const workbook = new Workbook();
    workbook.creator = 'Cobro';
    workbook.created = new Date();

    const sheet = workbook.addWorksheet('Caja menor');
    const columnas: ColumnaExportacion[] = [
      { header: 'Fecha', key: 'fechaMovimiento', width: 14 },
      { header: 'Caja menor', key: 'cajaMenor', width: 24 },
      { header: 'Cliente', key: 'cliente', width: 30 },
      { header: 'Identificacion', key: 'clienteIdentificacion', width: 20 },
      { header: 'Tipo', key: 'tipo', width: 20 },
      { header: 'Naturaleza', key: 'naturaleza', width: 12 },
      { header: 'Monto', key: 'monto', width: 16 },
      { header: 'Motivo', key: 'motivo', width: 40 },
      { header: 'Usuario', key: 'usuario', width: 28 },
      { header: 'Referencia', key: 'referencia', width: 18 },
      { header: 'Creado en', key: 'creadoEn', width: 24 },
    ];
    sheet.columns = columnas;
    const filasExcel: FilaExportacion[] = filtrados.map((movimiento) => ({
      fechaMovimiento: movimiento.fechaMovimiento,
      cajaMenor: movimiento.cajaMenor,
      cliente: movimiento.cliente ?? '',
      clienteIdentificacion: movimiento.clienteIdentificacion ?? '',
      tipo: movimiento.tipoMovimiento.nombre,
      naturaleza:
        movimiento.tipoMovimiento.naturaleza === 'S' ? 'Salida' : 'Entrada',
      monto: movimiento.monto,
      motivo: movimiento.motivo,
      usuario: movimiento.usuario?.nombreCompleto ?? '',
      referencia: movimiento.referenciaTabla ?? '',
      creadoEn: movimiento.creadoEn,
    }));
    sheet.addRows(filasExcel);

    this.exportaciones.formatearHojaExportacion(sheet, ['monto']);

    return this.exportaciones.subirWorkbookExportacion({
      workbook,
      carpeta: 'caja-menor',
      nombreBase: 'caja-menor',
      filas: filtrados.length,
      vistaPrevia: this.exportaciones.crearVistaPreviaExportacion(
        columnas,
        filasExcel,
      ),
    });
  }

  async crearMovimientoCaja(
    dto: CrearMovimientoCajaDto,
    usuario: AuthenticatedUser,
  ) {
    this.asegurarPermiso(usuario, 'REGISTRAR_FLUJO_CAJA');

    const fechaMovimiento = this.parsearFechaMovimiento(
      dto.fechaMovimiento,
      'fechaMovimiento',
    );
    const monto = this.redondear(dto.monto);

    return this.crearMovimientoCajaTbl(dto, usuario, fechaMovimiento, monto);
  }

  private async crearMovimientoCajaTbl(
    dto: CrearMovimientoCajaDto,
    usuario: AuthenticatedUser,
    fechaMovimiento: Date,
    monto: number,
  ) {
    const tipoMovimientoCodigo = this.requerirTexto(
      dto.tipoMovimientoCodigo,
      'El tipo de movimiento es obligatorio',
    ).toUpperCase();
    const tipo = tiposMovimientoCajaTblBase.find(
      (item) => item.codigo === tipoMovimientoCodigo,
    );

    if (!tipo) {
      throw DomainError.notFound(
        'Tipo de movimiento de caja no encontrado',
        'TIPO_MOVIMIENTO_CAJA_NO_EXISTE',
      );
    }

    const motivo = this.requerirTexto(
      dto.motivo,
      'El motivo del movimiento es obligatorio',
    );
    const movimiento = await this.prisma.$transaction(async (tx) => {
      const scope = await this.obtenerScopeOrganizacionTbl(usuario, tx);
      const [caja] = await tx.$queryRaw<CajaMovimientoTblRow[]>(Prisma.sql`
        SELECT
          c.id_caj::text AS caja_menor_id,
          c.caj_nombre AS caja_menor,
          c.caj_activa AS activa,
          c.org_id::text AS org_id,
          sc.id_sca::text AS sesion_id,
          sc.sca_fecha_cierre AS fecha_cierre,
          tu.id_usu::text AS usuario_id,
          tu.usu_usuario AS usuario,
          p.per_primer_nombre AS nombres,
          p.per_apellido AS apellidos,
          COALESCE(p.per_email, '') AS correo,
          p.per_num_celular AS telefono
        FROM public.tbl_cajas c
        JOIN public.tbl_usuarios_organizaciones uo
          ON uo.org_id = c.org_id
        JOIN public.tbl_usuarios tu ON tu.id_usu = uo.usu_id
        JOIN public.tbl_personas p ON p.id_per = tu.persona_id
        LEFT JOIN LATERAL (
          SELECT
            sca.id_sca,
            sca.sca_fecha_cierre
          FROM public.tbl_sesiones_cajas sca
          WHERE sca.caj_id = c.id_caj
            AND sca.sca_estado::text = 'ABIERTA'
          ORDER BY sca.sca_fecha_apertura DESC, sca.id_sca DESC
          LIMIT 1
        ) sc ON TRUE
        WHERE c.id_caj::text = ${dto.cajaMenorId}
          AND c.org_id = ${scope.organizacionId}::uuid
          AND c.caj_tipo::text = 'MENOR'
          AND uo.urg_activo
          AND tu.usu_activo
          AND tu.id_usu = ${scope.usuarioId}::uuid
        LIMIT 1
      `);

      if (!caja) {
        throw DomainError.notFound(
          'Caja menor no encontrada',
          'CAJA_MENOR_NO_ENCONTRADA',
        );
      }

      if (!caja.activa) {
        throw DomainError.conflict(
          'La caja menor no esta activa',
          'CAJA_MENOR_INACTIVA',
        );
      }

      if (
        !caja.sesion_id ||
        (caja.fecha_cierre && caja.fecha_cierre <= new Date())
      ) {
        throw DomainError.conflict(
          'La caja menor esta cerrada o su horario de apertura ha finalizado',
          'CAJA_MENOR_CERRADA',
        );
      }

      const sesionId = caja.sesion_id;

      if (!sesionId) {
        throw DomainError.conflict(
          'No se pudo abrir la sesion de caja menor',
          'SESION_CAJA_NO_CREADA',
        );
      }

      const [creado] = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        INSERT INTO public.tbl_movimientos_cajas (
          mca_tipo,
          mca_monto,
          mca_referencia_tipo,
          mca_creacion,
          org_id,
          usu_id,
          sca_id
        )
        VALUES (
          ${tipo.codigo}::public.movimiento_caja_tipo_enum,
          ${this.decimal(monto)},
          NULL::public.movimiento_referencia_tipo_enum,
          ${fechaMovimiento},
          ${caja.org_id}::uuid,
          ${caja.usuario_id}::uuid,
          ${sesionId}::uuid
        )
        RETURNING id_mca::text AS id
      `);

      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_sesiones_cajas
        SET
          sca_total_cobrado = sca_total_cobrado + ${
            tipo.naturaleza === 'E' ? this.decimal(monto) : 0
          },
          sca_total_gasto = sca_total_gasto + ${
            tipo.naturaleza === 'S' ? this.decimal(monto) : 0
          }
        WHERE id_sca = ${sesionId}::uuid
      `);

      return this.obtenerMovimientoCajaTblPorId(tx, creado.id, motivo);
    });

    this.invalidarCacheLecturas();
    return this.formatearMovimientoCajaTbl(movimiento);
  }

  async actualizarMovimientoCaja(
    id: string,
    dto: ActualizarMovimientoCajaDto,
    usuario: AuthenticatedUser,
  ) {
    this.asegurarPermiso(usuario, 'MODIFICAR_MOVIMIENTOS');

    if (this.esIdPagoCaja(id)) {
      throw DomainError.conflict(
        'No se pueden modificar pagos desde caja menor. Utilice el modulo de creditos/pagos.',
        'PAGO_MODIFICACION_NO_DISPONIBLE',
      );
    }

    return this.actualizarMovimientoCajaTbl(id, dto, usuario);
  }

  private async actualizarMovimientoCajaTbl(
    id: string,
    dto: ActualizarMovimientoCajaDto,
    usuario: AuthenticatedUser,
  ) {
    const idLimpio = id.startsWith('mov-') ? id.slice(4) : id;
    if (!uuidPattern.test(idLimpio)) {
      throw DomainError.validation(
        'El ID del movimiento no es valido',
        'ID_MOVIMIENTO_INVALIDO',
      );
    }

    const tipoMovimientoCodigo = this.requerirTexto(
      dto.tipoMovimientoCodigo,
      'El tipo de movimiento es obligatorio',
    ).toUpperCase();
    const tipo = tiposMovimientoCajaTblBase.find(
      (item) => item.codigo === tipoMovimientoCodigo,
    );

    if (!tipo) {
      throw DomainError.notFound(
        'Tipo de movimiento de caja no encontrado',
        'TIPO_MOVIMIENTO_CAJA_NO_EXISTE',
      );
    }

    if (
      ['APERTURA', 'CIERRE', 'RECAUDO', 'DESEMBOLSO_CREDITO'].includes(
        tipo.codigo,
      )
    ) {
      throw DomainError.conflict(
        'No se puede cambiar el movimiento a este tipo reservado',
        'TIPO_MOVIMIENTO_RESERVADO',
      );
    }

    const fechaMovimiento = this.parsearFechaMovimiento(
      dto.fechaMovimiento,
      'fechaMovimiento',
    );
    const monto = this.redondear(dto.monto);
    const motivo = this.requerirTexto(
      dto.motivo,
      'El motivo del movimiento es obligatorio',
    );

    const movimiento = await this.prisma.$transaction(async (tx) => {
      const scope = await this.obtenerScopeOrganizacionTbl(usuario, tx);

      const [actual] = await tx.$queryRaw<
        Array<{
          id: string;
          tipo: string;
          monto: Prisma.Decimal;
          referencia_id: string | null;
          referencia_tipo: string | null;
          sesion_id: string | null;
          org_id: string;
        }>
      >(Prisma.sql`
        SELECT
          m.id_mca::text AS id,
          m.mca_tipo::text AS tipo,
          m.mca_monto AS monto,
          m.mca_referencia_id::text AS referencia_id,
          m.mca_referencia_tipo::text AS referencia_tipo,
          m.sca_id::text AS sesion_id,
          m.org_id::text AS org_id
        FROM public.tbl_movimientos_cajas m
        WHERE m.id_mca = ${idLimpio}::uuid
          AND m.org_id = ${scope.organizacionId}::uuid
        LIMIT 1
      `);

      if (!actual) {
        throw DomainError.notFound(
          'Movimiento de caja menor no encontrado',
          'MOVIMIENTO_CAJA_NO_ENCONTRADO',
        );
      }

      if (actual.referencia_tipo === 'PAGO' || actual.tipo === 'RECAUDO') {
        throw DomainError.conflict(
          'No se pueden modificar pagos desde caja menor',
          'PAGO_TIPO_NO_EDITABLE',
        );
      }
      if (
        actual.referencia_tipo === 'CREDITO' ||
        actual.tipo === 'DESEMBOLSO_CREDITO'
      ) {
        throw DomainError.conflict(
          'No se pueden modificar desembolsos de credito desde caja menor',
          'DESEMBOLSO_CREDITO_TIPO_NO_EDITABLE',
        );
      }
      if (['APERTURA', 'CIERRE'].includes(actual.tipo)) {
        throw DomainError.conflict(
          'No se pueden modificar aperturas o cierres de caja',
          'SESION_CAJA_NO_EDITABLE',
        );
      }

      const oldMonto = this.decimalANumero(actual.monto);
      const oldNaturaleza = this.naturalezaMovimientoCaja({
        codigo: actual.tipo,
        naturaleza: '',
      });

      if (actual.sesion_id) {
        await tx.$executeRaw(Prisma.sql`
          UPDATE public.tbl_sesiones_cajas
          SET
            sca_total_cobrado = GREATEST(0, sca_total_cobrado - ${
              oldNaturaleza === 'E' ? this.decimal(oldMonto) : 0
            }),
            sca_total_gasto = GREATEST(0, sca_total_gasto - ${
              oldNaturaleza === 'S' ? this.decimal(oldMonto) : 0
            })
          WHERE id_sca = ${actual.sesion_id}::uuid
        `);
      }

      const [caja] = await tx.$queryRaw<CajaMovimientoTblRow[]>(Prisma.sql`
        SELECT
          c.id_caj::text AS caja_menor_id,
          c.caj_nombre AS caja_menor,
          c.caj_activa AS activa,
          c.org_id::text AS org_id,
          sc.id_sca::text AS sesion_id,
          sc.sca_fecha_cierre AS fecha_cierre,
          tu.id_usu::text AS usuario_id,
          tu.usu_usuario AS usuario,
          p.per_primer_nombre AS nombres,
          p.per_apellido AS apellidos,
          COALESCE(p.per_email, '') AS correo,
          p.per_num_celular AS telefono
        FROM public.tbl_cajas c
        JOIN public.tbl_usuarios_organizaciones uo
          ON uo.org_id = c.org_id
        JOIN public.tbl_usuarios tu ON tu.id_usu = uo.usu_id
        JOIN public.tbl_personas p ON p.id_per = tu.persona_id
        LEFT JOIN LATERAL (
          SELECT
            sca.id_sca,
            sca.sca_fecha_cierre
          FROM public.tbl_sesiones_cajas sca
          WHERE sca.caj_id = c.id_caj
            AND sca.sca_estado::text = 'ABIERTA'
          ORDER BY sca.sca_fecha_apertura DESC, sca.id_sca DESC
          LIMIT 1
        ) sc ON TRUE
        WHERE c.id_caj::text = ${dto.cajaMenorId}
          AND c.org_id = ${scope.organizacionId}::uuid
          AND c.caj_tipo::text = 'MENOR'
          AND uo.urg_activo
          AND tu.usu_activo
          AND tu.id_usu = ${scope.usuarioId}::uuid
        LIMIT 1
      `);

      if (!caja) {
        throw DomainError.notFound(
          'Caja menor no encontrada',
          'CAJA_MENOR_NO_ENCONTRADA',
        );
      }

      if (!caja.activa) {
        throw DomainError.conflict(
          'La caja menor no esta activa',
          'CAJA_MENOR_INACTIVA',
        );
      }

      const targetSesionId = caja.sesion_id ?? actual.sesion_id;

      if (targetSesionId) {
        await tx.$executeRaw(Prisma.sql`
          UPDATE public.tbl_sesiones_cajas
          SET
            sca_total_cobrado = sca_total_cobrado + ${
              tipo.naturaleza === 'E' ? this.decimal(monto) : 0
            },
            sca_total_gasto = sca_total_gasto + ${
              tipo.naturaleza === 'S' ? this.decimal(monto) : 0
            }
          WHERE id_sca = ${targetSesionId}::uuid
        `);
      }

      const sesionSql = targetSesionId
        ? Prisma.sql`${targetSesionId}::uuid`
        : Prisma.sql`NULL`;

      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_movimientos_cajas
        SET
          mca_tipo = ${tipo.codigo}::public.movimiento_caja_tipo_enum,
          mca_monto = ${this.decimal(monto)},
          mca_creacion = ${fechaMovimiento},
          sca_id = ${sesionSql}
        WHERE id_mca = ${idLimpio}::uuid
      `);

      return this.obtenerMovimientoCajaTblPorId(tx, idLimpio, motivo);
    });

    this.invalidarCacheLecturas();
    return this.formatearMovimientoCajaTbl(movimiento);
  }

  async eliminarMovimientoCaja(id: string, usuario: AuthenticatedUser) {
    this.asegurarPermiso(usuario, 'ELIMINAR_MOVIMIENTOS');

    if (this.esIdPagoCaja(id)) {
      throw DomainError.conflict(
        'No se pueden eliminar pagos desde caja menor. Utilice el modulo de creditos/pagos.',
        'PAGO_ELIMINACION_NO_DISPONIBLE',
      );
    }

    return this.eliminarMovimientoCajaTbl(id, usuario);
  }

  private async eliminarMovimientoCajaTbl(
    id: string,
    usuario: AuthenticatedUser,
  ) {
    const idLimpio = id.startsWith('mov-') ? id.slice(4) : id;
    if (!uuidPattern.test(idLimpio)) {
      throw DomainError.validation(
        'El ID del movimiento no es valido',
        'ID_MOVIMIENTO_INVALIDO',
      );
    }

    await this.prisma.$transaction(async (tx) => {
      const scope = await this.obtenerScopeOrganizacionTbl(usuario, tx);

      const [actual] = await tx.$queryRaw<
        Array<{
          id: string;
          tipo: string;
          monto: Prisma.Decimal;
          referencia_id: string | null;
          referencia_tipo: string | null;
          sesion_id: string | null;
          org_id: string;
        }>
      >(Prisma.sql`
        SELECT
          m.id_mca::text AS id,
          m.mca_tipo::text AS tipo,
          m.mca_monto AS monto,
          m.mca_referencia_id::text AS referencia_id,
          m.mca_referencia_tipo::text AS referencia_tipo,
          m.sca_id::text AS sesion_id,
          m.org_id::text AS org_id
        FROM public.tbl_movimientos_cajas m
        WHERE m.id_mca = ${idLimpio}::uuid
          AND m.org_id = ${scope.organizacionId}::uuid
        LIMIT 1
      `);

      if (!actual) {
        throw DomainError.notFound(
          'Movimiento de caja menor no encontrado',
          'MOVIMIENTO_CAJA_NO_ENCONTRADO',
        );
      }

      if (actual.referencia_tipo === 'PAGO' || actual.tipo === 'RECAUDO') {
        throw DomainError.conflict(
          'No se pueden eliminar pagos desde caja menor',
          'PAGO_ELIMINACION_NO_DISPONIBLE',
        );
      }
      if (
        actual.referencia_tipo === 'CREDITO' ||
        actual.tipo === 'DESEMBOLSO_CREDITO'
      ) {
        throw DomainError.conflict(
          'No se pueden eliminar desembolsos de credito desde caja menor',
          'DESEMBOLSO_ELIMINACION_NO_DISPONIBLE',
        );
      }
      if (['APERTURA', 'CIERRE'].includes(actual.tipo)) {
        throw DomainError.conflict(
          'No se pueden eliminar aperturas o cierres de caja',
          'SESION_CAJA_NO_ELIMINABLE',
        );
      }

      const monto = this.decimalANumero(actual.monto);
      const naturaleza = this.naturalezaMovimientoCaja({
        codigo: actual.tipo,
        naturaleza: '',
      });

      if (actual.sesion_id) {
        await tx.$executeRaw(Prisma.sql`
          UPDATE public.tbl_sesiones_cajas
          SET
            sca_total_cobrado = GREATEST(0, sca_total_cobrado - ${
              naturaleza === 'E' ? this.decimal(monto) : 0
            }),
            sca_total_gasto = GREATEST(0, sca_total_gasto - ${
              naturaleza === 'S' ? this.decimal(monto) : 0
            })
          WHERE id_sca = ${actual.sesion_id}::uuid
        `);
      }

      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_movimientos_cajas
        WHERE id_mca = ${idLimpio}::uuid
      `);
    });

    this.invalidarCacheLecturas();
    return { ok: true };
  }

  async registrarMovimientoDesembolsoTbl(
    tx: PrismaExecutor,
    input: {
      monto: number;
      creditoId: string;
      fecha?: Date;
      organizacionId: string;
      usuarioId: string;
      sesionId: string;
    },
  ) {
    const fechaDesembolso = input.fecha ?? new Date();
    await tx.$executeRaw(Prisma.sql`
      INSERT INTO public.tbl_movimientos_cajas (
        mca_tipo,
        mca_monto,
        mca_referencia_id,
        mca_referencia_tipo,
        mca_creacion,
        org_id,
        usu_id,
        sca_id
      )
      VALUES (
        'DESEMBOLSO_CREDITO'::public.movimiento_caja_tipo_enum,
        ${this.decimal(input.monto)},
        ${input.creditoId}::uuid,
        'CREDITO'::public.movimiento_referencia_tipo_enum,
        ${fechaDesembolso},
        ${input.organizacionId}::uuid,
        ${input.usuarioId}::uuid,
        ${input.sesionId}::uuid
      )
    `);

    await tx.$executeRaw(Prisma.sql`
      UPDATE public.tbl_sesiones_cajas
      SET sca_total_gasto = sca_total_gasto + ${this.decimal(input.monto)}
      WHERE id_sca = ${input.sesionId}::uuid
    `);
  }

  async registrarMovimientoRecaudoTbl(
    tx: PrismaExecutor,
    input: {
      monto: number;
      pagoId: string;
      fecha?: Date;
      organizacionId: string;
      usuarioId: string;
      cobradorId?: string;
    },
  ) {
    const fechaRecaudo = input.fecha ?? new Date();

    const sesiones = await tx.$queryRaw<
      Array<{
        sesion_id: string;
        caja_id: string;
        usuario_id: string;
      }>
    >(Prisma.sql`
      SELECT
        sca.id_sca::text AS sesion_id,
        sca.caj_id::text AS caja_id,
        sca.usu_id::text AS usuario_id
      FROM public.tbl_sesiones_cajas sca
      JOIN public.tbl_cajas c ON c.id_caj = sca.caj_id
      WHERE c.org_id = ${input.organizacionId}::uuid
        AND c.caj_tipo::text = 'MENOR'
        AND c.caj_activa
        AND sca.sca_estado::text = 'ABIERTA'
        AND (sca.sca_fecha_cierre IS NULL OR sca.sca_fecha_cierre > now())
      ORDER BY
        CASE
          WHEN sca.usu_id = ${input.usuarioId}::uuid THEN 0
          WHEN ${input.cobradorId ? Prisma.sql`sca.usu_id = ${input.cobradorId}::uuid` : Prisma.sql`FALSE`} THEN 1
          ELSE 2
        END,
        sca.sca_fecha_apertura DESC,
        sca.id_sca DESC
      LIMIT 1
    `);

    const sesion = sesiones[0];
    const usuarioMovimiento = sesion?.usuario_id ?? input.usuarioId;
    const sesionSql = sesion?.sesion_id
      ? Prisma.sql`${sesion.sesion_id}::uuid`
      : Prisma.sql`NULL`;

    await tx.$executeRaw(Prisma.sql`
      INSERT INTO public.tbl_movimientos_cajas (
        mca_tipo,
        mca_monto,
        mca_referencia_id,
        mca_referencia_tipo,
        mca_creacion,
        org_id,
        usu_id,
        sca_id
      )
      VALUES (
        'RECAUDO'::public.movimiento_caja_tipo_enum,
        ${this.decimal(input.monto)},
        ${input.pagoId}::uuid,
        'PAGO'::public.movimiento_referencia_tipo_enum,
        ${fechaRecaudo},
        ${input.organizacionId}::uuid,
        ${usuarioMovimiento}::uuid,
        ${sesionSql}
      )
    `);

    if (sesion?.sesion_id) {
      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_sesiones_cajas
        SET sca_total_cobrado = sca_total_cobrado + ${this.decimal(input.monto)}
        WHERE id_sca = ${sesion.sesion_id}::uuid
      `);
    }
  }

  async sincronizarMovimientosRecaudoTbl(
    executor: PrismaExecutor = this.prisma,
  ): Promise<number> {
    try {
      const pagosSinMovimiento = await executor.$queryRaw<
        Array<{
          pago_id: string;
          monto: Prisma.Decimal;
          fecha: Date;
          org_id: string;
          usuario_id: string;
          sesion_id: string | null;
        }>
      >(Prisma.sql`
        SELECT
          pa.id_pag::text AS pago_id,
          pa.pag_monto AS monto,
          pa.pag_fecha AS fecha,
          cl.org_id::text AS org_id,
          tu.id_usu::text AS usuario_id,
          sc.id_sca::text AS sesion_id
        FROM (
          SELECT DISTINCT ON (pa.id_pag)
            pa.id_pag,
            pa.pag_fecha,
            pa.pag_monto,
            cu.cre_id AS credito_id
          FROM public.tbl_pagos pa
          JOIN public.tbl_cuotas_pagos cp ON cp.pagos_id = pa.id_pag
          JOIN public.tbl_cuotas cu ON cu.id_cuo = cp.cuo_id
          WHERE NOT EXISTS (
            SELECT 1
            FROM public.tbl_movimientos_cajas mc
            WHERE mc.mca_referencia_tipo::text = 'PAGO'
              AND mc.mca_referencia_id = pa.id_pag
          )
          ORDER BY pa.id_pag, cu.cre_id
        ) pa
        JOIN public.tbl_creditos cr ON cr.id_cre = pa.credito_id
        JOIN public.tbl_usuarios tu ON tu.id_usu = cr.usu_id
        JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
        LEFT JOIN LATERAL (
          SELECT sca.id_sca
          FROM public.tbl_sesiones_cajas sca
          JOIN public.tbl_cajas c ON c.id_caj = sca.caj_id
          WHERE c.org_id = cl.org_id
            AND c.caj_tipo::text = 'MENOR'
            AND c.caj_activa
          ORDER BY
            (sca.usu_id = tu.id_usu) DESC,
            (sca.sca_estado::text = 'ABIERTA') DESC,
            sca.sca_fecha_apertura DESC,
            sca.id_sca DESC
          LIMIT 1
        ) sc ON TRUE
      `);

      if (!pagosSinMovimiento.length) {
        return 0;
      }

      for (const pago of pagosSinMovimiento) {
        const sesionSql = pago.sesion_id
          ? Prisma.sql`${pago.sesion_id}::uuid`
          : Prisma.sql`NULL`;

        await executor.$executeRaw(Prisma.sql`
          INSERT INTO public.tbl_movimientos_cajas (
            mca_tipo,
            mca_monto,
            mca_referencia_id,
            mca_referencia_tipo,
            mca_creacion,
            org_id,
            usu_id,
            sca_id
          )
          VALUES (
            'RECAUDO'::public.movimiento_caja_tipo_enum,
            ${this.decimal(this.decimalANumero(pago.monto))},
            ${pago.pago_id}::uuid,
            'PAGO'::public.movimiento_referencia_tipo_enum,
            ${pago.fecha},
            ${pago.org_id}::uuid,
            ${pago.usuario_id}::uuid,
            ${sesionSql}
          )
        `);

        if (pago.sesion_id) {
          await executor.$executeRaw(Prisma.sql`
            UPDATE public.tbl_sesiones_cajas
            SET sca_total_cobrado = sca_total_cobrado + ${this.decimal(this.decimalANumero(pago.monto))}
            WHERE id_sca = ${pago.sesion_id}::uuid
          `);
        }
      }

      this.invalidarCacheLecturas();
      return pagosSinMovimiento.length;
    } catch (error) {
      this.logger.warn(
        `Error en sincronizarMovimientosRecaudoTbl: ${(error as Error)?.message}`,
      );
      return 0;
    }
  }
}
