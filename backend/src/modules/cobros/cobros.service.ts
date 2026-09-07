import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Workbook, type Worksheet } from 'exceljs';
import { Buffer } from 'node:buffer';
import { randomUUID } from 'node:crypto';

import { cacheKeyFromCriteria } from '../../common/cache/cache-key';
import { InMemoryCacheService } from '../../common/cache/in-memory-cache.service';
import { DomainError } from '../../common/domain/domain-error';
import { PrismaService } from '../../common/prisma/prisma.service';
import { AuthenticatedUser } from '../auth/auth.types';
import {
  permisosEmpleadoPorCodigo,
  type PermisoEmpleadoCodigo,
} from '../auth/permissions';
import { NotificationsService } from '../notifications/notifications.service';
import {
  ActualizarClienteDto,
  ActualizarCreditoDto,
  ActualizarUbicacionClienteDto,
  ActualizarMovimientoCajaDto,
  CrearCajaMenorDto,
  CrearClienteDto,
  CrearCreditoDto,
  CrearMovimientoCajaDto,
  ExportarMovimientosCajaQueryDto,
  ListarClientesQueryDto,
  ListarCobrosRutaQueryDto,
  ListarCreditosQueryDto,
  ListarMovimientosCajaQueryDto,
  ObtenerPresupuestoQueryDto,
  RegistrarPagoDto,
  RefinanciarCreditoDto,
} from './dto';
import { ExportacionesR2Service } from './exportaciones-r2.service';

type ClienteConRelaciones = Prisma.ClienteGetPayload<{
  include: {
    estadoCliente: true;
    contactos: { include: { tipoContacto: true } };
    documentos: { include: { tipoDocumento: true } };
    direcciones: { include: { tipoDireccion: true } };
  };
}>;

type CreditoCuotaParaPago = Prisma.CreditoCuotaGetPayload<{
  include: {
    estadoCuota: true;
    planPago: {
      include: {
        credito: {
          include: {
            ruta: true;
            cliente: true;
          };
        };
      };
    };
  };
}>;

type CobroRutaRow = {
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

type CreditoListadoRow = {
  credito_id: string;
  cliente_id: string;
  cliente: string;
  cedula: string | null;
  negocio: string | null;
  direccion: string | null;
  ruta_id: string;
  ruta: string;
  caja_menor_id: string | null;
  caja_menor: string | null;
  moneda_codigo: string;
  frecuencia_pago_id: number;
  frecuencia_codigo: string;
  frecuencia_nombre: string;
  dias_intervalo: number;
  estado_codigo: string;
  estado_nombre: string;
  valor_principal: Prisma.Decimal;
  porcentaje_interes: Prisma.Decimal;
  plazo_dias: number;
  omitir_domingos: boolean;
  valor_total: Prisma.Decimal;
  valor_cuota: Prisma.Decimal;
  total_abonado: Prisma.Decimal;
  saldo: Prisma.Decimal;
  numero_cuotas: number;
  cuotas_restantes: number;
  fecha_inicio: Date;
  fecha_maxima: Date;
  refinanciado_en: Date | null;
  valor_principal_anterior: Prisma.Decimal | null;
  valor_principal_refinanciado: Prisma.Decimal | null;
  observacion: string | null;
  creado_en: Date;
  actualizado_en: Date;
};

type CreditoConteoRow = {
  total: number;
  activos: number;
  inactivos: number;
};

type PresupuestoRow = {
  caja_menor_id: string;
  caja_menor_nombre: string;
  responsable_usuario_id: string;
  moneda_codigo: string;
  caja_menor: Prisma.Decimal;
  recaudado: Prisma.Decimal;
  gastos: Prisma.Decimal;
  creditos: Prisma.Decimal;
  presupuesto: Prisma.Decimal;
};

type PresupuestoDisponibleRow = {
  presupuesto: Prisma.Decimal;
};

type ResumenCreditoRow = {
  total_abonado: Prisma.Decimal;
  cuotas_restantes: number;
};

type PagoTblRow = {
  pago_id: string;
  credito_id: string;
  cliente_id: string;
  cliente: string;
  ruta_id: string | null;
  ruta: string | null;
  medio_pago_id: string;
  medio_pago_codigo: string;
  medio_pago_nombre: string;
  moneda_codigo: string;
  fecha_pago: Date;
  total_pagado: Prisma.Decimal;
  referencia_externa: string | null;
};

type PagoAplicacionTblRow = {
  aplicacion_id: string;
  credito_cuota_id: string;
  numero_cuota: number;
  monto_capital: Prisma.Decimal;
  monto_interes: Prisma.Decimal;
  monto_mora: Prisma.Decimal;
  monto_descuento: Prisma.Decimal;
};

type EsquemaTblDisponibleRow = {
  disponible: boolean;
};

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
  usuario_id: string;
  usuario: string;
  nombres: string;
  apellidos: string;
  correo: string;
  telefono: string | null;
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

type ClienteTblRow = {
  id: string;
  nombre_completo: string;
  nombre_comercial: string | null;
  notas: string | null;
  cedula: string;
  direccion: string | null;
  correo?: string | null;
  latitud: Prisma.Decimal | null;
  longitud: Prisma.Decimal | null;
  telefono: string | null;
  creado_en: Date;
  actualizado_en: Date;
  activo: boolean;
};

type ClienteUbicacionTblRow = {
  persona_id: string;
  direccion: string | null;
};

type ClienteTblDetalleRow = ClienteTblRow & {
  persona_id: string;
};

type OrganizacionScopeTbl = {
  usuarioId: string;
  organizacionId: string;
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

type CuotaCreditoTblRow = {
  credito_cuota_id: string;
  numero_cuota: number;
  fecha_vencimiento: Date;
  estado_codigo: string;
  estado_nombre: string;
  valor_capital: Prisma.Decimal;
  valor_interes: Prisma.Decimal;
  valor_total: Prisma.Decimal;
  abonado: Prisma.Decimal;
  saldo: Prisma.Decimal;
};

type CreditoTblRow = {
  credito_id: string;
  cliente_id: string;
  cliente: string;
  cedula: string | null;
  negocio: string | null;
  direccion: string | null;
  ruta_id: string | null;
  ruta: string | null;
  caja_menor_id: string | null;
  caja_menor: string | null;
  moneda_codigo: string;
  frecuencia_id: string;
  frecuencia_codigo: string;
  frecuencia_nombre: string;
  estado_codigo: string;
  fecha_inicio: Date;
  fecha_fin: Date;
  valor_principal: Prisma.Decimal;
  porcentaje_interes: Prisma.Decimal;
  interes_total: Prisma.Decimal;
  valor_total: Prisma.Decimal;
  numero_cuotas: number;
  valor_cuota: Prisma.Decimal;
  total_abonado: Prisma.Decimal;
  cuotas_restantes: number;
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

type PresupuestoTblRow = {
  caja_menor_id: string;
  caja_menor_nombre: string;
  responsable_usuario_id: string;
  moneda_codigo: string;
  caja_menor: Prisma.Decimal;
  recaudado: Prisma.Decimal;
  gastos: Prisma.Decimal;
  creditos: Prisma.Decimal;
  presupuesto: Prisma.Decimal;
};

type CajaResumenPago = {
  cajaMenorId: string;
  nombre: string;
  responsableUsuarioId: string;
  monedaCodigo: string;
};

type CuotaCreditoRow = {
  credito_cuota_id: string;
  numero_cuota: number;
  fecha_vencimiento: Date;
  estado_codigo: string;
  estado_nombre: string;
  valor_capital: Prisma.Decimal;
  valor_interes: Prisma.Decimal;
  valor_total: Prisma.Decimal;
  abonado: Prisma.Decimal;
  saldo: Prisma.Decimal;
};

type PlanCalculado = {
  numeroCuotas: number;
  valorCuota: number;
  valorTotal: number;
  fechaMaxima: Date;
  domingosOmitidos: number;
  cuotas: Array<{
    numeroCuota: number;
    fechaVencimiento: Date;
    valorCapital: number;
    valorInteres: number;
  }>;
};

type SumaAplicaciones = {
  _sum: {
    montoCapital: Prisma.Decimal | null;
    montoInteres: Prisma.Decimal | null;
    montoMora: Prisma.Decimal | null;
    montoDescuento: Prisma.Decimal | null;
  };
};

type PrismaExecutor = Pick<
  Prisma.TransactionClient,
  '$executeRaw' | '$queryRaw'
>;

type MovimientoCajaConRelaciones = Prisma.CajaMenorMovimientoGetPayload<{
  include: {
    cajaMenor: true;
    tipoMovimientoCaja: true;
    usuario: true;
  };
}>;

type CobroRutaExportado = {
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
  proximoSaldoCuota: number;
  estadoCobro: string;
};

type CreditoExportado = {
  id: string;
  cliente: string;
  cedula: string | null;
  negocio: string | null;
  direccion: string | null;
  ruta: string;
  cajaMenor: string | null;
  monedaCodigo: string;
  frecuenciaPago: { nombre: string };
  estado: { codigo: string; nombre: string };
  valorPrincipal: number;
  porcentajeInteres: number;
  plazoDias: number;
  valorTotal: number;
  valorCuota: number;
  totalAbonado: number;
  saldo: number;
  numeroCuotas: number;
  cuotasRestantes: number;
  fechaInicio: string;
  fechaMaxima: string;
  refinanciacion: {
    valorAnterior: number;
    valorNuevo: number;
    fecha: string;
  } | null;
  observacion: string | null;
  creadoEn: string;
};

type MovimientoCajaExportado = {
  cajaMenor: string;
  cliente: string | null;
  clienteIdentificacion: string | null;
  tipoMovimiento: {
    codigo: string;
    nombre: string;
    naturaleza: string;
  };
  usuario: { nombreCompleto: string } | null;
  fechaMovimiento: string;
  monto: number;
  montoConNaturaleza: number;
  motivo: string;
  referenciaTabla: string | null;
  creadoEn: string;
};

type ExportacionExcel = {
  archivo: string;
  key: string;
  url: string;
  filas: number;
  generadoEn: string;
  vistaPrevia: ExportacionVistaPrevia;
};

type ExportacionVistaPrevia = {
  columnas: string[];
  filas: Array<Array<string | number | null>>;
};

type ColumnaExportacion = {
  header: string;
  key: string;
  width: number;
};

type FilaExportacion = Record<string, string | number | null | undefined>;

type PaginaRespuesta<T> = {
  items: T[];
  limit: number;
  offset: number;
  nextOffset: number | null;
  hasMore: boolean;
};

const maxExportRows = 10_000;
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
export class CobrosService {
  private esquemaTblDisponible?: boolean;
  private readonly tablaExisteCache = new Map<string, boolean>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly exportacionesR2: ExportacionesR2Service,
    private readonly cache: InMemoryCacheService,
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

  async obtenerCatalogos(usuario: AuthenticatedUser) {
    if (await this.usarEsquemaTbl()) {
      return this.obtenerCatalogosTbl(usuario);
    }

    const puedeVerTodo = this.puedeVerDatosOrganizacion(usuario);
    const [
      monedas,
      frecuenciasPago,
      mediosPago,
      tiposMovimientoCaja,
      categoriasGasto,
      rutas,
      cajasMenores,
      usuarios,
    ] = await Promise.all([
      this.prisma.moneda.findMany({ orderBy: { codigoMoneda: 'asc' } }),
      this.prisma.frecuenciaPago.findMany({
        orderBy: { diasIntervalo: 'asc' },
      }),
      this.prisma.medioPago.findMany({ orderBy: { medioPagoId: 'asc' } }),
      this.prisma.tipoMovimientoCaja.findMany({
        orderBy: { tipoMovimientoCajaId: 'asc' },
      }),
      this.prisma.categoriaGasto.findMany({ orderBy: { nombre: 'asc' } }),
      this.prisma.ruta.findMany({
        where: puedeVerTodo
          ? undefined
          : { responsableUsuarioId: usuario.usuarioId },
        include: {
          estadoRuta: true,
          responsable: true,
          _count: { select: { clientes: true, creditos: true } },
        },
        orderBy: [{ esPrincipal: 'desc' }, { nombre: 'asc' }],
      }),
      this.prisma.cajaMenor.findMany({
        where: puedeVerTodo
          ? undefined
          : { responsableUsuarioId: usuario.usuarioId },
        include: { responsable: true, moneda: true },
        orderBy: [{ activa: 'desc' }, { nombre: 'asc' }],
      }),
      this.prisma.usuario.findMany({
        where: puedeVerTodo ? undefined : { usuarioId: usuario.usuarioId },
        orderBy: [{ nombres: 'asc' }],
      }),
    ]);

    return {
      monedas: monedas.map((moneda) => ({
        codigo: moneda.codigoMoneda,
        nombre: moneda.nombre,
        simbolo: moneda.simbolo,
        decimales: moneda.decimales,
      })),
      frecuenciasPago: frecuenciasPago.map((frecuencia) => ({
        id: frecuencia.frecuenciaPagoId,
        codigo: frecuencia.codigo,
        nombre: frecuencia.nombre,
        diasIntervalo: frecuencia.diasIntervalo,
      })),
      mediosPago: mediosPago.map((medio) => ({
        id: medio.medioPagoId,
        codigo: medio.codigo,
        nombre: medio.nombre,
      })),
      tiposMovimientoCaja: tiposMovimientoCaja.map((tipo) => ({
        id: tipo.tipoMovimientoCajaId,
        codigo: tipo.codigo,
        nombre: tipo.nombre,
        naturaleza: this.naturalezaMovimientoCaja(tipo),
      })),
      categoriasGasto: categoriasGasto.map((categoria) => ({
        id: categoria.categoriaGastoId,
        codigo: categoria.codigo,
        nombre: categoria.nombre,
        activa: categoria.activa,
      })),
      rutas: rutas.map((ruta) => ({
        id: ruta.rutaId,
        nombre: ruta.nombre,
        descripcion: ruta.descripcion,
        esPrincipal: ruta.esPrincipal,
        estado: {
          codigo: ruta.estadoRuta.codigo,
          nombre: ruta.estadoRuta.nombre,
        },
        responsable: this.formatearUsuario(ruta.responsable),
        clientes: ruta._count.clientes,
        creditos: ruta._count.creditos,
      })),
      cajasMenores: cajasMenores.map((caja) => ({
        id: caja.cajaMenorId,
        nombre: caja.nombre,
        activa: caja.activa,
        monedaCodigo: caja.monedaCodigo,
        fechaApertura: caja.fechaApertura.toISOString(),
        fechaCierre: caja.fechaCierre?.toISOString() ?? null,
        responsable: this.formatearUsuario(caja.responsable),
      })),
      usuarios: usuarios.map((usuario) => this.formatearUsuario(usuario)),
    };
  }

  async listarClientes(
    query: ListarClientesQueryDto,
    usuario: AuthenticatedUser,
  ) {
    if (await this.usarEsquemaTbl()) {
      return this.listarClientesTbl(query, usuario);
    }

    const search = this.normalizarTextoOpcional(query.search);
    const where: Prisma.ClienteWhereInput = this.puedeVerDatosOrganizacion(
      usuario,
    )
      ? {}
      : { creadoPorUsuarioId: usuario.usuarioId };

    if (search) {
      where.OR = [
        { nombreCompleto: { contains: search, mode: 'insensitive' } },
        { nombreComercial: { contains: search, mode: 'insensitive' } },
        {
          contactos: {
            some: { valor: { contains: search, mode: 'insensitive' } },
          },
        },
        {
          documentos: { some: { numeroDocumento: { contains: search } } },
        },
        {
          direcciones: {
            some: { direccion: { contains: search, mode: 'insensitive' } },
          },
        },
      ];
    }

    const clientes = await this.prisma.cliente.findMany({
      where,
      include: {
        estadoCliente: true,
        contactos: { include: { tipoContacto: true } },
        documentos: { include: { tipoDocumento: true } },
        direcciones: { include: { tipoDireccion: true } },
      },
      orderBy: { nombreCompleto: 'asc' },
    });

    return clientes.map((cliente) => this.formatearCliente(cliente));
  }

  async crearCliente(dto: CrearClienteDto, usuario: AuthenticatedUser) {
    const nombreCompleto = this.requerirTexto(
      dto.nombreCompleto,
      'El nombre del cliente es obligatorio',
    );
    const cedula = this.normalizarTextoOpcional(dto.cedula);
    const nombreComercial = this.normalizarTextoOpcional(dto.nombreComercial);
    const direccion = this.normalizarTextoOpcional(dto.direccion);
    const latitud = dto.latitud;
    const longitud = dto.longitud;
    if (
      [latitud, longitud].some(
        (value: unknown) =>
          value !== undefined &&
          (typeof value !== 'number' || !Number.isFinite(value)),
      )
    ) {
      throw DomainError.validation(
        'Las coordenadas deben ser números finitos',
        'COORDENADAS_INVALIDAS',
      );
    }
    if ((latitud === undefined) !== (longitud === undefined)) {
      throw DomainError.validation(
        'La latitud y la longitud deben enviarse juntas',
        'COORDENADAS_INCOMPLETAS',
      );
    }
    if (latitud !== undefined && !direccion) {
      throw DomainError.validation(
        'La dirección es obligatoria cuando se envían coordenadas',
        'DIRECCION_COORDENADAS_REQUERIDA',
      );
    }
    const notas = this.normalizarTextoOpcional(dto.notas);
    const correo = this.normalizarCorreo(dto.correo);
    const telefono = this.normalizarTextoOpcional(dto.telefono);
    const whatsapp = this.normalizarTextoOpcional(dto.whatsapp);

    if (await this.usarEsquemaTbl()) {
      return this.crearClienteTbl(
        {
          nombreCompleto,
          cedula,
          nombreComercial,
          direccion,
          notas,
          correo,
          telefono,
          whatsapp,
          latitud,
          longitud,
        },
        usuario,
      );
    }

    const cliente = await this.prisma.$transaction(async (tx) => {
      const estadoActivo = await tx.estadoCliente.findUnique({
        where: { codigo: 'ACTIVO' },
      });

      if (!estadoActivo) {
        throw DomainError.notFound(
          'No existe el estado de cliente ACTIVO en los catalogos',
          'ESTADO_CLIENTE_ACTIVO_NO_EXISTE',
        );
      }

      const created = await tx.cliente.create({
        data: {
          estadoClienteId: estadoActivo.estadoClienteId,
          creadoPorUsuarioId: usuario.usuarioId,
          nombreCompleto,
          nombreComercial,
          notas,
        },
      });

      await this.crearDocumentoCliente(tx, created.clienteId, 'CC', cedula);
      await this.crearContactoCliente(tx, created.clienteId, 'CORREO', correo);
      await this.crearContactoCliente(
        tx,
        created.clienteId,
        'TELEFONO',
        telefono,
      );
      await this.crearContactoCliente(
        tx,
        created.clienteId,
        'WHATSAPP',
        whatsapp,
      );
      await this.crearDireccionCliente(
        tx,
        created.clienteId,
        direccion,
        latitud,
        longitud,
      );

      const completo = await tx.cliente.findUnique({
        where: { clienteId: created.clienteId },
        include: {
          estadoCliente: true,
          contactos: { include: { tipoContacto: true } },
          documentos: { include: { tipoDocumento: true } },
          direcciones: { include: { tipoDireccion: true } },
        },
      });

      if (!completo) {
        throw DomainError.notFound(
          'Cliente no encontrado despues de crear',
          'CLIENTE_NO_ENCONTRADO',
        );
      }

      return completo;
    });

    return this.formatearCliente(cliente);
  }

  async actualizarCliente(
    clienteId: string,
    dto: ActualizarClienteDto,
    usuario: AuthenticatedUser,
  ) {
    this.asegurarAdministrador(usuario);

    if (await this.usarEsquemaTbl()) {
      return this.actualizarClienteTbl(clienteId, dto, usuario);
    }

    const nombreCompleto = this.requerirTexto(
      dto.nombreCompleto,
      'El nombre del cliente es obligatorio',
    );
    const cedula = this.normalizarTextoOpcional(dto.cedula);
    const nombreComercial = this.normalizarTextoOpcional(dto.nombreComercial);
    const direccion = this.normalizarTextoOpcional(dto.direccion);
    const notas = this.normalizarTextoOpcional(dto.notas);
    const correo = this.normalizarCorreo(dto.correo);
    const telefono = this.normalizarTextoOpcional(dto.telefono);
    const whatsapp = this.normalizarTextoOpcional(dto.whatsapp);
    const latitud = dto.latitud;
    const longitud = dto.longitud;
    if (
      [latitud, longitud].some(
        (value: unknown) =>
          value !== undefined &&
          (typeof value !== 'number' || !Number.isFinite(value)),
      )
    ) {
      throw DomainError.validation(
        'Las coordenadas deben ser números finitos',
        'COORDENADAS_INVALIDAS',
      );
    }
    if ((latitud === undefined) !== (longitud === undefined)) {
      throw DomainError.validation(
        'La latitud y la longitud deben enviarse juntas',
        'COORDENADAS_INCOMPLETAS',
      );
    }
    if (latitud !== undefined && !direccion) {
      throw DomainError.validation(
        'La dirección es obligatoria cuando se envían coordenadas',
        'DIRECCION_COORDENADAS_REQUERIDA',
      );
    }

    await this.prisma.$transaction(
      async (tx) => {
        const actual = await tx.cliente.findUnique({
          where: { clienteId },
          include: {
            estadoCliente: true,
            contactos: { include: { tipoContacto: true } },
            documentos: { include: { tipoDocumento: true } },
            direcciones: { include: { tipoDireccion: true } },
          },
        });

        if (!actual) {
          throw DomainError.notFound(
            'Cliente no encontrado',
            'CLIENTE_NO_ENCONTRADO',
          );
        }

        await tx.cliente.update({
          where: { clienteId },
          data: {
            nombreCompleto,
            nombreComercial,
            notas,
            actualizadoEn: new Date(),
          },
        });

        await this.reemplazarDocumentoCliente(tx, clienteId, 'CC', cedula);
        await this.reemplazarContactoCliente(tx, clienteId, 'CORREO', correo);
        await this.reemplazarContactoCliente(
          tx,
          clienteId,
          'TELEFONO',
          telefono,
        );
        await this.reemplazarContactoCliente(
          tx,
          clienteId,
          'WHATSAPP',
          whatsapp,
        );
        const direccionPrincipal =
          actual.direcciones.find((item) => item.esPrincipal) ??
          actual.direcciones[0];
        const latitudFinal =
          latitud ??
          (direccionPrincipal?.latitud === null ||
          direccionPrincipal?.latitud === undefined
            ? null
            : this.decimalANumero(direccionPrincipal.latitud));
        const longitudFinal =
          longitud ??
          (direccionPrincipal?.longitud === null ||
          direccionPrincipal?.longitud === undefined
            ? null
            : this.decimalANumero(direccionPrincipal.longitud));
        await this.reemplazarDireccionCliente(
          tx,
          clienteId,
          direccion,
          latitudFinal,
          longitudFinal,
        );

        await this.registrarAuditoria(tx, {
          usuarioId: usuario.usuarioId,
          tabla: 'cliente',
          registroId: clienteId,
          accion: 'MODIFICAR',
          descripcion: `Se modifico cliente ${actual.nombreCompleto}`,
          valoresAnteriores: this.formatearCliente(actual),
          valoresNuevos: {
            nombreCompleto,
            cedula,
            nombreComercial,
            direccion,
            notas,
            correo,
            telefono,
            whatsapp,
            latitud: latitudFinal,
            longitud: longitudFinal,
          },
        });
      },
      { maxWait: 10_000, timeout: 10_000 },
    );

    const cliente = await this.prisma.cliente.findUnique({
      where: { clienteId },
      include: {
        estadoCliente: true,
        contactos: { include: { tipoContacto: true } },
        documentos: { include: { tipoDocumento: true } },
        direcciones: { include: { tipoDireccion: true } },
      },
    });

    if (!cliente) {
      throw DomainError.notFound(
        'Cliente no encontrado despues de modificar',
        'CLIENTE_NO_ENCONTRADO',
      );
    }

    this.invalidarCacheLecturas();
    return this.formatearCliente(cliente);
  }

  async eliminarCliente(clienteId: string, usuario: AuthenticatedUser) {
    this.asegurarAdministrador(usuario);

    if (await this.usarEsquemaTbl()) {
      return this.eliminarClienteTbl(clienteId, usuario);
    }

    await this.prisma.$transaction(async (tx) => {
      const cliente = await tx.cliente.findUnique({
        where: { clienteId },
        include: {
          estadoCliente: true,
          contactos: { include: { tipoContacto: true } },
          documentos: { include: { tipoDocumento: true } },
          direcciones: { include: { tipoDireccion: true } },
        },
      });

      if (!cliente) {
        throw DomainError.notFound(
          'Cliente no encontrado',
          'CLIENTE_NO_ENCONTRADO',
        );
      }

      const [creditos, pagos] = await Promise.all([
        tx.credito.count({ where: { clienteId } }),
        tx.pago.count({ where: { clienteId } }),
      ]);

      if (creditos > 0 || pagos > 0) {
        throw DomainError.conflict(
          'No se puede eliminar un cliente con creditos o pagos registrados',
          'CLIENTE_CON_MOVIMIENTOS_NO_ELIMINABLE',
        );
      }

      await this.registrarAuditoria(tx, {
        usuarioId: usuario.usuarioId,
        tabla: 'cliente',
        registroId: clienteId,
        accion: 'ELIMINAR',
        descripcion: `Se elimino cliente ${cliente.nombreCompleto}`,
        valoresAnteriores: this.formatearCliente(cliente),
      });

      await tx.rutaCliente.deleteMany({ where: { clienteId } });
      await tx.cliente.delete({ where: { clienteId } });
    });

    this.invalidarCacheLecturas();
    return { ok: true };
  }

  async actualizarUbicacionCliente(
    clienteId: string,
    dto: ActualizarUbicacionClienteDto,
    usuario: AuthenticatedUser,
  ) {
    if (
      !Number.isFinite(dto.latitud) ||
      !Number.isFinite(dto.longitud) ||
      dto.latitud < -90 ||
      dto.latitud > 90 ||
      dto.longitud < -180 ||
      dto.longitud > 180
    ) {
      throw DomainError.validation(
        'Las coordenadas no son válidas',
        'COORDENADAS_INVALIDAS',
      );
    }

    if (await this.usarEsquemaTbl()) {
      return this.actualizarUbicacionClienteTbl(clienteId, dto, usuario);
    }

    const direccionSolicitada = this.normalizarTextoOpcional(dto.direccion);
    return this.prisma.$transaction(async (tx) => {
      const cliente = await tx.cliente.findUnique({
        where: { clienteId },
        include: {
          direcciones: {
            orderBy: [{ esPrincipal: 'desc' }, { direccion: 'asc' }],
          },
        },
      });
      if (!cliente) {
        throw DomainError.notFound(
          'Cliente no encontrado',
          'CLIENTE_NO_ENCONTRADO',
        );
      }

      if (!this.esAdministrador(usuario)) {
        const creditoVisible = await tx.credito.findFirst({
          where: {
            clienteId,
            OR: [
              { creadoPorUsuarioId: usuario.usuarioId },
              { ruta: { responsableUsuarioId: usuario.usuarioId } },
            ],
          },
          select: { creditoId: true },
        });
        if (!creditoVisible) {
          throw new ForbiddenException('No tienes acceso a este cliente');
        }
      }

      const direccionActual = cliente.direcciones[0];
      const direccion = direccionSolicitada ?? direccionActual?.direccion;
      if (!direccion) {
        throw DomainError.validation(
          'La dirección es obligatoria para guardar la ubicación',
          'DIRECCION_COORDENADAS_REQUERIDA',
        );
      }

      if (direccionActual) {
        await tx.clienteDireccion.update({
          where: {
            clienteDireccionId: direccionActual.clienteDireccionId,
          },
          data: {
            direccion,
            latitud: dto.latitud,
            longitud: dto.longitud,
            esPrincipal: true,
          },
        });
      } else {
        const tipoDireccion = await tx.tipoDireccion.findUnique({
          where: { codigo: 'CASA' },
        });
        if (!tipoDireccion) {
          throw DomainError.notFound(
            'No existe el tipo de dirección CASA',
            'TIPO_DIRECCION_NO_EXISTE',
          );
        }
        await tx.clienteDireccion.create({
          data: {
            clienteId,
            tipoDireccionId: tipoDireccion.tipoDireccionId,
            direccion,
            municipio: 'No especificado',
            departamento: 'No especificado',
            latitud: dto.latitud,
            longitud: dto.longitud,
            esPrincipal: true,
          },
        });
      }

      return {
        clienteId,
        direccion,
        latitud: dto.latitud,
        longitud: dto.longitud,
      };
    });
  }

  private async actualizarUbicacionClienteTbl(
    clienteId: string,
    dto: ActualizarUbicacionClienteDto,
    usuario: AuthenticatedUser,
  ) {
    const scope = await this.obtenerScopeOrganizacionTbl(usuario);
    const rows = await this.prisma.$queryRaw<
      ClienteUbicacionTblRow[]
    >(Prisma.sql`
      SELECT
        p.id_per::text AS persona_id,
        p.per_direccion AS direccion
      FROM public.tbl_clientes c
      JOIN public.tbl_personas p ON p.id_per = c.cli_persona
      WHERE c.id_cli::text = ${clienteId}
        AND c.org_id = ${scope.organizacionId}::uuid
        AND ${
          this.esAdministrador(usuario)
            ? Prisma.sql`TRUE`
            : Prisma.sql`(
              EXISTS (
                SELECT 1
                FROM public.tbl_creditos cr
                JOIN public.tbl_usuarios tu ON tu.id_usu = cr.usu_id
                WHERE cr.cli_id = c.id_cli
                  AND UPPER(cr.cre_estado::text) <> 'ANULADO'
                  AND tu.usu_usuario = ${usuario.usuario}
              )
              OR EXISTS (
                SELECT 1
                FROM public.tbl_rutas_clientes rc
                JOIN public.tbl_rutas r ON r.id_rut = rc.rut_id
                JOIN public.tbl_usuarios tu ON tu.id_usu = r.usu_id
                WHERE rc.cli_id = c.id_cli
                  AND r.org_id = c.org_id
                  AND rc.rcl_activo
                  AND tu.usu_usuario = ${usuario.usuario}
              )
            )`
        }
      LIMIT 1
    `);
    const cliente = rows[0];
    if (!cliente) {
      throw DomainError.notFound(
        'Cliente no encontrado',
        'CLIENTE_NO_ENCONTRADO',
      );
    }

    const direccion =
      this.normalizarTextoOpcional(dto.direccion) ?? cliente.direccion;
    if (!direccion) {
      throw DomainError.validation(
        'La dirección es obligatoria para guardar la ubicación',
        'DIRECCION_COORDENADAS_REQUERIDA',
      );
    }

    await this.prisma.$executeRaw(Prisma.sql`
      UPDATE public.tbl_personas
      SET
        per_direccion = ${direccion},
        per_latitud = ${dto.latitud},
        per_longitud = ${dto.longitud}
      WHERE id_per::text = ${cliente.persona_id}
    `);

    return {
      clienteId,
      direccion,
      latitud: dto.latitud,
      longitud: dto.longitud,
    };
  }

  async listarRutas(usuario: AuthenticatedUser) {
    if (await this.usarEsquemaTbl()) {
      return this.listarRutasTbl(usuario);
    }

    const rutas = await this.prisma.ruta.findMany({
      where: this.puedeVerDatosOrganizacion(usuario)
        ? undefined
        : { responsableUsuarioId: usuario.usuarioId },
      include: {
        estadoRuta: true,
        responsable: true,
        _count: { select: { clientes: true, creditos: true } },
      },
      orderBy: [{ esPrincipal: 'desc' }, { nombre: 'asc' }],
    });

    return rutas.map((ruta) => ({
      id: ruta.rutaId,
      nombre: ruta.nombre,
      descripcion: ruta.descripcion,
      esPrincipal: ruta.esPrincipal,
      estado: {
        codigo: ruta.estadoRuta.codigo,
        nombre: ruta.estadoRuta.nombre,
      },
      responsable: this.formatearUsuario(ruta.responsable),
      clientes: ruta._count.clientes,
      creditos: ruta._count.creditos,
    }));
  }

  async listarCobrosRuta(
    query: ListarCobrosRutaQueryDto,
    usuario: AuthenticatedUser,
    limit?: number,
  ) {
    if (await this.usarEsquemaTbl()) {
      return this.listarCobrosRutaTbl(query, usuario, limit);
    }

    const conditions: Prisma.Sql[] = [Prisma.sql`ecr.codigo <> 'ANULADO'`];
    const search = this.normalizarTextoOpcional(query.search);

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      conditions.push(
        Prisma.sql`c.creado_por_usuario_id = ${usuario.usuarioId}::uuid`,
      );
    }

    if (query.rutaId) {
      conditions.push(Prisma.sql`c.ruta_id = ${query.rutaId}::uuid`);
    }

    if (query.estadoCobro === 'PAGADO') {
      conditions.push(Prisma.sql`(
        ecr.codigo = 'PAGADO'
        OR COALESCE(rp.cuotas_restantes, 0) <= 0
        OR (cpp.valor_total - COALESCE(rp.total_abonado, 0)) <= 0
      )`);
    } else if (query.estadoCobro === 'ATRASADO') {
      conditions.push(Prisma.sql`
        ecr.codigo <> 'PAGADO'
        AND
        COALESCE(rp.cuotas_restantes, 0) > 0
        AND
        (cpp.valor_total - COALESCE(rp.total_abonado, 0)) > 0
        AND prox.fecha_vencimiento < CURRENT_DATE
      `);
    } else if (query.estadoCobro === 'PENDIENTE') {
      conditions.push(Prisma.sql`
        ecr.codigo <> 'PAGADO'
        AND
        COALESCE(rp.cuotas_restantes, 0) > 0
        AND
        (cpp.valor_total - COALESCE(rp.total_abonado, 0)) > 0
        AND prox.fecha_vencimiento = CURRENT_DATE
      `);
    } else if (query.estadoCobro === 'AL_DIA') {
      conditions.push(Prisma.sql`
        ecr.codigo <> 'PAGADO'
        AND
        COALESCE(rp.cuotas_restantes, 0) > 0
        AND
        (cpp.valor_total - COALESCE(rp.total_abonado, 0)) > 0
        AND prox.fecha_vencimiento > CURRENT_DATE
      `);
    }

    if (search) {
      const pattern = `%${search}%`;
      conditions.push(
        Prisma.sql`(
          cl.nombre_completo ILIKE ${pattern}
          OR cl.nombre_comercial ILIKE ${pattern}
          OR r.nombre ILIKE ${pattern}
          OR EXISTS (
            SELECT 1
            FROM public.cliente_direccion cd_busqueda
            WHERE cd_busqueda.cliente_id = cl.cliente_id
              AND cd_busqueda.direccion ILIKE ${pattern}
          )
          OR EXISTS (
            SELECT 1
            FROM public.cliente_documento cd_busqueda
            WHERE cd_busqueda.cliente_id = cl.cliente_id
              AND cd_busqueda.numero_documento ILIKE ${pattern}
          )
        )`,
      );
    }

    const rows = await this.prisma.$queryRaw<CobroRutaRow[]>(Prisma.sql`
      WITH abonos_cuota AS (
        SELECT
          cc.credito_cuota_id,
          COALESCE(
            SUM(
              pa.monto_capital
              + pa.monto_interes
              + pa.monto_mora
              - pa.monto_descuento
            ),
            0
          ) AS abonado
        FROM public.credito_cuota cc
        LEFT JOIN public.pago_aplicacion pa
          ON pa.credito_cuota_id = cc.credito_cuota_id
        GROUP BY cc.credito_cuota_id
      ),
      resumen_plan AS (
        SELECT
          cc.credito_plan_pago_id,
          COALESCE(SUM(ac.abonado), 0) AS total_abonado,
          COUNT(*) FILTER (
            WHERE ecu.codigo NOT IN ('PAGADA', 'ANULADA')
              AND (cc.valor_total - COALESCE(ac.abonado, 0)) > 0
          )::int AS cuotas_restantes
        FROM public.credito_cuota cc
        JOIN public.estado_cuota ecu
          ON ecu.estado_cuota_id = cc.estado_cuota_id
        LEFT JOIN abonos_cuota ac
          ON ac.credito_cuota_id = cc.credito_cuota_id
        GROUP BY cc.credito_plan_pago_id
      )
      SELECT
        c.credito_id,
        cl.cliente_id,
        cl.nombre_completo AS cliente,
        doc_cc.numero_documento AS cedula,
        cl.nombre_comercial AS negocio,
        dir_principal.direccion,
        dir_principal.latitud,
        dir_principal.longitud,
        r.ruta_id,
        r.nombre AS ruta,
        c.moneda_codigo,
        c.valor_principal,
        cpp.valor_total,
        cpp.valor_cuota,
        COALESCE(rp.total_abonado, 0) AS total_abonado,
        GREATEST(cpp.valor_total - COALESCE(rp.total_abonado, 0), 0) AS saldo,
        cpp.numero_cuotas,
        COALESCE(rp.cuotas_restantes, 0) AS cuotas_restantes,
        c.fecha_inicio,
        cpp.fecha_maxima,
        prox.credito_cuota_id AS proxima_cuota_id,
        prox.numero_cuota AS proxima_numero_cuota,
        prox.fecha_vencimiento AS proxima_fecha_pago,
        prox.valor_total AS proximo_valor_cuota,
        prox.saldo_cuota AS proximo_saldo_cuota,
        CASE
          WHEN ecr.codigo = 'PAGADO'
            OR COALESCE(rp.cuotas_restantes, 0) <= 0
            OR (cpp.valor_total - COALESCE(rp.total_abonado, 0)) <= 0
            THEN 'PAGADO'
          WHEN prox.fecha_vencimiento < CURRENT_DATE THEN 'ATRASADO'
          WHEN prox.fecha_vencimiento = CURRENT_DATE THEN 'PENDIENTE'
          ELSE 'AL_DIA'
        END AS estado_cobro
      FROM public.credito c
      JOIN public.cliente cl
        ON cl.cliente_id = c.cliente_id
      JOIN public.ruta r
        ON r.ruta_id = c.ruta_id
      JOIN public.estado_credito ecr
        ON ecr.estado_credito_id = c.estado_credito_id
      JOIN public.credito_plan_pago cpp
        ON cpp.credito_id = c.credito_id
      LEFT JOIN LATERAL (
        SELECT cd.numero_documento
        FROM public.cliente_documento cd
        JOIN public.tipo_documento td
          ON td.tipo_documento_id = cd.tipo_documento_id
        WHERE cd.cliente_id = cl.cliente_id
          AND td.codigo = 'CC'
        ORDER BY cd.numero_documento ASC
        LIMIT 1
      ) doc_cc ON TRUE
      LEFT JOIN LATERAL (
        SELECT cd.direccion, cd.latitud, cd.longitud
        FROM public.cliente_direccion cd
        WHERE cd.cliente_id = cl.cliente_id
        ORDER BY cd.es_principal DESC, cd.direccion ASC
        LIMIT 1
      ) dir_principal ON TRUE
      LEFT JOIN resumen_plan rp
        ON rp.credito_plan_pago_id = cpp.credito_plan_pago_id
      LEFT JOIN LATERAL (
        SELECT
          cc.credito_cuota_id,
          cc.numero_cuota,
          cc.fecha_vencimiento,
          cc.valor_total,
          GREATEST(cc.valor_total - COALESCE(ac.abonado, 0), 0) AS saldo_cuota
        FROM public.credito_cuota cc
        JOIN public.estado_cuota ecu
          ON ecu.estado_cuota_id = cc.estado_cuota_id
        LEFT JOIN abonos_cuota ac
          ON ac.credito_cuota_id = cc.credito_cuota_id
        WHERE cc.credito_plan_pago_id = cpp.credito_plan_pago_id
          AND ecu.codigo NOT IN ('PAGADA', 'ANULADA')
          AND (cc.valor_total - COALESCE(ac.abonado, 0)) > 0
        ORDER BY cc.fecha_vencimiento ASC, cc.numero_cuota ASC
        LIMIT 1
      ) prox ON TRUE
      WHERE ${Prisma.join(conditions, ' AND ')}
      ORDER BY r.nombre ASC, prox.fecha_vencimiento ASC NULLS LAST, cl.nombre_completo ASC
      ${limit ? Prisma.sql`LIMIT ${limit}` : Prisma.empty}
    `);

    return rows.map((row) => ({
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
      numeroCuotas: row.numero_cuotas,
      cuotasRestantes: row.cuotas_restantes,
      fechaInicio: this.fechaIso(row.fecha_inicio),
      fechaMaxima: this.fechaIso(row.fecha_maxima),
      proximaCuotaId: row.proxima_cuota_id,
      proximaNumeroCuota: row.proxima_numero_cuota,
      proximaFechaPago: row.proxima_fecha_pago
        ? this.fechaIso(row.proxima_fecha_pago)
        : null,
      proximoValorCuota: this.decimalANumero(row.proximo_valor_cuota),
      proximoSaldoCuota: this.decimalANumero(row.proximo_saldo_cuota),
      estadoCobro: row.estado_cobro,
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
    )) as CobroRutaExportado[];
    this.asegurarTamanoExportacion(cobros.length);
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

    this.formatearHojaExportacion(sheet, [
      'valorPrincipal',
      'valorTotal',
      'valorCuota',
      'totalAbonado',
      'saldo',
      'proximoSaldoCuota',
    ]);

    return this.subirWorkbookExportacion({
      workbook,
      carpeta: 'cobros-ruta',
      nombreBase: 'cobros-ruta',
      filas: cobros.length,
      vistaPrevia: this.crearVistaPreviaExportacion(columnas, filasExcel),
    });
  }

  async listarCreditos(
    query: ListarCreditosQueryDto,
    usuario: AuthenticatedUser,
  ) {
    const paginado = this.hayPaginacion(query);
    const limit = this.limitePagina(
      query,
      paginado ? 40 : 250,
      paginado ? 100 : 250,
    );
    const offset = paginado ? this.offsetPagina(query) : 0;
    const cacheKey = `cobros:${this.usuarioCacheKey(usuario)}:creditos:${cacheKeyFromCriteria(
      {
        cajaMenorId: query.cajaMenorId,
        estado: query.estado,
        estadoCobro: query.estadoCobro,
        fechaDesde: query.fechaDesde,
        fechaHasta: query.fechaHasta,
        limit,
        offset,
        rutaId: query.rutaId,
        search: query.search,
      },
    )}`;

    return this.cache.remember(
      cacheKey,
      async () => {
        const rows = await this.consultarCreditos(
          query,
          usuario,
          paginado ? limit + 1 : limit,
          offset,
        );

        const pageRows: unknown[] = [...rows];
        return paginado ? this.paginaRespuesta(pageRows, limit, offset) : rows;
      },
      { ttlMs: 15_000 },
    );
  }

  async resumenCreditos(
    query: ListarCreditosQueryDto,
    usuario: AuthenticatedUser,
  ) {
    const cacheKey = `cobros:${this.usuarioCacheKey(usuario)}:creditos-resumen:${cacheKeyFromCriteria(
      {
        cajaMenorId: query.cajaMenorId,
        fechaDesde: query.fechaDesde,
        fechaHasta: query.fechaHasta,
        rutaId: query.rutaId,
        search: query.search,
      },
    )}`;

    return this.cache.remember(
      cacheKey,
      async () => {
        const [row] = await this.contarCreditosPorEstado(query, usuario);

        return {
          total: Number(row?.total ?? 0),
          activos: Number(row?.activos ?? 0),
          inactivos: Number(row?.inactivos ?? 0),
        };
      },
      { ttlMs: 15_000 },
    );
  }

  async exportarCreditos(
    query: ListarCreditosQueryDto,
    usuario: AuthenticatedUser,
  ): Promise<ExportacionExcel> {
    const creditos = (await this.consultarCreditos(
      query,
      usuario,
      maxExportRows + 1,
    )) as CreditoExportado[];
    this.asegurarTamanoExportacion(creditos.length);
    const workbook = new Workbook();
    workbook.creator = 'Cobro';
    workbook.created = new Date();

    const sheet = workbook.addWorksheet('Creditos');
    const columnas: ColumnaExportacion[] = [
      { header: 'Cliente', key: 'cliente', width: 30 },
      { header: 'Cedula', key: 'cedula', width: 18 },
      { header: 'Negocio', key: 'negocio', width: 24 },
      { header: 'Direccion', key: 'direccion', width: 32 },
      { header: 'Ruta', key: 'ruta', width: 22 },
      { header: 'Caja menor', key: 'cajaMenor', width: 24 },
      { header: 'Estado', key: 'estado', width: 16 },
      { header: 'Moneda', key: 'monedaCodigo', width: 10 },
      { header: 'Frecuencia', key: 'frecuencia', width: 18 },
      { header: 'Valor principal', key: 'valorPrincipal', width: 16 },
      { header: 'Interes %', key: 'porcentajeInteres', width: 12 },
      { header: 'Valor total', key: 'valorTotal', width: 16 },
      { header: 'Valor cuota', key: 'valorCuota', width: 16 },
      { header: 'Total abonado', key: 'totalAbonado', width: 16 },
      { header: 'Saldo', key: 'saldo', width: 16 },
      { header: 'Cuotas', key: 'cuotas', width: 12 },
      { header: 'Cuotas restantes', key: 'cuotasRestantes', width: 16 },
      { header: 'Fecha inicio', key: 'fechaInicio', width: 14 },
      { header: 'Fecha maxima', key: 'fechaMaxima', width: 14 },
      { header: 'Refinanciado', key: 'refinanciado', width: 34 },
      { header: 'Observacion', key: 'observacion', width: 34 },
      { header: 'Creado en', key: 'creadoEn', width: 24 },
    ];
    sheet.columns = columnas;
    const filasExcel: FilaExportacion[] = creditos.map((credito) => ({
      cliente: credito.cliente,
      cedula: credito.cedula ?? '',
      negocio: credito.negocio ?? '',
      direccion: credito.direccion ?? '',
      ruta: credito.ruta,
      cajaMenor: credito.cajaMenor ?? '',
      estado: credito.estado.nombre,
      monedaCodigo: credito.monedaCodigo,
      frecuencia: credito.frecuenciaPago.nombre,
      valorPrincipal: credito.valorPrincipal,
      porcentajeInteres: credito.porcentajeInteres,
      valorTotal: credito.valorTotal,
      valorCuota: credito.valorCuota,
      totalAbonado: credito.totalAbonado,
      saldo: credito.saldo,
      cuotas: `${credito.cuotasRestantes} / ${credito.numeroCuotas}`,
      cuotasRestantes: credito.cuotasRestantes,
      fechaInicio: credito.fechaInicio,
      fechaMaxima: credito.fechaMaxima,
      refinanciado: credito.refinanciacion
        ? `Refinanciado ${credito.refinanciacion.valorAnterior} a ${credito.refinanciacion.valorNuevo}`
        : '',
      observacion: credito.observacion ?? '',
      creadoEn: credito.creadoEn,
    }));
    sheet.addRows(filasExcel);

    this.formatearHojaExportacion(sheet, [
      'valorPrincipal',
      'valorTotal',
      'valorCuota',
      'totalAbonado',
      'saldo',
    ]);

    return this.subirWorkbookExportacion({
      workbook,
      carpeta: 'creditos',
      nombreBase: 'creditos',
      filas: creditos.length,
      vistaPrevia: this.crearVistaPreviaExportacion(columnas, filasExcel),
    });
  }

  private async consultarCreditos(
    query: ListarCreditosQueryDto,
    usuario: AuthenticatedUser,
    limite?: number,
    offset = 0,
  ) {
    if (await this.usarEsquemaTbl()) {
      return this.consultarCreditosTbl(query, usuario, limite, offset);
    }

    const conditions: Prisma.Sql[] = [Prisma.sql`1 = 1`];
    const search = this.normalizarTextoOpcional(query.search);
    const estado = query.estado ?? 'todos';

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      conditions.push(Prisma.sql`(
        c.creado_por_usuario_id = ${usuario.usuarioId}::uuid
        OR r.responsable_usuario_id = ${usuario.usuarioId}::uuid
      )`);
    }

    if (query.rutaId) {
      conditions.push(Prisma.sql`c.ruta_id = ${query.rutaId}::uuid`);
    }

    if (query.cajaMenorId) {
      conditions.push(
        Prisma.sql`cm.caja_menor_id = ${query.cajaMenorId}::uuid`,
      );
    }

    if (estado === 'activos') {
      conditions.push(Prisma.sql`ecr.codigo = 'ACTIVO'`);
    } else if (estado === 'inactivos') {
      conditions.push(Prisma.sql`ecr.codigo = 'PAGADO'`);
    }

    if (query.fechaDesde) {
      const fechaDesde = this.parsearFecha(query.fechaDesde, 'fechaDesde');
      conditions.push(Prisma.sql`
        CASE
          WHEN ecr.codigo = 'ACTIVO' THEN c.fecha_inicio
          ELSE COALESCE(
            pc.fecha_ultimo_pago,
            (c.actualizado_en AT TIME ZONE 'America/Bogota')::date,
            c.fecha_inicio
          )
        END >= ${fechaDesde}::date
      `);
    }

    if (query.fechaHasta) {
      const fechaHasta = this.parsearFecha(query.fechaHasta, 'fechaHasta');
      conditions.push(Prisma.sql`
        CASE
          WHEN ecr.codigo = 'ACTIVO' THEN c.fecha_inicio
          ELSE COALESCE(
            pc.fecha_ultimo_pago,
            (c.actualizado_en AT TIME ZONE 'America/Bogota')::date,
            c.fecha_inicio
          )
        END <= ${fechaHasta}::date
      `);
    }

    if (search) {
      const pattern = `%${search}%`;
      conditions.push(Prisma.sql`(
        cl.nombre_completo ILIKE ${pattern}
        OR cl.nombre_comercial ILIKE ${pattern}
        OR r.nombre ILIKE ${pattern}
        OR cm.nombre ILIKE ${pattern}
        OR c.observacion ILIKE ${pattern}
        OR EXISTS (
          SELECT 1
          FROM public.cliente_direccion cd_busqueda
          WHERE cd_busqueda.cliente_id = cl.cliente_id
            AND cd_busqueda.direccion ILIKE ${pattern}
        )
        OR EXISTS (
          SELECT 1
          FROM public.cliente_documento cd_busqueda
          WHERE cd_busqueda.cliente_id = cl.cliente_id
            AND cd_busqueda.numero_documento ILIKE ${pattern}
        )
      )`);
    }

    const rows = await this.prisma.$queryRaw<CreditoListadoRow[]>(Prisma.sql`
      WITH abonos_cuota AS (
        SELECT
          cc.credito_cuota_id,
          COALESCE(
            SUM(
              pa.monto_capital
              + pa.monto_interes
              + pa.monto_mora
              - pa.monto_descuento
            ),
            0
          ) AS abonado
        FROM public.credito_cuota cc
        LEFT JOIN public.pago_aplicacion pa
          ON pa.credito_cuota_id = cc.credito_cuota_id
        GROUP BY cc.credito_cuota_id
      ),
      resumen_plan AS (
        SELECT
          cc.credito_plan_pago_id,
          COALESCE(SUM(ac.abonado), 0) AS total_abonado,
          COUNT(*) FILTER (
            WHERE ecu.codigo NOT IN ('PAGADA', 'ANULADA')
              AND (cc.valor_total - COALESCE(ac.abonado, 0)) > 0
          )::int AS cuotas_restantes
        FROM public.credito_cuota cc
        JOIN public.estado_cuota ecu
          ON ecu.estado_cuota_id = cc.estado_cuota_id
        LEFT JOIN abonos_cuota ac
          ON ac.credito_cuota_id = cc.credito_cuota_id
        GROUP BY cc.credito_plan_pago_id
      ),
      pagos_credito AS (
        SELECT
          cpp_pago.credito_id,
          MAX((p.fecha_pago AT TIME ZONE 'America/Bogota')::date) AS fecha_ultimo_pago
        FROM public.credito_plan_pago cpp_pago
        JOIN public.credito_cuota cc_pago
          ON cc_pago.credito_plan_pago_id = cpp_pago.credito_plan_pago_id
        JOIN public.pago_aplicacion pa_pago
          ON pa_pago.credito_cuota_id = cc_pago.credito_cuota_id
        JOIN public.pago p
          ON p.pago_id = pa_pago.pago_id
        GROUP BY cpp_pago.credito_id
      )
      SELECT
        c.credito_id,
        cl.cliente_id,
        cl.nombre_completo AS cliente,
        doc_cc.numero_documento AS cedula,
        cl.nombre_comercial AS negocio,
        dir_principal.direccion,
        r.ruta_id,
        r.nombre AS ruta,
        cm.caja_menor_id,
        cm.nombre AS caja_menor,
        c.moneda_codigo,
        fp.frecuencia_pago_id,
        fp.codigo AS frecuencia_codigo,
        fp.nombre AS frecuencia_nombre,
        fp.dias_intervalo,
        ecr.codigo AS estado_codigo,
        ecr.nombre AS estado_nombre,
        c.valor_principal,
        c.porcentaje_interes,
        c.plazo_dias,
        c.omitir_domingos,
        cpp.valor_total,
        cpp.valor_cuota,
        COALESCE(rp.total_abonado, 0) AS total_abonado,
        GREATEST(cpp.valor_total - COALESCE(rp.total_abonado, 0), 0) AS saldo,
        cpp.numero_cuotas,
        COALESCE(rp.cuotas_restantes, 0) AS cuotas_restantes,
        c.fecha_inicio,
        cpp.fecha_maxima,
        c.refinanciado_en,
        c.valor_principal_anterior,
        c.valor_principal_refinanciado,
        c.observacion,
        c.creado_en,
        c.actualizado_en
      FROM public.credito c
      JOIN public.cliente cl
        ON cl.cliente_id = c.cliente_id
      JOIN public.ruta r
        ON r.ruta_id = c.ruta_id
      JOIN public.frecuencia_pago fp
        ON fp.frecuencia_pago_id = c.frecuencia_pago_id
      JOIN public.estado_credito ecr
        ON ecr.estado_credito_id = c.estado_credito_id
      JOIN public.credito_plan_pago cpp
        ON cpp.credito_id = c.credito_id
      LEFT JOIN resumen_plan rp
        ON rp.credito_plan_pago_id = cpp.credito_plan_pago_id
      LEFT JOIN pagos_credito pc
        ON pc.credito_id = c.credito_id
      LEFT JOIN public.credito_desembolso cde
        ON cde.credito_id = c.credito_id
      LEFT JOIN public.caja_menor_movimiento cmm
        ON cmm.caja_menor_movimiento_id = cde.caja_menor_movimiento_id
      LEFT JOIN public.caja_menor cm
        ON cm.caja_menor_id = cmm.caja_menor_id
      LEFT JOIN LATERAL (
        SELECT cd.numero_documento
        FROM public.cliente_documento cd
        JOIN public.tipo_documento td
          ON td.tipo_documento_id = cd.tipo_documento_id
        WHERE cd.cliente_id = cl.cliente_id
          AND td.codigo = 'CC'
        ORDER BY cd.numero_documento ASC
        LIMIT 1
      ) doc_cc ON TRUE
      LEFT JOIN LATERAL (
        SELECT cd.direccion
        FROM public.cliente_direccion cd
        WHERE cd.cliente_id = cl.cliente_id
        ORDER BY cd.es_principal DESC, cd.direccion ASC
        LIMIT 1
      ) dir_principal ON TRUE
      WHERE ${Prisma.join(conditions, ' AND ')}
      ORDER BY c.fecha_inicio DESC, c.creado_en DESC, cl.nombre_completo ASC
      ${limite ? Prisma.sql`LIMIT ${limite}` : Prisma.empty}
      ${offset > 0 ? Prisma.sql`OFFSET ${offset}` : Prisma.empty}
    `);

    return rows.map((row) => this.formatearCreditoListado(row));
  }

  private async contarCreditosPorEstado(
    query: ListarCreditosQueryDto,
    usuario: AuthenticatedUser,
  ) {
    if (await this.usarEsquemaTbl()) {
      return this.contarCreditosPorEstadoTbl(query, usuario);
    }

    const conditions: Prisma.Sql[] = [Prisma.sql`1 = 1`];
    const fechaConditions: Prisma.Sql[] = [Prisma.sql`1 = 1`];
    const search = this.normalizarTextoOpcional(query.search);

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      conditions.push(Prisma.sql`(
        c.creado_por_usuario_id = ${usuario.usuarioId}::uuid
        OR r.responsable_usuario_id = ${usuario.usuarioId}::uuid
      )`);
    }

    if (query.rutaId) {
      conditions.push(Prisma.sql`c.ruta_id = ${query.rutaId}::uuid`);
    }

    if (query.cajaMenorId) {
      conditions.push(
        Prisma.sql`cm.caja_menor_id = ${query.cajaMenorId}::uuid`,
      );
    }

    if (query.fechaDesde) {
      const fechaDesde = this.parsearFecha(query.fechaDesde, 'fechaDesde');
      fechaConditions.push(Prisma.sql`fecha_referencia >= ${fechaDesde}::date`);
    }

    if (query.fechaHasta) {
      const fechaHasta = this.parsearFecha(query.fechaHasta, 'fechaHasta');
      fechaConditions.push(Prisma.sql`fecha_referencia <= ${fechaHasta}::date`);
    }

    if (search) {
      const pattern = `%${search}%`;
      conditions.push(Prisma.sql`(
        cl.nombre_completo ILIKE ${pattern}
        OR cl.nombre_comercial ILIKE ${pattern}
        OR r.nombre ILIKE ${pattern}
        OR cm.nombre ILIKE ${pattern}
        OR c.observacion ILIKE ${pattern}
        OR EXISTS (
          SELECT 1
          FROM public.cliente_direccion cd_busqueda
          WHERE cd_busqueda.cliente_id = cl.cliente_id
            AND cd_busqueda.direccion ILIKE ${pattern}
        )
        OR EXISTS (
          SELECT 1
          FROM public.cliente_documento cd_busqueda
          WHERE cd_busqueda.cliente_id = cl.cliente_id
            AND cd_busqueda.numero_documento ILIKE ${pattern}
        )
      )`);
    }

    return this.prisma.$queryRaw<CreditoConteoRow[]>(Prisma.sql`
      WITH abonos_cuota AS (
        SELECT
          cc.credito_cuota_id,
          COALESCE(
            SUM(
              pa.monto_capital
              + pa.monto_interes
              + pa.monto_mora
              - pa.monto_descuento
            ),
            0
          ) AS abonado
        FROM public.credito_cuota cc
        LEFT JOIN public.pago_aplicacion pa
          ON pa.credito_cuota_id = cc.credito_cuota_id
        GROUP BY cc.credito_cuota_id
      ),
      resumen_plan AS (
        SELECT
          cc.credito_plan_pago_id,
          COALESCE(SUM(ac.abonado), 0) AS total_abonado,
          COUNT(*) FILTER (
            WHERE ecu.codigo NOT IN ('PAGADA', 'ANULADA')
              AND (cc.valor_total - COALESCE(ac.abonado, 0)) > 0
          )::int AS cuotas_restantes
        FROM public.credito_cuota cc
        JOIN public.estado_cuota ecu
          ON ecu.estado_cuota_id = cc.estado_cuota_id
        LEFT JOIN abonos_cuota ac
          ON ac.credito_cuota_id = cc.credito_cuota_id
        GROUP BY cc.credito_plan_pago_id
      ),
      pagos_credito AS (
        SELECT
          cpp_pago.credito_id,
          MAX((p.fecha_pago AT TIME ZONE 'America/Bogota')::date) AS fecha_ultimo_pago
        FROM public.credito_plan_pago cpp_pago
        JOIN public.credito_cuota cc_pago
          ON cc_pago.credito_plan_pago_id = cpp_pago.credito_plan_pago_id
        JOIN public.pago_aplicacion pa_pago
          ON pa_pago.credito_cuota_id = cc_pago.credito_cuota_id
        JOIN public.pago p
          ON p.pago_id = pa_pago.pago_id
        GROUP BY cpp_pago.credito_id
      ),
      creditos_estado AS (
        SELECT
          ecr.codigo,
          COALESCE(rp.cuotas_restantes, 0) AS cuotas_restantes,
          GREATEST(cpp.valor_total - COALESCE(rp.total_abonado, 0), 0) AS saldo,
          (ecr.codigo = 'ACTIVO') AS es_activo,
          (ecr.codigo = 'PAGADO') AS es_inactivo,
          CASE
            WHEN ecr.codigo = 'ACTIVO' THEN c.fecha_inicio
            ELSE COALESCE(
              pc.fecha_ultimo_pago,
              (c.actualizado_en AT TIME ZONE 'America/Bogota')::date,
              c.fecha_inicio
            )
          END AS fecha_referencia
        FROM public.credito c
        JOIN public.cliente cl ON cl.cliente_id = c.cliente_id
        JOIN public.ruta r ON r.ruta_id = c.ruta_id
        JOIN public.estado_credito ecr
          ON ecr.estado_credito_id = c.estado_credito_id
        JOIN public.credito_plan_pago cpp ON cpp.credito_id = c.credito_id
        LEFT JOIN public.credito_desembolso cde
          ON cde.credito_id = c.credito_id
        LEFT JOIN public.caja_menor_movimiento cmm
          ON cmm.caja_menor_movimiento_id = cde.caja_menor_movimiento_id
        LEFT JOIN public.caja_menor cm
          ON cm.caja_menor_id = cmm.caja_menor_id
        LEFT JOIN resumen_plan rp
          ON rp.credito_plan_pago_id = cpp.credito_plan_pago_id
        LEFT JOIN pagos_credito pc
          ON pc.credito_id = c.credito_id
        WHERE ${Prisma.join(conditions, ' AND ')}
      ),
      creditos_filtrados AS (
        SELECT *
        FROM creditos_estado
        WHERE ${Prisma.join(fechaConditions, ' AND ')}
      )
      SELECT
        COUNT(*)::int AS total,
        COUNT(*) FILTER (
          WHERE es_activo
        )::int AS activos,
        COUNT(*) FILTER (
          WHERE es_inactivo
        )::int AS inactivos
      FROM creditos_filtrados
    `);
  }

  async listarCuotasCredito(creditoId: string, usuario: AuthenticatedUser) {
    if (this.esIdTbl(creditoId) && (await this.usarEsquemaTbl())) {
      return this.listarCuotasCreditoTbl(creditoId, usuario);
    }

    await this.validarAccesoCreditoPorId(creditoId, usuario);

    const rows = await this.prisma.$queryRaw<CuotaCreditoRow[]>(Prisma.sql`
      WITH abonos_cuota AS (
        SELECT
          pa.credito_cuota_id,
          COALESCE(
            SUM(
              pa.monto_capital
              + pa.monto_interes
              + pa.monto_mora
              - pa.monto_descuento
            ),
            0
          ) AS abonado
        FROM public.pago_aplicacion pa
        GROUP BY pa.credito_cuota_id
      )
      SELECT
        cc.credito_cuota_id,
        cc.numero_cuota,
        cc.fecha_vencimiento,
        ec.codigo AS estado_codigo,
        ec.nombre AS estado_nombre,
        cc.valor_capital,
        cc.valor_interes,
        cc.valor_total,
        COALESCE(ac.abonado, 0) AS abonado,
        GREATEST(cc.valor_total - COALESCE(ac.abonado, 0), 0) AS saldo
      FROM public.credito_cuota cc
      JOIN public.estado_cuota ec
        ON ec.estado_cuota_id = cc.estado_cuota_id
      JOIN public.credito_plan_pago cpp
        ON cpp.credito_plan_pago_id = cc.credito_plan_pago_id
      LEFT JOIN abonos_cuota ac
        ON ac.credito_cuota_id = cc.credito_cuota_id
      WHERE cpp.credito_id = ${creditoId}::uuid
      ORDER BY cc.numero_cuota ASC
    `);

    return rows.map((row) => ({
      id: row.credito_cuota_id,
      numeroCuota: row.numero_cuota,
      fechaVencimiento: this.fechaIso(row.fecha_vencimiento),
      estado: {
        codigo: row.estado_codigo,
        nombre: row.estado_nombre,
      },
      valorCapital: this.decimalANumero(row.valor_capital),
      valorInteres: this.decimalANumero(row.valor_interes),
      valorTotal: this.decimalANumero(row.valor_total),
      abonado: this.decimalANumero(row.abonado),
      saldo: this.decimalANumero(row.saldo),
    }));
  }

  async crearCredito(dto: CrearCreditoDto, usuario: AuthenticatedUser) {
    this.asegurarPermiso(usuario, 'CREAR_CREDITOS');

    const fechaInicio = this.parsearFecha(dto.fechaInicio, 'fechaInicio');
    const valorPrincipal = this.redondear(dto.valorPrincipal);
    const porcentajeInteres = this.redondear(dto.porcentajeInteres, 4);

    if (await this.usarEsquemaTbl()) {
      return this.crearCreditoTbl(
        dto,
        usuario,
        fechaInicio,
        valorPrincipal,
        porcentajeInteres,
      );
    }

    const creditoId = await this.prisma.$transaction(async (tx) => {
      const [cliente, moneda, frecuenciaPago, estadoActivo, estadoPendiente] =
        await Promise.all([
          tx.cliente.findUnique({ where: { clienteId: dto.clienteId } }),
          tx.moneda.findUnique({ where: { codigoMoneda: dto.monedaCodigo } }),
          tx.frecuenciaPago.findUnique({
            where: { frecuenciaPagoId: dto.frecuenciaPagoId },
          }),
          tx.estadoCredito.findUnique({ where: { codigo: 'ACTIVO' } }),
          tx.estadoCuota.findUnique({ where: { codigo: 'PENDIENTE' } }),
        ]);

      if (!cliente) {
        throw DomainError.notFound(
          'Cliente no encontrado',
          'CLIENTE_NO_ENCONTRADO',
        );
      }

      if (!moneda) {
        throw DomainError.notFound(
          'Moneda no encontrada',
          'MONEDA_NO_ENCONTRADA',
        );
      }

      if (!frecuenciaPago) {
        throw DomainError.notFound(
          'Frecuencia de pago no encontrada',
          'FRECUENCIA_NO_ENCONTRADA',
        );
      }

      if (!estadoActivo || !estadoPendiente) {
        throw DomainError.notFound(
          'Faltan estados base para crear el credito',
          'CATALOGO_CREDITO_INCOMPLETO',
        );
      }

      const ruta = await this.obtenerOCrearRutaCredito(tx, dto, usuario);

      const plan = this.calcularPlan({
        fechaInicio,
        valorPrincipal,
        porcentajeInteres,
        plazoDias: dto.plazoDias,
        diasIntervalo: frecuenciaPago.diasIntervalo,
        omitirDomingos: dto.omitirDomingos ?? true,
        decimales: moneda.decimales,
      });

      const credito = await tx.credito.create({
        data: {
          clienteId: cliente.clienteId,
          rutaId: ruta.rutaId,
          monedaCodigo: moneda.codigoMoneda,
          frecuenciaPagoId: frecuenciaPago.frecuenciaPagoId,
          estadoCreditoId: estadoActivo.estadoCreditoId,
          creadoPorUsuarioId: usuario.usuarioId,
          fechaInicio,
          valorPrincipal: this.decimal(valorPrincipal),
          porcentajeInteres: this.decimal(porcentajeInteres, 4),
          plazoDias: dto.plazoDias,
          omitirDomingos: dto.omitirDomingos ?? true,
          observacion: this.normalizarTextoOpcional(dto.observacion),
        },
      });

      const planPago = await tx.creditoPlanPago.create({
        data: {
          creditoId: credito.creditoId,
          numeroCuotas: plan.numeroCuotas,
          valorCuota: this.decimal(plan.valorCuota),
          valorTotal: this.decimal(plan.valorTotal),
          fechaMaxima: plan.fechaMaxima,
          domingosOmitidos: plan.domingosOmitidos,
        },
      });

      await tx.creditoCuota.createMany({
        data: plan.cuotas.map((cuota) => ({
          creditoPlanPagoId: planPago.creditoPlanPagoId,
          estadoCuotaId: estadoPendiente.estadoCuotaId,
          numeroCuota: cuota.numeroCuota,
          fechaVencimiento: cuota.fechaVencimiento,
          valorCapital: this.decimal(cuota.valorCapital),
          valorInteres: this.decimal(cuota.valorInteres),
        })),
      });

      await this.asegurarClienteEnRuta(tx, ruta.rutaId, cliente.clienteId);
      const movimientoId = await this.registrarDesembolsoCaja(
        tx,
        dto,
        ruta,
        usuario,
        valorPrincipal,
        fechaInicio,
        cliente.nombreCompleto,
      );

      await tx.creditoDesembolso.create({
        data: {
          creditoId: credito.creditoId,
          cajaMenorMovimientoId: movimientoId,
          fechaDesembolso: fechaInicio,
          monto: this.decimal(valorPrincipal),
        },
      });

      return credito.creditoId;
    });

    this.invalidarCacheLecturas();
    const credito = await this.obtenerCredito(creditoId, usuario);
    void this.notifications.notifyCreditApproved(creditoId);
    return credito;
  }

  private async crearCreditoTbl(
    dto: CrearCreditoDto,
    usuario: AuthenticatedUser,
    fechaInicio: Date,
    valorPrincipal: number,
    porcentajeInteres: number,
  ) {
    const creditoId = await this.prisma.$transaction(
      async (tx) => {
        const orgScope = await this.obtenerScopeOrganizacionTbl(usuario, tx);
        const scope = {
          usuario_id: orgScope.usuarioId,
          org_id: orgScope.organizacionId,
        };

        const [cliente] = await tx.$queryRaw<
          Array<{ id: string; org_id: string; nombre: string }>
        >(Prisma.sql`
          SELECT
            c.id_cli::text AS id,
            c.org_id::text AS org_id,
            TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS nombre
          FROM public.tbl_clientes c
          JOIN public.tbl_personas p ON p.id_per = c.cli_persona
          WHERE c.id_cli = ${dto.clienteId}::uuid
            AND c.cli_activo
            AND c.org_id = ${scope.org_id}::uuid
          LIMIT 1
        `);

        if (!cliente) {
          throw DomainError.notFound(
            'Cliente no encontrado',
            'CLIENTE_NO_ENCONTRADO',
          );
        }

        const [moneda] = await tx.$queryRaw<
          Array<{ id: string; codigo: string; decimales: number | bigint }>
        >(Prisma.sql`
          SELECT
            id_mon::text AS id,
            mon_codigo::text AS codigo,
            mon_decimales AS decimales
          FROM public.tbl_monedas
          WHERE mon_activa
            AND UPPER(TRIM(mon_codigo::text)) = ${dto.monedaCodigo}
          LIMIT 1
        `);

        if (!moneda) {
          throw DomainError.notFound(
            'Moneda no encontrada',
            'MONEDA_NO_ENCONTRADA',
          );
        }

        const frecuenciaMap: Record<number, string> = {
          1: 'DIARIO',
          2: 'SEMANAL',
          3: 'QUINCENAL',
          4: 'MENSUAL',
        };
        const frecuenciaCodigo =
          frecuenciaMap[Number(dto.frecuenciaPagoId)] ?? 'DIARIO';

        const [producto] = await tx.$queryRaw<
          Array<{ id: string; dias_intervalo: number }>
        >(Prisma.sql`
          SELECT
            pc.id_pcr::text AS id,
            CASE pc.pcr_frecuencia::text
              WHEN 'SEMANAL' THEN 7
              WHEN 'QUINCENAL' THEN 15
              WHEN 'MENSUAL' THEN 30
              ELSE 1
            END AS dias_intervalo
          FROM public.tbl_productos_creditos pc
          WHERE pc.pcr_frecuencia::text = ${frecuenciaCodigo}
             OR pc.id_pcr::text = ${String(dto.frecuenciaPagoId)}
          ORDER BY (pc.pcr_frecuencia::text = ${frecuenciaCodigo}) DESC
          LIMIT 1
        `);

        if (!producto) {
          throw DomainError.notFound(
            'Frecuencia de pago no encontrada',
            'FRECUENCIA_NO_ENCONTRADA',
          );
        }

        const [caja] = await tx.$queryRaw<
          Array<{ id: string; nombre: string; sesion_id: string | null }>
        >(Prisma.sql`
          SELECT
            c.id_caj::text AS id,
            c.caj_nombre AS nombre,
            sc.id_sca::text AS sesion_id
          FROM public.tbl_cajas c
          LEFT JOIN LATERAL (
            SELECT sca.id_sca
            FROM public.tbl_sesiones_cajas sca
            WHERE sca.caj_id = c.id_caj
              AND sca.sca_estado::text = 'ABIERTA'
            ORDER BY sca.sca_fecha_apertura DESC, sca.id_sca DESC
            LIMIT 1
          ) sc ON TRUE
          WHERE c.id_caj = ${dto.cajaMenorId}::uuid
            AND c.org_id = ${cliente.org_id}::uuid
            AND c.mon_id = ${moneda.id}::uuid
            AND c.caj_tipo::text = 'MENOR'
            AND c.caj_activa
          LIMIT 1
        `);

        if (!caja) {
          throw DomainError.notFound(
            'Caja menor no encontrada o no coincide con la moneda',
            'CAJA_MENOR_NO_ENCONTRADA',
          );
        }

        const [presupuesto] = await tx.$queryRaw<
          Array<{ presupuesto: Prisma.Decimal }>
        >(
          Prisma.sql`
            SELECT presupuesto
            FROM public.vista_presupuesto_actual
            WHERE caja_menor_id::text = ${caja.id}
            LIMIT 1
          `,
        );

        if (
          this.decimalANumero(presupuesto?.presupuesto ?? null) < valorPrincipal
        ) {
          throw DomainError.conflict(
            'No se puede hacer credito sin caja suficiente',
            'CAJA_MENOR_SALDO_INSUFICIENTE',
          );
        }

        const rutaId = await this.obtenerOCrearRutaCreditoTbl(
          tx,
          dto.rutaId,
          cliente.org_id,
          scope.usuario_id,
          usuario.usuario,
        );

        const plan = this.calcularPlan({
          fechaInicio,
          valorPrincipal,
          porcentajeInteres,
          plazoDias: dto.plazoDias,
          diasIntervalo: Number(producto.dias_intervalo),
          omitirDomingos: dto.omitirDomingos ?? true,
          decimales: Number(moneda.decimales),
        });
        const interesTotal = this.redondear(
          plan.valorTotal - valorPrincipal,
          Number(moneda.decimales),
        );

        const [credito] = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
          INSERT INTO public.tbl_creditos (
            cre_total,
            cre_estado,
            cre_tasa_interes,
            cre_interes_total,
            cre_total_pagar,
            cre_fecha_inicio,
            cre_fecha_fin,
            usu_id,
            pcr_id,
            cli_id,
            mon_id
          )
          VALUES (
            ${this.decimal(valorPrincipal)},
            'ACTIVO'::public.credito_estado_enum,
            ${this.decimal(porcentajeInteres, 4)},
            ${this.decimal(interesTotal)},
            ${this.decimal(plan.valorTotal)},
            ${fechaInicio}::date,
            ${plan.fechaMaxima}::date,
            ${scope.usuario_id}::uuid,
            ${producto.id}::uuid,
            ${cliente.id}::uuid,
            ${moneda.id}::uuid
          )
          RETURNING id_cre::text AS id
        `);

        for (const cuota of plan.cuotas) {
          await tx.$executeRaw(Prisma.sql`
            INSERT INTO public.tbl_cuotas (
              cuo_numero,
              cuo_valor,
              cuo_estado,
              cuo_fecha_vencimiento,
              cre_id
            )
            VALUES (
              ${cuota.numeroCuota},
              ${this.decimal(cuota.valorCapital + cuota.valorInteres)},
              'PENDIENTE'::public.cuota_estado_enum,
              ${cuota.fechaVencimiento}::date,
              ${credito.id}::uuid
            )
          `);
        }

        await tx.$executeRaw(Prisma.sql`
          INSERT INTO public.tbl_rutas_clientes (rut_id, cli_id)
          VALUES (${rutaId}::uuid, ${cliente.id}::uuid)
          ON CONFLICT (rut_id, cli_id) DO UPDATE
          SET rcl_activo = TRUE
        `);

        const sesionId =
          caja.sesion_id ??
          (
            await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
              INSERT INTO public.tbl_sesiones_cajas (
                sca_fecha_apertura,
                sca_monto_inicial,
                caj_id,
                usu_id
              )
              VALUES (
                ${fechaInicio},
                0,
                ${caja.id}::uuid,
                ${scope.usuario_id}::uuid
              )
              RETURNING id_sca::text AS id
            `)
          )[0]?.id;

        if (!sesionId) {
          throw DomainError.conflict(
            'No se pudo abrir la sesion de caja menor',
            'SESION_CAJA_NO_CREADA',
          );
        }

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
            ${this.decimal(valorPrincipal)},
            ${credito.id}::uuid,
            'CREDITO'::public.movimiento_referencia_tipo_enum,
            ${fechaInicio},
            ${cliente.org_id}::uuid,
            ${scope.usuario_id}::uuid,
            ${sesionId}::uuid
          )
        `);

        await tx.$executeRaw(Prisma.sql`
          UPDATE public.tbl_sesiones_cajas
          SET sca_total_gasto = sca_total_gasto + ${this.decimal(valorPrincipal)}
          WHERE id_sca = ${sesionId}::uuid
        `);

        return credito.id;
      },
      { maxWait: 10_000, timeout: 20_000 },
    );

    this.invalidarCacheLecturas();
    const credito = await this.obtenerCredito(creditoId, usuario);
    void this.notifications.notifyCreditApproved(creditoId);
    return credito;
  }

  async actualizarCredito(
    creditoId: string,
    dto: ActualizarCreditoDto,
    usuario: AuthenticatedUser,
  ) {
    this.asegurarPermiso(usuario, 'MODIFICAR_CREDITOS');

    const fechaInicio = this.parsearFecha(dto.fechaInicio, 'fechaInicio');
    const valorPrincipal = this.redondear(dto.valorPrincipal);
    const porcentajeInteres = this.redondear(dto.porcentajeInteres, 4);

    const creditoActualizadoId = await this.prisma.$transaction(
      async (tx) => {
        await tx.$queryRaw(Prisma.sql`
          SELECT credito_id
          FROM public.credito
          WHERE credito_id = ${creditoId}::uuid
          FOR UPDATE
        `);

        const credito = await tx.credito.findUnique({
          where: { creditoId },
          include: {
            cliente: true,
            ruta: true,
            moneda: true,
            frecuenciaPago: true,
            estadoCredito: true,
            planPago: { include: { cuotas: true } },
            desembolso: {
              include: {
                cajaMenorMovimiento: {
                  include: {
                    cajaMenor: true,
                    tipoMovimientoCaja: true,
                    usuario: true,
                  },
                },
              },
            },
          },
        });

        if (!credito || !credito.planPago) {
          throw DomainError.notFound(
            'Credito no encontrado',
            'CREDITO_NO_ENCONTRADO',
          );
        }

        const pagosAplicados = await tx.pagoAplicacion.count({
          where: { creditoCuota: { planPago: { creditoId } } },
        });
        const tienePagosAplicados = pagosAplicados > 0;

        const [
          cliente,
          moneda,
          frecuenciaPago,
          estadoPendiente,
          tipoDesembolso,
        ] = await Promise.all([
          tx.cliente.findUnique({ where: { clienteId: dto.clienteId } }),
          tx.moneda.findUnique({ where: { codigoMoneda: dto.monedaCodigo } }),
          tx.frecuenciaPago.findUnique({
            where: { frecuenciaPagoId: dto.frecuenciaPagoId },
          }),
          tx.estadoCuota.findUnique({ where: { codigo: 'PENDIENTE' } }),
          tx.tipoMovimientoCaja.findUnique({
            where: { codigo: 'DESEMBOLSO_CREDITO' },
          }),
        ]);

        if (!cliente) {
          throw DomainError.notFound(
            'Cliente no encontrado',
            'CLIENTE_NO_ENCONTRADO',
          );
        }

        if (!moneda) {
          throw DomainError.notFound(
            'Moneda no encontrada',
            'MONEDA_NO_ENCONTRADA',
          );
        }

        if (!frecuenciaPago) {
          throw DomainError.notFound(
            'Frecuencia de pago no encontrada',
            'FRECUENCIA_NO_ENCONTRADA',
          );
        }

        if (!estadoPendiente || !tipoDesembolso) {
          throw DomainError.notFound(
            'Faltan catalogos base para modificar el credito',
            'CATALOGO_CREDITO_INCOMPLETO',
          );
        }

        const ruta = dto.rutaId
          ? await tx.ruta.findUnique({
              where: { rutaId: dto.rutaId },
              include: { estadoRuta: true },
            })
          : await tx.ruta.findUnique({
              where: { rutaId: credito.rutaId },
              include: { estadoRuta: true },
            });

        if (!ruta) {
          throw DomainError.notFound(
            'Ruta no encontrada',
            'RUTA_NO_ENCONTRADA',
          );
        }

        this.asegurarResponsableRuta(ruta.responsableUsuarioId, usuario);

        if (ruta.estadoRuta.codigo !== 'ABIERTA') {
          throw DomainError.conflict(
            'La ruta no esta abierta para modificar creditos',
            'RUTA_NO_ABIERTA',
          );
        }

        const cajaMenorId =
          dto.cajaMenorId ??
          credito.desembolso?.cajaMenorMovimiento?.cajaMenorId;

        if (!cajaMenorId) {
          throw DomainError.validation(
            'No se puede modificar credito sin caja menor',
            'CREDITO_REQUIERE_CAJA_MENOR',
          );
        }

        const caja = await tx.cajaMenor.findUnique({
          where: { cajaMenorId },
        });

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

        if (caja.responsableUsuarioId !== ruta.responsableUsuarioId) {
          throw DomainError.conflict(
            'La caja menor no pertenece al responsable de la ruta',
            'CAJA_MENOR_RUTA_RESPONSABLE_DIFERENTE',
          );
        }

        if (caja.monedaCodigo !== moneda.codigoMoneda) {
          throw DomainError.conflict(
            'La moneda de la caja menor no coincide con el credito',
            'CAJA_MENOR_MONEDA_DIFERENTE',
          );
        }

        const omitirDomingos = dto.omitirDomingos ?? credito.omitirDomingos;
        const valorPrincipalActual = this.redondear(
          this.decimalANumero(credito.valorPrincipal),
        );
        const valorPrincipalRefinanciado = credito.valorPrincipalRefinanciado
          ? this.redondear(
              this.decimalANumero(credito.valorPrincipalRefinanciado),
            )
          : null;
        const cambiaValorPrincipal = valorPrincipalActual !== valorPrincipal;
        const limpiarRefinanciacion =
          cambiaValorPrincipal ||
          (valorPrincipalRefinanciado !== null &&
            valorPrincipalRefinanciado !== valorPrincipal);
        const cambiaCondicionesFinancieras =
          moneda.codigoMoneda !== credito.monedaCodigo ||
          frecuenciaPago.frecuenciaPagoId !== credito.frecuenciaPagoId ||
          this.fechaIso(fechaInicio) !== this.fechaIso(credito.fechaInicio) ||
          cambiaValorPrincipal ||
          this.redondear(this.decimalANumero(credito.porcentajeInteres), 4) !==
            porcentajeInteres ||
          dto.plazoDias !== credito.plazoDias ||
          omitirDomingos !== credito.omitirDomingos;

        if (tienePagosAplicados && cambiaCondicionesFinancieras) {
          throw DomainError.conflict(
            'No se pueden modificar valor, interes, plazo, frecuencia, moneda, fecha u omitir domingos en un credito con pagos registrados',
            'CREDITO_CON_PAGOS_CAMPOS_FINANCIEROS_NO_EDITABLES',
          );
        }

        const plan = tienePagosAplicados
          ? null
          : this.calcularPlan({
              fechaInicio,
              valorPrincipal,
              porcentajeInteres,
              plazoDias: dto.plazoDias,
              diasIntervalo: frecuenciaPago.diasIntervalo,
              omitirDomingos,
              decimales: moneda.decimales,
            });

        const movimientoAnterior = credito.desembolso?.cajaMenorMovimiento;
        let cajaMenorMovimientoId = movimientoAnterior?.cajaMenorMovimientoId;

        if (movimientoAnterior) {
          await this.asegurarPresupuestoDespuesDeCambioMovimientoCaja(
            tx,
            movimientoAnterior,
            {
              cajaMenorId: caja.cajaMenorId,
              monto: valorPrincipal,
              naturaleza: tipoDesembolso.naturaleza,
            },
          );

          const movimientoActualizado = await tx.cajaMenorMovimiento.update({
            where: {
              cajaMenorMovimientoId: movimientoAnterior.cajaMenorMovimientoId,
            },
            data: {
              cajaMenorId: caja.cajaMenorId,
              tipoMovimientoCajaId: tipoDesembolso.tipoMovimientoCajaId,
              usuarioId: usuario.usuarioId,
              fechaMovimiento: fechaInicio,
              monto: this.decimal(valorPrincipal),
              motivo: this.motivoDesembolsoCredito(cliente.nombreCompleto),
              referenciaTabla: 'credito_desembolso',
              referenciaId: creditoId,
            },
            include: {
              cajaMenor: true,
              tipoMovimientoCaja: true,
              usuario: true,
            },
          });

          await this.registrarAuditoriaMovimientoCaja(tx, {
            cajaMenorId: movimientoActualizado.cajaMenorId,
            cajaMenorMovimientoId: movimientoAnterior.cajaMenorMovimientoId,
            usuarioId: usuario.usuarioId,
            accion: 'MODIFICAR',
            detalle: this.detalleMovimientoCajaModificado(
              movimientoAnterior,
              movimientoActualizado,
            ),
          });
          await this.registrarAuditoria(tx, {
            usuarioId: usuario.usuarioId,
            tabla: 'caja_menor_movimiento',
            registroId: movimientoAnterior.cajaMenorMovimientoId,
            accion: 'MODIFICAR',
            descripcion: this.detalleMovimientoCajaModificado(
              movimientoAnterior,
              movimientoActualizado,
            ),
            valoresAnteriores: {
              cajaMenorId: movimientoAnterior.cajaMenorId,
              tipoMovimientoCodigo:
                movimientoAnterior.tipoMovimientoCaja.codigo,
              fechaMovimiento: this.fechaIso(
                movimientoAnterior.fechaMovimiento,
              ),
              monto: this.decimalANumero(movimientoAnterior.monto),
              motivo: movimientoAnterior.motivo,
              creditoId,
            },
            valoresNuevos: {
              cajaMenorId: movimientoActualizado.cajaMenorId,
              tipoMovimientoCodigo:
                movimientoActualizado.tipoMovimientoCaja.codigo,
              fechaMovimiento: this.fechaIso(
                movimientoActualizado.fechaMovimiento,
              ),
              monto: this.decimalANumero(movimientoActualizado.monto),
              motivo: movimientoActualizado.motivo,
              creditoId,
            },
          });
        } else {
          await this.asegurarSalidaCajaConPresupuesto(
            tx,
            caja.cajaMenorId,
            valorPrincipal,
            'La modificacion deja la caja menor sin presupuesto disponible',
            'CAJA_MENOR_SALDO_INSUFICIENTE',
          );

          const movimientoCreado = await tx.cajaMenorMovimiento.create({
            data: {
              cajaMenorId: caja.cajaMenorId,
              tipoMovimientoCajaId: tipoDesembolso.tipoMovimientoCajaId,
              usuarioId: usuario.usuarioId,
              fechaMovimiento: fechaInicio,
              monto: this.decimal(valorPrincipal),
              motivo: this.motivoDesembolsoCredito(cliente.nombreCompleto),
              referenciaTabla: 'credito_desembolso',
              referenciaId: creditoId,
            },
          });
          cajaMenorMovimientoId = movimientoCreado.cajaMenorMovimientoId;
          const detalle =
            `Se modifico credito de ${credito.cliente.nombreCompleto} ` +
            `y se registro desembolso por ${valorPrincipal}`;
          await this.registrarAuditoriaMovimientoCaja(tx, {
            cajaMenorId: caja.cajaMenorId,
            cajaMenorMovimientoId,
            usuarioId: usuario.usuarioId,
            accion: 'MODIFICAR',
            detalle,
          });
          await this.registrarAuditoria(tx, {
            usuarioId: usuario.usuarioId,
            tabla: 'caja_menor_movimiento',
            registroId: cajaMenorMovimientoId,
            accion: 'MODIFICAR',
            descripcion: detalle,
            valoresNuevos: {
              cajaMenorId: caja.cajaMenorId,
              tipoMovimientoCodigo: tipoDesembolso.codigo,
              fechaMovimiento: this.fechaIso(fechaInicio),
              monto: valorPrincipal,
              motivo: this.motivoDesembolsoCredito(cliente.nombreCompleto),
              creditoId,
            },
          });
        }

        if (credito.desembolso) {
          await tx.creditoDesembolso.update({
            where: {
              creditoDesembolsoId: credito.desembolso.creditoDesembolsoId,
            },
            data: {
              cajaMenorMovimientoId,
              fechaDesembolso: fechaInicio,
              monto: this.decimal(valorPrincipal),
            },
          });
        } else {
          await tx.creditoDesembolso.create({
            data: {
              creditoId,
              cajaMenorMovimientoId,
              fechaDesembolso: fechaInicio,
              monto: this.decimal(valorPrincipal),
            },
          });
        }

        if (plan) {
          await tx.creditoCuota.deleteMany({
            where: { creditoPlanPagoId: credito.planPago.creditoPlanPagoId },
          });

          await tx.creditoPlanPago.update({
            where: { creditoPlanPagoId: credito.planPago.creditoPlanPagoId },
            data: {
              numeroCuotas: plan.numeroCuotas,
              valorCuota: this.decimal(plan.valorCuota),
              valorTotal: this.decimal(plan.valorTotal),
              fechaMaxima: plan.fechaMaxima,
              domingosOmitidos: plan.domingosOmitidos,
            },
          });

          await tx.creditoCuota.createMany({
            data: plan.cuotas.map((cuota) => ({
              creditoPlanPagoId: credito.planPago!.creditoPlanPagoId,
              estadoCuotaId: estadoPendiente.estadoCuotaId,
              numeroCuota: cuota.numeroCuota,
              fechaVencimiento: cuota.fechaVencimiento,
              valorCapital: this.decimal(cuota.valorCapital),
              valorInteres: this.decimal(cuota.valorInteres),
            })),
          });
        }

        await tx.credito.update({
          where: { creditoId },
          data: {
            clienteId: dto.clienteId,
            rutaId: ruta.rutaId,
            monedaCodigo: moneda.codigoMoneda,
            frecuenciaPagoId: frecuenciaPago.frecuenciaPagoId,
            fechaInicio,
            valorPrincipal: this.decimal(valorPrincipal),
            porcentajeInteres: this.decimal(porcentajeInteres, 4),
            plazoDias: dto.plazoDias,
            omitirDomingos,
            observacion: this.normalizarTextoOpcional(dto.observacion),
            ...(limpiarRefinanciacion
              ? {
                  refinanciadoEn: null,
                  valorPrincipalAnterior: null,
                  valorPrincipalRefinanciado: null,
                }
              : {}),
          },
        });
        await this.asegurarClienteEnRuta(tx, ruta.rutaId, cliente.clienteId);

        await this.registrarAuditoria(tx, {
          usuarioId: usuario.usuarioId,
          tabla: 'credito',
          registroId: creditoId,
          accion: 'MODIFICAR',
          descripcion: `Se modifico credito de ${credito.cliente.nombreCompleto}`,
          valoresAnteriores: {
            clienteId: credito.clienteId,
            rutaId: credito.rutaId,
            monedaCodigo: credito.monedaCodigo,
            frecuenciaPagoId: credito.frecuenciaPagoId,
            fechaInicio: this.fechaIso(credito.fechaInicio),
            valorPrincipal: this.decimalANumero(credito.valorPrincipal),
            porcentajeInteres: this.decimalANumero(credito.porcentajeInteres),
            plazoDias: credito.plazoDias,
            omitirDomingos: credito.omitirDomingos,
            observacion: credito.observacion,
          },
          valoresNuevos: {
            clienteId: dto.clienteId,
            rutaId: ruta.rutaId,
            monedaCodigo: moneda.codigoMoneda,
            frecuenciaPagoId: frecuenciaPago.frecuenciaPagoId,
            fechaInicio: this.fechaIso(fechaInicio),
            valorPrincipal,
            porcentajeInteres,
            plazoDias: dto.plazoDias,
            omitirDomingos,
            observacion: this.normalizarTextoOpcional(dto.observacion),
          },
        });

        return creditoId;
      },
      { maxWait: 10_000, timeout: 20_000 },
    );

    this.invalidarCacheLecturas();
    return this.obtenerCredito(creditoActualizadoId, usuario);
  }

  async eliminarCredito(creditoId: string, usuario: AuthenticatedUser) {
    this.asegurarPermiso(usuario, 'ELIMINAR_CREDITOS');

    await this.prisma.$transaction(
      async (tx) => {
        await tx.$queryRaw(Prisma.sql`
          SELECT credito_id
          FROM public.credito
          WHERE credito_id = ${creditoId}::uuid
          FOR UPDATE
        `);

        const credito = await tx.credito.findUnique({
          where: { creditoId },
          include: {
            cliente: true,
            planPago: true,
            desembolso: {
              include: {
                cajaMenorMovimiento: {
                  include: {
                    cajaMenor: true,
                    tipoMovimientoCaja: true,
                    usuario: true,
                  },
                },
              },
            },
          },
        });

        if (!credito) {
          throw DomainError.notFound(
            'Credito no encontrado',
            'CREDITO_NO_ENCONTRADO',
          );
        }

        const pagosAplicados = await tx.pagoAplicacion.count({
          where: { creditoCuota: { planPago: { creditoId } } },
        });

        if (pagosAplicados > 0) {
          throw DomainError.conflict(
            'No se puede eliminar un credito con pagos registrados',
            'CREDITO_CON_PAGOS_NO_ELIMINABLE',
          );
        }

        const movimiento = credito.desembolso?.cajaMenorMovimiento;
        if (movimiento) {
          await this.registrarAuditoriaMovimientoCaja(tx, {
            cajaMenorId: movimiento.cajaMenorId,
            cajaMenorMovimientoId: movimiento.cajaMenorMovimientoId,
            usuarioId: usuario.usuarioId,
            accion: 'ELIMINAR',
            detalle: this.detalleMovimientoCajaEliminado(movimiento),
          });
        }

        await this.registrarAuditoria(tx, {
          usuarioId: usuario.usuarioId,
          tabla: 'credito',
          registroId: creditoId,
          accion: 'ELIMINAR',
          descripcion: `Se elimino credito de ${credito.cliente.nombreCompleto}`,
          valoresAnteriores: {
            clienteId: credito.clienteId,
            fechaInicio: this.fechaIso(credito.fechaInicio),
            valorPrincipal: this.decimalANumero(credito.valorPrincipal),
            porcentajeInteres: this.decimalANumero(credito.porcentajeInteres),
            plazoDias: credito.plazoDias,
          },
        });

        if (credito.desembolso) {
          await tx.creditoDesembolso.delete({
            where: {
              creditoDesembolsoId: credito.desembolso.creditoDesembolsoId,
            },
          });
        }

        await tx.credito.delete({ where: { creditoId } });

        if (movimiento) {
          await tx.cajaMenorMovimiento.delete({
            where: { cajaMenorMovimientoId: movimiento.cajaMenorMovimientoId },
          });
        }
      },
      { maxWait: 10_000, timeout: 20_000 },
    );

    this.invalidarCacheLecturas();
    return { ok: true };
  }

  async refinanciarCredito(
    creditoId: string,
    dto: RefinanciarCreditoDto,
    usuario: AuthenticatedUser,
  ) {
    this.asegurarPermiso(usuario, 'REFINANCIAR_CREDITOS');

    const fechaInicio = this.parsearFecha(dto.fechaInicio, 'fechaInicio');
    const valorNuevo = this.redondear(dto.valorPrincipal);
    const porcentajeInteres = this.redondear(dto.porcentajeInteres, 4);

    const creditoRefinanciadoId = await this.prisma.$transaction(
      async (tx) => {
        await tx.$queryRaw(Prisma.sql`
          SELECT credito_id
          FROM public.credito
          WHERE credito_id = ${creditoId}::uuid
          FOR UPDATE
        `);

        const credito = await tx.credito.findUnique({
          where: { creditoId },
          include: {
            cliente: true,
            ruta: true,
            moneda: true,
            frecuenciaPago: true,
            estadoCredito: true,
            planPago: {
              include: {
                cuotas: {
                  include: { estadoCuota: true },
                  orderBy: { numeroCuota: 'asc' },
                },
              },
            },
            desembolso: true,
          },
        });

        if (!credito || !credito.planPago) {
          throw DomainError.notFound(
            'Credito no encontrado',
            'CREDITO_NO_ENCONTRADO',
          );
        }

        this.asegurarAccesoCredito(credito, usuario);

        if (['PAGADO', 'ANULADO'].includes(credito.estadoCredito.codigo)) {
          throw DomainError.conflict(
            'Solo se pueden refinanciar creditos activos',
            'CREDITO_NO_ACTIVO',
          );
        }

        if (
          dto.monedaCodigo &&
          dto.monedaCodigo.trim().toUpperCase() !== credito.monedaCodigo
        ) {
          throw DomainError.conflict(
            'La refinanciacion debe conservar la moneda del credito',
            'CREDITO_MONEDA_NO_EDITABLE',
          );
        }

        const valorAnterior = this.decimalANumero(credito.valorPrincipal);
        if (valorNuevo <= valorAnterior) {
          throw DomainError.validation(
            'El nuevo valor debe ser mayor al valor actual del credito',
            'REFINANCIACION_VALOR_INVALIDO',
          );
        }

        const incremento = this.redondear(
          valorNuevo - valorAnterior,
          credito.moneda.decimales,
        );

        const [frecuenciaPago, estadoPendiente, estadoAnulada, rutaDestino] =
          await Promise.all([
            tx.frecuenciaPago.findUnique({
              where: { frecuenciaPagoId: dto.frecuenciaPagoId },
            }),
            tx.estadoCuota.findUnique({ where: { codigo: 'PENDIENTE' } }),
            tx.estadoCuota.findUnique({ where: { codigo: 'ANULADA' } }),
            dto.rutaId
              ? tx.ruta.findUnique({
                  where: { rutaId: dto.rutaId },
                  include: { estadoRuta: true },
                })
              : tx.ruta.findUnique({
                  where: { rutaId: credito.rutaId },
                  include: { estadoRuta: true },
                }),
          ]);

        if (!frecuenciaPago || !estadoPendiente || !estadoAnulada) {
          throw DomainError.notFound(
            'Faltan catalogos base para refinanciar el credito',
            'CATALOGO_CREDITO_INCOMPLETO',
          );
        }

        if (!rutaDestino) {
          throw DomainError.notFound(
            'Ruta no encontrada',
            'RUTA_NO_ENCONTRADA',
          );
        }

        this.asegurarResponsableRuta(rutaDestino.responsableUsuarioId, usuario);

        if (rutaDestino.estadoRuta.codigo !== 'ABIERTA') {
          throw DomainError.conflict(
            'La ruta no esta abierta para refinanciar creditos',
            'RUTA_NO_ABIERTA',
          );
        }

        const cuotaIds = credito.planPago.cuotas.map(
          (cuota) => cuota.creditoCuotaId,
        );
        const sumas =
          cuotaIds.length === 0
            ? []
            : await tx.pagoAplicacion.groupBy({
                by: ['creditoCuotaId'],
                where: { creditoCuotaId: { in: cuotaIds } },
                _sum: {
                  montoCapital: true,
                  montoInteres: true,
                  montoMora: true,
                  montoDescuento: true,
                },
              });
        const sumasPorCuota = new Map<string, SumaAplicaciones>();
        let capitalAbonado = 0;
        let interesAbonado = 0;

        for (const suma of sumas) {
          const item: SumaAplicaciones = { _sum: suma._sum };
          sumasPorCuota.set(suma.creditoCuotaId, item);
          capitalAbonado += this.decimalANumero(suma._sum.montoCapital);
          interesAbonado += this.decimalANumero(suma._sum.montoInteres);
          interesAbonado += this.decimalANumero(suma._sum.montoMora);
          interesAbonado -= this.decimalANumero(suma._sum.montoDescuento);
        }

        const cuotasPagadas = credito.planPago.cuotas.filter((cuota) => {
          if (cuota.estadoCuota.codigo === 'PAGADA') {
            return true;
          }

          const sumasCuota =
            sumasPorCuota.get(cuota.creditoCuotaId) ??
            this.sumasAplicacionesVacias();
          return this.saldoCuota(cuota, sumasCuota) <= 0;
        });
        const totalNuevo = this.redondear(
          valorNuevo + valorNuevo * (porcentajeInteres / 100),
          credito.moneda.decimales,
        );
        const interesNuevo = this.redondear(
          totalNuevo - valorNuevo,
          credito.moneda.decimales,
        );
        const capitalPendiente = this.redondear(
          Math.max(0, valorNuevo - capitalAbonado),
          credito.moneda.decimales,
        );
        const interesPendiente = this.redondear(
          Math.max(0, interesNuevo - interesAbonado),
          credito.moneda.decimales,
        );
        const planPendiente = this.calcularPlanPendiente({
          fechaInicio,
          valorCapital: capitalPendiente,
          valorInteres: interesPendiente,
          plazoDias: dto.plazoDias,
          diasIntervalo: frecuenciaPago.diasIntervalo,
          omitirDomingos: dto.omitirDomingos ?? credito.omitirDomingos,
          decimales: credito.moneda.decimales,
        });

        const movimientoRefinanciacionId =
          await this.registrarRefinanciacionCaja(
            tx,
            {
              cajaMenorId: dto.cajaMenorId,
              monedaCodigo: credito.monedaCodigo,
            },
            rutaDestino,
            usuario,
            incremento,
            fechaInicio,
            credito.cliente.nombreCompleto,
            credito.creditoId,
            valorAnterior,
            valorNuevo,
          );

        await tx.creditoCuota.updateMany({
          where: {
            creditoPlanPagoId: credito.planPago.creditoPlanPagoId,
            estadoCuota: { codigo: { not: 'PAGADA' } },
          },
          data: { estadoCuotaId: estadoAnulada.estadoCuotaId },
        });

        const ultimoNumeroCuota = credito.planPago.cuotas.reduce(
          (maximo, cuota) => Math.max(maximo, cuota.numeroCuota),
          0,
        );

        await tx.creditoCuota.createMany({
          data: planPendiente.cuotas.map((cuota, index) => ({
            creditoPlanPagoId: credito.planPago!.creditoPlanPagoId,
            estadoCuotaId: estadoPendiente.estadoCuotaId,
            numeroCuota: ultimoNumeroCuota + index + 1,
            fechaVencimiento: cuota.fechaVencimiento,
            valorCapital: this.decimal(cuota.valorCapital),
            valorInteres: this.decimal(cuota.valorInteres),
          })),
        });

        await tx.credito.update({
          where: { creditoId },
          data: {
            rutaId: rutaDestino.rutaId,
            frecuenciaPagoId: frecuenciaPago.frecuenciaPagoId,
            fechaInicio,
            valorPrincipal: this.decimal(valorNuevo),
            porcentajeInteres: this.decimal(porcentajeInteres, 4),
            plazoDias: dto.plazoDias,
            omitirDomingos: dto.omitirDomingos ?? credito.omitirDomingos,
            observacion: this.normalizarTextoOpcional(dto.observacion),
            refinanciadoEn: new Date(),
            valorPrincipalAnterior: this.decimal(valorAnterior),
            valorPrincipalRefinanciado: this.decimal(valorNuevo),
          },
        });

        await tx.creditoPlanPago.update({
          where: { creditoPlanPagoId: credito.planPago.creditoPlanPagoId },
          data: {
            numeroCuotas: cuotasPagadas.length + planPendiente.numeroCuotas,
            valorCuota: this.decimal(planPendiente.valorCuota),
            valorTotal: this.decimal(totalNuevo),
            fechaMaxima: planPendiente.fechaMaxima,
            domingosOmitidos: planPendiente.domingosOmitidos,
          },
        });

        if (credito.desembolso) {
          await tx.creditoDesembolso.update({
            where: {
              creditoDesembolsoId: credito.desembolso.creditoDesembolsoId,
            },
            data: {
              monto: this.decimal(valorNuevo),
              fechaDesembolso: fechaInicio,
            },
          });
        } else {
          await tx.creditoDesembolso.create({
            data: {
              creditoId: credito.creditoId,
              cajaMenorMovimientoId: movimientoRefinanciacionId,
              fechaDesembolso: fechaInicio,
              monto: this.decimal(valorNuevo),
            },
          });
        }

        await this.registrarAuditoria(tx, {
          usuarioId: usuario.usuarioId,
          tabla: 'credito',
          registroId: credito.creditoId,
          accion: 'REFINANCIAR',
          descripcion:
            `Credito refinanciado para ${credito.cliente.nombreCompleto}: ` +
            `${this.formatearMontoAuditoria(valorAnterior)} a ` +
            `${this.formatearMontoAuditoria(valorNuevo)}`,
          valoresAnteriores: {
            rutaId: credito.rutaId,
            frecuenciaPagoId: credito.frecuenciaPagoId,
            fechaInicio: this.fechaIso(credito.fechaInicio),
            valorPrincipal: valorAnterior,
            porcentajeInteres: this.decimalANumero(credito.porcentajeInteres),
            plazoDias: credito.plazoDias,
            omitirDomingos: credito.omitirDomingos,
            valorTotal: this.decimalANumero(credito.planPago.valorTotal),
            cuotasPlan: credito.planPago.numeroCuotas,
            fechaMaxima: this.fechaIso(credito.planPago.fechaMaxima),
          },
          valoresNuevos: {
            rutaId: rutaDestino.rutaId,
            frecuenciaPagoId: frecuenciaPago.frecuenciaPagoId,
            fechaInicio: this.fechaIso(fechaInicio),
            valorPrincipal: valorNuevo,
            porcentajeInteres,
            plazoDias: dto.plazoDias,
            omitirDomingos: dto.omitirDomingos ?? credito.omitirDomingos,
            valorTotal: totalNuevo,
            cuotasPlan: cuotasPagadas.length + planPendiente.numeroCuotas,
            fechaMaxima: this.fechaIso(planPendiente.fechaMaxima),
          },
          metadata: {
            incremento,
            cajaMenorId: dto.cajaMenorId,
            movimientoCajaId: movimientoRefinanciacionId,
            cuotasAnuladas:
              credito.planPago.cuotas.length - cuotasPagadas.length,
            cuotasNuevas: planPendiente.numeroCuotas,
            capitalAbonado: this.redondear(
              capitalAbonado,
              credito.moneda.decimales,
            ),
            interesAbonado: this.redondear(
              interesAbonado,
              credito.moneda.decimales,
            ),
          },
        });

        await this.asegurarClienteEnRuta(
          tx,
          rutaDestino.rutaId,
          credito.clienteId,
        );

        return credito.creditoId;
      },
      { maxWait: 10_000, timeout: 20_000 },
    );

    this.invalidarCacheLecturas();
    return this.obtenerCredito(creditoRefinanciadoId, usuario);
  }

  async obtenerCredito(creditoId: string, usuario: AuthenticatedUser) {
    if (this.esIdTbl(creditoId) && (await this.usarEsquemaTbl())) {
      return this.obtenerCreditoTbl(creditoId, usuario);
    }

    const credito = await this.prisma.credito.findUnique({
      where: { creditoId },
      include: {
        cliente: {
          include: {
            documentos: { include: { tipoDocumento: true } },
            direcciones: true,
          },
        },
        ruta: true,
        moneda: true,
        frecuenciaPago: true,
        estadoCredito: true,
        planPago: true,
        desembolso: {
          include: {
            cajaMenorMovimiento: {
              include: { cajaMenor: true },
            },
          },
        },
      },
    });

    if (!credito) {
      throw DomainError.notFound(
        'Credito no encontrado',
        'CREDITO_NO_ENCONTRADO',
      );
    }

    this.asegurarAccesoCredito(credito, usuario);
    const resumen = credito.planPago
      ? await this.resumenCredito(credito.planPago.creditoPlanPagoId)
      : { totalAbonado: 0, cuotasRestantes: 0 };
    const totalAbonado = resumen.totalAbonado;
    const valorTotal = credito.planPago
      ? this.decimalANumero(credito.planPago.valorTotal)
      : 0;
    const documentoPrincipal =
      credito.cliente.documentos.find(
        (documento) => documento.tipoDocumento.codigo === 'CC',
      ) ?? credito.cliente.documentos[0];
    const direccionPrincipal =
      credito.cliente.direcciones.find((direccion) => direccion.esPrincipal) ??
      credito.cliente.direcciones[0];
    const cajaMenor =
      credito.desembolso?.cajaMenorMovimiento?.cajaMenor ?? null;

    return {
      id: credito.creditoId,
      clienteId: credito.clienteId,
      cliente: credito.cliente.nombreCompleto,
      cedula: documentoPrincipal?.numeroDocumento ?? null,
      negocio: credito.cliente.nombreComercial,
      direccion: direccionPrincipal?.direccion ?? null,
      rutaId: credito.rutaId,
      ruta: credito.ruta.nombre,
      cajaMenorId: cajaMenor?.cajaMenorId ?? null,
      cajaMenor: cajaMenor?.nombre ?? null,
      monedaCodigo: credito.monedaCodigo,
      frecuenciaPago: {
        id: credito.frecuenciaPago.frecuenciaPagoId,
        codigo: credito.frecuenciaPago.codigo,
        nombre: credito.frecuenciaPago.nombre,
        diasIntervalo: credito.frecuenciaPago.diasIntervalo,
      },
      estado: {
        codigo: credito.estadoCredito.codigo,
        nombre: credito.estadoCredito.nombre,
      },
      fechaInicio: this.fechaIso(credito.fechaInicio),
      valorPrincipal: this.decimalANumero(credito.valorPrincipal),
      porcentajeInteres: this.decimalANumero(credito.porcentajeInteres),
      plazoDias: credito.plazoDias,
      omitirDomingos: credito.omitirDomingos,
      valorTotal,
      valorCuota: credito.planPago
        ? this.decimalANumero(credito.planPago.valorCuota)
        : 0,
      totalAbonado,
      saldo: this.redondear(Math.max(valorTotal - totalAbonado, 0)),
      numeroCuotas: credito.planPago?.numeroCuotas ?? 0,
      cuotasRestantes: resumen.cuotasRestantes,
      fechaMaxima: credito.planPago
        ? this.fechaIso(credito.planPago.fechaMaxima)
        : this.fechaIso(credito.fechaInicio),
      observacion: credito.observacion,
      refinanciacion:
        credito.refinanciadoEn &&
        credito.valorPrincipalAnterior &&
        credito.valorPrincipalRefinanciado
          ? {
              fecha: credito.refinanciadoEn.toISOString(),
              valorAnterior: this.decimalANumero(
                credito.valorPrincipalAnterior,
              ),
              valorNuevo: this.decimalANumero(
                credito.valorPrincipalRefinanciado,
              ),
            }
          : null,
      planPago: credito.planPago
        ? {
            id: credito.planPago.creditoPlanPagoId,
            numeroCuotas: credito.planPago.numeroCuotas,
            valorCuota: this.decimalANumero(credito.planPago.valorCuota),
            valorTotal: this.decimalANumero(credito.planPago.valorTotal),
            fechaMaxima: this.fechaIso(credito.planPago.fechaMaxima),
            domingosOmitidos: credito.planPago.domingosOmitidos,
          }
        : null,
      desembolso: credito.desembolso
        ? {
            id: credito.desembolso.creditoDesembolsoId,
            fechaDesembolso: this.fechaIso(credito.desembolso.fechaDesembolso),
            monto: this.decimalANumero(credito.desembolso.monto),
          }
        : null,
      creadoEn: credito.creadoEn.toISOString(),
      actualizadoEn: credito.actualizadoEn.toISOString(),
    };
  }

  private async resumenCredito(creditoPlanPagoId: string) {
    const rows = await this.prisma.$queryRaw<ResumenCreditoRow[]>(Prisma.sql`
      WITH abonos_cuota AS (
        SELECT
          cc.credito_cuota_id,
          COALESCE(
            SUM(
              pa.monto_capital
              + pa.monto_interes
              + pa.monto_mora
              - pa.monto_descuento
            ),
            0
          ) AS abonado
        FROM public.credito_cuota cc
        LEFT JOIN public.pago_aplicacion pa
          ON pa.credito_cuota_id = cc.credito_cuota_id
        WHERE cc.credito_plan_pago_id = ${creditoPlanPagoId}::uuid
        GROUP BY cc.credito_cuota_id
      )
      SELECT
        COALESCE(SUM(ac.abonado), 0) AS total_abonado,
        COUNT(*) FILTER (
          WHERE ec.codigo NOT IN ('PAGADA', 'ANULADA')
            AND (cc.valor_total - COALESCE(ac.abonado, 0)) > 0
        )::int AS cuotas_restantes
      FROM public.credito_cuota cc
      JOIN public.estado_cuota ec
        ON ec.estado_cuota_id = cc.estado_cuota_id
      LEFT JOIN abonos_cuota ac
        ON ac.credito_cuota_id = cc.credito_cuota_id
      WHERE cc.credito_plan_pago_id = ${creditoPlanPagoId}::uuid
    `);
    const row = rows[0];

    return {
      totalAbonado: row ? this.decimalANumero(row.total_abonado) : 0,
      cuotasRestantes: row?.cuotas_restantes ?? 0,
    };
  }

  async registrarPago(dto: RegistrarPagoDto, usuario: AuthenticatedUser) {
    this.asegurarPermiso(usuario, 'AGREGAR_CUOTA');

    if (this.esIdTbl(dto.creditoCuotaId) && (await this.usarEsquemaTbl())) {
      return this.registrarPagoTbl(dto, usuario);
    }

    const resultadoPago = await this.prisma.$transaction(
      async (tx) => {
        await tx.$queryRaw(Prisma.sql`
          SELECT credito_cuota_id
          FROM public.credito_cuota
          WHERE credito_cuota_id = ${dto.creditoCuotaId}::uuid
          FOR UPDATE
        `);

        const cuota = await tx.creditoCuota.findUnique({
          where: { creditoCuotaId: dto.creditoCuotaId },
          include: {
            estadoCuota: true,
            planPago: {
              include: {
                credito: {
                  include: {
                    ruta: true,
                    cliente: true,
                  },
                },
              },
            },
          },
        });

        if (!cuota) {
          throw DomainError.notFound(
            'Cuota no encontrada',
            'CUOTA_NO_ENCONTRADA',
          );
        }

        this.asegurarAccesoCredito(cuota.planPago.credito, usuario);

        if (cuota.estadoCuota.codigo === 'ANULADA') {
          throw DomainError.conflict('La cuota esta anulada', 'CUOTA_ANULADA');
        }

        const medioPago = await tx.medioPago.findUnique({
          where: { codigo: dto.medioPagoCodigo ?? 'EFECTIVO' },
        });

        if (!medioPago) {
          throw DomainError.notFound(
            'Medio de pago no encontrado',
            'MEDIO_PAGO_NO_ENCONTRADO',
          );
        }

        const montoPagado = this.redondear(dto.montoPagado);
        const pagoRecienteDuplicado = await tx.pago.findFirst({
          where: {
            cobradorUsuarioId: usuario.usuarioId,
            totalPagado: this.decimal(montoPagado),
            creadoEn: { gte: this.segundosAtras(30) },
            aplicaciones: {
              some: { creditoCuotaId: dto.creditoCuotaId },
            },
          },
          orderBy: { creadoEn: 'desc' },
          select: { pagoId: true },
        });

        if (pagoRecienteDuplicado) {
          return { pagoId: pagoRecienteDuplicado.pagoId, creado: false };
        }

        const cuotas = await tx.creditoCuota.findMany({
          where: {
            creditoPlanPagoId: cuota.creditoPlanPagoId,
            estadoCuota: { codigo: { not: 'ANULADA' } },
          },
          include: {
            estadoCuota: true,
            planPago: {
              include: {
                credito: {
                  include: {
                    ruta: true,
                    cliente: true,
                  },
                },
              },
            },
          },
          orderBy: { numeroCuota: 'asc' },
        });

        const cuotasConSaldo: Array<{
          cuota: CreditoCuotaParaPago;
          sumas: SumaAplicaciones;
          saldo: number;
        }> = [];

        const sumasPorCuota = new Map<string, SumaAplicaciones>();
        const cuotaIds = cuotas.map((item) => item.creditoCuotaId);

        if (cuotaIds.length > 0) {
          const sumas = await tx.pagoAplicacion.groupBy({
            by: ['creditoCuotaId'],
            where: { creditoCuotaId: { in: cuotaIds } },
            _sum: {
              montoCapital: true,
              montoInteres: true,
              montoMora: true,
              montoDescuento: true,
            },
          });

          sumas.forEach((suma) => {
            sumasPorCuota.set(suma.creditoCuotaId, { _sum: suma._sum });
          });
        }

        for (const cuotaPendiente of cuotas) {
          const sumas =
            sumasPorCuota.get(cuotaPendiente.creditoCuotaId) ??
            this.sumasAplicacionesVacias();
          const saldo = this.saldoCuota(cuotaPendiente, sumas);

          if (saldo > 0 && cuotaPendiente.estadoCuota.codigo !== 'PAGADA') {
            cuotasConSaldo.push({
              cuota: cuotaPendiente,
              sumas,
              saldo,
            });
          }
        }

        const saldoCredito = this.redondear(
          cuotasConSaldo.reduce((total, item) => total + item.saldo, 0),
        );

        if (saldoCredito <= 0) {
          throw DomainError.conflict(
            'El credito ya esta pagado',
            'CREDITO_YA_PAGADO',
          );
        }

        if (this.redondear(montoPagado - saldoCredito) > 0) {
          throw DomainError.validation(
            'El pago supera el saldo del credito',
            'PAGO_SUPERA_SALDO_CREDITO',
          );
        }

        const credito = cuota.planPago.credito;
        const pago = await tx.pago.create({
          data: {
            clienteId: credito.clienteId,
            rutaId: credito.rutaId,
            cobradorUsuarioId: usuario.usuarioId,
            medioPagoId: medioPago.medioPagoId,
            monedaCodigo: credito.monedaCodigo,
            totalPagado: this.decimal(montoPagado),
            referenciaExterna: this.normalizarTextoOpcional(
              dto.referenciaExterna,
            ),
            observacion: this.normalizarTextoOpcional(dto.observacion),
          },
        });

        const aplicaciones: Prisma.PagoAplicacionCreateManyInput[] = [];
        const cuotasPagadas: string[] = [];
        let restante = montoPagado;

        for (const cuotaConSaldo of cuotasConSaldo) {
          if (restante <= 0) {
            break;
          }

          const montoCuota = this.redondear(
            Math.min(restante, cuotaConSaldo.saldo),
          );
          const distribucion = this.distribuirPagoEnCuota(
            cuotaConSaldo.cuota,
            cuotaConSaldo.sumas,
            montoCuota,
          );

          aplicaciones.push({
            pagoId: pago.pagoId,
            creditoCuotaId: cuotaConSaldo.cuota.creditoCuotaId,
            montoCapital: this.decimal(distribucion.capital),
            montoInteres: this.decimal(distribucion.interes),
            montoMora: this.decimal(0),
            montoDescuento: this.decimal(0),
          });

          if (this.redondear(cuotaConSaldo.saldo - montoCuota) <= 0) {
            cuotasPagadas.push(cuotaConSaldo.cuota.creditoCuotaId);
          }

          restante = this.redondear(restante - montoCuota);
        }

        await tx.pagoAplicacion.createMany({
          data: aplicaciones,
        });

        if (cuotasPagadas.length > 0) {
          const estadoPagada = await tx.estadoCuota.findUnique({
            where: { codigo: 'PAGADA' },
          });

          if (!estadoPagada) {
            throw DomainError.notFound(
              'Falta el estado de cuota PAGADA',
              'ESTADO_CUOTA_PAGADA_NO_EXISTE',
            );
          }

          await tx.creditoCuota.updateMany({
            where: { creditoCuotaId: { in: cuotasPagadas } },
            data: { estadoCuotaId: estadoPagada.estadoCuotaId },
          });

          await this.marcarCreditoPagadoSiCorresponde(tx, credito.creditoId);
        }

        return { pagoId: pago.pagoId, creado: true };
      },
      { maxWait: 10_000, timeout: 15_000 },
    );

    this.invalidarCacheLecturas();
    const pago = await this.obtenerPago(resultadoPago.pagoId, usuario);
    if (resultadoPago.creado) {
      void this.notifications.notifyPaymentReceived(resultadoPago.pagoId);
    }
    return pago;
  }

  private async registrarPagoTbl(
    dto: RegistrarPagoDto,
    usuario: AuthenticatedUser,
  ) {
    const montoPagado = this.redondear(dto.montoPagado);
    const codigoMedioPago = (dto.medioPagoCodigo ?? 'EFECTIVO')
      .trim()
      .toUpperCase();
    const referenciaPago =
      this.normalizarTextoOpcional(dto.referenciaExterna) ??
      this.normalizarTextoOpcional(dto.observacion);

    const resultadoPago = await this.prisma.$transaction(
      async (tx) => {
        const scope = await this.obtenerScopeOrganizacionTbl(usuario, tx);
        await tx.$queryRaw(Prisma.sql`
          SELECT id_cuo
          FROM public.tbl_cuotas
          WHERE id_cuo = ${dto.creditoCuotaId}::uuid
          FOR UPDATE
        `);

        const [cuota] = await tx.$queryRaw<
          Array<{
            cuota_id: string;
            cuota_estado: string;
            credito_id: string;
            credito_estado: string;
            cliente_id: string;
            cliente: string;
            org_id: string;
            usuario_id: string;
            usuario: string;
            moneda_id: string;
            moneda_codigo: string;
          }>
        >(Prisma.sql`
          SELECT
            cu.id_cuo::text AS cuota_id,
            UPPER(cu.cuo_estado::text) AS cuota_estado,
            cr.id_cre::text AS credito_id,
            UPPER(cr.cre_estado::text) AS credito_estado,
            cl.id_cli::text AS cliente_id,
            TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS cliente,
            cl.org_id::text AS org_id,
            tu.id_usu::text AS usuario_id,
            tu.usu_usuario AS usuario,
            mon.id_mon::text AS moneda_id,
            mon.mon_codigo::text AS moneda_codigo
          FROM public.tbl_cuotas cu
          JOIN public.tbl_creditos cr ON cr.id_cre = cu.cre_id
          JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
          JOIN public.tbl_personas p ON p.id_per = cl.cli_persona
          JOIN public.tbl_usuarios tu ON tu.id_usu = cr.usu_id
          JOIN public.tbl_monedas mon ON mon.id_mon = cr.mon_id
          WHERE cu.id_cuo = ${dto.creditoCuotaId}::uuid
          LIMIT 1
        `);

        if (!cuota) {
          throw DomainError.notFound(
            'Cuota no encontrada',
            'CUOTA_NO_ENCONTRADA',
          );
        }

        if (cuota.org_id !== scope.organizacionId) {
          throw new ForbiddenException('No tienes acceso a este credito');
        }

        if (
          !this.esAdministrador(usuario) &&
          cuota.usuario !== usuario.usuario
        ) {
          throw new ForbiddenException('No tienes acceso a este credito');
        }

        if (cuota.cuota_estado === 'ANULADA') {
          throw DomainError.conflict('La cuota esta anulada', 'CUOTA_ANULADA');
        }

        if (cuota.credito_estado === 'ANULADO') {
          throw DomainError.conflict(
            'El credito esta anulado',
            'CREDITO_ANULADO',
          );
        }

        let [medioPago] = await tx.$queryRaw<
          Array<{ id: string; codigo: string; nombre: string }>
        >(Prisma.sql`
          SELECT
            id_med::text AS id,
            UPPER(med_tipo::text) AS codigo,
            med_nombre AS nombre
          FROM public.tbl_medios_pagos
          WHERE med_activo
            AND (
              UPPER(med_tipo::text) = ${codigoMedioPago}
              OR UPPER(TRIM(med_nombre)) = ${codigoMedioPago}
            )
          ORDER BY
            CASE WHEN UPPER(med_tipo::text) = ${codigoMedioPago} THEN 0 ELSE 1 END,
            id_med ASC
          LIMIT 1
        `);

        if (!medioPago) {
          const mediosPagoBase = [
            'EFECTIVO',
            'TRANSFERENCIA',
            'TARJETA',
            'BILLETERA',
            'OTRO',
          ];
          if (!mediosPagoBase.includes(codigoMedioPago)) {
            throw DomainError.notFound(
              'Medio de pago no encontrado',
              'MEDIO_PAGO_NO_ENCONTRADO',
            );
          }

          [medioPago] = await tx.$queryRaw<
            Array<{ id: string; codigo: string; nombre: string }>
          >(Prisma.sql`
            INSERT INTO public.tbl_medios_pagos (
              med_nombre,
              med_tipo
            )
            VALUES (
              ${this.nombreDesdeCodigo(codigoMedioPago)},
              ${codigoMedioPago}::public.medio_pago_tipo_enum
            )
            ON CONFLICT (med_tipo) DO UPDATE
            SET
              med_nombre = EXCLUDED.med_nombre,
              med_activo = TRUE
            RETURNING
              id_med::text AS id,
              UPPER(med_tipo::text) AS codigo,
              med_nombre AS nombre
          `);
        }

        const [pagoRecienteDuplicado] = await tx.$queryRaw<
          Array<{ id: string }>
        >(Prisma.sql`
          SELECT pa.id_pag::text AS id
          FROM public.tbl_pagos pa
          JOIN public.tbl_cuotas_pagos cp ON cp.pagos_id = pa.id_pag
          WHERE cp.cuo_id = ${dto.creditoCuotaId}::uuid
            AND pa.pag_monto = ${this.decimal(montoPagado)}
            AND pa.pag_fecha >= ${this.segundosAtras(30)}
          ORDER BY pa.pag_fecha DESC, pa.id_pag DESC
          LIMIT 1
        `);

        if (pagoRecienteDuplicado) {
          return { pagoId: pagoRecienteDuplicado.id, creado: false };
        }

        await tx.$queryRaw(Prisma.sql`
          SELECT id_cuo
          FROM public.tbl_cuotas
          WHERE cre_id = ${cuota.credito_id}::uuid
          FOR UPDATE
        `);

        const cuotas = await tx.$queryRaw<
          Array<{
            cuota_id: string;
            numero: number | bigint;
            valor: Prisma.Decimal;
            abonado: Prisma.Decimal;
            estado: string;
          }>
        >(Prisma.sql`
          SELECT
            cu.id_cuo::text AS cuota_id,
            cu.cuo_numero AS numero,
            cu.cuo_valor AS valor,
            GREATEST(
              COALESCE(cu.cuo_total_pagado, 0),
              COALESCE(SUM(cp.cpa_total), 0)
            ) AS abonado,
            UPPER(cu.cuo_estado::text) AS estado
          FROM public.tbl_cuotas cu
          LEFT JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
          WHERE cu.cre_id = ${cuota.credito_id}::uuid
            AND UPPER(cu.cuo_estado::text) <> 'ANULADA'
          GROUP BY cu.id_cuo
          ORDER BY cu.cuo_numero ASC
        `);

        const cuotasConSaldo = cuotas
          .map((item) => {
            const saldo = this.redondear(
              this.decimalANumero(item.valor) -
                this.decimalANumero(item.abonado),
            );
            return { cuota: item, saldo };
          })
          .filter((item) => item.saldo > 0);
        const saldoCredito = this.redondear(
          cuotasConSaldo.reduce((total, item) => total + item.saldo, 0),
        );

        if (saldoCredito <= 0) {
          throw DomainError.conflict(
            'El credito ya esta pagado',
            'CREDITO_YA_PAGADO',
          );
        }

        if (this.redondear(montoPagado - saldoCredito) > 0) {
          throw DomainError.validation(
            'El pago supera el saldo del credito',
            'PAGO_SUPERA_SALDO_CREDITO',
          );
        }

        const [pago] = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
          INSERT INTO public.tbl_pagos (
            pag_monto,
            pag_referencia,
            med_id,
            mon_id
          )
          VALUES (
            ${this.decimal(montoPagado)},
            ${referenciaPago},
            ${medioPago.id}::uuid,
            ${cuota.moneda_id}::uuid
          )
          RETURNING id_pag::text AS id
        `);

        const cuotasAfectadas: string[] = [];
        let restante = montoPagado;

        for (const cuotaConSaldo of cuotasConSaldo) {
          if (restante <= 0) {
            break;
          }

          const montoCuota = this.redondear(
            Math.min(restante, cuotaConSaldo.saldo),
          );
          await tx.$executeRaw(Prisma.sql`
            INSERT INTO public.tbl_cuotas_pagos (
              cpa_numero,
              cpa_capital,
              cpa_interes,
              cuo_id,
              pagos_id
            )
            VALUES (
              ${Number(cuotaConSaldo.cuota.numero)},
              ${this.decimal(montoCuota)},
              0,
              ${cuotaConSaldo.cuota.cuota_id}::uuid,
              ${pago.id}::uuid
            )
          `);

          cuotasAfectadas.push(cuotaConSaldo.cuota.cuota_id);
          restante = this.redondear(restante - montoCuota);
        }

        for (const cuotaId of cuotasAfectadas) {
          await tx.$executeRaw(Prisma.sql`
            UPDATE public.tbl_cuotas cu
            SET
              cuo_total_pagado = LEAST(
                cu.cuo_valor,
                GREATEST(
                  COALESCE(cu.cuo_total_pagado, 0),
                  COALESCE((
                    SELECT SUM(cp.cpa_total)
                    FROM public.tbl_cuotas_pagos cp
                    WHERE cp.cuo_id = cu.id_cuo
                  ), 0)
                )
              ),
              cuo_estado = CASE
                WHEN LEAST(
                  cu.cuo_valor,
                  GREATEST(
                    COALESCE(cu.cuo_total_pagado, 0),
                    COALESCE((
                      SELECT SUM(cp.cpa_total)
                      FROM public.tbl_cuotas_pagos cp
                      WHERE cp.cuo_id = cu.id_cuo
                    ), 0)
                  )
                ) >= cu.cuo_valor
                  THEN 'PAGADA'::public.cuota_estado_enum
                ELSE 'PENDIENTE'::public.cuota_estado_enum
              END
            WHERE cu.id_cuo = ${cuotaId}::uuid
              AND UPPER(cu.cuo_estado::text) <> 'ANULADA'
          `);
        }

        await tx.$executeRaw(Prisma.sql`
          UPDATE public.tbl_creditos cr
          SET cre_estado = CASE
            WHEN NOT EXISTS (
              SELECT 1
              FROM public.tbl_cuotas cu
              WHERE cu.cre_id = cr.id_cre
                AND UPPER(cu.cuo_estado::text) <> 'ANULADA'
                AND (cu.cuo_valor - COALESCE(cu.cuo_total_pagado, 0)) > 0
            )
              THEN 'PAGADO'::public.credito_estado_enum
            ELSE 'ACTIVO'::public.credito_estado_enum
          END
          WHERE cr.id_cre = ${cuota.credito_id}::uuid
            AND UPPER(cr.cre_estado::text) <> 'ANULADO'
        `);

        return { pagoId: pago.id, creado: true };
      },
      { maxWait: 10_000, timeout: 15_000 },
    );

    this.invalidarCacheLecturas();
    const pago = await this.obtenerPagoTbl(resultadoPago.pagoId, usuario);
    if (resultadoPago.creado) {
      void this.notifications.notifyPaymentReceived(resultadoPago.pagoId);
    }
    return pago;
  }

  async obtenerPago(pagoId: string, usuario: AuthenticatedUser) {
    if (this.esIdTbl(pagoId) && (await this.usarEsquemaTbl())) {
      return this.obtenerPagoTbl(pagoId, usuario);
    }

    const pago = await this.prisma.pago.findUnique({
      where: { pagoId },
      include: {
        cliente: true,
        ruta: true,
        medioPago: true,
        aplicaciones: {
          include: {
            creditoCuota: true,
          },
        },
      },
    });

    if (!pago) {
      throw DomainError.notFound('Pago no encontrado', 'PAGO_NO_ENCONTRADO');
    }

    this.asegurarResponsableRuta(pago.ruta.responsableUsuarioId, usuario);

    return {
      id: pago.pagoId,
      clienteId: pago.clienteId,
      cliente: pago.cliente.nombreCompleto,
      rutaId: pago.rutaId,
      ruta: pago.ruta.nombre,
      medioPago: {
        id: pago.medioPago.medioPagoId,
        codigo: pago.medioPago.codigo,
        nombre: pago.medioPago.nombre,
      },
      monedaCodigo: pago.monedaCodigo,
      fechaPago: pago.fechaPago.toISOString(),
      totalPagado: this.decimalANumero(pago.totalPagado),
      referenciaExterna: pago.referenciaExterna,
      observacion: pago.observacion,
      aplicaciones: pago.aplicaciones.map((aplicacion) => ({
        id: aplicacion.pagoAplicacionId,
        creditoCuotaId: aplicacion.creditoCuotaId,
        numeroCuota: aplicacion.creditoCuota.numeroCuota,
        montoCapital: this.decimalANumero(aplicacion.montoCapital),
        montoInteres: this.decimalANumero(aplicacion.montoInteres),
        montoMora: this.decimalANumero(aplicacion.montoMora),
        montoDescuento: this.decimalANumero(aplicacion.montoDescuento),
      })),
    };
  }

  private async obtenerPagoTbl(pagoId: string, usuario: AuthenticatedUser) {
    const scope = await this.obtenerScopeOrganizacionTbl(usuario);
    const rows = await this.prisma.$queryRaw<PagoTblRow[]>(Prisma.sql`
      SELECT
        pa.id_pag::text AS pago_id,
        cr.id_cre::text AS credito_id,
        cl.id_cli::text AS cliente_id,
        TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS cliente,
        ruta_credito.ruta_id::text AS ruta_id,
        ruta_credito.ruta AS ruta,
        med.id_med::text AS medio_pago_id,
        UPPER(med.med_tipo::text) AS medio_pago_codigo,
        med.med_nombre AS medio_pago_nombre,
        mon.mon_codigo::text AS moneda_codigo,
        pa.pag_fecha AS fecha_pago,
        pa.pag_monto AS total_pagado,
        pa.pag_referencia AS referencia_externa
      FROM public.tbl_pagos pa
      JOIN public.tbl_cuotas_pagos cp_pago ON cp_pago.pagos_id = pa.id_pag
      JOIN public.tbl_cuotas cu_pago ON cu_pago.id_cuo = cp_pago.cuo_id
      JOIN public.tbl_creditos cr ON cr.id_cre = cu_pago.cre_id
      JOIN public.tbl_usuarios tu ON tu.id_usu = cr.usu_id
      JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
      JOIN public.tbl_personas p ON p.id_per = cl.cli_persona
      JOIN public.tbl_medios_pagos med ON med.id_med = pa.med_id
      JOIN public.tbl_monedas mon ON mon.id_mon = pa.mon_id
      LEFT JOIN LATERAL (
        SELECT r.id_rut AS ruta_id, r.rut_nombre AS ruta
        FROM public.tbl_rutas_clientes rc
        JOIN public.tbl_rutas r ON r.id_rut = rc.rut_id
        WHERE rc.cli_id = cl.id_cli
          AND r.org_id = cl.org_id
        ORDER BY (r.usu_id = cr.usu_id) DESC, r.rut_activa DESC
        LIMIT 1
      ) ruta_credito ON TRUE
      WHERE pa.id_pag = ${pagoId}::uuid
        AND cl.org_id = ${scope.organizacionId}::uuid
        AND ${
          this.puedeVerDatosOrganizacion(usuario)
            ? Prisma.sql`TRUE`
            : Prisma.sql`tu.id_usu = ${scope.usuarioId}::uuid`
        }
      ORDER BY cr.id_cre
      LIMIT 1
    `);
    const pago = rows[0];

    if (!pago) {
      throw DomainError.notFound('Pago no encontrado', 'PAGO_NO_ENCONTRADO');
    }

    const aplicaciones = await this.prisma.$queryRaw<PagoAplicacionTblRow[]>(
      Prisma.sql`
        SELECT
          cp.id_cpa::text AS aplicacion_id,
          cu.id_cuo::text AS credito_cuota_id,
          cu.cuo_numero::int AS numero_cuota,
          cp.cpa_capital AS monto_capital,
          cp.cpa_interes AS monto_interes,
          0::numeric AS monto_mora,
          0::numeric AS monto_descuento
        FROM public.tbl_cuotas_pagos cp
        JOIN public.tbl_cuotas cu ON cu.id_cuo = cp.cuo_id
        WHERE cp.pagos_id = ${pagoId}::uuid
        ORDER BY cu.cuo_numero ASC
      `,
    );

    return {
      id: pago.pago_id,
      clienteId: pago.cliente_id,
      cliente: pago.cliente,
      rutaId: pago.ruta_id ?? '',
      ruta: pago.ruta ?? 'Sin ruta',
      medioPago: {
        id: Number(pago.medio_pago_id),
        codigo: pago.medio_pago_codigo,
        nombre: pago.medio_pago_nombre,
      },
      monedaCodigo: pago.moneda_codigo.trim(),
      fechaPago: pago.fecha_pago.toISOString(),
      totalPagado: this.decimalANumero(pago.total_pagado),
      referenciaExterna: pago.referencia_externa,
      observacion: null,
      aplicaciones: aplicaciones.map((aplicacion) => ({
        id: aplicacion.aplicacion_id,
        creditoCuotaId: aplicacion.credito_cuota_id,
        numeroCuota: aplicacion.numero_cuota,
        montoCapital: this.decimalANumero(aplicacion.monto_capital),
        montoInteres: this.decimalANumero(aplicacion.monto_interes),
        montoMora: this.decimalANumero(aplicacion.monto_mora),
        montoDescuento: this.decimalANumero(aplicacion.monto_descuento),
      })),
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

    this.formatearHojaExportacion(sheet, ['monto']);

    return this.subirWorkbookExportacion({
      workbook,
      carpeta: 'caja-menor',
      nombreBase: 'caja-menor',
      filas: filtrados.length,
      vistaPrevia: this.crearVistaPreviaExportacion(columnas, filasExcel),
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
          SELECT sca.id_sca
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

      const sesionId =
        caja.sesion_id ??
        (
          await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
            INSERT INTO public.tbl_sesiones_cajas (
              sca_fecha_apertura,
              sca_monto_inicial,
              caj_id,
              usu_id
            )
            VALUES (
              ${fechaMovimiento},
              0,
              ${caja.caja_menor_id}::uuid,
              ${caja.usuario_id}::uuid
            )
            RETURNING id_sca::text AS id
          `)
        )[0]?.id;

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
      const movimiento = await this.actualizarPagoComoMovimientoCaja(
        this.idPagoDesdeMovimientoCaja(id),
        dto,
        usuario,
      );
      this.invalidarCacheLecturas();
      return movimiento;
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

      const creditoDesembolso = actual.desembolsoCredito
        ? await this.obtenerCreditoEditableDesdeDesembolso(
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
        },
      });

      if (creditoDesembolso && actual.desembolsoCredito) {
        await this.sincronizarCreditoDesdeMovimientoDesembolso(
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
      await this.eliminarPagoComoMovimientoCaja(
        this.idPagoDesdeMovimientoCaja(id),
        usuario,
      );
      this.invalidarCacheLecturas();
      return { ok: true };
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
        this.asegurarPermiso(usuario, 'ELIMINAR_CREDITOS');
        await this.eliminarCreditoDesdeMovimientoDesembolso(
          tx,
          actual,
          actual.desembolsoCredito.creditoId,
          usuario,
        );
        return;
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

  async crearCajaMenor(dto: CrearCajaMenorDto, usuario: AuthenticatedUser) {
    this.asegurarPermiso(usuario, 'CREAR_CAJA_MENOR');

    if (await this.usarEsquemaTbl()) {
      return this.crearCajaMenorTbl(dto, usuario);
    }

    const nombre = this.requerirTexto(
      dto.nombre,
      'El nombre de la caja menor es obligatorio',
    );
    const responsableUsuarioId = usuario.usuarioId;
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

    const [responsable, moneda, existente] = await Promise.all([
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
          WHERE tu.id_usu = ${scope.usuarioId}::uuid
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

  async obtenerPresupuesto(
    query: ObtenerPresupuestoQueryDto,
    usuario: AuthenticatedUser,
  ) {
    if (await this.usarEsquemaTbl()) {
      return this.obtenerPresupuestoTbl(query, usuario);
    }

    const search = this.normalizarTextoOpcional(query.search);
    const fechaDesde = query.fechaDesde
      ? this.parsearFecha(query.fechaDesde, 'fechaDesde')
      : null;
    const fechaHasta = query.fechaHasta
      ? this.finDia(this.parsearFecha(query.fechaHasta, 'fechaHasta'))
      : null;
    const fechaDesdePago = query.fechaDesde
      ? this.inicioDiaColombia(
          this.parsearFecha(query.fechaDesde, 'fechaDesde'),
        )
      : null;
    const fechaHastaPago = query.fechaHasta
      ? this.finDiaColombia(this.parsearFecha(query.fechaHasta, 'fechaHasta'))
      : null;
    const condiciones: Prisma.Sql[] = [Prisma.sql`cm.activa = TRUE`];
    const filtrosFechaMovimiento: Prisma.Sql[] = [];
    const filtrosFechaPago: Prisma.Sql[] = [];
    const filtrosFechaGasto: Prisma.Sql[] = [];
    const filtrosFechaCredito: Prisma.Sql[] = [];

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      condiciones.push(
        Prisma.sql`cm.responsable_usuario_id = ${usuario.usuarioId}::uuid`,
      );
    }

    if (query.cajaMenorId) {
      condiciones.push(
        Prisma.sql`cm.caja_menor_id = ${query.cajaMenorId}::uuid`,
      );
    }

    if (search) {
      const pattern = `%${search}%`;
      condiciones.push(Prisma.sql`cm.nombre ILIKE ${pattern}`);
    }

    if (fechaDesde) {
      filtrosFechaMovimiento.push(
        Prisma.sql`cmm.fecha_movimiento >= ${fechaDesde}`,
      );
      filtrosFechaGasto.push(Prisma.sql`g.fecha_gasto >= ${fechaDesde}`);
      filtrosFechaCredito.push(Prisma.sql`c.fecha_inicio >= ${fechaDesde}`);
    }

    if (fechaDesdePago) {
      filtrosFechaPago.push(Prisma.sql`p.fecha_pago >= ${fechaDesdePago}`);
    }

    if (fechaHasta) {
      filtrosFechaMovimiento.push(
        Prisma.sql`cmm.fecha_movimiento <= ${fechaHasta}`,
      );
      filtrosFechaGasto.push(Prisma.sql`g.fecha_gasto <= ${fechaHasta}`);
      filtrosFechaCredito.push(Prisma.sql`c.fecha_inicio <= ${fechaHasta}`);
    }

    if (fechaHastaPago) {
      filtrosFechaPago.push(Prisma.sql`p.fecha_pago <= ${fechaHastaPago}`);
    }

    const where = Prisma.sql`WHERE ${Prisma.join(condiciones, ' AND ')}`;
    const fechaMovimientoWhere =
      filtrosFechaMovimiento.length > 0
        ? Prisma.sql`AND ${Prisma.join(filtrosFechaMovimiento, ' AND ')}`
        : Prisma.empty;
    const fechaSaldoCajaWhere = fechaDesde
      ? Prisma.sql`AND cmm.fecha_movimiento < ${fechaDesde}`
      : Prisma.empty;
    const fechaPagoWhere =
      filtrosFechaPago.length > 0
        ? Prisma.sql`AND ${Prisma.join(filtrosFechaPago, ' AND ')}`
        : Prisma.empty;
    const fechaGastoWhere =
      filtrosFechaGasto.length > 0
        ? Prisma.sql`AND ${Prisma.join(filtrosFechaGasto, ' AND ')}`
        : Prisma.empty;
    const fechaCreditoWhere =
      filtrosFechaCredito.length > 0
        ? Prisma.sql`AND ${Prisma.join(filtrosFechaCredito, ' AND ')}`
        : Prisma.empty;
    const condicionMostrarCreditos = query.cajaMenorId
      ? Prisma.sql`TRUE`
      : Prisma.sql`cr.caja_menor_id = cm.caja_menor_id`;

    const rows = await this.prisma.$queryRaw<PresupuestoRow[]>(Prisma.sql`
      WITH caja_recaudo AS (
        SELECT DISTINCT ON (cmr.responsable_usuario_id, cmr.moneda_codigo)
          cmr.caja_menor_id,
          cmr.responsable_usuario_id,
          cmr.moneda_codigo
        FROM public.caja_menor cmr
        WHERE cmr.activa = TRUE
        ORDER BY
          cmr.responsable_usuario_id,
          cmr.moneda_codigo,
          cmr.creada_en ASC,
          cmr.caja_menor_id ASC
      )
      SELECT
        cm.caja_menor_id,
        cm.nombre AS caja_menor_nombre,
        cm.responsable_usuario_id,
        cm.moneda_codigo,
        COALESCE(saldo_caja.saldo_caja_menor, 0) AS caja_menor,
        (
          CASE
            WHEN cr.caja_menor_id = cm.caja_menor_id THEN COALESCE(pagos.total_recaudado, 0)
            ELSE 0
          END
          + COALESCE(entradas_caja.total_entradas, 0)
        ) AS recaudado,
        (
          COALESCE(gastos.total_gastos, 0)
          + COALESCE(gastos_caja.total_gastos_caja, 0)
        ) AS gastos,
        CASE
          WHEN ${condicionMostrarCreditos} THEN COALESCE(creditos.total_creditos, 0)
          ELSE 0
        END AS creditos,
        (
          COALESCE(saldo_caja.saldo_caja_menor, 0)
          + (
            CASE
              WHEN cr.caja_menor_id = cm.caja_menor_id THEN COALESCE(pagos.total_recaudado, 0)
              ELSE 0
            END
            + COALESCE(entradas_caja.total_entradas, 0)
          )
          - (
            COALESCE(gastos.total_gastos, 0)
            + COALESCE(gastos_caja.total_gastos_caja, 0)
          )
        ) AS presupuesto
      FROM public.caja_menor cm
      LEFT JOIN caja_recaudo cr
        ON cr.responsable_usuario_id = cm.responsable_usuario_id
       AND cr.moneda_codigo = cm.moneda_codigo
      LEFT JOIN LATERAL (
        SELECT SUM(
          CASE
            WHEN tmc.codigo IN ('GASTO', 'DESEMBOLSO_CREDITO', 'AJUSTE_SALIDA') THEN -cmm.monto
            WHEN tmc.codigo IN ('RECAUDO', 'AJUSTE_ENTRADA') THEN cmm.monto
            WHEN tmc.naturaleza = 'E' THEN cmm.monto
            ELSE -cmm.monto
          END
        ) AS saldo_caja_menor
        FROM public.caja_menor_movimiento cmm
        JOIN public.tipo_movimiento_caja tmc
          ON tmc.tipo_movimiento_caja_id = cmm.tipo_movimiento_caja_id
        WHERE cmm.caja_menor_id = cm.caja_menor_id
          ${fechaSaldoCajaWhere}
      ) saldo_caja ON TRUE
      LEFT JOIN LATERAL (
        SELECT SUM(p.total_pagado) AS total_recaudado
        FROM public.pago p
        JOIN public.ruta r ON r.ruta_id = p.ruta_id
        WHERE r.responsable_usuario_id = cm.responsable_usuario_id
          AND p.moneda_codigo = cm.moneda_codigo
          ${fechaPagoWhere}
      ) pagos ON TRUE
      LEFT JOIN LATERAL (
        SELECT SUM(cmm.monto) AS total_entradas
        FROM public.caja_menor_movimiento cmm
        JOIN public.tipo_movimiento_caja tmc
          ON tmc.tipo_movimiento_caja_id = cmm.tipo_movimiento_caja_id
        WHERE cmm.caja_menor_id = cm.caja_menor_id
          AND (
            CASE
              WHEN tmc.codigo IN ('GASTO', 'DESEMBOLSO_CREDITO', 'AJUSTE_SALIDA') THEN 'S'
              WHEN tmc.codigo IN ('RECAUDO', 'AJUSTE_ENTRADA') THEN 'E'
              ELSE tmc.naturaleza
            END
          ) = 'E'
          AND tmc.codigo NOT IN ('GASTO', 'DESEMBOLSO_CREDITO', 'AJUSTE_SALIDA')
          ${fechaMovimientoWhere}
      ) entradas_caja ON TRUE
      LEFT JOIN LATERAL (
        SELECT SUM(g.monto) AS total_gastos
        FROM public.gasto g
        WHERE g.caja_menor_id = cm.caja_menor_id
          AND g.moneda_codigo = cm.moneda_codigo
          ${fechaGastoWhere}
      ) gastos ON TRUE
      LEFT JOIN LATERAL (
        SELECT SUM(cmm.monto) AS total_gastos_caja
        FROM public.caja_menor_movimiento cmm
        JOIN public.tipo_movimiento_caja tmc
          ON tmc.tipo_movimiento_caja_id = cmm.tipo_movimiento_caja_id
        WHERE cmm.caja_menor_id = cm.caja_menor_id
          AND tmc.codigo = 'GASTO'
          ${fechaMovimientoWhere}
      ) gastos_caja ON TRUE
      LEFT JOIN LATERAL (
        SELECT SUM(c.valor_principal) AS total_creditos
        FROM public.credito c
        JOIN public.ruta r ON r.ruta_id = c.ruta_id
        JOIN public.estado_credito ec
          ON ec.estado_credito_id = c.estado_credito_id
        WHERE r.responsable_usuario_id = cm.responsable_usuario_id
          AND c.moneda_codigo = cm.moneda_codigo
          AND ec.codigo <> 'ANULADO'
          ${fechaCreditoWhere}
      ) creditos ON TRUE
      ${where}
      ORDER BY cm.activa DESC, cm.nombre ASC, cm.caja_menor_id ASC
    `);

    const items = rows.map((row) => ({
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

  private async usarEsquemaTbl() {
    if (this.esquemaTblDisponible !== undefined) {
      return this.esquemaTblDisponible;
    }

    try {
      const rows = await this.prisma.$queryRaw<EsquemaTblDisponibleRow[]>`
        SELECT COUNT(*) = 3 AS disponible
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name IN (
            'tbl_usuarios',
            'tbl_organizaciones',
            'tbl_clientes'
          )
      `;
      this.esquemaTblDisponible = rows[0]?.disponible ?? false;
    } catch {
      this.esquemaTblDisponible = false;
    }

    return this.esquemaTblDisponible;
  }

  private async obtenerScopeOrganizacionTbl(
    usuario: AuthenticatedUser,
    executor: PrismaExecutor = this.prisma,
  ): Promise<OrganizacionScopeTbl> {
    const conditions: Prisma.Sql[] = [Prisma.sql`tu.usu_activo`];

    if (this.esIdTbl(usuario.usuarioId)) {
      conditions.push(Prisma.sql`tu.id_usu = ${usuario.usuarioId}::uuid`);
    } else {
      conditions.push(
        Prisma.sql`lower(tu.usu_usuario) = lower(${usuario.usuario})`,
      );
    }

    if (usuario.organizacionId && this.esIdTbl(usuario.organizacionId)) {
      conditions.push(
        Prisma.sql`uo.org_id = ${usuario.organizacionId}::uuid`,
      );
    }

    const [scope] = await executor.$queryRaw<
      Array<{ usuario_id: string; organizacion_id: string }>
    >(Prisma.sql`
      SELECT
        tu.id_usu::text AS usuario_id,
        uo.org_id::text AS organizacion_id
      FROM public.tbl_usuarios tu
      JOIN public.tbl_usuarios_organizaciones uo
        ON uo.usu_id = tu.id_usu
       AND uo.urg_activo
      JOIN public.tbl_organizaciones org
        ON org.id_org = uo.org_id
       AND org.org_activo
       AND NOT COALESCE(org.org_es_sistema, FALSE)
       AND (
         org.org_acceso_hasta IS NULL
         OR org.org_acceso_hasta >= CURRENT_DATE
       )
      WHERE ${Prisma.join(conditions, ' AND ')}
      ORDER BY uo.id_urg ASC
      LIMIT 1
    `);

    if (!scope) {
      throw new ForbiddenException('No tienes una institucion activa');
    }

    return {
      usuarioId: scope.usuario_id,
      organizacionId: scope.organizacion_id,
    };
  }

  private async obtenerCatalogosTbl(usuario: AuthenticatedUser) {
    const scope = await this.obtenerScopeOrganizacionTbl(usuario);
    const puedeVerTodo = this.puedeVerDatosOrganizacion(usuario);
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
            FROM public.tbl_productos_creditos
            GROUP BY pcr_frecuencia::text
            UNION ALL
            SELECT
              'medio_pago',
              id_med::text,
              UPPER(med_tipo::text),
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
        this.prisma.$queryRaw<CatalogoTblRow[]>(Prisma.sql`
          SELECT
            'caja_menor' AS tipo,
            c.id_caj::text AS id,
            c.id_caj::text AS codigo,
            c.caj_nombre AS nombre,
            COALESCE(
              (
                SELECT sc.usu_id::text
                FROM public.tbl_sesiones_cajas sc
                WHERE sc.caj_id = c.id_caj
                ORDER BY
                  (sc.sca_estado::text = 'ABIERTA') DESC,
                  sc.sca_fecha_apertura DESC,
                  sc.id_sca DESC
                LIMIT 1
              ),
              ''
            ) AS extra,
            c.caj_activa AS activo
          FROM public.tbl_cajas c
          WHERE c.caj_tipo::text = 'MENOR'
            AND c.org_id = ${scope.organizacionId}::uuid
            AND ${
              puedeVerTodo
                ? Prisma.sql`TRUE`
                : Prisma.sql`EXISTS (
                    SELECT 1
                    FROM public.tbl_sesiones_cajas sc_acl
                    WHERE sc_acl.caj_id = c.id_caj
                      AND sc_acl.usu_id = ${scope.usuarioId}::uuid
                  )`
            }
          ORDER BY c.caj_activa DESC, c.caj_nombre ASC
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
              codigo: moneda.codigo.trim(),
              nombre: moneda.nombre,
              simbolo: moneda.simbolo,
              decimales: Number(moneda.decimales),
            }))
          : [
              {
                codigo: 'COP',
                nombre: 'Peso colombiano',
                simbolo: '$',
                decimales: 2,
              },
            ],
      frecuenciasPago: frecuenciasPago.map((frecuencia, index) => ({
        id:
          Number.isFinite(Number(frecuencia.id)) && Number(frecuencia.id) > 0
            ? Number(frecuencia.id)
            : index + 1,
        codigo: frecuencia.codigo,
        nombre: frecuencia.nombre,
        diasIntervalo: Number(frecuencia.extra ?? 1),
      })),
      mediosPago: [...mediosPago.values()],
      tiposMovimientoCaja: tiposMovimientoCaja.map((tipo, index) => ({
        id:
          Number.isFinite(Number(tipo.id)) && Number(tipo.id) > 0
            ? Number(tipo.id)
            : index + 1,
        codigo: tipo.codigo,
        nombre: tipo.nombre,
        naturaleza: tipo.extra ?? 'E',
      })),
      categoriasGasto: categoriasGasto.map((categoria, index) => ({
        id:
          Number.isFinite(Number(categoria.id)) && Number(categoria.id) > 0
            ? Number(categoria.id)
            : index + 1,
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
          activa: caja.activo ?? true,
          monedaCodigo: 'COP',
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

  private async listarClientesTbl(
    query: ListarClientesQueryDto,
    usuario: AuthenticatedUser,
  ) {
    const scope = await this.obtenerScopeOrganizacionTbl(usuario);
    const search = this.normalizarTextoOpcional(query.search);
    const conditions: Prisma.Sql[] = [
      Prisma.sql`c.org_id = ${scope.organizacionId}::uuid`,
    ];

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      conditions.push(Prisma.sql`EXISTS (
        SELECT 1
        FROM public.tbl_rutas_clientes rc_acl
        JOIN public.tbl_rutas r_acl ON r_acl.id_rut = rc_acl.rut_id
        WHERE rc_acl.cli_id = c.id_cli
          AND rc_acl.rcl_activo
          AND r_acl.org_id = c.org_id
          AND r_acl.usu_id = ${scope.usuarioId}::uuid
      )`);
    }

    if (search) {
      const pattern = `%${search}%`;
      conditions.push(Prisma.sql`(
        CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido) ILIKE ${pattern}
        OR p.per_documento ILIKE ${pattern}
        OR p.per_direccion ILIKE ${pattern}
        OR p.per_num_celular ILIKE ${pattern}
        OR c.cli_referencia ILIKE ${pattern}
      )`);
    }

    const where =
      conditions.length > 0
        ? Prisma.sql`WHERE ${Prisma.join(conditions, ' AND ')}`
        : Prisma.empty;
    const rows = await this.prisma.$queryRaw<ClienteTblRow[]>(Prisma.sql`
      SELECT
        c.id_cli::text AS id,
        TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS nombre_completo,
        c.cli_referencia AS nombre_comercial,
        NULL::text AS notas,
        p.per_documento AS cedula,
        p.per_direccion AS direccion,
        p.per_latitud AS latitud,
        p.per_longitud AS longitud,
        p.per_num_celular AS telefono,
        p.per_email AS correo,
        c.cli_creacion AS creado_en,
        c.cli_creacion AS actualizado_en,
        c.cli_activo AS activo
      FROM public.tbl_clientes c
      JOIN public.tbl_personas p ON p.id_per = c.cli_persona
      ${where}
      ORDER BY nombre_completo ASC
    `);

    return rows.map((cliente) => this.formatearClienteTbl(cliente));
  }

  private async crearClienteTbl(
    input: {
      nombreCompleto: string;
      cedula: string | null;
      nombreComercial: string | null;
      direccion: string | null;
      notas: string | null;
      correo: string | null;
      telefono: string | null;
      whatsapp: string | null;
      latitud?: number;
      longitud?: number;
    },
    usuario: AuthenticatedUser,
  ) {
    const nombrePersona = this.dividirNombrePersonaTbl(input.nombreCompleto);
    const telefono = input.telefono ?? input.whatsapp;
    const cedula = input.cedula ?? this.generarDocumentoClienteTbl();

    const clienteId = await this.prisma.$transaction(
      async (tx) => {
        const scope = await this.obtenerScopeOrganizacionTbl(usuario, tx);

        if (input.cedula) {
          const [duplicado] = await tx.$queryRaw<Array<{ existe: boolean }>>(
            Prisma.sql`
              SELECT EXISTS (
                SELECT 1
                FROM public.tbl_personas
                WHERE per_documento = ${input.cedula}
              ) AS existe
            `,
          );

          if (duplicado?.existe) {
            throw DomainError.conflict(
              'Ya existe un cliente con esta cedula',
              'CEDULA_YA_REGISTRADA',
            );
          }
        }

        const [persona] = await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
            INSERT INTO public.tbl_personas (
              per_primer_nombre,
              per_apellido,
              per_documento,
              per_direccion,
              per_num_celular,
              per_latitud,
              per_longitud
            )
            VALUES (
              ${nombrePersona.nombres},
              ${nombrePersona.apellidos},
              ${cedula},
              ${input.direccion},
              ${telefono},
              ${input.latitud ?? null},
              ${input.longitud ?? null}
            )
            RETURNING id_per::text AS id
          `,
        );

        const [cliente] = await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
            INSERT INTO public.tbl_clientes (
              cli_referencia,
              org_id,
              cli_persona
            )
            VALUES (
              ${input.nombreComercial},
              ${scope.organizacionId}::uuid,
              ${persona.id}::uuid
            )
            RETURNING id_cli::text AS id
          `,
        );

        const rutaId = await this.obtenerOCrearRutaCreditoTbl(
          tx,
          undefined,
          scope.organizacionId,
          scope.usuarioId,
          usuario.usuario,
        );

        await tx.$executeRaw(Prisma.sql`
          INSERT INTO public.tbl_rutas_clientes (rut_id, cli_id)
          VALUES (${rutaId}::uuid, ${cliente.id}::uuid)
          ON CONFLICT (rut_id, cli_id) DO UPDATE
          SET rcl_activo = TRUE
        `);

        await this.registrarAuditoria(tx, {
          usuarioId: usuario.usuarioId,
          tabla: 'tbl_clientes',
          registroId: cliente.id,
          accion: 'CREAR',
          descripcion: `Se creo cliente ${input.nombreCompleto}`,
          valoresNuevos: {
            nombreCompleto: input.nombreCompleto,
            cedula: input.cedula,
            nombreComercial: input.nombreComercial,
            direccion: input.direccion,
            notas: input.notas,
            correo: input.correo,
            telefono,
            latitud: input.latitud ?? null,
            longitud: input.longitud ?? null,
            organizacionId: scope.organizacionId,
          },
        });

        return cliente.id;
      },
      { maxWait: 10_000, timeout: 10_000 },
    );

    const creados = await this.prisma.$queryRaw<ClienteTblRow[]>(Prisma.sql`
      SELECT
        c.id_cli::text AS id,
        TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS nombre_completo,
        c.cli_referencia AS nombre_comercial,
        NULL::text AS notas,
        p.per_documento AS cedula,
        p.per_direccion AS direccion,
        p.per_latitud AS latitud,
        p.per_longitud AS longitud,
        p.per_num_celular AS telefono,
        c.cli_creacion AS creado_en,
        c.cli_creacion AS actualizado_en,
        c.cli_activo AS activo
      FROM public.tbl_clientes c
      JOIN public.tbl_personas p ON p.id_per = c.cli_persona
      WHERE c.id_cli::text = ${clienteId}
    `);
    const cliente = creados[0];

    if (!cliente) {
      throw DomainError.notFound(
        'Cliente no encontrado despues de crear',
        'CLIENTE_NO_ENCONTRADO',
      );
    }

    this.invalidarCacheLecturas();
    return this.formatearClienteTbl(cliente);
  }

  private async actualizarClienteTbl(
    clienteId: string,
    dto: ActualizarClienteDto,
    usuario: AuthenticatedUser,
  ) {
    this.asegurarAdministrador(usuario);

    const nombreCompleto = this.requerirTexto(
      dto.nombreCompleto,
      'El nombre del cliente es obligatorio',
    );
    const cedula = this.normalizarTextoOpcional(dto.cedula);
    const nombreComercial = this.normalizarTextoOpcional(dto.nombreComercial);
    const direccion = this.normalizarTextoOpcional(dto.direccion);
    const telefono = this.normalizarTextoOpcional(dto.telefono);
    const latitud = dto.latitud;
    const longitud = dto.longitud;
    if (
      [latitud, longitud].some(
        (value: unknown) =>
          value !== undefined &&
          (typeof value !== 'number' || !Number.isFinite(value)),
      )
    ) {
      throw DomainError.validation(
        'Las coordenadas deben ser números finitos',
        'COORDENADAS_INVALIDAS',
      );
    }
    if ((latitud === undefined) !== (longitud === undefined)) {
      throw DomainError.validation(
        'La latitud y la longitud deben enviarse juntas',
        'COORDENADAS_INCOMPLETAS',
      );
    }
    if (latitud !== undefined && !direccion) {
      throw DomainError.validation(
        'La dirección es obligatoria cuando se envían coordenadas',
        'DIRECCION_COORDENADAS_REQUERIDA',
      );
    }
    const nombrePersona = this.dividirNombrePersonaTbl(nombreCompleto);
    const scope = await this.obtenerScopeOrganizacionTbl(usuario);

    await this.prisma.$transaction(
      async (tx) => {
        const rows = await tx.$queryRaw<ClienteTblDetalleRow[]>(Prisma.sql`
        SELECT
          c.id_cli::text AS id,
          c.cli_persona::text AS persona_id,
          TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS nombre_completo,
          c.cli_referencia AS nombre_comercial,
          NULL::text AS notas,
          p.per_documento AS cedula,
          p.per_direccion AS direccion,
          p.per_latitud AS latitud,
          p.per_longitud AS longitud,
          p.per_num_celular AS telefono,
          c.cli_creacion AS creado_en,
          c.cli_creacion AS actualizado_en,
          c.cli_activo AS activo
        FROM public.tbl_clientes c
        JOIN public.tbl_personas p ON p.id_per = c.cli_persona
        WHERE c.id_cli::text = ${clienteId}
          AND c.org_id = ${scope.organizacionId}::uuid
        FOR UPDATE OF c, p
      `);
        const actual = rows[0];

        if (!actual) {
          throw DomainError.notFound(
            'Cliente no encontrado',
            'CLIENTE_NO_ENCONTRADO',
          );
        }

        const cedulaFinal = cedula ?? actual.cedula;
        const latitudFinal =
          latitud ??
          (actual.latitud === null
            ? null
            : this.decimalANumero(actual.latitud));
        const longitudFinal =
          longitud ??
          (actual.longitud === null
            ? null
            : this.decimalANumero(actual.longitud));
        if (cedulaFinal !== actual.cedula) {
          const duplicados = await tx.$queryRaw<Array<{ existe: boolean }>>(
            Prisma.sql`
            SELECT EXISTS (
              SELECT 1
              FROM public.tbl_personas
              WHERE per_documento = ${cedulaFinal}
                AND id_per::text <> ${actual.persona_id}
            ) AS existe
          `,
          );

          if (duplicados[0]?.existe) {
            throw DomainError.conflict(
              'Ya existe un cliente con esta cedula',
              'CEDULA_YA_REGISTRADA',
            );
          }
        }

        await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_personas
        SET
          per_primer_nombre = ${nombrePersona.nombres},
          per_apellido = ${nombrePersona.apellidos},
          per_documento = ${cedulaFinal},
          per_direccion = ${direccion},
          per_latitud = ${latitudFinal},
          per_longitud = ${longitudFinal},
          per_num_celular = ${telefono}
        WHERE id_per::text = ${actual.persona_id}
      `);

        await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_clientes
        SET cli_referencia = ${nombreComercial}
        WHERE id_cli::text = ${clienteId}
      `);

        await this.registrarAuditoria(tx, {
          usuarioId: usuario.usuarioId,
          tabla: 'tbl_clientes',
          registroId: clienteId,
          accion: 'MODIFICAR',
          descripcion: `Se modifico cliente ${actual.nombre_completo}`,
          valoresAnteriores: this.formatearClienteTbl(actual),
          valoresNuevos: {
            nombreCompleto,
            cedula: cedulaFinal,
            nombreComercial,
            direccion,
            telefono,
            latitud: latitudFinal,
            longitud: longitudFinal,
          },
        });
      },
      { maxWait: 10_000, timeout: 10_000 },
    );

    const actualizados = await this.prisma.$queryRaw<
      ClienteTblRow[]
    >(Prisma.sql`
      SELECT
        c.id_cli::text AS id,
        TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS nombre_completo,
        c.cli_referencia AS nombre_comercial,
        NULL::text AS notas,
        p.per_documento AS cedula,
        p.per_direccion AS direccion,
        p.per_latitud AS latitud,
        p.per_longitud AS longitud,
        p.per_num_celular AS telefono,
        c.cli_creacion AS creado_en,
        c.cli_creacion AS actualizado_en,
        c.cli_activo AS activo
      FROM public.tbl_clientes c
      JOIN public.tbl_personas p ON p.id_per = c.cli_persona
      WHERE c.id_cli::text = ${clienteId}
        AND c.org_id = ${scope.organizacionId}::uuid
    `);
    const cliente = actualizados[0];

    if (!cliente) {
      throw DomainError.notFound(
        'Cliente no encontrado despues de modificar',
        'CLIENTE_NO_ENCONTRADO',
      );
    }

    this.invalidarCacheLecturas();
    return this.formatearClienteTbl(cliente);
  }

  private async eliminarClienteTbl(
    clienteId: string,
    usuario: AuthenticatedUser,
  ) {
    this.asegurarAdministrador(usuario);
    const scope = await this.obtenerScopeOrganizacionTbl(usuario);

    await this.prisma.$transaction(async (tx) => {
      const rows = await tx.$queryRaw<ClienteTblDetalleRow[]>(Prisma.sql`
        SELECT
          c.id_cli::text AS id,
          c.cli_persona::text AS persona_id,
          TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS nombre_completo,
          c.cli_referencia AS nombre_comercial,
          NULL::text AS notas,
          p.per_documento AS cedula,
          p.per_direccion AS direccion,
          p.per_latitud AS latitud,
          p.per_longitud AS longitud,
          p.per_num_celular AS telefono,
          c.cli_creacion AS creado_en,
          c.cli_creacion AS actualizado_en,
          c.cli_activo AS activo
        FROM public.tbl_clientes c
        JOIN public.tbl_personas p ON p.id_per = c.cli_persona
        WHERE c.id_cli::text = ${clienteId}
          AND c.org_id = ${scope.organizacionId}::uuid
        FOR UPDATE OF c, p
      `);
      const cliente = rows[0];

      if (!cliente) {
        throw DomainError.notFound(
          'Cliente no encontrado',
          'CLIENTE_NO_ENCONTRADO',
        );
      }

      const relaciones = await tx.$queryRaw<
        Array<{ creditos: number; pagos: number }>
      >(Prisma.sql`
        SELECT
          COUNT(DISTINCT cr.id_cre)::int AS creditos,
          COUNT(DISTINCT pa.id_pag)::int AS pagos
        FROM public.tbl_clientes c
        LEFT JOIN public.tbl_creditos cr ON cr.cli_id = c.id_cli
        LEFT JOIN public.tbl_cuotas cu ON cu.cre_id = cr.id_cre
        LEFT JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
        LEFT JOIN public.tbl_pagos pa ON pa.id_pag = cp.pagos_id
        WHERE c.id_cli::text = ${clienteId}
          AND c.org_id = ${scope.organizacionId}::uuid
      `);
      const conteo = relaciones[0];

      if ((conteo?.creditos ?? 0) > 0 || (conteo?.pagos ?? 0) > 0) {
        throw DomainError.conflict(
          'No se puede eliminar un cliente con creditos o pagos registrados',
          'CLIENTE_CON_MOVIMIENTOS_NO_ELIMINABLE',
        );
      }

      await this.registrarAuditoria(tx, {
        usuarioId: usuario.usuarioId,
        tabla: 'tbl_clientes',
        registroId: clienteId,
        accion: 'ELIMINAR',
        descripcion: `Se elimino cliente ${cliente.nombre_completo}`,
        valoresAnteriores: this.formatearClienteTbl(cliente),
      });

      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_rutas_clientes
        USING public.tbl_rutas r
        WHERE tbl_rutas_clientes.rut_id = r.id_rut
          AND tbl_rutas_clientes.cli_id::text = ${clienteId}
          AND r.org_id = ${scope.organizacionId}::uuid
      `);
      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_clientes
        WHERE id_cli::text = ${clienteId}
          AND org_id = ${scope.organizacionId}::uuid
      `);
      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_personas
        WHERE id_per::text = ${cliente.persona_id}
      `);
    });

    this.invalidarCacheLecturas();
    return { ok: true };
  }

  private async listarRutasTbl(usuario: AuthenticatedUser) {
    const scope = await this.obtenerScopeOrganizacionTbl(usuario);
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
          this.puedeVerDatosOrganizacion(usuario)
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

  private async listarCobrosRutaTbl(
    query: ListarCobrosRutaQueryDto,
    usuario: AuthenticatedUser,
    limit?: number,
  ) {
    const scope = await this.obtenerScopeOrganizacionTbl(usuario);
    const search = this.normalizarTextoOpcional(query.search);
    const conditions: Prisma.Sql[] = [
      Prisma.sql`cl.org_id = ${scope.organizacionId}::uuid`,
      Prisma.sql`UPPER(cr.cre_estado::text) <> 'ANULADO'`,
    ];

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      conditions.push(Prisma.sql`tu.id_usu = ${scope.usuarioId}::uuid`);
    }

    if (query.rutaId) {
      conditions.push(
        Prisma.sql`ruta_credito.ruta_id = ${query.rutaId}::uuid`,
      );
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

  private async consultarCreditosTbl(
    query: ListarCreditosQueryDto,
    usuario: AuthenticatedUser,
    limite?: number,
    offset = 0,
  ) {
    const scope = await this.obtenerScopeOrganizacionTbl(usuario);
    const search = this.normalizarTextoOpcional(query.search);
    const estado = query.estado ?? 'todos';
    const conditions: Prisma.Sql[] = [
      Prisma.sql`cl.org_id = ${scope.organizacionId}::uuid`,
    ];

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      conditions.push(Prisma.sql`tu.id_usu = ${scope.usuarioId}::uuid`);
    }

    if (query.rutaId) {
      conditions.push(
        Prisma.sql`ruta_credito.ruta_id = ${query.rutaId}::uuid`,
      );
    }

    if (estado === 'activos') {
      conditions.push(Prisma.sql`UPPER(cr.cre_estado::text) = 'ACTIVO'`);
    } else if (estado === 'inactivos') {
      conditions.push(Prisma.sql`UPPER(cr.cre_estado::text) = 'PAGADO'`);
    }

    if (query.fechaDesde) {
      const fechaDesde = this.parsearFecha(query.fechaDesde, 'fechaDesde');
      conditions.push(Prisma.sql`
        CASE
          WHEN UPPER(cr.cre_estado::text) = 'ACTIVO' THEN cr.cre_fecha_inicio
          ELSE COALESCE(
            pc_ultimo.fecha_ultimo_pago,
            cr.cre_fecha_fin,
            cr.cre_fecha_inicio
          )
        END >= ${fechaDesde}::date
      `);
    }

    if (query.fechaHasta) {
      const fechaHasta = this.parsearFecha(query.fechaHasta, 'fechaHasta');
      conditions.push(Prisma.sql`
        CASE
          WHEN UPPER(cr.cre_estado::text) = 'ACTIVO' THEN cr.cre_fecha_inicio
          ELSE COALESCE(
            pc_ultimo.fecha_ultimo_pago,
            cr.cre_fecha_fin,
            cr.cre_fecha_inicio
          )
        END <= ${fechaHasta}::date
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
        OR UPPER(cr.cre_estado::text) ILIKE ${pattern}
      )`);
    }

    const rows = await this.prisma.$queryRaw<CreditoListadoRow[]>(Prisma.sql`
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
      ),
      pagos_credito AS (
        SELECT
          cu.cre_id,
          MAX((pa.pag_fecha AT TIME ZONE 'America/Bogota')::date) AS fecha_ultimo_pago
        FROM public.tbl_pagos pa
        JOIN public.tbl_cuotas_pagos cp ON cp.pagos_id = pa.id_pag
        JOIN public.tbl_cuotas cu ON cu.id_cuo = cp.cuo_id
        GROUP BY cu.cre_id
      )
      SELECT
        cr.id_cre::text AS credito_id,
        cl.id_cli::text AS cliente_id,
        TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS cliente,
        p.per_documento AS cedula,
        cl.cli_referencia AS negocio,
        p.per_direccion AS direccion,
        COALESCE(ruta_credito.ruta_id::text, '') AS ruta_id,
        COALESCE(ruta_credito.ruta, 'Sin ruta') AS ruta,
        caja_credito.caja_menor_id::text AS caja_menor_id,
        caja_credito.caja_menor AS caja_menor,
        mon.mon_codigo::text AS moneda_codigo,
        CASE pc.pcr_frecuencia::text
          WHEN 'DIARIO' THEN 1
          WHEN 'SEMANAL' THEN 2
          WHEN 'QUINCENAL' THEN 3
          WHEN 'MENSUAL' THEN 4
          ELSE 1
        END AS frecuencia_pago_id,
        pc.pcr_frecuencia::text AS frecuencia_codigo,
        INITCAP(REPLACE(pc.pcr_frecuencia::text, '_', ' ')) AS frecuencia_nombre,
        CASE pc.pcr_frecuencia::text
          WHEN 'SEMANAL' THEN 7
          WHEN 'QUINCENAL' THEN 15
          WHEN 'MENSUAL' THEN 30
          ELSE 1
        END AS dias_intervalo,
        UPPER(cr.cre_estado::text) AS estado_codigo,
        INITCAP(REPLACE(cr.cre_estado::text, '_', ' ')) AS estado_nombre,
        cr.cre_total AS valor_principal,
        cr.cre_tasa_interes AS porcentaje_interes,
        GREATEST((cr.cre_fecha_fin - cr.cre_fecha_inicio), 1)::int AS plazo_dias,
        false AS omitir_domingos,
        cr.cre_total_pagar AS valor_total,
        COALESCE(rc.valor_cuota, 0) AS valor_cuota,
        COALESCE(rc.total_abonado, 0) AS total_abonado,
        GREATEST(cr.cre_total_pagar - COALESCE(rc.total_abonado, 0), 0) AS saldo,
        COALESCE(rc.numero_cuotas, 0) AS numero_cuotas,
        COALESCE(rc.cuotas_restantes, 0) AS cuotas_restantes,
        cr.cre_fecha_inicio AS fecha_inicio,
        cr.cre_fecha_fin AS fecha_maxima,
        NULL::timestamp AS refinanciado_en,
        NULL::numeric AS valor_principal_anterior,
        NULL::numeric AS valor_principal_refinanciado,
        NULL::text AS observacion,
        cr.cre_fecha_inicio::timestamp AS creado_en,
        cr.cre_fecha_inicio::timestamp AS actualizado_en
      FROM public.tbl_creditos cr
      JOIN public.tbl_usuarios tu ON tu.id_usu = cr.usu_id
      JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
      JOIN public.tbl_personas p ON p.id_per = cl.cli_persona
      JOIN public.tbl_productos_creditos pc ON pc.id_pcr = cr.pcr_id
      JOIN public.tbl_monedas mon ON mon.id_mon = cr.mon_id
      LEFT JOIN resumen_credito rc ON rc.cre_id = cr.id_cre
      LEFT JOIN pagos_credito pc_ultimo ON pc_ultimo.cre_id = cr.id_cre
      LEFT JOIN LATERAL (
        SELECT r.id_rut AS ruta_id, r.rut_nombre AS ruta
        FROM public.tbl_rutas_clientes rc_ruta
        JOIN public.tbl_rutas r ON r.id_rut = rc_ruta.rut_id
        WHERE rc_ruta.cli_id = cl.id_cli
          AND r.org_id = cl.org_id
        ORDER BY (r.usu_id = cr.usu_id) DESC, r.rut_activa DESC, r.rut_nombre ASC
        LIMIT 1
      ) ruta_credito ON TRUE
      LEFT JOIN LATERAL (
        SELECT c.id_caj AS caja_menor_id, c.caj_nombre AS caja_menor
        FROM public.tbl_movimientos_cajas mc
        JOIN public.tbl_sesiones_cajas sc ON sc.id_sca = mc.sca_id
        JOIN public.tbl_cajas c ON c.id_caj = sc.caj_id
        WHERE mc.mca_referencia_tipo::text = 'CREDITO'
          AND mc.mca_referencia_id = cr.id_cre
          AND mc.mca_tipo::text = 'DESEMBOLSO_CREDITO'
        ORDER BY mc.id_mca DESC
        LIMIT 1
      ) caja_credito ON TRUE
      WHERE ${Prisma.join(conditions, ' AND ')}
      ORDER BY cr.cre_fecha_inicio DESC, cr.id_cre DESC
      ${limite ? Prisma.sql`LIMIT ${limite}` : Prisma.empty}
      ${offset > 0 ? Prisma.sql`OFFSET ${offset}` : Prisma.empty}
    `);

    return rows.map((row) => ({
      ...this.formatearCreditoListado(row),
      frecuenciaPago: {
        id: Number(row.frecuencia_pago_id),
        codigo: row.frecuencia_codigo,
        nombre: row.frecuencia_nombre,
        diasIntervalo: Number(this.diasIntervaloFrecuencia(row.frecuencia_codigo)),
      },
    }));
  }

  private async contarCreditosPorEstadoTbl(
    query: ListarCreditosQueryDto,
    usuario: AuthenticatedUser,
  ) {
    const scope = await this.obtenerScopeOrganizacionTbl(usuario);
    const search = this.normalizarTextoOpcional(query.search);
    const conditions: Prisma.Sql[] = [
      Prisma.sql`cl.org_id = ${scope.organizacionId}::uuid`,
    ];
    const fechaConditions: Prisma.Sql[] = [Prisma.sql`1 = 1`];

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      conditions.push(Prisma.sql`tu.id_usu = ${scope.usuarioId}::uuid`);
    }

    if (query.rutaId) {
      conditions.push(
        Prisma.sql`ruta_credito.ruta_id = ${query.rutaId}::uuid`,
      );
    }

    if (query.fechaDesde) {
      const fechaDesde = this.parsearFecha(query.fechaDesde, 'fechaDesde');
      fechaConditions.push(Prisma.sql`fecha_referencia >= ${fechaDesde}::date`);
    }

    if (query.fechaHasta) {
      const fechaHasta = this.parsearFecha(query.fechaHasta, 'fechaHasta');
      fechaConditions.push(Prisma.sql`fecha_referencia <= ${fechaHasta}::date`);
    }

    if (search) {
      const pattern = `%${search}%`;
      conditions.push(Prisma.sql`(
        TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) ILIKE ${pattern}
        OR p.per_documento ILIKE ${pattern}
        OR p.per_direccion ILIKE ${pattern}
        OR cl.cli_referencia ILIKE ${pattern}
        OR ruta_credito.ruta ILIKE ${pattern}
        OR UPPER(cr.cre_estado::text) ILIKE ${pattern}
      )`);
    }

    return this.prisma.$queryRaw<CreditoConteoRow[]>(Prisma.sql`
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
          COUNT(*) FILTER (
            WHERE UPPER(cu.cuo_estado::text) NOT IN ('PAGADA', 'ANULADA')
              AND (cu.cuo_valor - COALESCE(ac.abonado, 0)) > 0
          )::int AS cuotas_restantes
        FROM public.tbl_cuotas cu
        LEFT JOIN abonos_cuota ac ON ac.id_cuo = cu.id_cuo
        GROUP BY cu.cre_id
      ),
      pagos_credito AS (
        SELECT
          cu.cre_id,
          MAX((pa.pag_fecha AT TIME ZONE 'America/Bogota')::date) AS fecha_ultimo_pago
        FROM public.tbl_pagos pa
        JOIN public.tbl_cuotas_pagos cp ON cp.pagos_id = pa.id_pag
        JOIN public.tbl_cuotas cu ON cu.id_cuo = cp.cuo_id
        GROUP BY cu.cre_id
      ),
      creditos_estado AS (
        SELECT
          UPPER(cr.cre_estado::text) AS codigo,
          COALESCE(rc.cuotas_restantes, 0) AS cuotas_restantes,
          GREATEST(cr.cre_total_pagar - COALESCE(rc.total_abonado, 0), 0) AS saldo,
          (UPPER(cr.cre_estado::text) = 'ACTIVO') AS es_activo,
          (UPPER(cr.cre_estado::text) = 'PAGADO') AS es_inactivo,
          CASE
            WHEN UPPER(cr.cre_estado::text) = 'ACTIVO' THEN cr.cre_fecha_inicio
            ELSE COALESCE(
              pc_ultimo.fecha_ultimo_pago,
              cr.cre_fecha_fin,
              cr.cre_fecha_inicio
            )
          END AS fecha_referencia
        FROM public.tbl_creditos cr
        JOIN public.tbl_usuarios tu ON tu.id_usu = cr.usu_id
        JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
        JOIN public.tbl_personas p ON p.id_per = cl.cli_persona
        LEFT JOIN resumen_credito rc ON rc.cre_id = cr.id_cre
        LEFT JOIN pagos_credito pc_ultimo ON pc_ultimo.cre_id = cr.id_cre
        LEFT JOIN LATERAL (
          SELECT r.id_rut AS ruta_id, r.rut_nombre AS ruta
          FROM public.tbl_rutas_clientes rc_ruta
          JOIN public.tbl_rutas r ON r.id_rut = rc_ruta.rut_id
          WHERE rc_ruta.cli_id = cl.id_cli
            AND r.org_id = cl.org_id
          ORDER BY (r.usu_id = cr.usu_id) DESC, r.rut_activa DESC, r.rut_nombre ASC
          LIMIT 1
        ) ruta_credito ON TRUE
        WHERE ${Prisma.join(conditions, ' AND ')}
      ),
      creditos_filtrados AS (
        SELECT *
        FROM creditos_estado
        WHERE ${Prisma.join(fechaConditions, ' AND ')}
      )
      SELECT
        COUNT(*)::int AS total,
        COUNT(*) FILTER (
          WHERE es_activo
        )::int AS activos,
        COUNT(*) FILTER (
          WHERE es_inactivo
        )::int AS inactivos
      FROM creditos_filtrados
    `);
  }

  private async listarCuotasCreditoTbl(
    creditoId: string,
    usuario: AuthenticatedUser,
  ) {
    await this.validarAccesoCreditoTbl(creditoId, usuario);

    const rows = await this.prisma.$queryRaw<CuotaCreditoTblRow[]>(Prisma.sql`
      WITH abonos_cuota AS (
        SELECT
          cu.id_cuo,
          GREATEST(
            COALESCE(cu.cuo_total_pagado, 0),
            COALESCE(SUM(cp.cpa_total), 0)
          ) AS abonado
        FROM public.tbl_cuotas cu
        LEFT JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
        WHERE cu.cre_id = ${creditoId}::uuid
        GROUP BY cu.id_cuo, cu.cuo_total_pagado
      )
      SELECT
        cu.id_cuo::text AS credito_cuota_id,
        cu.cuo_numero::int AS numero_cuota,
        cu.cuo_fecha_vencimiento AS fecha_vencimiento,
        UPPER(cu.cuo_estado::text) AS estado_codigo,
        INITCAP(REPLACE(cu.cuo_estado::text, '_', ' ')) AS estado_nombre,
        cu.cuo_valor AS valor_capital,
        0::numeric AS valor_interes,
        cu.cuo_valor AS valor_total,
        COALESCE(ac.abonado, 0) AS abonado,
        GREATEST(cu.cuo_valor - COALESCE(ac.abonado, 0), 0) AS saldo
      FROM public.tbl_cuotas cu
      LEFT JOIN abonos_cuota ac ON ac.id_cuo = cu.id_cuo
      WHERE cu.cre_id = ${creditoId}::uuid
      ORDER BY cu.cuo_numero ASC
    `);

    return rows.map((row) => ({
      id: row.credito_cuota_id,
      numeroCuota: row.numero_cuota,
      fechaVencimiento: this.fechaIso(row.fecha_vencimiento),
      estado: {
        codigo: row.estado_codigo,
        nombre: row.estado_nombre,
      },
      valorCapital: this.decimalANumero(row.valor_capital),
      valorInteres: this.decimalANumero(row.valor_interes),
      valorTotal: this.decimalANumero(row.valor_total),
      abonado: this.decimalANumero(row.abonado),
      saldo: this.decimalANumero(row.saldo),
    }));
  }

  private async obtenerCreditoTbl(
    creditoId: string,
    usuario: AuthenticatedUser,
  ) {
    await this.validarAccesoCreditoTbl(creditoId, usuario);

    const rows = await this.prisma.$queryRaw<CreditoTblRow[]>(Prisma.sql`
      SELECT
        cr.id_cre::text AS credito_id,
        cl.id_cli::text AS cliente_id,
        TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS cliente,
        p.per_documento AS cedula,
        cl.cli_referencia AS negocio,
        p.per_direccion AS direccion,
        ruta_credito.ruta_id::text AS ruta_id,
        ruta_credito.ruta AS ruta,
        caja_credito.caja_menor_id::text AS caja_menor_id,
        caja_credito.caja_menor AS caja_menor,
        mon.mon_codigo::text AS moneda_codigo,
        pc.id_pcr::text AS frecuencia_id,
        pc.pcr_frecuencia::text AS frecuencia_codigo,
        INITCAP(REPLACE(pc.pcr_frecuencia::text, '_', ' ')) AS frecuencia_nombre,
        UPPER(cr.cre_estado::text) AS estado_codigo,
        cr.cre_fecha_inicio AS fecha_inicio,
        cr.cre_fecha_fin AS fecha_fin,
        cr.cre_total AS valor_principal,
        cr.cre_tasa_interes AS porcentaje_interes,
        cr.cre_interes_total AS interes_total,
        cr.cre_total_pagar AS valor_total,
        COUNT(cu.id_cuo)::int AS numero_cuotas,
        COALESCE(MAX(cu.cuo_valor), 0) AS valor_cuota,
        COALESCE(SUM(cu.cuo_total_pagado), 0) AS total_abonado,
        COUNT(*) FILTER (
          WHERE UPPER(cu.cuo_estado::text) NOT IN ('PAGADA', 'ANULADA')
            AND (cu.cuo_valor - COALESCE(cu.cuo_total_pagado, 0)) > 0
        )::int AS cuotas_restantes
      FROM public.tbl_creditos cr
      JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
      JOIN public.tbl_personas p ON p.id_per = cl.cli_persona
      JOIN public.tbl_productos_creditos pc ON pc.id_pcr = cr.pcr_id
      JOIN public.tbl_monedas mon ON mon.id_mon = cr.mon_id
      LEFT JOIN public.tbl_cuotas cu ON cu.cre_id = cr.id_cre
      LEFT JOIN LATERAL (
        SELECT r.id_rut AS ruta_id, r.rut_nombre AS ruta
        FROM public.tbl_rutas_clientes rc
        JOIN public.tbl_rutas r ON r.id_rut = rc.rut_id
        WHERE rc.cli_id = cl.id_cli
          AND r.org_id = cl.org_id
        ORDER BY (r.usu_id = cr.usu_id) DESC, r.rut_activa DESC
        LIMIT 1
      ) ruta_credito ON TRUE
      LEFT JOIN LATERAL (
        SELECT c.id_caj AS caja_menor_id, c.caj_nombre AS caja_menor
        FROM public.tbl_movimientos_cajas mc
        JOIN public.tbl_sesiones_cajas sc ON sc.id_sca = mc.sca_id
        JOIN public.tbl_cajas c ON c.id_caj = sc.caj_id
        WHERE mc.mca_referencia_tipo::text = 'CREDITO'
          AND mc.mca_referencia_id = cr.id_cre
          AND mc.mca_tipo::text = 'DESEMBOLSO_CREDITO'
        ORDER BY mc.id_mca DESC
        LIMIT 1
      ) caja_credito ON TRUE
      WHERE cr.id_cre = ${creditoId}::uuid
      GROUP BY
        cr.id_cre,
        cl.id_cli,
        p.id_per,
        pc.id_pcr,
        mon.id_mon,
        ruta_credito.ruta_id,
        ruta_credito.ruta,
        caja_credito.caja_menor_id,
        caja_credito.caja_menor
    `);
    const credito = rows[0];

    if (!credito) {
      throw DomainError.notFound(
        'Credito no encontrado',
        'CREDITO_NO_ENCONTRADO',
      );
    }

    const plazoDias = Math.max(
      1,
      Math.ceil(
        (this.fechaUtc(credito.fecha_fin).getTime() -
          this.fechaUtc(credito.fecha_inicio).getTime()) /
          86_400_000,
      ),
    );

    return {
      id: credito.credito_id,
      clienteId: credito.cliente_id,
      cliente: credito.cliente,
      cedula: credito.cedula,
      negocio: credito.negocio,
      direccion: credito.direccion,
      rutaId: credito.ruta_id ?? '',
      ruta: credito.ruta ?? 'Sin ruta',
      cajaMenorId: credito.caja_menor_id,
      cajaMenor: credito.caja_menor,
      monedaCodigo: credito.moneda_codigo.trim(),
      frecuenciaPago: {
        id: Number(credito.frecuencia_id),
        codigo: credito.frecuencia_codigo,
        nombre: credito.frecuencia_nombre,
        diasIntervalo: this.diasIntervaloFrecuencia(credito.frecuencia_codigo),
      },
      estado: {
        codigo: credito.estado_codigo,
        nombre: this.nombreDesdeCodigo(credito.estado_codigo),
      },
      fechaInicio: this.fechaIso(credito.fecha_inicio),
      valorPrincipal: this.decimalANumero(credito.valor_principal),
      porcentajeInteres: this.decimalANumero(credito.porcentaje_interes),
      plazoDias,
      omitirDomingos: false,
      observacion: null,
      valorTotal: this.decimalANumero(credito.valor_total),
      valorCuota: this.decimalANumero(credito.valor_cuota),
      totalAbonado: this.decimalANumero(credito.total_abonado),
      saldo: this.redondear(
        Math.max(
          this.decimalANumero(credito.valor_total) -
            this.decimalANumero(credito.total_abonado),
          0,
        ),
      ),
      numeroCuotas: credito.numero_cuotas,
      cuotasRestantes: credito.cuotas_restantes,
      fechaMaxima: this.fechaIso(credito.fecha_fin),
      planPago: {
        id: credito.credito_id,
        numeroCuotas: credito.numero_cuotas,
        valorCuota: this.decimalANumero(credito.valor_cuota),
        valorTotal: this.decimalANumero(credito.valor_total),
        fechaMaxima: this.fechaIso(credito.fecha_fin),
        domingosOmitidos: 0,
      },
      desembolso: null,
      creadoEn: this.fechaUtc(credito.fecha_inicio).toISOString(),
      actualizadoEn: this.fechaUtc(credito.fecha_inicio).toISOString(),
    };
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
      WHERE m.id_mca::text = ${movimientoId}
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

  private async obtenerPresupuestoTbl(
    query: ObtenerPresupuestoQueryDto,
    usuario: AuthenticatedUser,
  ) {
    const scope = await this.obtenerScopeOrganizacionTbl(usuario);
    const puedeVerTodo = this.puedeVerDatosOrganizacion(usuario);
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

    const items = rows.map((row) => ({
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

  private async validarAccesoCreditoTbl(
    creditoId: string,
    usuario: AuthenticatedUser,
  ) {
    const scope = await this.obtenerScopeOrganizacionTbl(usuario);
    const rows = await this.prisma.$queryRaw<Array<{ existe: boolean }>>(
      Prisma.sql`
        SELECT EXISTS (
          SELECT 1
          FROM public.tbl_creditos cr
          JOIN public.tbl_usuarios tu ON tu.id_usu = cr.usu_id
          JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
          WHERE cr.id_cre = ${creditoId}::uuid
            AND cl.org_id = ${scope.organizacionId}::uuid
            AND ${
              this.puedeVerDatosOrganizacion(usuario)
                ? Prisma.sql`TRUE`
                : Prisma.sql`tu.id_usu = ${scope.usuarioId}::uuid`
            }
        ) AS existe
      `,
    );

    if (!rows[0]?.existe) {
      throw DomainError.notFound(
        'Credito no encontrado',
        'CREDITO_NO_ENCONTRADO',
      );
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
        row.proxima_numero_cuota !== null && row.proxima_numero_cuota !== undefined
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

  private formatearClienteTbl(cliente: ClienteTblRow) {
    const cedula = this.esDocumentoClienteGeneradoTbl(cliente.cedula)
      ? null
      : cliente.cedula;

    return {
      id: cliente.id,
      nombreCompleto: cliente.nombre_completo,
      nombreComercial: cliente.nombre_comercial,
      notas: cliente.notas,
      cedula,
      direccion: cliente.direccion,
      correo: cliente.correo ?? null,
      telefono: cliente.telefono,
      whatsapp: cliente.telefono,
      estado: {
        codigo: cliente.activo ? 'ACTIVO' : 'INACTIVO',
        nombre: cliente.activo ? 'Activo' : 'Inactivo',
      },
      documentos: [
        ...(cedula
          ? [
              {
                id: `doc-${cliente.id}`,
                tipo: { id: 1, codigo: 'CC', nombre: 'Documento' },
                numeroDocumento: cedula,
                expedidoEn: null,
              },
            ]
          : []),
      ],
      direcciones: cliente.direccion
        ? [
            {
              id: `dir-${cliente.id}`,
              tipo: { id: 1, codigo: 'CASA', nombre: 'Direccion' },
              direccion: cliente.direccion,
              barrio: null,
              municipio: '',
              departamento: '',
              pais: 'Colombia',
              referencia: null,
              latitud:
                cliente.latitud === null
                  ? null
                  : this.decimalANumero(cliente.latitud),
              longitud:
                cliente.longitud === null
                  ? null
                  : this.decimalANumero(cliente.longitud),
              esPrincipal: true,
            },
          ]
        : [],
      creadoEn: cliente.creado_en.toISOString(),
      actualizadoEn: cliente.actualizado_en.toISOString(),
    };
  }

  private generarDocumentoClienteTbl() {
    return `AUTO-CLIENTE-${randomUUID()}`;
  }

  private esDocumentoClienteGeneradoTbl(value: string | null) {
    return value?.startsWith('AUTO-CLIENTE-') ?? false;
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

  private esIdTbl(value: string) {
    return /^\d+$/.test(value) || /^[0-9a-fA-F-]{36}$/.test(value);
  }

  private diasIntervaloFrecuencia(codigo: string) {
    switch (codigo.toUpperCase()) {
      case 'SEMANAL':
        return 7;
      case 'QUINCENAL':
        return 15;
      case 'MENSUAL':
        return 30;
      default:
        return 1;
    }
  }

  private nombreDesdeCodigo(codigo: string) {
    return codigo
      .toLowerCase()
      .split('_')
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(' ');
  }

  private formatearHojaExportacion(
    sheet: Worksheet,
    columnasMonetarias: string[],
  ) {
    sheet.views = [{ state: 'frozen', ySplit: 1 }];
    sheet.getRow(1).height = 22;
    sheet.getRow(1).eachCell((cell) => {
      cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
      cell.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FF1F2937' },
      };
      cell.alignment = { vertical: 'middle' };
    });

    for (const key of columnasMonetarias) {
      sheet.getColumn(key).numFmt = '#,##0.##########';
    }

    sheet.eachRow((row, rowNumber) => {
      if (rowNumber === 1) {
        return;
      }

      row.eachCell((cell) => {
        cell.alignment = { vertical: 'top', wrapText: true };
      });
    });
  }

  private crearVistaPreviaExportacion(
    columnas: ColumnaExportacion[],
    filas: FilaExportacion[],
  ): ExportacionVistaPrevia {
    return {
      columnas: columnas.map((columna) => columna.header),
      filas: filas.slice(0, 50).map((fila) =>
        columnas.map((columna) => {
          const valor = fila[columna.key];

          if (valor === undefined) {
            return null;
          }

          return valor;
        }),
      ),
    };
  }

  private async subirWorkbookExportacion(input: {
    workbook: Workbook;
    carpeta: string;
    nombreBase: string;
    filas: number;
    vistaPrevia: ExportacionVistaPrevia;
  }): Promise<ExportacionExcel> {
    const contenido = Buffer.from(await input.workbook.xlsx.writeBuffer());
    const nombreArchivo = `${input.nombreBase}-${this.timestampArchivo()}.xlsx`;
    const resultado = await this.exportacionesR2.subirExcel({
      carpeta: input.carpeta,
      nombreArchivo,
      contenido,
    });

    return {
      ...resultado,
      filas: input.filas,
      generadoEn: new Date().toISOString(),
      vistaPrevia: input.vistaPrevia,
    };
  }

  private timestampArchivo() {
    return new Date().toISOString().replace(/[:.]/g, '-');
  }

  private asegurarTamanoExportacion(rowCount: number) {
    if (rowCount > maxExportRows) {
      throw DomainError.validation(
        `La exportacion supera el maximo de ${maxExportRows} filas; aplica filtros mas especificos`,
        'EXPORTACION_DEMASIADO_GRANDE',
      );
    }
  }

  private async crearContactoCliente(
    tx: Prisma.TransactionClient,
    clienteId: string,
    codigoTipo: string,
    valor: string | null,
  ) {
    if (!valor) {
      return;
    }

    const tipo = await tx.tipoContacto.findUnique({
      where: { codigo: codigoTipo },
    });

    if (!tipo) {
      throw DomainError.notFound(
        `No existe el tipo de contacto ${codigoTipo}`,
        'TIPO_CONTACTO_NO_EXISTE',
      );
    }

    await tx.clienteContacto.create({
      data: {
        clienteId,
        tipoContactoId: tipo.tipoContactoId,
        valor,
        esPrincipal: true,
      },
    });
  }

  private async reemplazarContactoCliente(
    tx: Prisma.TransactionClient,
    clienteId: string,
    codigoTipo: string,
    valor: string | null,
  ) {
    const tipo = await tx.tipoContacto.findUnique({
      where: { codigo: codigoTipo },
    });

    if (!tipo) {
      throw DomainError.notFound(
        `No existe el tipo de contacto ${codigoTipo}`,
        'TIPO_CONTACTO_NO_EXISTE',
      );
    }

    await tx.clienteContacto.deleteMany({
      where: { clienteId, tipoContactoId: tipo.tipoContactoId },
    });

    if (!valor) {
      return;
    }

    await tx.clienteContacto.create({
      data: {
        clienteId,
        tipoContactoId: tipo.tipoContactoId,
        valor,
        esPrincipal: true,
      },
    });
  }

  private async crearDocumentoCliente(
    tx: Prisma.TransactionClient,
    clienteId: string,
    codigoTipo: string,
    numeroDocumento: string | null,
  ) {
    if (!numeroDocumento) {
      return;
    }

    const tipo = await tx.tipoDocumento.findUnique({
      where: { codigo: codigoTipo },
    });

    if (!tipo) {
      throw DomainError.notFound(
        `No existe el tipo de documento ${codigoTipo}`,
        'TIPO_DOCUMENTO_NO_EXISTE',
      );
    }

    const existente = await tx.clienteDocumento.findFirst({
      where: {
        tipoDocumentoId: tipo.tipoDocumentoId,
        numeroDocumento,
      },
      select: { clienteId: true },
    });

    if (existente) {
      throw DomainError.conflict(
        'Ya existe un cliente con esta cedula',
        'CEDULA_YA_REGISTRADA',
      );
    }

    await tx.clienteDocumento.create({
      data: {
        clienteId,
        tipoDocumentoId: tipo.tipoDocumentoId,
        numeroDocumento,
      },
    });
  }

  private async reemplazarDocumentoCliente(
    tx: Prisma.TransactionClient,
    clienteId: string,
    codigoTipo: string,
    numeroDocumento: string | null,
  ) {
    const tipo = await tx.tipoDocumento.findUnique({
      where: { codigo: codigoTipo },
    });

    if (!tipo) {
      throw DomainError.notFound(
        `No existe el tipo de documento ${codigoTipo}`,
        'TIPO_DOCUMENTO_NO_EXISTE',
      );
    }

    if (numeroDocumento) {
      const existente = await tx.clienteDocumento.findFirst({
        where: {
          tipoDocumentoId: tipo.tipoDocumentoId,
          numeroDocumento,
          NOT: { clienteId },
        },
        select: { clienteId: true },
      });

      if (existente) {
        throw DomainError.conflict(
          'Ya existe un cliente con esta cedula',
          'CEDULA_YA_REGISTRADA',
        );
      }
    }

    await tx.clienteDocumento.deleteMany({
      where: { clienteId, tipoDocumentoId: tipo.tipoDocumentoId },
    });

    if (!numeroDocumento) {
      return;
    }

    await tx.clienteDocumento.create({
      data: {
        clienteId,
        tipoDocumentoId: tipo.tipoDocumentoId,
        numeroDocumento,
      },
    });
  }

  private async crearDireccionCliente(
    tx: Prisma.TransactionClient,
    clienteId: string,
    direccion: string | null,
    latitud?: number,
    longitud?: number,
  ) {
    if (!direccion) {
      return;
    }

    const tipo = await tx.tipoDireccion.findUnique({
      where: { codigo: 'CASA' },
    });

    if (!tipo) {
      throw DomainError.notFound(
        'No existe el tipo de direccion CASA',
        'TIPO_DIRECCION_NO_EXISTE',
      );
    }

    await tx.clienteDireccion.create({
      data: {
        clienteId,
        tipoDireccionId: tipo.tipoDireccionId,
        direccion,
        municipio: 'No especificado',
        departamento: 'No especificado',
        latitud,
        longitud,
        esPrincipal: true,
      },
    });
  }

  private async reemplazarDireccionCliente(
    tx: Prisma.TransactionClient,
    clienteId: string,
    direccion: string | null,
    latitud?: number | null,
    longitud?: number | null,
  ) {
    const tipo = await tx.tipoDireccion.findUnique({
      where: { codigo: 'CASA' },
    });

    if (!tipo) {
      throw DomainError.notFound(
        'No existe el tipo de direccion CASA',
        'TIPO_DIRECCION_NO_EXISTE',
      );
    }

    await tx.clienteDireccion.deleteMany({
      where: { clienteId, tipoDireccionId: tipo.tipoDireccionId },
    });

    if (!direccion) {
      return;
    }

    await tx.clienteDireccion.create({
      data: {
        clienteId,
        tipoDireccionId: tipo.tipoDireccionId,
        direccion,
        municipio: 'No especificado',
        departamento: 'No especificado',
        latitud: latitud ?? undefined,
        longitud: longitud ?? undefined,
        esPrincipal: true,
      },
    });
  }

  private dividirNombrePersonaTbl(nombreCompleto: string) {
    const partes = nombreCompleto.split(/\s+/).filter(Boolean);

    if (partes.length <= 1) {
      return { nombres: nombreCompleto, apellidos: '-' };
    }

    return {
      nombres: partes.slice(0, -1).join(' '),
      apellidos: partes[partes.length - 1],
    };
  }

  private async obtenerOCrearRutaCredito(
    tx: Prisma.TransactionClient,
    dto: CrearCreditoDto,
    usuario: AuthenticatedUser,
  ) {
    if (dto.rutaId) {
      const ruta = await tx.ruta.findUnique({
        where: { rutaId: dto.rutaId },
        include: { estadoRuta: true },
      });

      if (!ruta) {
        throw DomainError.notFound('Ruta no encontrada', 'RUTA_NO_ENCONTRADA');
      }

      this.asegurarResponsableRuta(ruta.responsableUsuarioId, usuario);

      if (ruta.estadoRuta.codigo !== 'ABIERTA') {
        throw DomainError.conflict(
          'La ruta no esta abierta para nuevos creditos',
          'RUTA_NO_ABIERTA',
        );
      }

      return ruta;
    }

    const estadoAbierta = await tx.estadoRuta.findUnique({
      where: { codigo: 'ABIERTA' },
    });

    if (!estadoAbierta) {
      throw DomainError.notFound(
        'No existe el estado de ruta ABIERTA en los catalogos',
        'ESTADO_RUTA_ABIERTA_NO_EXISTE',
      );
    }

    const rutaAbierta = await tx.ruta.findFirst({
      where: {
        responsableUsuarioId: usuario.usuarioId,
        estadoRutaId: estadoAbierta.estadoRutaId,
      },
      include: { estadoRuta: true },
      orderBy: [{ esPrincipal: 'desc' }, { creadoEn: 'asc' }],
    });

    if (rutaAbierta) {
      return rutaAbierta;
    }

    const rutasResponsable = await tx.ruta.findMany({
      where: { responsableUsuarioId: usuario.usuarioId },
      select: { nombre: true },
    });
    const nombresExistentes = new Set(
      rutasResponsable.map((ruta) => ruta.nombre),
    );
    let nombre = 'Ruta principal';
    let indice = 1;

    while (nombresExistentes.has(nombre)) {
      indice += 1;
      nombre = `Ruta principal ${indice}`;
    }

    return tx.ruta.create({
      data: {
        responsableUsuarioId: usuario.usuarioId,
        estadoRutaId: estadoAbierta.estadoRutaId,
        nombre,
        descripcion: 'Creada automaticamente al registrar un credito',
        esPrincipal: rutasResponsable.length === 0,
      },
      include: { estadoRuta: true },
    });
  }

  private async obtenerOCrearRutaCreditoTbl(
    tx: Prisma.TransactionClient,
    rutaId: string | undefined,
    organizacionId: string,
    usuarioId: string,
    usuarioNombre: string,
  ) {
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

  private async asegurarClienteEnRuta(
    tx: Prisma.TransactionClient,
    rutaId: string,
    clienteId: string,
  ) {
    const existente = await tx.rutaCliente.findUnique({
      where: { rutaId_clienteId: { rutaId, clienteId } },
    });

    if (existente) {
      return;
    }

    const ultimoOrden = await tx.rutaCliente.aggregate({
      where: { rutaId },
      _max: { ordenVisita: true },
    });

    await tx.rutaCliente.create({
      data: {
        rutaId,
        clienteId,
        ordenVisita: (ultimoOrden._max.ordenVisita ?? 0) + 1,
        activo: true,
      },
    });
  }

  private async registrarDesembolsoCaja(
    tx: Prisma.TransactionClient,
    dto: CrearCreditoDto,
    ruta: { responsableUsuarioId: string; rutaId: string },
    usuario: AuthenticatedUser,
    valorPrincipal: number,
    fechaInicio: Date,
    clienteNombre: string,
  ) {
    if (!dto.cajaMenorId) {
      throw DomainError.validation(
        'No se puede hacer credito sin caja menor',
        'CREDITO_REQUIERE_CAJA_MENOR',
      );
    }

    const [caja, tipoDesembolso] = await Promise.all([
      tx.cajaMenor.findUnique({ where: { cajaMenorId: dto.cajaMenorId } }),
      tx.tipoMovimientoCaja.findUnique({
        where: { codigo: 'DESEMBOLSO_CREDITO' },
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

    if (caja.responsableUsuarioId !== ruta.responsableUsuarioId) {
      throw DomainError.conflict(
        'La caja menor no pertenece al responsable de la ruta',
        'CAJA_MENOR_RUTA_RESPONSABLE_DIFERENTE',
      );
    }

    if (caja.monedaCodigo !== dto.monedaCodigo) {
      throw DomainError.conflict(
        'La moneda de la caja menor no coincide con el credito',
        'CAJA_MENOR_MONEDA_DIFERENTE',
      );
    }

    if (!tipoDesembolso) {
      throw DomainError.notFound(
        'Falta el tipo DESEMBOLSO_CREDITO',
        'TIPO_DESEMBOLSO_CREDITO_NO_EXISTE',
      );
    }

    await this.asegurarSalidaCajaConPresupuesto(
      tx,
      caja.cajaMenorId,
      valorPrincipal,
      'No se puede hacer credito sin caja suficiente',
      'CAJA_MENOR_SALDO_INSUFICIENTE',
    );

    const movimiento = await tx.cajaMenorMovimiento.create({
      data: {
        cajaMenorId: caja.cajaMenorId,
        tipoMovimientoCajaId: tipoDesembolso.tipoMovimientoCajaId,
        usuarioId: usuario.usuarioId,
        fechaMovimiento: fechaInicio,
        monto: this.decimal(valorPrincipal),
        motivo: this.motivoDesembolsoCredito(clienteNombre),
      },
    });

    return movimiento.cajaMenorMovimientoId;
  }

  private async registrarRefinanciacionCaja(
    tx: Prisma.TransactionClient,
    dto: { cajaMenorId: string; monedaCodigo: string },
    ruta: { responsableUsuarioId: string; rutaId: string },
    usuario: AuthenticatedUser,
    incremento: number,
    fechaInicio: Date,
    clienteNombre: string,
    creditoId: string,
    valorAnterior: number,
    valorNuevo: number,
  ) {
    const [caja, tipoDesembolso] = await Promise.all([
      tx.cajaMenor.findUnique({ where: { cajaMenorId: dto.cajaMenorId } }),
      tx.tipoMovimientoCaja.findUnique({
        where: { codigo: 'DESEMBOLSO_CREDITO' },
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

    if (caja.responsableUsuarioId !== ruta.responsableUsuarioId) {
      throw DomainError.conflict(
        'La caja menor no pertenece al responsable de la ruta',
        'CAJA_MENOR_RUTA_RESPONSABLE_DIFERENTE',
      );
    }

    if (caja.monedaCodigo !== dto.monedaCodigo) {
      throw DomainError.conflict(
        'La moneda de la caja menor no coincide con el credito',
        'CAJA_MENOR_MONEDA_DIFERENTE',
      );
    }

    if (!tipoDesembolso) {
      throw DomainError.notFound(
        'Falta el tipo DESEMBOLSO_CREDITO',
        'TIPO_DESEMBOLSO_CREDITO_NO_EXISTE',
      );
    }

    await this.asegurarSalidaCajaConPresupuesto(
      tx,
      caja.cajaMenorId,
      incremento,
      'No se puede refinanciar credito sin caja suficiente',
      'CAJA_MENOR_SALDO_INSUFICIENTE',
    );

    const movimiento = await tx.cajaMenorMovimiento.create({
      data: {
        cajaMenorId: caja.cajaMenorId,
        tipoMovimientoCajaId: tipoDesembolso.tipoMovimientoCajaId,
        usuarioId: usuario.usuarioId,
        fechaMovimiento: fechaInicio,
        monto: this.decimal(incremento),
        motivo:
          `Refinanciacion de credito para ${clienteNombre}: ` +
          `${this.formatearMontoAuditoria(valorAnterior)} a ` +
          `${this.formatearMontoAuditoria(valorNuevo)}`,
        referenciaTabla: 'credito_refinanciacion',
        referenciaId: creditoId,
      },
    });

    return movimiento.cajaMenorMovimientoId;
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

  private async marcarCreditoPagadoSiCorresponde(
    tx: Prisma.TransactionClient,
    creditoId: string,
  ) {
    const cuotasPendientes = await tx.creditoCuota.count({
      where: {
        planPago: { creditoId },
        estadoCuota: { codigo: { notIn: ['PAGADA', 'ANULADA'] } },
      },
    });

    if (cuotasPendientes > 0) {
      return;
    }

    const estadoPagado = await tx.estadoCredito.findUnique({
      where: { codigo: 'PAGADO' },
    });

    if (!estadoPagado) {
      throw DomainError.notFound(
        'Falta el estado de credito PAGADO',
        'ESTADO_CREDITO_PAGADO_NO_EXISTE',
      );
    }

    await tx.credito.update({
      where: { creditoId },
      data: { estadoCreditoId: estadoPagado.estadoCreditoId },
    });
  }

  private calcularPlan(input: {
    fechaInicio: Date;
    valorPrincipal: number;
    porcentajeInteres: number;
    plazoDias: number;
    diasIntervalo: number;
    omitirDomingos: boolean;
    decimales: number;
  }): PlanCalculado {
    const numeroCuotas = Math.max(
      1,
      Math.ceil(input.plazoDias / input.diasIntervalo),
    );
    const unidadesPrincipal = this.dineroAUnidades(
      input.valorPrincipal,
      input.decimales,
    );
    const unidadesTotal = this.dineroAUnidades(
      input.valorPrincipal +
        input.valorPrincipal * (input.porcentajeInteres / 100),
      input.decimales,
    );
    const unidadesInteres = Math.max(0, unidadesTotal - unidadesPrincipal);
    const valorTotal = this.unidadesADinero(unidadesTotal, input.decimales);
    const valorCuota = this.redondear(
      valorTotal / numeroCuotas,
      input.decimales,
    );
    const totalesPorCuota = this.distribuirUnidades(
      unidadesTotal,
      numeroCuotas,
    );
    const interesesPorCuota = this.distribuirUnidadesAcotadas(
      unidadesInteres,
      totalesPorCuota,
    );
    const capitalesPorCuota = totalesPorCuota.map(
      (totalCuota, index) => totalCuota - interesesPorCuota[index],
    );
    const totalCapitalCalculado = capitalesPorCuota.reduce(
      (sum, value) => sum + value,
      0,
    );

    if (totalCapitalCalculado !== unidadesPrincipal) {
      throw DomainError.validation(
        'No se pudo distribuir el capital del credito en cuotas validas',
        'PLAN_CREDITO_DISTRIBUCION_INVALIDA',
      );
    }

    let cursor = this.fechaUtc(input.fechaInicio);
    let domingosOmitidos = 0;

    const cuotas = Array.from({ length: numeroCuotas }, (_, index) => {
      if (input.diasIntervalo === 1 && input.omitirDomingos) {
        do {
          cursor = this.sumarDias(cursor, 1);
          if (cursor.getUTCDay() === 0) {
            domingosOmitidos++;
          }
        } while (cursor.getUTCDay() === 0);
      } else {
        cursor = this.sumarDias(cursor, input.diasIntervalo);
      }

      return {
        numeroCuota: index + 1,
        fechaVencimiento: cursor,
        valorCapital: this.unidadesADinero(
          capitalesPorCuota[index],
          input.decimales,
        ),
        valorInteres: this.unidadesADinero(
          interesesPorCuota[index],
          input.decimales,
        ),
      };
    });

    return {
      numeroCuotas,
      valorCuota,
      valorTotal,
      fechaMaxima: cuotas[cuotas.length - 1].fechaVencimiento,
      domingosOmitidos,
      cuotas,
    };
  }

  private calcularPlanPendiente(input: {
    fechaInicio: Date;
    valorCapital: number;
    valorInteres: number;
    plazoDias: number;
    diasIntervalo: number;
    omitirDomingos: boolean;
    decimales: number;
  }): PlanCalculado {
    const numeroCuotas = Math.max(
      1,
      Math.ceil(input.plazoDias / input.diasIntervalo),
    );
    const unidadesCapital = this.dineroAUnidades(
      input.valorCapital,
      input.decimales,
    );
    const unidadesInteres = this.dineroAUnidades(
      input.valorInteres,
      input.decimales,
    );
    const unidadesTotal = unidadesCapital + unidadesInteres;
    const valorTotal = this.unidadesADinero(unidadesTotal, input.decimales);
    const valorCuota = this.redondear(
      valorTotal / numeroCuotas,
      input.decimales,
    );
    const totalesPorCuota = this.distribuirUnidades(
      unidadesTotal,
      numeroCuotas,
    );
    const interesesPorCuota = this.distribuirUnidadesAcotadas(
      unidadesInteres,
      totalesPorCuota,
    );
    const capitalesPorCuota = totalesPorCuota.map(
      (totalCuota, index) => totalCuota - interesesPorCuota[index],
    );

    let cursor = this.fechaUtc(input.fechaInicio);
    let domingosOmitidos = 0;

    const cuotas = Array.from({ length: numeroCuotas }, (_, index) => {
      if (input.diasIntervalo === 1 && input.omitirDomingos) {
        do {
          cursor = this.sumarDias(cursor, 1);
          if (cursor.getUTCDay() === 0) {
            domingosOmitidos++;
          }
        } while (cursor.getUTCDay() === 0);
      } else {
        cursor = this.sumarDias(cursor, input.diasIntervalo);
      }

      return {
        numeroCuota: index + 1,
        fechaVencimiento: cursor,
        valorCapital: this.unidadesADinero(
          capitalesPorCuota[index],
          input.decimales,
        ),
        valorInteres: this.unidadesADinero(
          interesesPorCuota[index],
          input.decimales,
        ),
      };
    });

    return {
      numeroCuotas,
      valorCuota,
      valorTotal,
      fechaMaxima: cuotas[cuotas.length - 1].fechaVencimiento,
      domingosOmitidos,
      cuotas,
    };
  }

  private distribuirUnidades(total: number, partes: number) {
    const base = Math.floor(total / partes);
    let restante = total - base * partes;

    return Array.from({ length: partes }, (_, index) => {
      const partesPendientes = partes - index;
      if (restante <= 0) {
        return base;
      }

      if (restante >= partesPendientes) {
        restante--;
        return base + 1;
      }

      return base;
    });
  }

  private distribuirUnidadesAcotadas(total: number, topes: number[]) {
    const distribucion = this.distribuirUnidades(total, topes.length).map(
      (valor, index) => Math.min(valor, topes[index]),
    );
    let restante = total - distribucion.reduce((sum, value) => sum + value, 0);

    for (
      let index = distribucion.length - 1;
      index >= 0 && restante > 0;
      index--
    ) {
      const disponible = topes[index] - distribucion[index];
      const asignado = Math.min(disponible, restante);
      distribucion[index] += asignado;
      restante -= asignado;
    }

    if (restante > 0) {
      throw DomainError.validation(
        'No se pudo distribuir el interes del credito en cuotas validas',
        'PLAN_CREDITO_INTERES_INVALIDO',
      );
    }

    return distribucion;
  }

  private dineroAUnidades(value: number, decimales: number) {
    const factor = 10 ** decimales;
    return Math.round((value + Number.EPSILON) * factor);
  }

  private unidadesADinero(value: number, decimales: number) {
    return this.redondear(value / 10 ** decimales, decimales);
  }

  private saldoCuota(
    cuota: { valorTotal: Prisma.Decimal },
    sumas: SumaAplicaciones,
  ) {
    const totalAplicado =
      this.decimalANumero(sumas._sum.montoCapital) +
      this.decimalANumero(sumas._sum.montoInteres) +
      this.decimalANumero(sumas._sum.montoMora) -
      this.decimalANumero(sumas._sum.montoDescuento);

    return this.redondear(
      this.decimalANumero(cuota.valorTotal) - totalAplicado,
    );
  }

  private sumasAplicacionesVacias(): SumaAplicaciones {
    return {
      _sum: {
        montoCapital: null,
        montoInteres: null,
        montoMora: null,
        montoDescuento: null,
      },
    };
  }

  private distribuirPagoEnCuota(
    cuota: CreditoCuotaParaPago,
    sumas: SumaAplicaciones,
    montoPagado: number,
  ) {
    const interesPendiente = Math.max(
      0,
      this.decimalANumero(cuota.valorInteres) -
        this.decimalANumero(sumas._sum.montoInteres),
    );
    const interes = Math.min(montoPagado, this.redondear(interesPendiente));
    const capital = this.redondear(montoPagado - interes);

    return {
      capital,
      interes: this.redondear(interes),
    };
  }

  private async validarAccesoCreditoPorId(
    creditoId: string,
    usuario: AuthenticatedUser,
  ) {
    const credito = await this.prisma.credito.findUnique({
      where: { creditoId },
      select: {
        creadoPorUsuarioId: true,
        ruta: {
          select: {
            responsableUsuarioId: true,
          },
        },
      },
    });

    if (!credito) {
      throw DomainError.notFound(
        'Credito no encontrado',
        'CREDITO_NO_ENCONTRADO',
      );
    }

    this.asegurarAccesoCredito(credito, usuario);
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

  private claveCajaPago(responsableUsuarioId: string, monedaCodigo: string) {
    return `${responsableUsuarioId}:${monedaCodigo}`;
  }

  private asegurarAccesoCredito(
    credito: {
      creadoPorUsuarioId: string | null;
      ruta: { responsableUsuarioId: string };
    },
    usuario: AuthenticatedUser,
  ) {
    if (this.puedeVerDatosOrganizacion(usuario)) {
      return;
    }

    if (
      credito.creadoPorUsuarioId !== usuario.usuarioId &&
      credito.ruta.responsableUsuarioId !== usuario.usuarioId
    ) {
      throw new ForbiddenException('No tienes acceso a este credito');
    }
  }

  private asegurarResponsableRuta(
    responsableUsuarioId: string,
    usuario: AuthenticatedUser,
  ) {
    if (
      this.esAdministrador(usuario) ||
      responsableUsuarioId === usuario.usuarioId
    ) {
      return;
    }

    throw new ForbiddenException('No tienes acceso a esta ruta');
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

  private asegurarAdministrador(usuario: AuthenticatedUser) {
    if (this.esAdministrador(usuario)) {
      return;
    }

    throw new ForbiddenException(
      'Solo el administrador puede hacer esta accion',
    );
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

  private puedeVerDatosOrganizacion(usuario: AuthenticatedUser) {
    return this.esAdministrador(usuario) || usuario.roles.includes('AUDITOR');
  }

  private esAdministrador(usuario: AuthenticatedUser) {
    return usuario.roles.includes('ADMINISTRADOR');
  }

  private esIdPagoCaja(id: string) {
    return id.startsWith('pago-');
  }

  private idPagoDesdeMovimientoCaja(id: string) {
    return id.replace(/^pago-/, '');
  }

  private async actualizarPagoComoMovimientoCaja(
    pagoId: string,
    dto: ActualizarMovimientoCajaDto,
    usuario: AuthenticatedUser,
  ) {
    if (dto.tipoMovimientoCodigo !== 'RECAUDO') {
      throw DomainError.conflict(
        'Los pagos deben conservar el tipo Recaudo',
        'PAGO_TIPO_NO_EDITABLE',
      );
    }

    const fechaPago = this.parsearFecha(dto.fechaMovimiento, 'fechaMovimiento');
    const montoPagado = this.redondear(dto.monto);
    const observacion = this.requerirTexto(
      dto.motivo,
      'El motivo del movimiento es obligatorio',
    );

    await this.prisma.$transaction(
      async (tx) => {
        const pago = await tx.pago.findUnique({
          where: { pagoId },
          include: {
            ruta: true,
            cliente: true,
            medioPago: true,
            aplicaciones: {
              include: {
                creditoCuota: {
                  include: { planPago: { include: { credito: true } } },
                },
              },
            },
          },
        });

        if (!pago) {
          throw DomainError.notFound(
            'Pago no encontrado',
            'PAGO_NO_ENCONTRADO',
          );
        }

        const caja = await tx.cajaMenor.findUnique({
          where: { cajaMenorId: dto.cajaMenorId },
        });

        if (!caja) {
          throw DomainError.notFound(
            'Caja menor no encontrada',
            'CAJA_MENOR_NO_ENCONTRADA',
          );
        }

        if (
          caja.responsableUsuarioId !== pago.ruta.responsableUsuarioId ||
          caja.monedaCodigo !== pago.monedaCodigo
        ) {
          throw DomainError.conflict(
            'El pago pertenece a otra caja menor',
            'PAGO_CAJA_NO_EDITABLE',
          );
        }

        const creditoIds = [
          ...new Set(
            pago.aplicaciones.map(
              (aplicacion) =>
                aplicacion.creditoCuota.planPago.credito.creditoId,
            ),
          ),
        ];

        if (creditoIds.length !== 1) {
          throw DomainError.conflict(
            'No se puede modificar un pago sin credito asociado',
            'PAGO_CREDITO_NO_EDITABLE',
          );
        }

        const creditoId = creditoIds[0];
        await this.asegurarPresupuestoDespuesDeCambioEntradaCaja(
          tx,
          caja.cajaMenorId,
          this.decimalANumero(pago.totalPagado),
          montoPagado,
        );

        await tx.pagoAplicacion.deleteMany({ where: { pagoId } });
        await this.recalcularEstadosCreditos(tx, creditoIds);

        await tx.pago.update({
          where: { pagoId },
          data: {
            fechaPago,
            totalPagado: this.decimal(montoPagado),
            observacion,
            cobradorUsuarioId: usuario.usuarioId,
          },
        });

        await this.crearAplicacionesPagoParaCredito(tx, {
          pagoId,
          creditoId,
          montoPagado,
        });
        await this.recalcularEstadosCreditos(tx, [creditoId]);

        await this.registrarAuditoriaMovimientoCaja(tx, {
          cajaMenorId: caja.cajaMenorId,
          cajaMenorMovimientoId: null,
          usuarioId: usuario.usuarioId,
          accion: 'MODIFICAR',
          detalle: `Se modifico pago de ${pago.cliente.nombreCompleto}`,
        });

        await this.registrarAuditoria(tx, {
          usuarioId: usuario.usuarioId,
          tabla: 'pago',
          registroId: pagoId,
          accion: 'MODIFICAR',
          descripcion: `Se modifico pago de ${pago.cliente.nombreCompleto}`,
          valoresAnteriores: {
            fechaPago: pago.fechaPago.toISOString(),
            totalPagado: this.decimalANumero(pago.totalPagado),
            observacion: pago.observacion,
          },
          valoresNuevos: {
            fechaPago: fechaPago.toISOString(),
            totalPagado: montoPagado,
            observacion,
          },
        });
      },
      { maxWait: 10_000, timeout: 20_000 },
    );

    return this.obtenerMovimientoPagoCaja(pagoId, usuario);
  }

  private async eliminarPagoComoMovimientoCaja(
    pagoId: string,
    usuario: AuthenticatedUser,
  ) {
    await this.prisma.$transaction(
      async (tx) => {
        const pago = await tx.pago.findUnique({
          where: { pagoId },
          include: {
            ruta: true,
            cliente: true,
            aplicaciones: {
              include: {
                creditoCuota: {
                  include: { planPago: { include: { credito: true } } },
                },
              },
            },
          },
        });

        if (!pago) {
          throw DomainError.notFound(
            'Pago no encontrado',
            'PAGO_NO_ENCONTRADO',
          );
        }

        const creditoIds = [
          ...new Set(
            pago.aplicaciones.map(
              (aplicacion) =>
                aplicacion.creditoCuota.planPago.credito.creditoId,
            ),
          ),
        ];
        const caja = await tx.cajaMenor.findFirst({
          where: {
            responsableUsuarioId: pago.ruta.responsableUsuarioId,
            monedaCodigo: pago.monedaCodigo,
            activa: true,
          },
          orderBy: [{ fechaApertura: 'desc' }, { creadaEn: 'desc' }],
        });

        if (caja) {
          await this.asegurarPresupuestoDespuesDeCambioEntradaCaja(
            tx,
            caja.cajaMenorId,
            this.decimalANumero(pago.totalPagado),
          );
        }

        await tx.pago.delete({ where: { pagoId } });
        await this.recalcularEstadosCreditos(tx, creditoIds);

        if (caja) {
          await this.registrarAuditoriaMovimientoCaja(tx, {
            cajaMenorId: caja.cajaMenorId,
            cajaMenorMovimientoId: null,
            usuarioId: usuario.usuarioId,
            accion: 'ELIMINAR',
            detalle: `Se elimino pago de ${pago.cliente.nombreCompleto}`,
          });
        }

        await this.registrarAuditoria(tx, {
          usuarioId: usuario.usuarioId,
          tabla: 'pago',
          registroId: pagoId,
          accion: 'ELIMINAR',
          descripcion: `Se elimino pago de ${pago.cliente.nombreCompleto}`,
          valoresAnteriores: {
            fechaPago: pago.fechaPago.toISOString(),
            totalPagado: this.decimalANumero(pago.totalPagado),
            observacion: pago.observacion,
          },
        });
      },
      { maxWait: 10_000, timeout: 20_000 },
    );
  }

  private async obtenerMovimientoPagoCaja(
    pagoId: string,
    usuario: AuthenticatedUser,
  ) {
    const pago = await this.prisma.pago.findUnique({
      where: { pagoId },
      include: {
        cliente: {
          include: { documentos: { include: { tipoDocumento: true } } },
        },
        cobrador: true,
        medioPago: true,
        ruta: true,
      },
    });

    if (!pago) {
      throw DomainError.notFound('Pago no encontrado', 'PAGO_NO_ENCONTRADO');
    }

    const tipoRecaudo = await this.prisma.tipoMovimientoCaja.findUnique({
      where: { codigo: 'RECAUDO' },
    });
    const cajas = await this.cajasParaPagos(
      [
        {
          responsableUsuarioId: pago.ruta.responsableUsuarioId,
          monedaCodigo: pago.monedaCodigo,
        },
      ],
      null,
    );
    const caja = cajas.get(
      this.claveCajaPago(pago.ruta.responsableUsuarioId, pago.monedaCodigo),
    );
    const monto = this.decimalANumero(pago.totalPagado);

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      this.asegurarResponsableRuta(pago.ruta.responsableUsuarioId, usuario);
    }

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
      fechaMovimiento: pago.fechaPago.toISOString(),
      monto,
      montoConNaturaleza: monto,
      motivo:
        pago.observacion ?? `Pago del usuario ${pago.cliente.nombreCompleto}`,
      referenciaTabla: 'pago',
      referenciaId: pago.pagoId,
      creadoEn: pago.creadoEn.toISOString(),
    };
  }

  private async crearAplicacionesPagoParaCredito(
    tx: Prisma.TransactionClient,
    input: { pagoId: string; creditoId: string; montoPagado: number },
  ) {
    const cuotas = await tx.creditoCuota.findMany({
      where: {
        planPago: { creditoId: input.creditoId },
        estadoCuota: { codigo: { not: 'ANULADA' } },
      },
      include: {
        estadoCuota: true,
        planPago: {
          include: {
            credito: {
              include: {
                ruta: true,
                cliente: true,
              },
            },
          },
        },
      },
      orderBy: { numeroCuota: 'asc' },
    });
    const cuotaIds = cuotas.map((cuota) => cuota.creditoCuotaId);
    const sumas =
      cuotaIds.length === 0
        ? []
        : await tx.pagoAplicacion.groupBy({
            by: ['creditoCuotaId'],
            where: { creditoCuotaId: { in: cuotaIds } },
            _sum: {
              montoCapital: true,
              montoInteres: true,
              montoMora: true,
              montoDescuento: true,
            },
          });
    const sumasPorCuota = new Map<string, SumaAplicaciones>();
    for (const suma of sumas) {
      sumasPorCuota.set(suma.creditoCuotaId, { _sum: suma._sum });
    }

    const cuotasConSaldo = cuotas
      .map((cuota) => {
        const sumasCuota =
          sumasPorCuota.get(cuota.creditoCuotaId) ??
          this.sumasAplicacionesVacias();
        return {
          cuota,
          sumas: sumasCuota,
          saldo: this.saldoCuota(cuota, sumasCuota),
        };
      })
      .filter((item) => item.saldo > 0);
    const saldoCredito = this.redondear(
      cuotasConSaldo.reduce((total, item) => total + item.saldo, 0),
    );

    if (saldoCredito <= 0) {
      throw DomainError.conflict(
        'El credito ya esta pagado',
        'CREDITO_YA_PAGADO',
      );
    }

    if (this.redondear(input.montoPagado - saldoCredito) > 0) {
      throw DomainError.validation(
        'El pago supera el saldo del credito',
        'PAGO_SUPERA_SALDO_CREDITO',
      );
    }

    const aplicaciones: Prisma.PagoAplicacionCreateManyInput[] = [];
    let restante = input.montoPagado;

    for (const cuotaConSaldo of cuotasConSaldo) {
      if (restante <= 0) {
        break;
      }

      const montoCuota = this.redondear(
        Math.min(restante, cuotaConSaldo.saldo),
      );
      const distribucion = this.distribuirPagoEnCuota(
        cuotaConSaldo.cuota,
        cuotaConSaldo.sumas,
        montoCuota,
      );

      aplicaciones.push({
        pagoId: input.pagoId,
        creditoCuotaId: cuotaConSaldo.cuota.creditoCuotaId,
        montoCapital: this.decimal(distribucion.capital),
        montoInteres: this.decimal(distribucion.interes),
        montoMora: this.decimal(0),
        montoDescuento: this.decimal(0),
      });

      restante = this.redondear(restante - montoCuota);
    }

    if (aplicaciones.length > 0) {
      await tx.pagoAplicacion.createMany({ data: aplicaciones });
    }
  }

  private async recalcularEstadosCreditos(
    tx: Prisma.TransactionClient,
    creditoIds: string[],
  ) {
    const ids = [...new Set(creditoIds)];
    if (ids.length === 0) {
      return;
    }

    const [
      estadoCuotaPendiente,
      estadoCuotaPagada,
      estadoCreditoActivo,
      estadoCreditoPagado,
    ] = await Promise.all([
      tx.estadoCuota.findUnique({ where: { codigo: 'PENDIENTE' } }),
      tx.estadoCuota.findUnique({ where: { codigo: 'PAGADA' } }),
      tx.estadoCredito.findUnique({ where: { codigo: 'ACTIVO' } }),
      tx.estadoCredito.findUnique({ where: { codigo: 'PAGADO' } }),
    ]);

    if (
      !estadoCuotaPendiente ||
      !estadoCuotaPagada ||
      !estadoCreditoActivo ||
      !estadoCreditoPagado
    ) {
      throw DomainError.notFound(
        'Faltan estados base para recalcular pagos',
        'CATALOGO_PAGO_INCOMPLETO',
      );
    }

    for (const creditoId of ids) {
      const credito = await tx.credito.findUnique({
        where: { creditoId },
        include: { estadoCredito: true },
      });

      if (!credito || credito.estadoCredito.codigo === 'ANULADO') {
        continue;
      }

      const cuotas = await tx.creditoCuota.findMany({
        where: {
          planPago: { creditoId },
          estadoCuota: { codigo: { not: 'ANULADA' } },
        },
        include: { estadoCuota: true },
      });
      const cuotaIds = cuotas.map((cuota) => cuota.creditoCuotaId);
      const sumas =
        cuotaIds.length === 0
          ? []
          : await tx.pagoAplicacion.groupBy({
              by: ['creditoCuotaId'],
              where: { creditoCuotaId: { in: cuotaIds } },
              _sum: {
                montoCapital: true,
                montoInteres: true,
                montoMora: true,
                montoDescuento: true,
              },
            });
      const sumasPorCuota = new Map<string, SumaAplicaciones>();
      for (const suma of sumas) {
        sumasPorCuota.set(suma.creditoCuotaId, { _sum: suma._sum });
      }

      let cuotasPendientes = 0;
      for (const cuota of cuotas) {
        const sumasCuota =
          sumasPorCuota.get(cuota.creditoCuotaId) ??
          this.sumasAplicacionesVacias();
        const pagada = this.saldoCuota(cuota, sumasCuota) <= 0;
        const estadoCuotaId = pagada
          ? estadoCuotaPagada.estadoCuotaId
          : estadoCuotaPendiente.estadoCuotaId;

        if (!pagada) {
          cuotasPendientes += 1;
        }

        if (cuota.estadoCuotaId !== estadoCuotaId) {
          await tx.creditoCuota.update({
            where: { creditoCuotaId: cuota.creditoCuotaId },
            data: { estadoCuotaId },
          });
        }
      }

      const estadoCreditoId =
        cuotas.length > 0 && cuotasPendientes === 0
          ? estadoCreditoPagado.estadoCreditoId
          : estadoCreditoActivo.estadoCreditoId;

      if (credito.estadoCreditoId !== estadoCreditoId) {
        await tx.credito.update({
          where: { creditoId },
          data: { estadoCreditoId },
        });
      }
    }
  }

  private async obtenerCreditoEditableDesdeDesembolso(
    tx: Prisma.TransactionClient,
    creditoId: string,
  ) {
    const pagosAplicados = await tx.pagoAplicacion.count({
      where: { creditoCuota: { planPago: { creditoId } } },
    });

    if (pagosAplicados > 0) {
      throw DomainError.conflict(
        'No se puede modificar un desembolso con pagos registrados',
        'DESEMBOLSO_CON_PAGOS_NO_EDITABLE',
      );
    }

    const credito = await tx.credito.findUnique({
      where: { creditoId },
      include: {
        moneda: true,
        frecuenciaPago: true,
        ruta: true,
        planPago: true,
      },
    });

    if (!credito || !credito.planPago) {
      throw DomainError.notFound(
        'Credito no encontrado',
        'CREDITO_NO_ENCONTRADO',
      );
    }

    return credito;
  }

  private async sincronizarCreditoDesdeMovimientoDesembolso(
    tx: Prisma.TransactionClient,
    credito: Awaited<
      ReturnType<CobrosService['obtenerCreditoEditableDesdeDesembolso']>
    >,
    creditoDesembolsoId: string,
    movimiento: MovimientoCajaConRelaciones,
  ) {
    const valorPrincipal = this.decimalANumero(movimiento.monto);
    const plan = this.calcularPlan({
      fechaInicio: movimiento.fechaMovimiento,
      valorPrincipal,
      porcentajeInteres: this.decimalANumero(credito.porcentajeInteres),
      plazoDias: credito.plazoDias,
      diasIntervalo: credito.frecuenciaPago.diasIntervalo,
      omitirDomingos: credito.omitirDomingos,
      decimales: credito.moneda.decimales,
    });
    const estadoPendiente = await tx.estadoCuota.findUnique({
      where: { codigo: 'PENDIENTE' },
    });

    if (!estadoPendiente) {
      throw DomainError.notFound(
        'Falta el estado de cuota PENDIENTE',
        'ESTADO_CUOTA_PENDIENTE_NO_EXISTE',
      );
    }

    await tx.creditoDesembolso.update({
      where: { creditoDesembolsoId },
      data: {
        cajaMenorMovimientoId: movimiento.cajaMenorMovimientoId,
        fechaDesembolso: movimiento.fechaMovimiento,
        monto: movimiento.monto,
      },
    });

    await tx.credito.update({
      where: { creditoId: credito.creditoId },
      data: {
        fechaInicio: movimiento.fechaMovimiento,
        valorPrincipal: movimiento.monto,
      },
    });

    await tx.creditoCuota.deleteMany({
      where: { creditoPlanPagoId: credito.planPago!.creditoPlanPagoId },
    });

    await tx.creditoPlanPago.update({
      where: { creditoPlanPagoId: credito.planPago!.creditoPlanPagoId },
      data: {
        numeroCuotas: plan.numeroCuotas,
        valorCuota: this.decimal(plan.valorCuota),
        valorTotal: this.decimal(plan.valorTotal),
        fechaMaxima: plan.fechaMaxima,
        domingosOmitidos: plan.domingosOmitidos,
      },
    });

    await tx.creditoCuota.createMany({
      data: plan.cuotas.map((cuota) => ({
        creditoPlanPagoId: credito.planPago!.creditoPlanPagoId,
        estadoCuotaId: estadoPendiente.estadoCuotaId,
        numeroCuota: cuota.numeroCuota,
        fechaVencimiento: cuota.fechaVencimiento,
        valorCapital: this.decimal(cuota.valorCapital),
        valorInteres: this.decimal(cuota.valorInteres),
      })),
    });
  }

  private async eliminarCreditoDesdeMovimientoDesembolso(
    tx: Prisma.TransactionClient,
    movimiento: MovimientoCajaConRelaciones,
    creditoId: string,
    usuario: AuthenticatedUser,
  ) {
    const credito = await tx.credito.findUnique({
      where: { creditoId },
      include: { cliente: true, desembolso: true },
    });

    if (!credito || !credito.desembolso) {
      throw DomainError.notFound(
        'Credito no encontrado',
        'CREDITO_NO_ENCONTRADO',
      );
    }

    const pagosAplicados = await tx.pagoAplicacion.count({
      where: { creditoCuota: { planPago: { creditoId } } },
    });

    if (pagosAplicados > 0) {
      throw DomainError.conflict(
        'No se puede eliminar un desembolso con pagos registrados',
        'DESEMBOLSO_CON_PAGOS_NO_ELIMINABLE',
      );
    }

    await this.registrarAuditoriaMovimientoCaja(tx, {
      cajaMenorId: movimiento.cajaMenorId,
      cajaMenorMovimientoId: movimiento.cajaMenorMovimientoId,
      usuarioId: usuario.usuarioId,
      accion: 'ELIMINAR',
      detalle: this.detalleMovimientoCajaEliminado(movimiento),
    });

    await this.registrarAuditoria(tx, {
      usuarioId: usuario.usuarioId,
      tabla: 'credito',
      registroId: creditoId,
      accion: 'ELIMINAR',
      descripcion: `Se elimino credito de ${credito.cliente.nombreCompleto}`,
      valoresAnteriores: {
        clienteId: credito.clienteId,
        fechaInicio: this.fechaIso(credito.fechaInicio),
        valorPrincipal: this.decimalANumero(credito.valorPrincipal),
        porcentajeInteres: this.decimalANumero(credito.porcentajeInteres),
        plazoDias: credito.plazoDias,
      },
    });

    await tx.creditoDesembolso.delete({
      where: { creditoDesembolsoId: credito.desembolso.creditoDesembolsoId },
    });
    await tx.credito.delete({ where: { creditoId } });
    await tx.cajaMenorMovimiento.delete({
      where: { cajaMenorMovimientoId: movimiento.cajaMenorMovimientoId },
    });
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

  private async asegurarPresupuestoDespuesDeCambioEntradaCaja(
    tx: Prisma.TransactionClient,
    cajaMenorId: string,
    montoActual: number,
    montoSiguiente = 0,
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
    const presupuesto = this.decimalANumero(presupuestoRows[0]?.presupuesto);

    if (presupuesto - montoActual + montoSiguiente < -0.004) {
      throw DomainError.conflict(
        'La modificacion deja la caja menor sin presupuesto disponible',
        'CAJA_MENOR_SALDO_INSUFICIENTE',
      );
    }
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

  private formatearMontoAuditoria(monto: number) {
    return monto.toLocaleString('es-CO', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
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

  private formatearCreditoListado(row: CreditoListadoRow) {
    return {
      id: row.credito_id,
      creditoId: row.credito_id,
      clienteId: row.cliente_id,
      cliente: row.cliente,
      cedula: row.cedula,
      negocio: row.negocio,
      direccion: row.direccion,
      rutaId: row.ruta_id,
      ruta: row.ruta,
      cajaMenorId: row.caja_menor_id,
      cajaMenor: row.caja_menor,
      monedaCodigo: row.moneda_codigo,
      frecuenciaPago: {
        id: Number(row.frecuencia_pago_id),
        codigo: row.frecuencia_codigo,
        nombre: row.frecuencia_nombre,
        diasIntervalo: Number(row.dias_intervalo),
      },
      estado: {
        codigo: row.estado_codigo,
        nombre: row.estado_nombre,
      },
      fechaInicio: this.fechaIso(row.fecha_inicio),
      valorPrincipal: this.decimalANumero(row.valor_principal),
      porcentajeInteres: this.decimalANumero(row.porcentaje_interes),
      plazoDias: Number(row.plazo_dias),
      omitirDomingos: Boolean(row.omitir_domingos),
      valorTotal: this.decimalANumero(row.valor_total),
      valorCuota: this.decimalANumero(row.valor_cuota),
      totalAbonado: this.decimalANumero(row.total_abonado),
      saldo: this.decimalANumero(row.saldo),
      numeroCuotas: Number(row.numero_cuotas),
      cuotasRestantes: Number(row.cuotas_restantes),
      fechaMaxima: this.fechaIso(row.fecha_maxima),
      refinanciacion:
        row.refinanciado_en &&
        row.valor_principal_anterior &&
        row.valor_principal_refinanciado
          ? {
              fecha: row.refinanciado_en.toISOString(),
              valorAnterior: this.decimalANumero(row.valor_principal_anterior),
              valorNuevo: this.decimalANumero(row.valor_principal_refinanciado),
            }
          : null,
      observacion: row.observacion,
      creadoEn: row.creado_en.toISOString(),
      actualizadoEn: row.actualizado_en.toISOString(),
    };
  }

  private formatearCliente(cliente: ClienteConRelaciones) {
    const contactoPrincipal = (codigo: string) =>
      cliente.contactos.find(
        (contacto) =>
          contacto.tipoContacto.codigo === codigo && contacto.esPrincipal,
      ) ??
      cliente.contactos.find(
        (contacto) => contacto.tipoContacto.codigo === codigo,
      );
    const documentoPrincipal = (codigo: string) =>
      cliente.documentos.find(
        (documento) => documento.tipoDocumento.codigo === codigo,
      );
    const direccionPrincipal =
      cliente.direcciones.find((direccion) => direccion.esPrincipal) ??
      cliente.direcciones[0];

    return {
      id: cliente.clienteId,
      nombreCompleto: cliente.nombreCompleto,
      nombreComercial: cliente.nombreComercial,
      notas: cliente.notas,
      cedula: documentoPrincipal('CC')?.numeroDocumento ?? null,
      direccion: direccionPrincipal?.direccion ?? null,
      correo: contactoPrincipal('CORREO')?.valor ?? null,
      telefono: contactoPrincipal('TELEFONO')?.valor ?? null,
      whatsapp: contactoPrincipal('WHATSAPP')?.valor ?? null,
      estado: {
        codigo: cliente.estadoCliente.codigo,
        nombre: cliente.estadoCliente.nombre,
      },
      documentos: cliente.documentos.map((documento) => ({
        id: documento.clienteDocumentoId,
        tipo: {
          id: documento.tipoDocumentoId,
          codigo: documento.tipoDocumento.codigo,
          nombre: documento.tipoDocumento.nombre,
        },
        numeroDocumento: documento.numeroDocumento,
        expedidoEn: documento.expedidoEn,
      })),
      direcciones: cliente.direcciones.map((direccion) => ({
        id: direccion.clienteDireccionId,
        tipo: {
          id: direccion.tipoDireccionId,
          codigo: direccion.tipoDireccion.codigo,
          nombre: direccion.tipoDireccion.nombre,
        },
        direccion: direccion.direccion,
        barrio: direccion.barrio,
        municipio: direccion.municipio,
        departamento: direccion.departamento,
        pais: direccion.pais,
        referencia: direccion.referencia,
        latitud:
          direccion.latitud === null
            ? null
            : this.decimalANumero(direccion.latitud),
        longitud:
          direccion.longitud === null
            ? null
            : this.decimalANumero(direccion.longitud),
        esPrincipal: direccion.esPrincipal,
      })),
      creadoEn: cliente.creadoEn.toISOString(),
      actualizadoEn: cliente.actualizadoEn.toISOString(),
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
      return this.motivoDesembolsoCredito(clienteNombre);
    }

    return motivo;
  }

  private motivoDesembolsoCredito(clienteNombre: string) {
    return `Desembolso de credito para ${clienteNombre}`;
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

  private normalizarTextoOpcional(value?: string | null) {
    if (value === undefined || value === null) {
      return null;
    }

    const normalized = value.trim();
    return normalized.length > 0 ? normalized : null;
  }

  private normalizarCorreo(value?: string | null) {
    return this.normalizarTextoOpcional(value)?.toLowerCase() ?? null;
  }

  private requerirTexto(value: string, message: string) {
    const normalized = value.trim();

    if (!normalized) {
      throw DomainError.validation(message);
    }

    return normalized;
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

  private sumarDias(value: Date, days: number) {
    const next = this.fechaUtc(value);
    next.setUTCDate(next.getUTCDate() + days);
    return next;
  }

  private segundosAtras(seconds: number) {
    return new Date(Date.now() - seconds * 1000);
  }

  private fechaIso(value: Date) {
    return this.fechaUtc(value).toISOString().slice(0, 10);
  }

  private fechaIsoColombia(value: Date) {
    return new Date(value.getTime() - 5 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);
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
}
