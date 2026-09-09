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
  CuotaCreditoTblRow,
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
    return true;
  }

  // ==========================================
  // CREACIÓN DE CRÉDITOS
  // ==========================================

  async crearCredito(dto: CrearCreditoDto, usuario: AuthenticatedUser) {
    this.asegurarPermiso(usuario, 'CREAR_CREDITOS');

    const fechaInicio = this.parsearFecha(dto.fechaInicio, 'fechaInicio');
    const valorPrincipal = redondear(dto.valorPrincipal);
    const porcentajeInteres = redondear(dto.porcentajeInteres, 4);

    return this.crearCreditoTbl(
      dto,
      usuario,
      fechaInicio,
      valorPrincipal,
      porcentajeInteres,
    );
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

        const saldoDisponible = await this.obtenerSaldoDisponibleCajaTbl(
          tx,
          caja.id,
        );

        if (saldoDisponible < valorPrincipal) {
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
            fecha: new Date(),
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
              ${new Date()},
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
    const credito = await this.obtenerCreditoTbl(creditoId, usuario);
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
    return this.consultarCreditosTbl(query, usuario, limite, offset);
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
          COUNT(*) FILTER (WHERE UPPER(cu.cuo_estado::text) != 'ANULADA')::int AS numero_cuotas,
          COUNT(*) FILTER (
            WHERE UPPER(cu.cuo_estado::text) NOT IN ('PAGADA', 'ANULADA')
              AND (cu.cuo_valor - COALESCE(ac.abonado, 0)) > 0
          )::int AS cuotas_restantes,
          COALESCE(
            (
              SELECT cu2.cuo_valor
              FROM public.tbl_cuotas cu2
              WHERE cu2.cre_id = cu.cre_id
                AND UPPER(cu2.cuo_estado::text) != 'ANULADA'
              ORDER BY cu2.cuo_numero DESC
              LIMIT 1
            ),
            MAX(cu.cuo_valor),
            0
          ) AS valor_cuota
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
    return this.contarCreditosPorEstadoTbl(query, usuario);
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
    return this.obtenerCreditoTbl(creditoId, usuario);
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
        COUNT(cu.id_cuo) FILTER (WHERE UPPER(cu.cuo_estado::text) != 'ANULADA')::int AS numero_cuotas,
        COALESCE(
          (
            SELECT cu2.cuo_valor
            FROM public.tbl_cuotas cu2
            WHERE cu2.cre_id = cr.id_cre
              AND UPPER(cu2.cuo_estado::text) != 'ANULADA'
            ORDER BY cu2.cuo_numero DESC
            LIMIT 1
          ),
          0
        ) AS valor_cuota,
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
    return this.listarCuotasCreditoTbl(creditoId, usuario);
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
    return this.actualizarCreditoTbl(
      creditoId,
      dto,
      usuario,
      fechaInicio,
      valorPrincipal,
      porcentajeInteres,
    );
  }

  async eliminarCredito(creditoId: string, usuario: AuthenticatedUser) {
    this.asegurarPermiso(usuario, 'ELIMINAR_CREDITOS');
    return this.eliminarCreditoTbl(creditoId, usuario);
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

    return this.refinanciarCreditoTbl(
      creditoId,
      dto,
      usuario,
      fechaInicio,
      valorNuevo,
      porcentajeInteres,
    );
  }

  private async refinanciarCreditoTbl(
    creditoId: string,
    dto: RefinanciarCreditoDto,
    usuario: AuthenticatedUser,
    fechaInicio: Date,
    valorNuevo: number,
    porcentajeInteres: number,
  ) {
    const creditoRefinanciadoId = await this.prisma.$transaction(
      async (tx) => {
        const orgScope = await this.tenantScope.obtenerScopeOrganizacionTbl(
          usuario,
          tx,
        );
        const scope = {
          usuario_id: orgScope.usuarioId,
          org_id: orgScope.organizacionId,
        };

        const [credito] = await tx.$queryRaw<
          Array<{
            id: string;
            cliente_id: string;
            valor_principal: Prisma.Decimal;
            tasa_interes: Prisma.Decimal;
            total_pagar: Prisma.Decimal;
            estado: string;
            mon_id: string;
            usu_id: string;
            pcr_id: string;
            moneda_codigo: string;
            decimales: number | bigint;
            org_id: string;
            cliente_nombre: string;
            ruta_id: string | null;
          }>
        >(Prisma.sql`
          SELECT
            cr.id_cre::text AS id,
            cr.cli_id::text AS cliente_id,
            cr.cre_total AS valor_principal,
            cr.cre_tasa_interes AS tasa_interes,
            cr.cre_total_pagar AS total_pagar,
            UPPER(cr.cre_estado::text) AS estado,
            cr.mon_id::text AS mon_id,
            cr.usu_id::text AS usu_id,
            cr.pcr_id::text AS pcr_id,
            mon.mon_codigo::text AS moneda_codigo,
            mon.mon_decimales AS decimales,
            cl.org_id::text AS org_id,
            TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS cliente_nombre,
            ruta_credito.ruta_id::text AS ruta_id
          FROM public.tbl_creditos cr
          JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
          JOIN public.tbl_personas p ON p.id_per = cl.cli_persona
          JOIN public.tbl_monedas mon ON mon.id_mon = cr.mon_id
          LEFT JOIN LATERAL (
            SELECT r.id_rut AS ruta_id
            FROM public.tbl_rutas_clientes rc
            JOIN public.tbl_rutas r ON r.id_rut = rc.rut_id
            WHERE rc.cli_id = cl.id_cli
              AND r.org_id = cl.org_id
            ORDER BY (r.usu_id = cr.usu_id) DESC, r.rut_activa DESC
            LIMIT 1
          ) ruta_credito ON TRUE
          WHERE cr.id_cre = ${creditoId}::uuid
            AND cl.org_id = ${scope.org_id}::uuid
          FOR UPDATE OF cr
        `);

        if (!credito) {
          throw DomainError.notFound(
            'Credito no encontrado',
            'CREDITO_NO_ENCONTRADO',
          );
        }

        if (['PAGADO', 'ANULADO'].includes(credito.estado)) {
          throw DomainError.conflict(
            'Solo se pueden refinanciar creditos activos',
            'CREDITO_NO_ACTIVO',
          );
        }

        if (
          dto.monedaCodigo &&
          dto.monedaCodigo.trim().toUpperCase() !== credito.moneda_codigo
        ) {
          throw DomainError.conflict(
            'La refinanciacion debe conservar la moneda del credito',
            'CREDITO_MONEDA_NO_EDITABLE',
          );
        }

        const valorAnterior = this.decimalANumero(credito.valor_principal);
        if (valorNuevo <= valorAnterior) {
          throw DomainError.validation(
            'El nuevo valor debe ser mayor al valor actual del credito',
            'REFINANCIACION_VALOR_INVALIDO',
          );
        }

        const decimales = Number(credito.decimales ?? 2);
        const incremento = redondear(valorNuevo - valorAnterior, decimales);

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
            AND c.org_id = ${credito.org_id}::uuid
            AND c.mon_id = ${credito.mon_id}::uuid
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

        const saldoDisponible = await this.obtenerSaldoDisponibleCajaTbl(
          tx,
          caja.id,
        );

        if (saldoDisponible < incremento) {
          throw DomainError.conflict(
            'No se puede refinanciar credito sin saldo suficiente en caja menor',
            'CAJA_MENOR_SALDO_INSUFICIENTE',
          );
        }

        const rutaId = await this.obtenerOCrearRutaCreditoTbl(
          tx,
          dto.rutaId ?? credito.ruta_id ?? undefined,
          credito.org_id,
          scope.usuario_id,
          usuario.usuario,
        );

        const cuotasExistentes = await tx.$queryRaw<
          Array<{
            id: string;
            numero: number | bigint;
            valor: Prisma.Decimal;
            total_pagado: Prisma.Decimal;
            estado: string;
          }>
        >(Prisma.sql`
          SELECT
            cu.id_cuo::text AS id,
            cu.cuo_numero::int AS numero,
            cu.cuo_valor AS valor,
            cu.cuo_total_pagado AS total_pagado,
            UPPER(cu.cuo_estado::text) AS estado
          FROM public.tbl_cuotas cu
          WHERE cu.cre_id = ${creditoId}::uuid
          ORDER BY cu.cuo_numero ASC
        `);

        const [abonosRow] = await tx.$queryRaw<
          Array<{ capital_abonado: Prisma.Decimal; interes_abonado: Prisma.Decimal }>
        >(Prisma.sql`
          SELECT
            COALESCE(SUM(cp.cpa_capital), 0) AS capital_abonado,
            COALESCE(SUM(cp.cpa_interes), 0) AS interes_abonado
          FROM public.tbl_cuotas cu
          JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
          WHERE cu.cre_id = ${creditoId}::uuid
        `);

        let capitalAbonado = this.decimalANumero(abonosRow?.capital_abonado);
        let interesAbonado = this.decimalANumero(abonosRow?.interes_abonado);

        const totalAbonado = cuotasExistentes.reduce(
          (acc, c) => acc + this.decimalANumero(c.total_pagado),
          0,
        );

        if (capitalAbonado === 0 && interesAbonado === 0 && totalAbonado > 0) {
          capitalAbonado = totalAbonado;
        }

        const ultimoNumeroCuota = cuotasExistentes.reduce(
          (max, c) => Math.max(max, Number(c.numero)),
          0,
        );

        const totalNuevo = redondear(
          valorNuevo + valorNuevo * (porcentajeInteres / 100),
          decimales,
        );
        const interesNuevo = redondear(totalNuevo - valorNuevo, decimales);
        const capitalPendiente = redondear(
          Math.max(0, valorNuevo - capitalAbonado),
          decimales,
        );
        const interesPendiente = redondear(
          Math.max(0, interesNuevo - interesAbonado),
          decimales,
        );

        const planPendiente = calcularPlanPendiente({
          fechaInicio,
          valorCapital: capitalPendiente,
          valorInteres: interesPendiente,
          plazoDias: dto.plazoDias,
          diasIntervalo: Number(producto.dias_intervalo),
          omitirDomingos: dto.omitirDomingos ?? true,
          decimales,
        });

        // Marcar cuotas pendientes anteriores como ANULADA
        await tx.$executeRaw(Prisma.sql`
          UPDATE public.tbl_cuotas
          SET cuo_estado = 'ANULADA'::public.cuota_estado_enum
          WHERE cre_id = ${creditoId}::uuid
            AND UPPER(cuo_estado::text) != 'PAGADA'
            AND cuo_total_pagado < cuo_valor
        `);

        // Insertar nuevas cuotas del plan refinanciado
        for (let i = 0; i < planPendiente.cuotas.length; i++) {
          const cuota = planPendiente.cuotas[i];
          await tx.$executeRaw(Prisma.sql`
            INSERT INTO public.tbl_cuotas (
              cuo_numero,
              cuo_valor,
              cuo_total_pagado,
              cuo_estado,
              cuo_fecha_vencimiento,
              cre_id
            )
            VALUES (
              ${ultimoNumeroCuota + i + 1},
              ${this.decimal(cuota.valorCapital + cuota.valorInteres, decimales)},
              0,
              'PENDIENTE'::public.cuota_estado_enum,
              ${cuota.fechaVencimiento}::date,
              ${creditoId}::uuid
            )
          `);
        }

        // Actualizar datos del crédito en tbl_creditos
        await tx.$executeRaw(Prisma.sql`
          UPDATE public.tbl_creditos
          SET
            cre_total = ${this.decimal(valorNuevo, decimales)},
            cre_tasa_interes = ${this.decimal(porcentajeInteres, 4)},
            cre_interes_total = ${this.decimal(interesNuevo, decimales)},
            cre_total_pagar = ${this.decimal(totalNuevo, decimales)},
            cre_fecha_inicio = ${fechaInicio}::date,
            cre_fecha_fin = ${planPendiente.fechaMaxima}::date,
            pcr_id = ${producto.id}::uuid,
            cre_estado = 'ACTIVO'::public.credito_estado_enum
          WHERE id_cre = ${creditoId}::uuid
        `);

        // Asegurar asignación a ruta
        await tx.$executeRaw(Prisma.sql`
          INSERT INTO public.tbl_rutas_clientes (rut_id, cli_id)
          VALUES (${rutaId}::uuid, ${credito.cliente_id}::uuid)
          ON CONFLICT (rut_id, cli_id) DO UPDATE
          SET rcl_activo = TRUE
        `);

        // Obtener o abrir sesión de caja menor
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

        // Registrar movimiento de desembolso por el incremento en caja menor
        if (this.cajaMenorService) {
          await this.cajaMenorService.registrarMovimientoDesembolsoTbl(tx, {
            monto: incremento,
            creditoId,
            fecha: new Date(),
            organizacionId: credito.org_id,
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
              ${this.decimal(incremento, decimales)},
              ${creditoId}::uuid,
              'CREDITO'::public.movimiento_referencia_tipo_enum,
              ${new Date()},
              ${credito.org_id}::uuid,
              ${scope.usuario_id}::uuid,
              ${sesionId}::uuid
            )
          `);
          await tx.$executeRaw(Prisma.sql`
            UPDATE public.tbl_sesiones_cajas
            SET sca_total_gasto = sca_total_gasto + ${this.decimal(incremento, decimales)}
            WHERE id_sca = ${sesionId}::uuid
          `);
        }

        return creditoId;
      },
      { maxWait: 10_000, timeout: 20_000 },
    );

    this.invalidarCacheLecturas();
    return this.obtenerCreditoTbl(creditoRefinanciadoId, usuario);
  }

  private async actualizarCreditoTbl(
    creditoId: string,
    dto: ActualizarCreditoDto,
    usuario: AuthenticatedUser,
    fechaInicio: Date,
    valorPrincipal: number,
    porcentajeInteres: number,
  ) {
    const creditoActualizadoId = await this.prisma.$transaction(
      async (tx) => {
        const orgScope = await this.tenantScope.obtenerScopeOrganizacionTbl(
          usuario,
          tx,
        );
        const scope = {
          usuario_id: orgScope.usuarioId,
          org_id: orgScope.organizacionId,
        };

        const [credito] = await tx.$queryRaw<
          Array<{
            id: string;
            cli_id: string;
            mon_id: string;
            org_id: string;
            valor_principal: Prisma.Decimal;
          }>
        >(Prisma.sql`
          SELECT
            cr.id_cre::text AS id,
            cr.cli_id::text AS cli_id,
            cr.mon_id::text AS mon_id,
            cl.org_id::text AS org_id,
            cr.cre_total AS valor_principal
          FROM public.tbl_creditos cr
          JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
          WHERE cr.id_cre = ${creditoId}::uuid
            AND cl.org_id = ${scope.org_id}::uuid
          FOR UPDATE OF cr
        `);

        if (!credito) {
          throw DomainError.notFound(
            'Credito no encontrado',
            'CREDITO_NO_ENCONTRADO',
          );
        }

        const [pagos] = await tx.$queryRaw<Array<{ count: number | bigint }>>(
          Prisma.sql`
            SELECT COUNT(cp.id_cpa) AS count
            FROM public.tbl_cuotas cu
            JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
            WHERE cu.cre_id = ${creditoId}::uuid
          `,
        );

        if (Number(pagos?.count ?? 0) > 0) {
          throw DomainError.conflict(
            'No se puede modificar un credito con pagos registrados',
            'CREDITO_CON_PAGOS_NO_MODIFICABLE',
          );
        }

        const [cliente] = await tx.$queryRaw<
          Array<{ id: string; org_id: string }>
        >(Prisma.sql`
          SELECT c.id_cli::text AS id, c.org_id::text AS org_id
          FROM public.tbl_clientes c
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
          Array<{ id: string; decimales: number | bigint }>
        >(Prisma.sql`
          SELECT id_mon::text AS id, mon_decimales AS decimales
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

        const rutaId = await this.obtenerOCrearRutaCreditoTbl(
          tx,
          dto.rutaId,
          cliente.org_id,
          scope.usuario_id,
          usuario.usuario,
        );

        const decimales = Number(moneda.decimales);
        const plan = calcularPlan({
          fechaInicio,
          valorPrincipal,
          porcentajeInteres,
          plazoDias: dto.plazoDias,
          diasIntervalo: Number(producto.dias_intervalo),
          omitirDomingos: dto.omitirDomingos ?? true,
          decimales,
        });
        const interesTotal = redondear(
          plan.valorTotal - valorPrincipal,
          decimales,
        );

        await tx.$executeRaw(Prisma.sql`
          UPDATE public.tbl_creditos
          SET
            cre_total = ${this.decimal(valorPrincipal, decimales)},
            cre_tasa_interes = ${this.decimal(porcentajeInteres, 4)},
            cre_interes_total = ${this.decimal(interesTotal, decimales)},
            cre_total_pagar = ${this.decimal(plan.valorTotal, decimales)},
            cre_fecha_inicio = ${fechaInicio}::date,
            cre_fecha_fin = ${plan.fechaMaxima}::date,
            cli_id = ${cliente.id}::uuid,
            pcr_id = ${producto.id}::uuid,
            mon_id = ${moneda.id}::uuid
          WHERE id_cre = ${creditoId}::uuid
        `);

        await tx.$executeRaw(Prisma.sql`
          DELETE FROM public.tbl_cuotas
          WHERE cre_id = ${creditoId}::uuid
        `);

        for (const cuota of plan.cuotas) {
          await tx.$executeRaw(Prisma.sql`
            INSERT INTO public.tbl_cuotas (
              cuo_numero,
              cuo_valor,
              cuo_total_pagado,
              cuo_estado,
              cuo_fecha_vencimiento,
              cre_id
            )
            VALUES (
              ${cuota.numeroCuota},
              ${this.decimal(cuota.valorCapital + cuota.valorInteres, decimales)},
              0,
              'PENDIENTE'::public.cuota_estado_enum,
              ${cuota.fechaVencimiento}::date,
              ${creditoId}::uuid
            )
          `);
        }

        await tx.$executeRaw(Prisma.sql`
          INSERT INTO public.tbl_rutas_clientes (rut_id, cli_id)
          VALUES (${rutaId}::uuid, ${cliente.id}::uuid)
          ON CONFLICT (rut_id, cli_id) DO UPDATE
          SET rcl_activo = TRUE
        `);

        const [movimiento] = await tx.$queryRaw<
          Array<{ id: string; monto: Prisma.Decimal; sca_id: string | null }>
        >(Prisma.sql`
          SELECT id_mca::text AS id, mca_monto AS monto, sca_id::text AS sca_id
          FROM public.tbl_movimientos_cajas
          WHERE mca_referencia_id = ${creditoId}::uuid
            AND mca_referencia_tipo::text = 'CREDITO'
            AND mca_tipo::text = 'DESEMBOLSO_CREDITO'
          ORDER BY mca_creacion ASC
          LIMIT 1
        `);

        if (movimiento) {
          const montoAnterior = this.decimalANumero(movimiento.monto);
          const diferencia = redondear(valorPrincipal - montoAnterior, decimales);
          await tx.$executeRaw(Prisma.sql`
            UPDATE public.tbl_movimientos_cajas
            SET mca_monto = ${this.decimal(valorPrincipal, decimales)}
            WHERE id_mca = ${movimiento.id}::uuid
          `);
          if (movimiento.sca_id && Math.abs(diferencia) > 0) {
            await tx.$executeRaw(Prisma.sql`
              UPDATE public.tbl_sesiones_cajas
              SET sca_total_gasto = GREATEST(sca_total_gasto + ${this.decimal(diferencia, decimales)}, 0)
              WHERE id_sca = ${movimiento.sca_id}::uuid
            `);
          }
        }

        return creditoId;
      },
      { maxWait: 10_000, timeout: 20_000 },
    );

    this.invalidarCacheLecturas();
    return this.obtenerCreditoTbl(creditoActualizadoId, usuario);
  }

  private async eliminarCreditoTbl(
    creditoId: string,
    usuario: AuthenticatedUser,
  ) {
    await this.prisma.$transaction(
      async (tx) => {
        const orgScope = await this.tenantScope.obtenerScopeOrganizacionTbl(
          usuario,
          tx,
        );

        const [credito] = await tx.$queryRaw<
          Array<{ id: string; org_id: string }>
        >(Prisma.sql`
          SELECT cr.id_cre::text AS id, cl.org_id::text AS org_id
          FROM public.tbl_creditos cr
          JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
          WHERE cr.id_cre = ${creditoId}::uuid
            AND cl.org_id = ${orgScope.organizacionId}::uuid
          FOR UPDATE OF cr
        `);

        if (!credito) {
          throw DomainError.notFound(
            'Credito no encontrado',
            'CREDITO_NO_ENCONTRADO',
          );
        }

        const [pagos] = await tx.$queryRaw<Array<{ count: number | bigint }>>(
          Prisma.sql`
            SELECT COUNT(cp.id_cpa) AS count
            FROM public.tbl_cuotas cu
            JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
            WHERE cu.cre_id = ${creditoId}::uuid
          `,
        );

        if (Number(pagos?.count ?? 0) > 0) {
          throw DomainError.conflict(
            'No se puede eliminar un credito con pagos registrados',
            'CREDITO_CON_PAGOS_NO_ELIMINABLE',
          );
        }

        const movimientos = await tx.$queryRaw<
          Array<{ id: string; monto: Prisma.Decimal; sca_id: string | null }>
        >(Prisma.sql`
          SELECT
            id_mca::text AS id,
            mca_monto AS monto,
            sca_id::text AS sca_id
          FROM public.tbl_movimientos_cajas
          WHERE mca_referencia_id = ${creditoId}::uuid
            AND mca_referencia_tipo::text = 'CREDITO'
        `);

        for (const mov of movimientos) {
          if (mov.sca_id) {
            await tx.$executeRaw(Prisma.sql`
              UPDATE public.tbl_sesiones_cajas
              SET sca_total_gasto = GREATEST(sca_total_gasto - ${mov.monto}, 0)
              WHERE id_sca = ${mov.sca_id}::uuid
            `);
          }
          await tx.$executeRaw(Prisma.sql`
            DELETE FROM public.tbl_movimientos_cajas
            WHERE id_mca = ${mov.id}::uuid
          `);
        }

        await tx.$executeRaw(Prisma.sql`
          DELETE FROM public.tbl_cuotas
          WHERE cre_id = ${creditoId}::uuid
        `);

        await tx.$executeRaw(Prisma.sql`
          DELETE FROM public.tbl_creditos
          WHERE id_cre = ${creditoId}::uuid
        `);
      },
      { maxWait: 10_000, timeout: 20_000 },
    );

    this.invalidarCacheLecturas();
    return { ok: true };
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

  private async obtenerSaldoDisponibleCajaTbl(
    tx: PrismaExecutor,
    cajaId: string,
  ): Promise<number> {
    const [presupuesto] = await tx.$queryRaw<
      Array<{
        saldo_disponible?: Prisma.Decimal | null;
        presupuesto?: Prisma.Decimal | null;
      }>
    >(
      Prisma.sql`
        WITH movimientos AS (
          SELECT mc.mca_tipo, mc.mca_monto
          FROM public.tbl_movimientos_cajas mc
          JOIN public.tbl_sesiones_cajas sc ON sc.id_sca = mc.sca_id
          WHERE sc.caj_id = ${cajaId}::uuid
        ),
        sesiones AS (
          SELECT COALESCE(SUM(sc.sca_monto_inicial), 0) AS inicial
          FROM public.tbl_sesiones_cajas sc
          WHERE sc.caj_id = ${cajaId}::uuid
        )
        SELECT
          (
            (SELECT inicial FROM sesiones)
            + COALESCE(
                SUM(
                  CASE
                    WHEN UPPER(m.mca_tipo::text) IN ('APERTURA', 'RECAUDO', 'AJUSTE_ENTRADA') THEN m.mca_monto
                    WHEN UPPER(m.mca_tipo::text) IN ('GASTO', 'DESEMBOLSO_CREDITO', 'AJUSTE_SALIDA') THEN -m.mca_monto
                    ELSE 0
                  END
                ),
                0
              )
          ) AS saldo_disponible
        FROM movimientos m
      `,
    );

    return this.decimalANumero(
      presupuesto?.saldo_disponible ?? presupuesto?.presupuesto ?? null,
    );
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

  private nombreDesdeCodigo(codigo: string): string {
    return codigo
      .toLowerCase()
      .split('_')
      .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
      .join(' ');
  }
}
