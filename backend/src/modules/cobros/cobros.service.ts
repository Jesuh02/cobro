import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Workbook, type Worksheet } from 'exceljs';
import { Buffer } from 'node:buffer';

import { DomainError } from '../../common/domain/domain-error';
import { PrismaService } from '../../common/prisma/prisma.service';
import { AuthenticatedUser } from '../auth/auth.types';
import { NotificationsService } from '../notifications/notifications.service';
import {
  CrearCajaMenorDto,
  CrearClienteDto,
  CrearCreditoDto,
  CrearMovimientoCajaDto,
  ExportarMovimientosCajaQueryDto,
  ListarClientesQueryDto,
  ListarCobrosRutaQueryDto,
  ListarMovimientosCajaQueryDto,
  RegistrarPagoDto,
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

type PresupuestoRow = {
  caja_menor_id: string;
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

type CobroRutaExportado = {
  cliente: string;
  cedula: string | null;
  negocio: string | null;
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

type MovimientoCajaExportado = {
  cajaMenor: string;
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

@Injectable()
export class CobrosService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly exportacionesR2: ExportacionesR2Service,
  ) {}

  async obtenerCatalogos(usuario: AuthenticatedUser) {
    const puedeVerTodo = this.esAdministrador(usuario);
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
        naturaleza: tipo.naturaleza,
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
        responsable: this.formatearUsuario(caja.responsable),
      })),
      usuarios: usuarios.map((usuario) => this.formatearUsuario(usuario)),
    };
  }

  async listarClientes(
    query: ListarClientesQueryDto,
    usuario: AuthenticatedUser,
  ) {
    const search = this.normalizarTextoOpcional(query.search);
    const where: Prisma.ClienteWhereInput = this.esAdministrador(usuario)
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
    const notas = this.normalizarTextoOpcional(dto.notas);
    const correo = this.normalizarCorreo(dto.correo);
    const telefono = this.normalizarTextoOpcional(dto.telefono);
    const whatsapp = this.normalizarTextoOpcional(dto.whatsapp);

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

  async listarRutas(usuario: AuthenticatedUser) {
    const rutas = await this.prisma.ruta.findMany({
      where: this.esAdministrador(usuario)
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
  ) {
    const conditions: Prisma.Sql[] = [
      Prisma.sql`ecr.codigo NOT IN ('PAGADO', 'ANULADO')`,
    ];
    const search = this.normalizarTextoOpcional(query.search);

    if (!this.esAdministrador(usuario)) {
      conditions.push(
        Prisma.sql`c.creado_por_usuario_id = ${usuario.usuarioId}::uuid`,
      );
    }

    if (query.rutaId) {
      conditions.push(Prisma.sql`c.ruta_id = ${query.rutaId}::uuid`);
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
        AND GREATEST(cpp.valor_total - COALESCE(rp.total_abonado, 0), 0) > 0
      ORDER BY r.nombre ASC, prox.fecha_vencimiento ASC NULLS LAST, cl.nombre_completo ASC
    `);

    return rows.map((row) => ({
      id: row.credito_id,
      creditoId: row.credito_id,
      clienteId: row.cliente_id,
      cliente: row.cliente,
      cedula: row.cedula,
      negocio: row.negocio,
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
    )) as CobroRutaExportado[];
    const workbook = new Workbook();
    workbook.creator = 'Cobro';
    workbook.created = new Date();

    const sheet = workbook.addWorksheet('Ruta activa');
    const columnas: ColumnaExportacion[] = [
      { header: 'Cliente', key: 'cliente', width: 30 },
      { header: 'Cedula', key: 'cedula', width: 18 },
      { header: 'Negocio', key: 'negocio', width: 24 },
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

  async listarCuotasCredito(creditoId: string, usuario: AuthenticatedUser) {
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
    const fechaInicio = this.parsearFecha(dto.fechaInicio, 'fechaInicio');
    const valorPrincipal = this.redondear(dto.valorPrincipal);
    const porcentajeInteres = this.redondear(dto.porcentajeInteres, 4);

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

    const credito = await this.obtenerCredito(creditoId, usuario);
    void this.notifications.notifyCreditApproved(creditoId);
    return credito;
  }

  async obtenerCredito(creditoId: string, usuario: AuthenticatedUser) {
    const credito = await this.prisma.credito.findUnique({
      where: { creditoId },
      include: {
        cliente: true,
        ruta: true,
        moneda: true,
        frecuenciaPago: true,
        estadoCredito: true,
        planPago: true,
        desembolso: true,
      },
    });

    if (!credito) {
      throw DomainError.notFound(
        'Credito no encontrado',
        'CREDITO_NO_ENCONTRADO',
      );
    }

    this.asegurarAccesoCredito(credito, usuario);

    return {
      id: credito.creditoId,
      clienteId: credito.clienteId,
      cliente: credito.cliente.nombreCompleto,
      rutaId: credito.rutaId,
      ruta: credito.ruta.nombre,
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
      observacion: credito.observacion,
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

  async registrarPago(dto: RegistrarPagoDto, usuario: AuthenticatedUser) {
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

    const pago = await this.obtenerPago(resultadoPago.pagoId, usuario);
    if (resultadoPago.creado) {
      void this.notifications.notifyPaymentReceived(resultadoPago.pagoId);
    }
    return pago;
  }

  async obtenerPago(pagoId: string, usuario: AuthenticatedUser) {
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

  async listarMovimientosCaja(
    query: ListarMovimientosCajaQueryDto,
    usuario: AuthenticatedUser,
  ) {
    const search = this.normalizarTextoOpcional(query.search);
    const where: Prisma.CajaMenorMovimientoWhereInput = {
      cajaMenorId: query.cajaMenorId,
    };

    if (!this.esAdministrador(usuario)) {
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
      ];
    }

    const cajaFiltro = query.cajaMenorId
      ? await this.prisma.cajaMenor.findUnique({
          where: { cajaMenorId: query.cajaMenorId },
        })
      : null;
    const cajaFiltroVisible =
      cajaFiltro &&
      (this.esAdministrador(usuario) ||
        cajaFiltro.responsableUsuarioId === usuario.usuarioId)
        ? cajaFiltro
        : null;
    const pagoWhere: Prisma.PagoWhereInput = {};

    if (query.cajaMenorId && !cajaFiltroVisible) {
      pagoWhere.pagoId = '00000000-0000-0000-0000-000000000000';
    } else if (cajaFiltroVisible) {
      pagoWhere.monedaCodigo = cajaFiltroVisible.monedaCodigo;
      pagoWhere.ruta = {
        responsableUsuarioId: cajaFiltroVisible.responsableUsuarioId,
      };
    } else if (!this.esAdministrador(usuario)) {
      pagoWhere.ruta = { responsableUsuarioId: usuario.usuarioId };
    }

    if (search) {
      pagoWhere.OR = [
        {
          cliente: {
            nombreCompleto: { contains: search, mode: 'insensitive' },
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

    const [movimientos, pagos, tipoRecaudo] = await Promise.all([
      this.prisma.cajaMenorMovimiento.findMany({
        where,
        include: {
          cajaMenor: true,
          tipoMovimientoCaja: true,
          usuario: true,
        },
        orderBy: [{ fechaMovimiento: 'desc' }, { creadoEn: 'desc' }],
        take: 100,
      }),
      this.prisma.pago.findMany({
        where: pagoWhere,
        include: {
          cliente: true,
          cobrador: true,
          medioPago: true,
          ruta: true,
        },
        orderBy: [{ fechaPago: 'desc' }, { creadoEn: 'desc' }],
        take: 100,
      }),
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

    const movimientosCaja = movimientos.map((movimiento) => ({
      id: movimiento.cajaMenorMovimientoId,
      cajaMenorId: movimiento.cajaMenorId,
      cajaMenor: movimiento.cajaMenor.nombre,
      tipoMovimiento: {
        id: movimiento.tipoMovimientoCajaId,
        codigo: movimiento.tipoMovimientoCaja.codigo,
        nombre: movimiento.tipoMovimientoCaja.nombre,
        naturaleza: movimiento.tipoMovimientoCaja.naturaleza,
      },
      usuario: movimiento.usuario
        ? this.formatearUsuario(movimiento.usuario)
        : null,
      fechaMovimiento: this.fechaIso(movimiento.fechaMovimiento),
      monto: this.decimalANumero(movimiento.monto),
      montoConNaturaleza:
        movimiento.tipoMovimientoCaja.naturaleza === 'S'
          ? -this.decimalANumero(movimiento.monto)
          : this.decimalANumero(movimiento.monto),
      motivo: movimiento.motivo,
      referenciaTabla: movimiento.referenciaTabla,
      referenciaId: movimiento.referenciaId,
      creadoEn: movimiento.creadoEn.toISOString(),
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
        tipoMovimiento: {
          id: tipoRecaudo?.tipoMovimientoCajaId ?? 0,
          codigo: tipoRecaudo?.codigo ?? 'RECAUDO',
          nombre: tipoRecaudo?.nombre ?? 'Recaudo',
          naturaleza: tipoRecaudo?.naturaleza ?? 'E',
        },
        usuario: pago.cobrador ? this.formatearUsuario(pago.cobrador) : null,
        fechaMovimiento: this.fechaIso(pago.fechaPago),
        monto,
        montoConNaturaleza: monto,
        motivo: `Pago del usuario ${pago.cliente.nombreCompleto}`,
        referenciaTabla: 'pago',
        referenciaId: pago.pagoId,
        creadoEn: pago.creadoEn.toISOString(),
      };
    });

    return [...movimientosCaja, ...movimientosPago]
      .sort((left, right) => {
        const fecha =
          Date.parse(right.fechaMovimiento) - Date.parse(left.fechaMovimiento);

        if (fecha !== 0) {
          return fecha;
        }

        return Date.parse(right.creadoEn) - Date.parse(left.creadoEn);
      })
      .slice(0, 100);
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
      ? this.parsearFecha(query.fechaHasta, 'fechaHasta')
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
      { header: 'Tipo', key: 'tipo', width: 20 },
      { header: 'Naturaleza', key: 'naturaleza', width: 12 },
      { header: 'Monto', key: 'monto', width: 16 },
      { header: 'Monto con naturaleza', key: 'montoConNaturaleza', width: 20 },
      { header: 'Motivo', key: 'motivo', width: 40 },
      { header: 'Usuario', key: 'usuario', width: 28 },
      { header: 'Referencia', key: 'referencia', width: 18 },
      { header: 'Creado en', key: 'creadoEn', width: 24 },
    ];
    sheet.columns = columnas;
    const filasExcel: FilaExportacion[] = filtrados.map((movimiento) => ({
      fechaMovimiento: movimiento.fechaMovimiento,
      cajaMenor: movimiento.cajaMenor,
      tipo: movimiento.tipoMovimiento.nombre,
      naturaleza:
        movimiento.tipoMovimiento.naturaleza === 'S' ? 'Salida' : 'Entrada',
      monto: movimiento.monto,
      montoConNaturaleza: movimiento.montoConNaturaleza,
      motivo: movimiento.motivo,
      usuario: movimiento.usuario?.nombreCompleto ?? '',
      referencia: movimiento.referenciaTabla ?? '',
      creadoEn: movimiento.creadoEn,
    }));
    sheet.addRows(filasExcel);

    this.formatearHojaExportacion(sheet, ['monto', 'montoConNaturaleza']);

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
    const fechaMovimiento = this.parsearFecha(
      dto.fechaMovimiento,
      'fechaMovimiento',
    );
    const monto = this.redondear(dto.monto);

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

    return {
      id: movimiento.cajaMenorMovimientoId,
      cajaMenorId: movimiento.cajaMenorId,
      cajaMenor: movimiento.cajaMenor.nombre,
      tipoMovimiento: {
        id: movimiento.tipoMovimientoCajaId,
        codigo: movimiento.tipoMovimientoCaja.codigo,
        nombre: movimiento.tipoMovimientoCaja.nombre,
        naturaleza: movimiento.tipoMovimientoCaja.naturaleza,
      },
      usuario: movimiento.usuario
        ? this.formatearUsuario(movimiento.usuario)
        : null,
      fechaMovimiento: this.fechaIso(movimiento.fechaMovimiento),
      monto: this.decimalANumero(movimiento.monto),
      montoConNaturaleza:
        movimiento.tipoMovimientoCaja.naturaleza === 'S'
          ? -this.decimalANumero(movimiento.monto)
          : this.decimalANumero(movimiento.monto),
      motivo: movimiento.motivo,
      referenciaTabla: movimiento.referenciaTabla,
      referenciaId: movimiento.referenciaId,
      creadoEn: movimiento.creadoEn.toISOString(),
    };
  }

  async crearCajaMenor(dto: CrearCajaMenorDto, usuario: AuthenticatedUser) {
    const nombre = this.requerirTexto(
      dto.nombre,
      'El nombre de la caja menor es obligatorio',
    );
    const responsableUsuarioId = usuario.usuarioId;
    const monedaCodigo = dto.monedaCodigo ?? 'COP';

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
      },
      include: { responsable: true },
    });

    return {
      id: caja.cajaMenorId,
      nombre: caja.nombre,
      activa: caja.activa,
      monedaCodigo: caja.monedaCodigo,
      responsable: this.formatearUsuario(caja.responsable),
    };
  }

  async obtenerPresupuesto(usuario: AuthenticatedUser) {
    const where = this.esAdministrador(usuario)
      ? Prisma.empty
      : Prisma.sql`WHERE responsable_usuario_id = ${usuario.usuarioId}::uuid`;
    const rows = await this.prisma.$queryRaw<PresupuestoRow[]>(Prisma.sql`
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
      ${where}
      ORDER BY moneda_codigo ASC, caja_menor_id ASC
    `);

    const items = rows.map((row) => ({
      cajaMenorId: row.caja_menor_id,
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

    await tx.$queryRaw(Prisma.sql`
      SELECT caja_menor_id
      FROM public.caja_menor
      WHERE caja_menor_id = ${caja.cajaMenorId}::uuid
      FOR UPDATE
    `);

    const presupuestoRows = await tx.$queryRaw<PresupuestoDisponibleRow[]>(
      Prisma.sql`
        SELECT presupuesto
        FROM public.vista_presupuesto_actual
        WHERE caja_menor_id = ${caja.cajaMenorId}::uuid
      `,
    );
    const presupuestoDisponible = this.decimalANumero(
      presupuestoRows[0]?.presupuesto,
    );

    if (valorPrincipal > presupuestoDisponible) {
      throw DomainError.conflict(
        'No se puede hacer credito sin caja suficiente',
        'CAJA_MENOR_SALDO_INSUFICIENTE',
      );
    }

    const movimiento = await tx.cajaMenorMovimiento.create({
      data: {
        cajaMenorId: caja.cajaMenorId,
        tipoMovimientoCajaId: tipoDesembolso.tipoMovimientoCajaId,
        usuarioId: usuario.usuarioId,
        fechaMovimiento: fechaInicio,
        monto: this.decimal(valorPrincipal),
        motivo: 'Desembolso de credito',
      },
    });

    return movimiento.cajaMenorMovimientoId;
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

  private saldoCuota(cuota: CreditoCuotaParaPago, sumas: SumaAplicaciones) {
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
    if (this.esAdministrador(usuario)) {
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
      this.esAdministrador(usuario) ||
      responsableUsuarioId === usuario.usuarioId
    ) {
      return;
    }

    throw new ForbiddenException('No tienes acceso a esta caja menor');
  }

  private esAdministrador(usuario: AuthenticatedUser) {
    return usuario.roles.includes('ADMINISTRADOR');
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

    return {
      id: cliente.clienteId,
      nombreCompleto: cliente.nombreCompleto,
      nombreComercial: cliente.nombreComercial,
      notas: cliente.notas,
      cedula: documentoPrincipal('CC')?.numeroDocumento ?? null,
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
        esPrincipal: direccion.esPrincipal,
      })),
      creadoEn: cliente.creadoEn.toISOString(),
      actualizadoEn: cliente.actualizadoEn.toISOString(),
    };
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

  private fechaUtc(value: Date) {
    return new Date(
      Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()),
    );
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
