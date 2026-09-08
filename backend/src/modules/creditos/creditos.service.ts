import {
  ForbiddenException,
  Injectable,
  Inject,
  Optional,
  forwardRef,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Workbook } from 'exceljs';

import { InMemoryCacheService } from '../../common/cache/in-memory-cache.service';
import { cacheKeyFromCriteria } from '../../common/cache/cache-key';
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
import { NotificationsService } from '../notifications/notifications.service';
import { CajaMenorService } from '../caja-menor/caja-menor.service';
import {
  ActualizarCreditoDto,
  CrearCreditoDto,
  ListarCreditosQueryDto,
  RefinanciarCreditoDto,
} from './dto';
import {
  CreditoExportado,
  CreditoListadoRow,
  CreditoTblRow,
  CuotaCreditoRow,
  CuotaCreditoTblRow,
  SumaAplicaciones,
} from './creditos.types';
import {
  calcularPlan,
  calcularPlanPendiente,
  fechaUtc,
  redondear,
} from './creditos-amortizacion.util';

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@Injectable()
export class CreditosService {
  private esquemaTblDisponible?: boolean;

  constructor(
    private readonly prisma: PrismaService,
    private readonly tenantScope: TenantScopeService,
    private readonly cache: InMemoryCacheService,
    private readonly exportaciones: ExportacionesService,
    private readonly notifications: NotificationsService,
    @Optional()
    @Inject(forwardRef(() => CajaMenorService))
    private readonly cajaMenorService?: CajaMenorService,
  ) {}

  esIdTbl(id: string): boolean {
    return uuidPattern.test(id.trim());
  }

  async usarEsquemaTbl(): Promise<boolean> {
    if (this.esquemaTblDisponible !== undefined) {
      return this.esquemaTblDisponible;
    }

    try {
      const rows = await this.prisma.$queryRaw<Array<{ existe: boolean }>>(
        Prisma.sql`
          SELECT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name = 'tbl_creditos'
          ) AS existe
        `,
      );
      this.esquemaTblDisponible = Boolean(rows[0]?.existe);
      return this.esquemaTblDisponible;
    } catch {
      this.esquemaTblDisponible = false;
      return false;
    }
  }

  // ==========================================
  // CREACIÓN DE CRÉDITOS
  // ==========================================

  async crearCredito(dto: CrearCreditoDto, usuario: AuthenticatedUser) {
    this.asegurarPermiso(usuario, 'CREAR_CREDITOS');

    const fechaInicio = this.parsearFecha(dto.fechaInicio, 'fechaInicio');
    const valorPrincipal = redondear(dto.valorPrincipal);
    const porcentajeInteres = redondear(dto.porcentajeInteres, 4);

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

      const plan = calcularPlan({
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
        const orgScope = await this.tenantScope.obtenerScopeOrganizacionTbl(
          usuario,
          tx,
        );
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

        const plan = calcularPlan({
          fechaInicio,
          valorPrincipal,
          porcentajeInteres,
          plazoDias: dto.plazoDias,
          diasIntervalo: Number(producto.dias_intervalo),
          omitirDomingos: dto.omitirDomingos ?? true,
          decimales: Number(moneda.decimales),
        });
        const interesTotal = redondear(
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

        if (this.cajaMenorService) {
          await this.cajaMenorService.registrarMovimientoDesembolsoTbl(tx, {
            monto: valorPrincipal,
            creditoId: credito.id,
            fecha: fechaInicio,
            organizacionId: cliente.org_id,
            usuarioId: scope.usuario_id,
            sesionId,
          });
        } else {
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
        }

        return credito.id;
      },
      { maxWait: 10_000, timeout: 20_000 },
    );

    this.invalidarCacheLecturas();
    const credito = await this.obtenerCredito(creditoId, usuario);
    void this.notifications.notifyCreditApproved(creditoId);
    return credito;
  }

  // ==========================================
  // LISTADO Y RESUMEN DE CRÉDITOS
  // ==========================================

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

  async consultarCreditos(
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
        JOIN public.pago_aplicacion pa ON pa.credito_cuota_id = cc.credito_cuota_id
        GROUP BY cc.credito_cuota_id
      ),
      resumen_credito AS (
        SELECT
          cpp.credito_id,
          COALESCE(SUM(ac.abonado), 0) AS total_abonado,
          COUNT(*)::int AS numero_cuotas,
          COUNT(*) FILTER (
            WHERE ec.codigo NOT IN ('PAGADA', 'ANULADA')
              AND (cc.valor_total - COALESCE(ac.abonado, 0)) > 0
          )::int AS cuotas_restantes,
          COALESCE(MAX(cc.valor_total), 0) AS valor_cuota
        FROM public.credito_cuota cc
        JOIN public.credito_plan_pago cpp ON cpp.credito_plan_pago_id = cc.credito_plan_pago_id
        JOIN public.estado_cuota ec ON ec.estado_cuota_id = cc.estado_cuota_id
        LEFT JOIN abonos_cuota ac ON ac.credito_cuota_id = cc.credito_cuota_id
        GROUP BY cpp.credito_id
      ),
      pagos_credito AS (
        SELECT
          cpp.credito_id,
          MAX((p.fecha_pago AT TIME ZONE 'America/Bogota')::date) AS fecha_ultimo_pago
        FROM public.pago p
        JOIN public.pago_aplicacion pa ON pa.pago_id = p.pago_id
        JOIN public.credito_cuota cc ON cc.credito_cuota_id = pa.credito_cuota_id
        JOIN public.credito_plan_pago cpp ON cpp.credito_plan_pago_id = cc.credito_plan_pago_id
        GROUP BY cpp.credito_id
      ),
      documento_principal AS (
        SELECT DISTINCT ON (cliente_id)
          cliente_id,
          numero_documento
        FROM public.cliente_documento
        ORDER BY cliente_id, (tipo_documento_id = 1) DESC, cliente_documento_id ASC
      ),
      direccion_principal AS (
        SELECT DISTINCT ON (cliente_id)
          cliente_id,
          direccion
        FROM public.cliente_direccion
        ORDER BY cliente_id, es_principal DESC, cliente_direccion_id ASC
      )
      SELECT
        c.credito_id,
        cl.cliente_id,
        cl.nombre_completo AS cliente,
        doc.numero_documento AS cedula,
        cl.nombre_comercial AS negocio,
        dir.direccion AS direccion,
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
        COALESCE(cpp.valor_total, 0) AS valor_total,
        COALESCE(rc.valor_cuota, cpp.valor_cuota, 0) AS valor_cuota,
        COALESCE(rc.total_abonado, 0) AS total_abonado,
        GREATEST(COALESCE(cpp.valor_total, 0) - COALESCE(rc.total_abonado, 0), 0) AS saldo,
        COALESCE(rc.numero_cuotas, cpp.numero_cuotas, 0) AS numero_cuotas,
        COALESCE(rc.cuotas_restantes, cpp.numero_cuotas, 0) AS cuotas_restantes,
        c.fecha_inicio,
        COALESCE(cpp.fecha_maxima, c.fecha_inicio) AS fecha_maxima,
        c.refinanciado_en,
        c.valor_principal_anterior,
        c.valor_principal_refinanciado,
        c.observacion,
        c.creado_en,
        c.actualizado_en
      FROM public.credito c
      JOIN public.cliente cl ON cl.cliente_id = c.cliente_id
      JOIN public.ruta r ON r.ruta_id = c.ruta_id
      JOIN public.frecuencia_pago fp ON fp.frecuencia_pago_id = c.frecuencia_pago_id
      JOIN public.estado_credito ecr ON ecr.estado_credito_id = c.estado_credito_id
      LEFT JOIN public.credito_plan_pago cpp ON cpp.credito_id = c.credito_id
      LEFT JOIN resumen_credito rc ON rc.credito_id = c.credito_id
      LEFT JOIN pagos_credito pc ON pc.credito_id = c.credito_id
      LEFT JOIN documento_principal doc ON doc.cliente_id = cl.cliente_id
      LEFT JOIN direccion_principal dir ON dir.cliente_id = cl.cliente_id
      LEFT JOIN public.credito_desembolso cd ON cd.credito_id = c.credito_id
      LEFT JOIN public.caja_menor_movimiento cmm ON cmm.caja_menor_movimiento_id = cd.caja_menor_movimiento_id
      LEFT JOIN public.caja_menor cm ON cm.caja_menor_id = cmm.caja_menor_id
      WHERE ${Prisma.join(conditions, ' AND ')}
      ORDER BY c.fecha_inicio DESC, c.credito_id DESC
      ${limite ? Prisma.sql`LIMIT ${limite}` : Prisma.empty}
      ${offset > 0 ? Prisma.sql`OFFSET ${offset}` : Prisma.empty}
    `);

    return rows.map((row) => this.formatearCreditoListado(row));
  }

  private async consultarCreditosTbl(
    query: ListarCreditosQueryDto,
    usuario: AuthenticatedUser,
    limite?: number,
    offset = 0,
  ) {
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);
    const search = this.normalizarTextoOpcional(query.search);
    const estado = query.estado ?? 'todos';
    const conditions: Prisma.Sql[] = [
      Prisma.sql`cl.org_id = ${scope.organizacionId}::uuid`,
    ];

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      conditions.push(Prisma.sql`tu.id_usu = ${scope.usuarioId}::uuid`);
    }

    if (query.rutaId) {
      conditions.push(Prisma.sql`ruta_credito.ruta_id = ${query.rutaId}::uuid`);
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
        diasIntervalo: Number(
          this.diasIntervaloFrecuencia(row.frecuencia_codigo),
        ),
      },
    }));
  }

  private async contarCreditosPorEstado(
    query: ListarCreditosQueryDto,
    usuario: AuthenticatedUser,
  ) {
    if (await this.usarEsquemaTbl()) {
      return this.contarCreditosPorEstadoTbl(query, usuario);
    }

    const conditions: Prisma.Sql[] = [Prisma.sql`1 = 1`];
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

    return this.prisma.$queryRaw<
      Array<{ total: number; activos: number; inactivos: number }>
    >(Prisma.sql`
      WITH pagos_credito AS (
        SELECT
          cpp.credito_id,
          MAX((p.fecha_pago AT TIME ZONE 'America/Bogota')::date) AS fecha_ultimo_pago
        FROM public.pago p
        JOIN public.pago_aplicacion pa ON pa.pago_id = p.pago_id
        JOIN public.credito_cuota cc ON cc.credito_cuota_id = pa.credito_cuota_id
        JOIN public.credito_plan_pago cpp ON cpp.credito_plan_pago_id = cc.credito_plan_pago_id
        GROUP BY cpp.credito_id
      )
      SELECT
        COUNT(*)::int AS total,
        COUNT(*) FILTER (WHERE ecr.codigo = 'ACTIVO')::int AS activos,
        COUNT(*) FILTER (WHERE ecr.codigo = 'PAGADO')::int AS inactivos
      FROM public.credito c
      JOIN public.cliente cl ON cl.cliente_id = c.cliente_id
      JOIN public.ruta r ON r.ruta_id = c.ruta_id
      JOIN public.estado_credito ecr ON ecr.estado_credito_id = c.estado_credito_id
      LEFT JOIN pagos_credito pc ON pc.credito_id = c.credito_id
      LEFT JOIN public.credito_desembolso cd ON cd.credito_id = c.credito_id
      LEFT JOIN public.caja_menor_movimiento cmm ON cmm.caja_menor_movimiento_id = cd.caja_menor_movimiento_id
      LEFT JOIN public.caja_menor cm ON cm.caja_menor_id = cmm.caja_menor_id
      WHERE ${Prisma.join(conditions, ' AND ')}
    `);
  }

  private async contarCreditosPorEstadoTbl(
    query: ListarCreditosQueryDto,
    usuario: AuthenticatedUser,
  ) {
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);
    const search = this.normalizarTextoOpcional(query.search);
    const conditions: Prisma.Sql[] = [
      Prisma.sql`cl.org_id = ${scope.organizacionId}::uuid`,
    ];
    const fechaConditions: Prisma.Sql[] = [Prisma.sql`1 = 1`];

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      conditions.push(Prisma.sql`tu.id_usu = ${scope.usuarioId}::uuid`);
    }

    if (query.rutaId) {
      conditions.push(Prisma.sql`ruta_credito.ruta_id = ${query.rutaId}::uuid`);
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

    return this.prisma.$queryRaw<
      Array<{ total: number; activos: number; inactivos: number }>
    >(Prisma.sql`
      WITH pagos_credito AS (
        SELECT
          cu.cre_id,
          MAX((pa.pag_fecha AT TIME ZONE 'America/Bogota')::date) AS fecha_ultimo_pago
        FROM public.tbl_pagos pa
        JOIN public.tbl_cuotas_pagos cp ON cp.pagos_id = pa.id_pag
        JOIN public.tbl_cuotas cu ON cu.id_cuo = cp.cuo_id
        GROUP BY cu.cre_id
      ),
      creditos_base AS (
        SELECT
          UPPER(cr.cre_estado::text) AS estado_codigo,
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
      )
      SELECT
        COUNT(*)::int AS total,
        COUNT(*) FILTER (WHERE estado_codigo = 'ACTIVO')::int AS activos,
        COUNT(*) FILTER (WHERE estado_codigo = 'PAGADO')::int AS inactivos
      FROM creditos_base
      WHERE ${Prisma.join(fechaConditions, ' AND ')}
    `);
  }

  // ==========================================
  // DETALLE Y CUOTAS DE CRÉDITO
  // ==========================================

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
      saldo: redondear(Math.max(valorTotal - totalAbonado, 0)),
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
              fecha: this.fechaIso(credito.refinanciadoEn),
              valorAnterior: this.decimalANumero(
                credito.valorPrincipalAnterior,
              ),
              valorNuevo: this.decimalANumero(
                credito.valorPrincipalRefinanciado,
              ),
            }
          : null,
      creadoEn: this.fechaIso(credito.creadoEn),
      actualizadoEn: this.fechaIso(credito.actualizadoEn),
    };
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
        (fechaUtc(credito.fecha_fin).getTime() -
          fechaUtc(credito.fecha_inicio).getTime()) /
          86_400_000,
      ),
    );
    const valorTotal = this.decimalANumero(credito.valor_total);
    const totalAbonado = this.decimalANumero(credito.total_abonado);
    const saldo = redondear(Math.max(valorTotal - totalAbonado, 0));

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
      monedaCodigo: credito.moneda_codigo,
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
      valorTotal,
      valorCuota: this.decimalANumero(credito.valor_cuota),
      totalAbonado,
      saldo,
      numeroCuotas: Number(credito.numero_cuotas),
      cuotasRestantes: Number(credito.cuotas_restantes),
      fechaMaxima: this.fechaIso(credito.fecha_fin),
      observacion: null,
      refinanciacion: null,
      creadoEn: this.fechaIso(credito.fecha_inicio),
      actualizadoEn: this.fechaIso(credito.fecha_inicio),
    };
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

  // ==========================================
  // ACTUALIZACIÓN, ELIMINACIÓN Y REFINANCIACIÓN
  // ==========================================

  async actualizarCredito(
    creditoId: string,
    dto: ActualizarCreditoDto,
    usuario: AuthenticatedUser,
  ) {
    this.asegurarPermiso(usuario, 'MODIFICAR_CREDITOS');

    const fechaInicio = this.parsearFecha(dto.fechaInicio, 'fechaInicio');
    const valorPrincipal = redondear(dto.valorPrincipal);
    const porcentajeInteres = redondear(dto.porcentajeInteres, 4);

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
        const valorPrincipalActual = redondear(
          this.decimalANumero(credito.valorPrincipal),
        );
        const cambiaValorPrincipal = valorPrincipalActual !== valorPrincipal;
        const cambiaCondicionesFinancieras =
          moneda.codigoMoneda !== credito.monedaCodigo ||
          frecuenciaPago.frecuenciaPagoId !== credito.frecuenciaPagoId ||
          this.fechaIso(fechaInicio) !== this.fechaIso(credito.fechaInicio) ||
          cambiaValorPrincipal ||
          redondear(this.decimalANumero(credito.porcentajeInteres), 4) !==
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
          : calcularPlan({
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
              motivo: `Desembolso de credito para ${cliente.nombreCompleto}`,
              referenciaTabla: 'credito_desembolso',
              referenciaId: creditoId,
            },
          });
          cajaMenorMovimientoId = movimientoActualizado.cajaMenorMovimientoId;
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
              motivo: `Desembolso de credito para ${cliente.nombreCompleto}`,
              referenciaTabla: 'credito_desembolso',
              referenciaId: creditoId,
            },
          });
          cajaMenorMovimientoId = movimientoCreado.cajaMenorMovimientoId;
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
        } else if (cajaMenorMovimientoId) {
          await tx.creditoDesembolso.create({
            data: {
              creditoId,
              cajaMenorMovimientoId,
              fechaDesembolso: fechaInicio,
              monto: this.decimal(valorPrincipal),
            },
          });
        }

        await tx.credito.update({
          where: { creditoId },
          data: {
            clienteId: cliente.clienteId,
            rutaId: ruta.rutaId,
            monedaCodigo: moneda.codigoMoneda,
            frecuenciaPagoId: frecuenciaPago.frecuenciaPagoId,
            fechaInicio,
            valorPrincipal: this.decimal(valorPrincipal),
            porcentajeInteres: this.decimal(porcentajeInteres, 4),
            plazoDias: dto.plazoDias,
            omitirDomingos,
            observacion: this.normalizarTextoOpcional(dto.observacion),
          },
        });

        if (plan) {
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

          await tx.creditoCuota.deleteMany({
            where: {
              creditoPlanPagoId: credito.planPago.creditoPlanPagoId,
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

        await this.asegurarClienteEnRuta(tx, ruta.rutaId, cliente.clienteId);
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
                cajaMenorMovimiento: true,
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
    const valorNuevo = redondear(dto.valorPrincipal);
    const porcentajeInteres = redondear(dto.porcentajeInteres, 4);

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

        const incremento = redondear(
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
        const totalNuevo = redondear(
          valorNuevo + valorNuevo * (porcentajeInteres / 100),
          credito.moneda.decimales,
        );
        const interesNuevo = redondear(
          totalNuevo - valorNuevo,
          credito.moneda.decimales,
        );
        const capitalPendiente = redondear(
          Math.max(0, valorNuevo - capitalAbonado),
          credito.moneda.decimales,
        );
        const interesPendiente = redondear(
          Math.max(0, interesNuevo - interesAbonado),
          credito.moneda.decimales,
        );
        const planPendiente = calcularPlanPendiente({
          fechaInicio,
          valorCapital: capitalPendiente,
          valorInteres: interesPendiente,
          plazoDias: dto.plazoDias,
          diasIntervalo: frecuenciaPago.diasIntervalo,
          omitirDomingos: dto.omitirDomingos ?? credito.omitirDomingos,
          decimales: credito.moneda.decimales,
        });

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

        return creditoId;
      },
      { maxWait: 10_000, timeout: 20_000 },
    );

    this.invalidarCacheLecturas();
    return this.obtenerCredito(creditoRefinanciadoId, usuario);
  }

  // ==========================================
  // EXPORTACIÓN EXCEL
  // ==========================================

  async exportarCreditos(
    query: ListarCreditosQueryDto,
    usuario: AuthenticatedUser,
  ): Promise<ExportacionExcel> {
    const creditos = (await this.consultarCreditos(
      query,
      usuario,
      maxExportRows + 1,
    )) as CreditoExportado[];

    this.exportaciones.asegurarTamanoExportacion(creditos.length);

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

    this.exportaciones.formatearHojaExportacion(sheet, [
      'valorPrincipal',
      'valorTotal',
      'valorCuota',
      'totalAbonado',
      'saldo',
    ]);

    return this.exportaciones.subirWorkbookExportacion({
      workbook,
      carpeta: 'creditos',
      nombreBase: 'creditos',
      filas: creditos.length,
      vistaPrevia: this.exportaciones.crearVistaPreviaExportacion(
        columnas,
        filasExcel,
      ),
    });
  }

  // ==========================================
  // MÉTODOS DE INTEGRACIÓN CON CAJA MENOR (DISBURSEMENT SYNC)
  // ==========================================

  async obtenerCreditoEditableDesdeDesembolso(
    tx: Prisma.TransactionClient,
    creditoId: string,
  ) {
    const credito = await tx.credito.findUnique({
      where: { creditoId },
      include: {
        ruta: true,
        moneda: true,
        frecuenciaPago: true,
        planPago: true,
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
        'No se puede modificar un desembolso con pagos registrados',
        'DESEMBOLSO_CON_PAGOS_NO_EDITABLE',
      );
    }

    return credito;
  }

  async sincronizarCreditoDesdeMovimientoDesembolso(
    tx: Prisma.TransactionClient,
    credito: Awaited<
      ReturnType<CreditosService['obtenerCreditoEditableDesdeDesembolso']>
    >,
    creditoDesembolsoId: string,
    movimiento: {
      cajaMenorMovimientoId: string;
      fechaMovimiento: Date;
      monto: Prisma.Decimal;
    },
  ) {
    const valorPrincipal = this.decimalANumero(movimiento.monto);
    const plan = calcularPlan({
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

  async eliminarCreditoDesdeMovimientoDesembolso(
    tx: Prisma.TransactionClient,
    _movimiento: unknown,
    creditoId: string,
    _usuario?: AuthenticatedUser,
  ) {
    void _movimiento;
    void _usuario;
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

    await tx.creditoDesembolso.delete({
      where: {
        creditoDesembolsoId: credito.desembolso.creditoDesembolsoId,
      },
    });

    await tx.credito.delete({ where: { creditoId } });
  }

  // ==========================================
  // HELPERS PRIVADOS DE LÓGICA Y SEGURIDAD
  // ==========================================

  private decimal(valor: number, escala = 2): Prisma.Decimal {
    return new Prisma.Decimal(redondear(valor, escala).toFixed(escala));
  }

  private decimalANumero(valor: Prisma.Decimal | null | undefined): number {
    if (valor === null || valor === undefined) return 0;
    return Number(valor);
  }

  private parsearFecha(valor: string, campo: string): Date {
    const parsed = new Date(valor);
    if (Number.isNaN(parsed.getTime())) {
      throw DomainError.validation(
        `La fecha enviada en ${campo} no es valida`,
        'FECHA_INVALIDA',
      );
    }
    return parsed;
  }

  private fechaIso(fecha: Date): string {
    return fecha.toISOString();
  }

  private normalizarTextoOpcional(texto?: string | null): string | null {
    if (texto === undefined || texto === null) return null;
    const limpio = texto.trim();
    return limpio.length > 0 ? limpio : null;
  }

  private hayPaginacion(query: { limit?: number; offset?: number }) {
    return query.limit !== undefined || query.offset !== undefined;
  }

  private limitePagina(query: { limit?: number }, defecto = 40, maximo = 100) {
    const raw = query.limit !== undefined ? Number(query.limit) : defecto;
    if (Number.isNaN(raw) || raw < 1) return defecto;
    return Math.min(raw, maximo);
  }

  private offsetPagina(query: { offset?: number }) {
    const raw = query.offset !== undefined ? Number(query.offset) : 0;
    if (Number.isNaN(raw) || raw < 0) return 0;
    return raw;
  }

  private paginaRespuesta<T>(items: T[], limit: number, offset: number) {
    const hasMore = items.length > limit;
    const rows = hasMore ? items.slice(0, limit) : items;
    return {
      items: rows,
      total: offset + rows.length + (hasMore ? 1 : 0),
      limit,
      offset,
      hasMore,
    };
  }

  private usuarioCacheKey(usuario: AuthenticatedUser) {
    const roles = [...usuario.roles].sort().join(':');
    return `${usuario.organizacionId}:${usuario.usuarioId}:${roles}`;
  }

  private invalidarCacheLecturas() {
    this.cache.clear();
  }

  private asegurarPermiso(usuario: AuthenticatedUser, permiso: string) {
    if (this.esAdministrador(usuario)) return;
    if (!usuario.permisos.includes(permiso)) {
      throw new ForbiddenException(
        `No tienes permiso para realizar esta accion (${permiso})`,
      );
    }
  }

  private esAdministrador(usuario: AuthenticatedUser): boolean {
    return (
      usuario.roles.includes('ADMIN') ||
      usuario.roles.includes('SUPERADMIN') ||
      usuario.roles.includes('ADMINISTRADOR')
    );
  }

  private puedeVerDatosOrganizacion(usuario: AuthenticatedUser): boolean {
    return (
      this.esAdministrador(usuario) ||
      usuario.roles.includes('AUDITOR') ||
      usuario.roles.includes('SUPERVISOR')
    );
  }

  private asegurarResponsableRuta(
    responsableUsuarioId: string,
    usuario: AuthenticatedUser,
  ) {
    if (this.esAdministrador(usuario)) return;
    if (responsableUsuarioId !== usuario.usuarioId) {
      throw new ForbiddenException(
        'No puedes gestionar operaciones sobre rutas de otro usuario',
      );
    }
  }

  private asegurarAccesoCredito(
    credito: {
      creadoPorUsuarioId?: string | null;
      ruta?: { responsableUsuarioId: string };
    },
    usuario: AuthenticatedUser,
  ) {
    if (this.puedeVerDatosOrganizacion(usuario)) return;
    if (
      credito.creadoPorUsuarioId !== usuario.usuarioId &&
      credito.ruta?.responsableUsuarioId !== usuario.usuarioId
    ) {
      throw new ForbiddenException('No tienes acceso a este credito');
    }
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

  private async validarAccesoCreditoTbl(
    creditoId: string,
    usuario: AuthenticatedUser,
  ) {
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);
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

  private async resumenCredito(planPagoId: string) {
    const rows = await this.prisma.$queryRaw<
      Array<{ total_abonado: Prisma.Decimal; cuotas_restantes: number }>
    >(Prisma.sql`
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
        JOIN public.pago_aplicacion pa ON pa.credito_cuota_id = cc.credito_cuota_id
        WHERE cc.credito_plan_pago_id = ${planPagoId}::uuid
        GROUP BY cc.credito_cuota_id
      )
      SELECT
        COALESCE(SUM(ac.abonado), 0) AS total_abonado,
        COUNT(*) FILTER (
          WHERE ec.codigo NOT IN ('PAGADA', 'ANULADA')
            AND (cc.valor_total - COALESCE(ac.abonado, 0)) > 0
        )::int AS cuotas_restantes
      FROM public.credito_cuota cc
      JOIN public.estado_cuota ec ON ec.estado_cuota_id = cc.estado_cuota_id
      LEFT JOIN abonos_cuota ac ON ac.credito_cuota_id = cc.credito_cuota_id
      WHERE cc.credito_plan_pago_id = ${planPagoId}::uuid
    `);

    return {
      totalAbonado: this.decimalANumero(rows[0]?.total_abonado),
      cuotasRestantes: Number(rows[0]?.cuotas_restantes ?? 0),
    };
  }

  private formatearCreditoListado(row: CreditoListadoRow) {
    return {
      id: row.credito_id,
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
      observacion: row.observacion,
      refinanciacion:
        row.refinanciado_en &&
        row.valor_principal_anterior &&
        row.valor_principal_refinanciado
          ? {
              fecha: this.fechaIso(row.refinanciado_en),
              valorAnterior: this.decimalANumero(row.valor_principal_anterior),
              valorNuevo: this.decimalANumero(row.valor_principal_refinanciado),
            }
          : null,
      creadoEn: this.fechaIso(row.creado_en),
      actualizadoEn: this.fechaIso(row.actualizado_en),
    };
  }

  private diasIntervaloFrecuencia(codigo?: string): number {
    switch ((codigo ?? '').trim().toUpperCase()) {
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

  private nombreDesdeCodigo(codigo: string): string {
    return codigo
      .toLowerCase()
      .split('_')
      .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
      .join(' ');
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

  private async asegurarClienteEnRuta(
    tx: Prisma.TransactionClient,
    rutaId: string,
    clienteId: string,
  ) {
    const existente = await tx.rutaCliente.findUnique({
      where: { rutaId_clienteId: { rutaId, clienteId } },
    });

    if (existente) {
      if (!existente.activo) {
        await tx.rutaCliente.update({
          where: { rutaId_clienteId: { rutaId, clienteId } },
          data: { activo: true },
        });
      }
      return;
    }

    const ultimoOrden = await tx.rutaCliente.aggregate({
      where: { rutaId },
      _max: { ordenVisita: true },
    });
    const ordenVisita = (ultimoOrden._max.ordenVisita ?? 0) + 1;

    await tx.rutaCliente.create({
      data: {
        rutaId,
        clienteId,
        ordenVisita,
        activo: true,
      },
    });
  }

  private async registrarDesembolsoCaja(
    tx: Prisma.TransactionClient,
    dto: CrearCreditoDto,
    ruta: { responsableUsuarioId: string; nombre: string },
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
        motivo: `Desembolso de credito para ${clienteNombre}`,
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
      'No se puede refinanciar credito sin saldo suficiente en caja menor',
      'CAJA_MENOR_SALDO_INSUFICIENTE',
    );

    const movimiento = await tx.cajaMenorMovimiento.create({
      data: {
        cajaMenorId: caja.cajaMenorId,
        tipoMovimientoCajaId: tipoDesembolso.tipoMovimientoCajaId,
        usuarioId: usuario.usuarioId,
        fechaMovimiento: fechaInicio,
        monto: this.decimal(incremento),
        motivo: `Refinanciacion de credito para ${clienteNombre} (+${incremento})`,
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

    const presupuestoRows = await tx.$queryRaw<
      Array<{ presupuesto: Prisma.Decimal }>
    >(
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

  private saldoCuota(
    cuota: { valorTotal: Prisma.Decimal },
    sumas: SumaAplicaciones,
  ) {
    const totalAplicado =
      this.decimalANumero(sumas._sum.montoCapital) +
      this.decimalANumero(sumas._sum.montoInteres) +
      this.decimalANumero(sumas._sum.montoMora) -
      this.decimalANumero(sumas._sum.montoDescuento);

    return redondear(this.decimalANumero(cuota.valorTotal) - totalAplicado);
  }
}
