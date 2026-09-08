import {
  ForbiddenException,
  Inject,
  Injectable,
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

type AuditoriaMovimientoCajaRow = {
  auditoria_id: string;
  caja_menor_id: string | null;
  caja_menor: string | null;
  registro_id: string | null;
  accion: string;
  descripcion: string;
  creado_en: Date;
  usuario_id: string | null;
  nombre_usuario: string | null;
  nombres: string | null;
  apellidos: string | null;
  correo: string | null;
  telefono: string | null;
};

type CajaResumenPago = {
  cajaMenorId: string;
  nombre: string;
  responsableUsuarioId: string;
  monedaCodigo: string;
};

type PresupuestoDisponibleRow = {
  presupuesto: Prisma.Decimal | null;
};

export type MovimientoCajaConRelaciones = Prisma.CajaMenorMovimientoGetPayload<{
  include: {
    cajaMenor: true;
    tipoMovimientoCaja: true;
    usuario: true;
    desembolsoCredito: true;
  };
}>;

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
export class CajaMenorService {
  private readonly tablaExisteCache = new Map<string, boolean>();

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

  private formatearUsuario(usuario: {
    usuarioId: string;
    nombreUsuario?: string;
    nombres: string;
    apellidos: string;
    correo: string;
    telefono: string | null;
  }) {
    return {
      id: usuario.usuarioId,
      usuario: usuario.nombreUsuario ?? null,
      nombres: usuario.nombres,
      apellidos: usuario.apellidos,
      nombreCompleto: `${usuario.nombres} ${usuario.apellidos}`.trim(),
      correo: usuario.correo,
      telefono: usuario.telefono,
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

  private identificacionCliente(cliente: {
    documentos: Array<{
      numeroDocumento: string;
      tipoDocumento?: { codigo: string } | null;
    }>;
  }) {
    const documento =
      cliente.documentos.find((item) => item.tipoDocumento?.codigo === 'CC') ??
      cliente.documentos[0];

    return documento?.numeroDocumento ?? null;
  }

  private formatearMotivoMovimientoCaja(
    motivo: string,
    referenciaTabla: string | null,
    clienteNombre: string | null,
  ) {
    if (referenciaTabla === 'credito_desembolso' && clienteNombre) {
      return `Desembolso de credito para ${clienteNombre}`;
    }

    return motivo;
  }

  private claveCajaPago(responsableUsuarioId: string, monedaCodigo: string) {
    return `${responsableUsuarioId}:${monedaCodigo}`;
  }

  private async cajasParaPagos(
    pagos: Array<{ responsableUsuarioId: string; monedaCodigo: string }>,
    cajaFiltro: CajaResumenPago | null,
  ) {
    const cajas = new Map<string, CajaResumenPago>();

    if (cajaFiltro) {
      cajas.set(
        this.claveCajaPago(
          cajaFiltro.responsableUsuarioId,
          cajaFiltro.monedaCodigo,
        ),
        cajaFiltro,
      );
      return cajas;
    }

    const claves = new Set(
      pagos.map((pago) =>
        this.claveCajaPago(pago.responsableUsuarioId, pago.monedaCodigo),
      ),
    );

    if (claves.size === 0) {
      return cajas;
    }

    const responsables = [
      ...new Set(pagos.map((pago) => pago.responsableUsuarioId)),
    ];
    const monedas = [...new Set(pagos.map((pago) => pago.monedaCodigo))];
    const candidatas = await this.prisma.cajaMenor.findMany({
      where: {
        responsableUsuarioId: { in: responsables },
        monedaCodigo: { in: monedas },
        activa: true,
      },
      orderBy: { creadaEn: 'asc' },
    });

    for (const caja of candidatas) {
      const clave = this.claveCajaPago(
        caja.responsableUsuarioId,
        caja.monedaCodigo,
      );

      if (claves.has(clave) && !cajas.has(clave)) {
        cajas.set(clave, {
          cajaMenorId: caja.cajaMenorId,
          nombre: caja.nombre,
          responsableUsuarioId: caja.responsableUsuarioId,
          monedaCodigo: caja.monedaCodigo,
        });
      }
    }

    return cajas;
  }

  private async tablaExiste(client: PrismaExecutor, nombre: string) {
    const enCache = this.tablaExisteCache.get(nombre);
    if (enCache !== undefined) {
      return enCache;
    }

    const resultado = await client.$queryRaw<Array<{ nombre: string | null }>>(
      Prisma.sql`SELECT to_regclass(${nombre})::text AS nombre`,
    );

    const existe = resultado[0]?.nombre !== null;
    this.tablaExisteCache.set(nombre, existe);
    return existe;
  }

  private async listarAuditoriasMovimientoCaja(
    query: ListarMovimientosCajaQueryDto,
    usuario: AuthenticatedUser,
    search: string | null,
    limit = 100,
  ): Promise<AuditoriaMovimientoCajaRow[]> {
    if (!(await this.tablaExiste(this.prisma, 'public.auditoria'))) {
      return [];
    }

    const condiciones: Prisma.Sql[] = [
      Prisma.sql`a.tabla = 'caja_menor_movimiento'`,
      Prisma.sql`a.accion IN ('MODIFICAR', 'ELIMINAR')`,
    ];

    if (query.cajaMenorId) {
      condiciones.push(
        Prisma.sql`cm.caja_menor_id = ${query.cajaMenorId}::uuid`,
      );
    }

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      condiciones.push(
        Prisma.sql`cm.responsable_usuario_id = ${usuario.usuarioId}::uuid`,
      );
    }

    if (query.fechaDesde) {
      const fechaDesde = this.inicioDiaColombia(
        this.parsearFecha(query.fechaDesde, 'fechaDesde'),
      );
      condiciones.push(Prisma.sql`a.creado_en >= ${fechaDesde}`);
    }

    if (query.fechaHasta) {
      const fechaHasta = this.finDiaColombia(
        this.parsearFecha(query.fechaHasta, 'fechaHasta'),
      );
      condiciones.push(Prisma.sql`a.creado_en <= ${fechaHasta}`);
    }

    if (search) {
      const patron = `%${search}%`;
      condiciones.push(Prisma.sql`(
        a.descripcion ILIKE ${patron}
        OR a.accion ILIKE ${patron}
        OR cm.nombre ILIKE ${patron}
        OR u.nombres ILIKE ${patron}
        OR u.apellidos ILIKE ${patron}
        OR u.nombre_usuario ILIKE ${patron}
      )`);
    }

    return this.prisma.$queryRaw<AuditoriaMovimientoCajaRow[]>(Prisma.sql`
      SELECT
        a.auditoria_id,
        cm.caja_menor_id,
        cm.nombre AS caja_menor,
        a.registro_id,
        a.accion,
        a.descripcion,
        a.creado_en,
        u.usuario_id,
        u.nombre_usuario,
        u.nombres,
        u.apellidos,
        u.correo,
        u.telefono
      FROM public.auditoria a
      LEFT JOIN public.caja_menor cm
        ON cm.caja_menor_id = COALESCE(
          NULLIF(a.valores_nuevos ->> 'cajaMenorId', ''),
          NULLIF(a.valores_anteriores ->> 'cajaMenorId', ''),
          NULLIF(a.metadata ->> 'cajaMenorId', '')
        )::uuid
      LEFT JOIN public.usuario u ON u.usuario_id = a.usuario_id
      WHERE ${Prisma.join(condiciones, ' AND ')}
      ORDER BY a.creado_en DESC
      LIMIT ${limit}
    `);
  }

  private async registrarAuditoriaMovimientoCaja(
    tx: Prisma.TransactionClient,
    input: {
      cajaMenorId: string;
      cajaMenorMovimientoId: string | null;
      usuarioId?: string | null;
      accion: 'MODIFICAR' | 'ELIMINAR';
      detalle: string;
    },
  ) {
    if (
      !(await this.tablaExiste(tx, 'public.caja_menor_movimiento_auditoria'))
    ) {
      return;
    }

    await tx.$executeRaw(Prisma.sql`
      INSERT INTO public.caja_menor_movimiento_auditoria (
        caja_menor_id,
        caja_menor_movimiento_id,
        usuario_id,
        accion,
        detalle
      )
      VALUES (
        ${input.cajaMenorId}::uuid,
        ${input.cajaMenorMovimientoId}::uuid,
        ${input.usuarioId ?? null}::uuid,
        ${input.accion},
        ${input.detalle}
      )
    `);
  }

  private async registrarAuditoria(
    tx: Prisma.TransactionClient,
    input: {
      usuarioId?: string | null;
      tabla: string;
      registroId?: string | null;
      accion: string;
      descripcion: string;
      valoresAnteriores?: unknown;
      valoresNuevos?: unknown;
      metadata?: unknown;
    },
  ) {
    if (!(await this.tablaExiste(tx, 'public.auditoria'))) {
      return;
    }

    const valoresAnteriores =
      input.valoresAnteriores === undefined
        ? null
        : JSON.stringify(input.valoresAnteriores);
    const valoresNuevos =
      input.valoresNuevos === undefined
        ? null
        : JSON.stringify(input.valoresNuevos);
    const metadata =
      input.metadata === undefined ? null : JSON.stringify(input.metadata);

    await tx.$executeRaw(Prisma.sql`
      INSERT INTO public.auditoria (
        usuario_id,
        tabla,
        registro_id,
        accion,
        descripcion,
        valores_anteriores,
        valores_nuevos,
        metadata
      )
      VALUES (
        ${input.usuarioId ?? null}::uuid,
        ${input.tabla},
        ${input.registroId ?? null},
        ${input.accion},
        ${input.descripcion},
        ${valoresAnteriores}::jsonb,
        ${valoresNuevos}::jsonb,
        ${metadata}::jsonb
      )
    `);
  }

  private formatearMontoAuditoria(monto: number) {
    return monto.toLocaleString('es-CO', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
  }

  private detalleMovimientoCajaModificado(
    anterior: MovimientoCajaConRelaciones,
    actualizado: MovimientoCajaConRelaciones,
  ) {
    return [
      `Se modifico movimiento "${anterior.motivo}"`,
      `de ${this.formatearMontoAuditoria(
        this.decimalANumero(anterior.monto),
      )} ${anterior.tipoMovimientoCaja.nombre}`,
      `a ${this.formatearMontoAuditoria(
        this.decimalANumero(actualizado.monto),
      )} ${actualizado.tipoMovimientoCaja.nombre}`,
    ].join(' ');
  }

  private detalleMovimientoCajaEliminado(
    movimiento: MovimientoCajaConRelaciones,
  ) {
    return [
      `Se elimino movimiento "${movimiento.motivo}"`,
      `por ${this.formatearMontoAuditoria(
        this.decimalANumero(movimiento.monto),
      )}`,
      `(${movimiento.tipoMovimientoCaja.nombre})`,
    ].join(' ');
  }

  private efectoPresupuestoMovimientoCaja(monto: number, naturaleza: string) {
    if (naturaleza === 'S') {
      return -monto;
    }

    if (naturaleza === 'N') {
      return 0;
    }

    return monto;
  }

  private async asegurarSalidaCajaConPresupuesto(
    tx: Prisma.TransactionClient,
    cajaMenorId: string,
    montoSalida: number,
    mensaje: string,
    codigo: string,
  ) {
    await tx.$queryRaw(Prisma.sql`
      SELECT caja_menor_id
      FROM public.caja_menor
      WHERE caja_menor_id = ${cajaMenorId}::uuid
      FOR UPDATE
    `);

    const presupuestoRows = await tx.$queryRaw<PresupuestoDisponibleRow[]>(
      Prisma.sql`
        SELECT presupuesto
        FROM public.vista_presupuesto_actual
        WHERE caja_menor_id = ${cajaMenorId}::uuid
      `,
    );
    const presupuestoDisponible = this.decimalANumero(
      presupuestoRows[0]?.presupuesto,
    );

    if (montoSalida > presupuestoDisponible) {
      throw DomainError.conflict(mensaje, codigo);
    }
  }

  private async asegurarPresupuestoDespuesDeCambioMovimientoCaja(
    tx: Prisma.TransactionClient,
    actual: {
      cajaMenorId: string;
      monto: Prisma.Decimal;
      tipoMovimientoCaja: { naturaleza: string };
    },
    siguiente?: {
      cajaMenorId: string;
      monto: number;
      naturaleza: string;
    },
  ) {
    const cajaMenorIds = [
      ...new Set(
        [actual.cajaMenorId, siguiente?.cajaMenorId].filter(
          (value): value is string => Boolean(value),
        ),
      ),
    ];

    for (const cajaMenorId of cajaMenorIds) {
      await tx.$queryRaw(Prisma.sql`
        SELECT caja_menor_id
        FROM public.caja_menor
        WHERE caja_menor_id = ${cajaMenorId}::uuid
        FOR UPDATE
      `);
    }

    const presupuestos = await Promise.all(
      cajaMenorIds.map(async (cajaMenorId) => {
        const rows = await tx.$queryRaw<PresupuestoDisponibleRow[]>(
          Prisma.sql`
            SELECT presupuesto
            FROM public.vista_presupuesto_actual
            WHERE caja_menor_id = ${cajaMenorId}::uuid
          `,
        );

        return [
          cajaMenorId,
          this.decimalANumero(rows[0]?.presupuesto),
        ] as const;
      }),
    );
    const presupuestoPorCaja = new Map<string, number>(presupuestos);

    for (const cajaMenorId of cajaMenorIds) {
      let presupuesto = presupuestoPorCaja.get(cajaMenorId) ?? 0;

      if (actual.cajaMenorId === cajaMenorId) {
        presupuesto -= this.efectoPresupuestoMovimientoCaja(
          this.decimalANumero(actual.monto),
          actual.tipoMovimientoCaja.naturaleza,
        );
      }

      if (siguiente?.cajaMenorId === cajaMenorId) {
        presupuesto += this.efectoPresupuestoMovimientoCaja(
          siguiente.monto,
          siguiente.naturaleza,
        );
      }

      if (presupuesto < -0.004) {
        throw DomainError.conflict(
          'La modificacion deja la caja menor sin presupuesto disponible',
          'CAJA_MENOR_SALDO_INSUFICIENTE',
        );
      }
    }
  }

  private formatearMovimientoCaja(movimiento: MovimientoCajaConRelaciones) {
    const monto = this.decimalANumero(movimiento.monto);
    const naturaleza = this.naturalezaMovimientoCaja(
      movimiento.tipoMovimientoCaja,
    );

    return {
      id: movimiento.cajaMenorMovimientoId,
      cajaMenorId: movimiento.cajaMenorId,
      cajaMenor: movimiento.cajaMenor.nombre,
      tipoMovimiento: {
        id: movimiento.tipoMovimientoCajaId,
        codigo: movimiento.tipoMovimientoCaja.codigo,
        nombre: movimiento.tipoMovimientoCaja.nombre,
        naturaleza,
      },
      usuario: movimiento.usuario
        ? this.formatearUsuario(movimiento.usuario)
        : null,
      fechaMovimiento: this.fechaIso(movimiento.fechaMovimiento),
      monto,
      montoConNaturaleza: naturaleza === 'S' ? -monto : monto,
      motivo: movimiento.motivo,
      cliente: null,
      clienteIdentificacion: null,
      referenciaTabla: movimiento.referenciaTabla,
      referenciaId: movimiento.referenciaId,
      creadoEn: movimiento.creadoEn.toISOString(),
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
    const rows = await tx.$queryRaw<MovimientoCajaTblRow[]>(Prisma.sql`
      SELECT
        CONCAT('mov-', m.id_mca::text) AS id,
        c.id_caj::text AS caja_menor_id,
        COALESCE(c.caj_nombre, o.org_nombre) AS caja_menor,
        NULL::text AS cliente,
        NULL::text AS cliente_identificacion,
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
        ${motivo} AS motivo,
        m.mca_referencia_tipo::text AS referencia_tabla,
        m.mca_referencia_id::text AS referencia_id,
        m.mca_creacion AS creado_en
      FROM public.tbl_movimientos_cajas m
      JOIN public.tbl_organizaciones o ON o.id_org = m.org_id
      JOIN public.tbl_usuarios tu ON tu.id_usu = m.usu_id
      JOIN public.tbl_personas p ON p.id_per = tu.persona_id
      LEFT JOIN public.tbl_sesiones_cajas sc ON sc.id_sca = m.sca_id
      LEFT JOIN public.tbl_cajas c ON c.id_caj = sc.caj_id
      WHERE m.id_mca = ${movimientoId}::bigint
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

    if (await this.usarEsquemaTbl()) {
      return this.crearCajaMenorTbl(dto, usuario);
    }

    const nombre = this.requerirTexto(
      dto.nombre,
      'El nombre de la caja menor es obligatorio',
    );
    const responsableUsuarioId =
      this.esAdministrador(usuario) && dto.responsableUsuarioId
        ? dto.responsableUsuarioId
        : usuario.usuarioId;
    const monedaCodigo = dto.monedaCodigo ?? 'COP';
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

    const [responsable, moneda, existente, cajaAbierta] = await Promise.all([
      this.prisma.usuario.findUnique({
        where: { usuarioId: responsableUsuarioId },
      }),
      this.prisma.moneda.findUnique({
        where: { codigoMoneda: monedaCodigo },
      }),
      this.prisma.cajaMenor.findFirst({
        where: {
          responsableUsuarioId,
          nombre,
        },
      }),
      this.prisma.cajaMenor.findFirst({
        where: {
          responsableUsuarioId,
          activa: true,
          OR: [{ fechaCierre: null }, { fechaCierre: { gt: new Date() } }],
        },
      }),
    ]);

    if (!responsable) {
      throw DomainError.notFound(
        'Responsable no encontrado',
        'RESPONSABLE_NO_ENCONTRADO',
      );
    }
    if (!moneda) {
      throw DomainError.notFound(
        'Moneda no encontrada',
        'MONEDA_NO_ENCONTRADA',
      );
    }
    if (cajaAbierta) {
      const detalleFecha = cajaAbierta.fechaCierre
        ? ` vigente hasta el ${cajaAbierta.fechaCierre.toLocaleString('es-CO')}`
        : '';
      throw DomainError.conflict(
        `El usuario ya tiene una caja menor abierta (${cajaAbierta.nombre})${detalleFecha}. Debe cerrarse antes de crear una nueva`,
        'CAJA_MENOR_ABIERTA_EXISTENTE',
      );
    }
    if (existente) {
      throw DomainError.conflict(
        'El responsable ya tiene una caja menor con ese nombre',
        'CAJA_MENOR_DUPLICADA',
      );
    }

    const caja = await this.prisma.cajaMenor.create({
      data: {
        responsableUsuarioId: responsable.usuarioId,
        monedaCodigo: moneda.codigoMoneda,
        nombre,
        fechaApertura,
        fechaCierre,
      },
      include: { responsable: true },
    });

    this.invalidarCacheLecturas();
    return {
      id: caja.cajaMenorId,
      nombre: caja.nombre,
      activa: caja.activa,
      monedaCodigo: caja.monedaCodigo,
      fechaApertura: caja.fechaApertura.toISOString(),
      fechaCierre: caja.fechaCierre?.toISOString() ?? null,
      responsable: this.formatearUsuario(caja.responsable),
    };
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
      const targetUsuarioId =
        this.esAdministrador(usuario) && dto.responsableUsuarioId?.trim()
          ? dto.responsableUsuarioId.trim()
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
    this.asegurarPermiso(usuario, 'REGISTRAR_FLUJO_CAJA');

    if (await this.usarEsquemaTbl()) {
      return this.cerrarCajaMenorTbl(id, usuario);
    }

    const caja = await this.prisma.cajaMenor.findUnique({
      where: { cajaMenorId: id },
    });
    if (!caja) {
      throw DomainError.notFound(
        'Caja menor no encontrada',
        'CAJA_MENOR_NO_ENCONTRADA',
      );
    }
    if (
      !this.esAdministrador(usuario) &&
      caja.responsableUsuarioId !== usuario.usuarioId
    ) {
      throw new ForbiddenException(
        'No tienes permiso para cerrar esta caja menor',
      );
    }

    const ahora = new Date();
    await this.prisma.cajaMenor.update({
      where: { cajaMenorId: id },
      data: {
        activa: false,
        fechaCierre: ahora,
      },
    });

    this.invalidarCacheLecturas();
    return {
      id: caja.cajaMenorId,
      nombre: caja.nombre,
      activa: false,
      fechaCierre: ahora.toISOString(),
      mensaje: 'Caja menor cerrada exitosamente',
    };
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
    paginado: boolean,
  ) {
    if (await this.usarEsquemaTbl()) {
      return this.listarMovimientosCajaTbl(query, usuario, limit, offset);
    }

    const search = this.normalizarTextoOpcional(query.search);
    const sourceTake = paginado ? offset + limit : limit;
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
    const tipo = query.tipo ?? 'todos';
    const where: Prisma.CajaMenorMovimientoWhereInput = {
      cajaMenorId: query.cajaMenorId,
    };

    if (fechaDesde || fechaHasta) {
      where.fechaMovimiento = {
        ...(fechaDesde ? { gte: fechaDesde } : {}),
        ...(fechaHasta ? { lte: fechaHasta } : {}),
      };
    }

    if (tipo === 'entradas') {
      where.tipoMovimientoCaja = { naturaleza: 'E' };
    } else if (tipo === 'salidas') {
      where.tipoMovimientoCaja = { naturaleza: 'S' };
    }

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      where.cajaMenor = { responsableUsuarioId: usuario.usuarioId };
    }

    if (search) {
      where.OR = [
        { motivo: { contains: search, mode: 'insensitive' } },
        {
          tipoMovimientoCaja: {
            nombre: { contains: search, mode: 'insensitive' },
          },
        },
        {
          cajaMenor: {
            nombre: { contains: search, mode: 'insensitive' },
          },
        },
        {
          desembolsoCredito: {
            is: {
              credito: {
                cliente: {
                  OR: [
                    {
                      nombreCompleto: {
                        contains: search,
                        mode: 'insensitive',
                      },
                    },
                    {
                      documentos: {
                        some: {
                          numeroDocumento: {
                            contains: search,
                            mode: 'insensitive',
                          },
                        },
                      },
                    },
                  ],
                },
              },
            },
          },
        },
      ];
    }

    const cajaFiltro = query.cajaMenorId
      ? await this.prisma.cajaMenor.findUnique({
          where: { cajaMenorId: query.cajaMenorId },
        })
      : null;
    const cajaFiltroVisible =
      cajaFiltro &&
      (this.puedeVerDatosOrganizacion(usuario) ||
        cajaFiltro.responsableUsuarioId === usuario.usuarioId)
        ? cajaFiltro
        : null;
    const pagoWhere: Prisma.PagoWhereInput = {};

    if (query.cajaMenorId && !cajaFiltroVisible) {
      pagoWhere.pagoId = '00000000-0000-0000-0000-000000000000';
    } else if (tipo === 'salidas') {
      pagoWhere.pagoId = '00000000-0000-0000-0000-000000000000';
    } else if (cajaFiltroVisible) {
      pagoWhere.monedaCodigo = cajaFiltroVisible.monedaCodigo;
      pagoWhere.ruta = {
        responsableUsuarioId: cajaFiltroVisible.responsableUsuarioId,
      };
    } else if (!this.puedeVerDatosOrganizacion(usuario)) {
      pagoWhere.ruta = { responsableUsuarioId: usuario.usuarioId };
    }

    if (fechaDesde || fechaHasta) {
      pagoWhere.fechaPago = {
        ...(fechaDesdeColombia ? { gte: fechaDesdeColombia } : {}),
        ...(fechaHastaColombia ? { lte: fechaHastaColombia } : {}),
      };
    }

    if (search) {
      pagoWhere.OR = [
        {
          cliente: {
            nombreCompleto: { contains: search, mode: 'insensitive' },
          },
        },
        {
          cliente: {
            documentos: {
              some: {
                numeroDocumento: { contains: search, mode: 'insensitive' },
              },
            },
          },
        },
        {
          medioPago: {
            nombre: { contains: search, mode: 'insensitive' },
          },
        },
        { ruta: { nombre: { contains: search, mode: 'insensitive' } } },
        { referenciaExterna: { contains: search, mode: 'insensitive' } },
        { observacion: { contains: search, mode: 'insensitive' } },
      ];
    }

    const [movimientos, pagos, auditorias, tipoRecaudo] = await Promise.all([
      this.prisma.cajaMenorMovimiento.findMany({
        where,
        include: {
          cajaMenor: true,
          tipoMovimientoCaja: true,
          usuario: true,
          desembolsoCredito: {
            include: {
              credito: {
                include: {
                  cliente: {
                    include: {
                      documentos: { include: { tipoDocumento: true } },
                    },
                  },
                },
              },
            },
          },
        },
        orderBy: [{ fechaMovimiento: 'desc' }, { creadoEn: 'desc' }],
        take: sourceTake,
      }),
      this.prisma.pago.findMany({
        where: pagoWhere,
        include: {
          cliente: {
            include: {
              documentos: { include: { tipoDocumento: true } },
            },
          },
          cobrador: true,
          medioPago: true,
          ruta: true,
        },
        orderBy: [{ fechaPago: 'desc' }, { creadoEn: 'desc' }],
        take: sourceTake,
      }),
      this.listarAuditoriasMovimientoCaja(query, usuario, search, sourceTake),
      this.prisma.tipoMovimientoCaja.findUnique({
        where: { codigo: 'RECAUDO' },
      }),
    ]);

    const cajasPago = await this.cajasParaPagos(
      pagos.map((pago) => ({
        responsableUsuarioId: pago.ruta.responsableUsuarioId,
        monedaCodigo: pago.monedaCodigo,
      })),
      cajaFiltroVisible
        ? {
            cajaMenorId: cajaFiltroVisible.cajaMenorId,
            nombre: cajaFiltroVisible.nombre,
            responsableUsuarioId: cajaFiltroVisible.responsableUsuarioId,
            monedaCodigo: cajaFiltroVisible.monedaCodigo,
          }
        : null,
    );

    const movimientosCaja = movimientos.map((movimiento) => {
      const clienteCredito =
        movimiento.desembolsoCredito?.credito.cliente ?? null;
      const referenciaTabla =
        movimiento.referenciaTabla ??
        (movimiento.desembolsoCredito ? 'credito_desembolso' : null);
      const monto = this.decimalANumero(movimiento.monto);
      const naturaleza = this.naturalezaMovimientoCaja(
        movimiento.tipoMovimientoCaja,
      );

      return {
        id: movimiento.cajaMenorMovimientoId,
        cajaMenorId: movimiento.cajaMenorId,
        cajaMenor: movimiento.cajaMenor.nombre,
        cliente: clienteCredito?.nombreCompleto ?? null,
        clienteIdentificacion: clienteCredito
          ? this.identificacionCliente(clienteCredito)
          : null,
        tipoMovimiento: {
          id: movimiento.tipoMovimientoCajaId,
          codigo: movimiento.tipoMovimientoCaja.codigo,
          nombre: movimiento.tipoMovimientoCaja.nombre,
          naturaleza,
        },
        usuario: movimiento.usuario
          ? this.formatearUsuario(movimiento.usuario)
          : null,
        fechaMovimiento: this.fechaIso(movimiento.fechaMovimiento),
        monto,
        montoConNaturaleza: naturaleza === 'S' ? -monto : monto,
        motivo: this.formatearMotivoMovimientoCaja(
          movimiento.motivo,
          referenciaTabla,
          clienteCredito?.nombreCompleto ?? null,
        ),
        referenciaTabla,
        referenciaId: movimiento.referenciaId,
        creadoEn: movimiento.creadoEn.toISOString(),
      };
    });

    const movimientosAuditoria = auditorias.map((auditoria) => ({
      id: `auditoria-${auditoria.auditoria_id}`,
      cajaMenorId: auditoria.caja_menor_id,
      cajaMenor: auditoria.caja_menor ?? 'Auditoria',
      cliente: null,
      clienteIdentificacion: null,
      tipoMovimiento: {
        id: 0,
        codigo: 'AUDITORIA',
        nombre: 'Registro',
        naturaleza: 'N',
      },
      usuario: auditoria.usuario_id
        ? this.formatearUsuario({
            usuarioId: auditoria.usuario_id,
            nombreUsuario: auditoria.nombre_usuario ?? undefined,
            nombres: auditoria.nombres ?? '',
            apellidos: auditoria.apellidos ?? '',
            correo: auditoria.correo ?? '',
            telefono: auditoria.telefono,
          })
        : null,
      fechaMovimiento: this.fechaIsoColombia(auditoria.creado_en),
      monto: 0,
      montoConNaturaleza: 0,
      motivo: auditoria.descripcion,
      referenciaTabla: 'auditoria_caja_menor',
      referenciaId: auditoria.registro_id,
      creadoEn: auditoria.creado_en.toISOString(),
    }));

    const movimientosPago = pagos.map((pago) => {
      const caja = cajasPago.get(
        this.claveCajaPago(pago.ruta.responsableUsuarioId, pago.monedaCodigo),
      );
      const monto = this.decimalANumero(pago.totalPagado);

      return {
        id: `pago-${pago.pagoId}`,
        cajaMenorId: caja?.cajaMenorId ?? null,
        cajaMenor: caja?.nombre ?? pago.ruta.nombre,
        cliente: pago.cliente.nombreCompleto,
        clienteIdentificacion: this.identificacionCliente(pago.cliente),
        tipoMovimiento: {
          id: tipoRecaudo?.tipoMovimientoCajaId ?? 0,
          codigo: tipoRecaudo?.codigo ?? 'RECAUDO',
          nombre: tipoRecaudo?.nombre ?? 'Recaudo',
          naturaleza: tipoRecaudo?.naturaleza ?? 'E',
        },
        usuario: pago.cobrador ? this.formatearUsuario(pago.cobrador) : null,
        fechaMovimiento: this.fechaIsoColombia(pago.fechaPago),
        monto,
        montoConNaturaleza: monto,
        motivo: `Pago del usuario ${pago.cliente.nombreCompleto}`,
        referenciaTabla: 'pago',
        referenciaId: pago.pagoId,
        creadoEn: pago.creadoEn.toISOString(),
      };
    });

    const rows = [
      ...movimientosCaja,
      ...movimientosPago,
      ...movimientosAuditoria,
    ]
      .filter((movimiento) => {
        const naturaleza = movimiento.tipoMovimiento.naturaleza.toUpperCase();
        const fechaMovimiento = new Date(movimiento.fechaMovimiento);

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
      })
      .sort((left, right) => {
        const fecha =
          Date.parse(right.fechaMovimiento) - Date.parse(left.fechaMovimiento);

        if (fecha !== 0) {
          return fecha;
        }

        return Date.parse(right.creadoEn) - Date.parse(left.creadoEn);
      });

    return rows.slice(offset, offset + limit);
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
          NULL::text AS cliente,
          NULL::text AS cliente_identificacion,
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
          COALESCE(m.mca_referencia_tipo::text, INITCAP(REPLACE(m.mca_tipo::text, '_', ' '))) AS motivo,
          m.mca_referencia_tipo::text AS referencia_tabla,
          m.mca_referencia_id::text AS referencia_id,
          m.mca_creacion AS creado_en
        FROM public.tbl_movimientos_cajas m
        JOIN public.tbl_organizaciones o ON o.id_org = m.org_id
        JOIN public.tbl_usuarios tu ON tu.id_usu = m.usu_id
        JOIN public.tbl_personas p ON p.id_per = tu.persona_id
        LEFT JOIN public.tbl_sesiones_cajas sc ON sc.id_sca = m.sca_id
        LEFT JOIN public.tbl_cajas c ON c.id_caj = sc.caj_id
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

    const fechaMovimiento = this.parsearFecha(
      dto.fechaMovimiento,
      'fechaMovimiento',
    );
    const monto = this.redondear(dto.monto);

    if (await this.usarEsquemaTbl()) {
      return this.crearMovimientoCajaTbl(dto, usuario, fechaMovimiento, monto);
    }

    const movimiento = await this.prisma.$transaction(async (tx) => {
      const caja = await tx.cajaMenor.findUnique({
        where: { cajaMenorId: dto.cajaMenorId },
      });

      if (!caja) {
        throw DomainError.notFound(
          'Caja menor no encontrada',
          'CAJA_MENOR_NO_ENCONTRADA',
        );
      }

      this.asegurarResponsableCaja(caja.responsableUsuarioId, usuario);

      if (!caja.activa) {
        throw DomainError.conflict(
          'La caja menor no esta activa',
          'CAJA_MENOR_INACTIVA',
        );
      }

      const tipo = await tx.tipoMovimientoCaja.findUnique({
        where: { codigo: dto.tipoMovimientoCodigo },
      });

      if (!tipo) {
        throw DomainError.notFound(
          'Tipo de movimiento de caja no encontrado',
          'TIPO_MOVIMIENTO_CAJA_NO_EXISTE',
        );
      }

      const naturalezaTipo = this.naturalezaMovimientoCaja(tipo);
      if (naturalezaTipo === 'S') {
        await this.asegurarSalidaCajaConPresupuesto(
          tx,
          caja.cajaMenorId,
          monto,
          'El movimiento supera el dinero disponible en caja menor',
          'CAJA_MENOR_SALDO_INSUFICIENTE',
        );
      }

      return tx.cajaMenorMovimiento.create({
        data: {
          cajaMenorId: caja.cajaMenorId,
          tipoMovimientoCajaId: tipo.tipoMovimientoCajaId,
          usuarioId: usuario.usuarioId,
          fechaMovimiento,
          monto: this.decimal(monto),
          motivo: this.requerirTexto(
            dto.motivo,
            'El motivo del movimiento es obligatorio',
          ),
        },
        include: {
          cajaMenor: true,
          tipoMovimientoCaja: true,
          usuario: true,
          desembolsoCredito: true,
        },
      });
    });

    this.invalidarCacheLecturas();
    return this.formatearMovimientoCaja(movimiento);
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
      if (this.pagosService) {
        const movimiento =
          await this.pagosService.actualizarPagoComoMovimientoCaja(
            this.idPagoDesdeMovimientoCaja(id),
            dto,
            usuario,
          );
        this.invalidarCacheLecturas();
        return movimiento;
      }
      throw DomainError.conflict(
        'No se pueden modificar pagos desde caja menor directamente sin el servicio de pagos',
        'PAGO_MODIFICACION_NO_DISPONIBLE',
      );
    }

    const fechaMovimiento = this.parsearFecha(
      dto.fechaMovimiento,
      'fechaMovimiento',
    );
    const monto = this.redondear(dto.monto);
    const motivo = this.requerirTexto(
      dto.motivo,
      'El motivo del movimiento es obligatorio',
    );

    const movimiento = await this.prisma.$transaction(async (tx) => {
      const actual = await tx.cajaMenorMovimiento.findUnique({
        where: { cajaMenorMovimientoId: id },
        include: {
          cajaMenor: true,
          tipoMovimientoCaja: true,
          usuario: true,
          desembolsoCredito: true,
        },
      });

      if (!actual) {
        throw DomainError.notFound(
          'Movimiento de caja menor no encontrado',
          'MOVIMIENTO_CAJA_NO_ENCONTRADO',
        );
      }

      const [caja, tipo] = await Promise.all([
        tx.cajaMenor.findUnique({ where: { cajaMenorId: dto.cajaMenorId } }),
        tx.tipoMovimientoCaja.findUnique({
          where: { codigo: dto.tipoMovimientoCodigo },
        }),
      ]);

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

      if (!tipo) {
        throw DomainError.notFound(
          'Tipo de movimiento de caja no encontrado',
          'TIPO_MOVIMIENTO_CAJA_NO_EXISTE',
        );
      }

      const creditoDesembolso =
        actual.desembolsoCredito && this.creditosService
          ? await this.creditosService.obtenerCreditoEditableDesdeDesembolso(
              tx,
              actual.desembolsoCredito.creditoId,
            )
          : null;

      if (creditoDesembolso) {
        this.asegurarPermiso(usuario, 'MODIFICAR_CREDITOS');
      }

      if (creditoDesembolso && tipo.codigo !== 'DESEMBOLSO_CREDITO') {
        throw DomainError.conflict(
          'Los desembolsos de credito deben conservar el tipo de desembolso',
          'DESEMBOLSO_CREDITO_TIPO_NO_EDITABLE',
        );
      }

      if (creditoDesembolso) {
        if (
          caja.responsableUsuarioId !==
          creditoDesembolso.ruta.responsableUsuarioId
        ) {
          throw DomainError.conflict(
            'La caja menor no pertenece al responsable de la ruta',
            'CAJA_MENOR_RUTA_RESPONSABLE_DIFERENTE',
          );
        }

        if (caja.monedaCodigo !== creditoDesembolso.monedaCodigo) {
          throw DomainError.conflict(
            'La moneda de la caja menor no coincide con el credito',
            'CAJA_MENOR_MONEDA_DIFERENTE',
          );
        }
      }

      await this.asegurarPresupuestoDespuesDeCambioMovimientoCaja(tx, actual, {
        cajaMenorId: caja.cajaMenorId,
        monto,
        naturaleza: this.naturalezaMovimientoCaja(tipo),
      });

      const actualizado = await tx.cajaMenorMovimiento.update({
        where: { cajaMenorMovimientoId: id },
        data: {
          cajaMenorId: caja.cajaMenorId,
          tipoMovimientoCajaId: tipo.tipoMovimientoCajaId,
          usuarioId: usuario.usuarioId,
          fechaMovimiento,
          monto: this.decimal(monto),
          motivo,
        },
        include: {
          cajaMenor: true,
          tipoMovimientoCaja: true,
          usuario: true,
          desembolsoCredito: true,
        },
      });

      if (creditoDesembolso && actual.desembolsoCredito && this.creditosService) {
        await this.creditosService.sincronizarCreditoDesdeMovimientoDesembolso(
          tx,
          creditoDesembolso,
          actual.desembolsoCredito.creditoDesembolsoId,
          actualizado,
        );
      }

      await this.registrarAuditoriaMovimientoCaja(tx, {
        cajaMenorId: actual.cajaMenorId,
        cajaMenorMovimientoId: actual.cajaMenorMovimientoId,
        usuarioId: usuario.usuarioId,
        accion: 'MODIFICAR',
        detalle: this.detalleMovimientoCajaModificado(actual, actualizado),
      });

      await this.registrarAuditoria(tx, {
        usuarioId: usuario.usuarioId,
        tabla: 'caja_menor_movimiento',
        registroId: actual.cajaMenorMovimientoId,
        accion: 'MODIFICAR',
        descripcion: this.detalleMovimientoCajaModificado(actual, actualizado),
        valoresAnteriores: {
          cajaMenorId: actual.cajaMenorId,
          tipoMovimientoCodigo: actual.tipoMovimientoCaja.codigo,
          fechaMovimiento: this.fechaIso(actual.fechaMovimiento),
          monto: this.decimalANumero(actual.monto),
          motivo: actual.motivo,
        },
        valoresNuevos: {
          cajaMenorId: actualizado.cajaMenorId,
          tipoMovimientoCodigo: actualizado.tipoMovimientoCaja.codigo,
          fechaMovimiento: this.fechaIso(actualizado.fechaMovimiento),
          monto: this.decimalANumero(actualizado.monto),
          motivo: actualizado.motivo,
        },
      });

      return actualizado;
    });

    this.invalidarCacheLecturas();
    return this.formatearMovimientoCaja(movimiento);
  }

  async eliminarMovimientoCaja(id: string, usuario: AuthenticatedUser) {
    this.asegurarPermiso(usuario, 'ELIMINAR_MOVIMIENTOS');

    if (this.esIdPagoCaja(id)) {
      if (this.pagosService) {
        await this.pagosService.eliminarPagoComoMovimientoCaja(
          this.idPagoDesdeMovimientoCaja(id),
          usuario,
        );
        this.invalidarCacheLecturas();
        return { ok: true };
      }
      throw DomainError.conflict(
        'No se pueden eliminar pagos desde caja menor directamente sin el servicio de pagos',
        'PAGO_ELIMINACION_NO_DISPONIBLE',
      );
    }

    await this.prisma.$transaction(async (tx) => {
      const actual = await tx.cajaMenorMovimiento.findUnique({
        where: { cajaMenorMovimientoId: id },
        include: {
          cajaMenor: true,
          tipoMovimientoCaja: true,
          usuario: true,
          desembolsoCredito: true,
        },
      });

      if (!actual) {
        throw DomainError.notFound(
          'Movimiento de caja menor no encontrado',
          'MOVIMIENTO_CAJA_NO_ENCONTRADO',
        );
      }

      if (actual.desembolsoCredito) {
        if (this.creditosService) {
          this.asegurarPermiso(usuario, 'ELIMINAR_CREDITOS');
          await this.creditosService.eliminarCreditoDesdeMovimientoDesembolso(
            tx,
            actual,
            actual.desembolsoCredito.creditoId,
            usuario,
          );
          return;
        }
      }

      await this.asegurarPresupuestoDespuesDeCambioMovimientoCaja(tx, actual);

      await this.registrarAuditoriaMovimientoCaja(tx, {
        cajaMenorId: actual.cajaMenorId,
        cajaMenorMovimientoId: actual.cajaMenorMovimientoId,
        usuarioId: usuario.usuarioId,
        accion: 'ELIMINAR',
        detalle: this.detalleMovimientoCajaEliminado(actual),
      });

      await this.registrarAuditoria(tx, {
        usuarioId: usuario.usuarioId,
        tabla: 'caja_menor_movimiento',
        registroId: actual.cajaMenorMovimientoId,
        accion: 'ELIMINAR',
        descripcion: this.detalleMovimientoCajaEliminado(actual),
        valoresAnteriores: {
          cajaMenorId: actual.cajaMenorId,
          tipoMovimientoCodigo: actual.tipoMovimientoCaja.codigo,
          fechaMovimiento: this.fechaIso(actual.fechaMovimiento),
          monto: this.decimalANumero(actual.monto),
          motivo: actual.motivo,
        },
      });

      await tx.cajaMenorMovimiento.delete({
        where: { cajaMenorMovimientoId: id },
      });
    });

    this.invalidarCacheLecturas();
    return { ok: true };
  }

  async registrarMovimientoDesembolsoTbl(
    tx: PrismaExecutor,
    input: {
      monto: number;
      creditoId: string;
      fecha: Date;
      organizacionId: string;
      usuarioId: string;
      sesionId: string;
    },
  ) {
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
        ${input.fecha},
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
}
