import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { InMemoryCacheService } from '../../common/cache/in-memory-cache.service';
import { DomainError } from '../../common/domain/domain-error';
import { PrismaService } from '../../common/prisma/prisma.service';
import { TenantScopeService } from '../../common/tenancy/tenant-scope.service';
import { AuthenticatedUser } from '../auth/auth.types';
import { NotificationsService } from '../notifications/notifications.service';
import { RegistrarPagoDto } from './dto';
import { PagoTblRow, SumaAplicaciones } from './creditos.types';
import { redondear } from './creditos-amortizacion.util';

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

type PagoAplicacionTblRow = {
  aplicacion_id: string;
  credito_cuota_id: string;
  numero_cuota: number;
  monto_capital: Prisma.Decimal;
  monto_interes: Prisma.Decimal;
  monto_mora: Prisma.Decimal;
  monto_descuento: Prisma.Decimal;
};

type CreditoCuotaParaPago = {
  creditoCuotaId: string;
  creditoPlanPagoId: string;
  numeroCuota: number;
  valorCapital: Prisma.Decimal;
  valorInteres: Prisma.Decimal;
  valorTotal: Prisma.Decimal;
  estadoCuota: {
    codigo: string;
    nombre: string;
  };
};

@Injectable()
export class PagosService {
  private esquemaTblDisponible?: boolean;

  constructor(
    private readonly prisma: PrismaService,
    private readonly tenantScope: TenantScopeService,
    private readonly cache: InMemoryCacheService,
    private readonly notifications: NotificationsService,
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

        const montoPagado = redondear(dto.montoPagado);
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

        const saldoCredito = redondear(
          cuotasConSaldo.reduce((total, item) => total + item.saldo, 0),
        );

        if (saldoCredito <= 0) {
          throw DomainError.conflict(
            'El credito ya esta pagado',
            'CREDITO_YA_PAGADO',
          );
        }

        if (redondear(montoPagado - saldoCredito) > 0) {
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

          const montoCuota = redondear(Math.min(restante, cuotaConSaldo.saldo));
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

          if (redondear(cuotaConSaldo.saldo - montoCuota) <= 0) {
            cuotasPagadas.push(cuotaConSaldo.cuota.creditoCuotaId);
          }

          restante = redondear(restante - montoCuota);
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
    const montoPagado = redondear(dto.montoPagado);
    const codigoMedioPago = (dto.medioPagoCodigo ?? 'EFECTIVO')
      .trim()
      .toUpperCase();
    const referenciaPago =
      this.normalizarTextoOpcional(dto.referenciaExterna) ??
      this.normalizarTextoOpcional(dto.observacion);

    const resultadoPago = await this.prisma.$transaction(
      async (tx) => {
        const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(
          usuario,
          tx,
        );
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
            const saldo = redondear(
              this.decimalANumero(item.valor) -
                this.decimalANumero(item.abonado),
            );
            return { cuota: item, saldo };
          })
          .filter((item) => item.saldo > 0);
        const saldoCredito = redondear(
          cuotasConSaldo.reduce((total, item) => total + item.saldo, 0),
        );

        if (saldoCredito <= 0) {
          throw DomainError.conflict(
            'El credito ya esta pagado',
            'CREDITO_YA_PAGADO',
          );
        }

        if (redondear(montoPagado - saldoCredito) > 0) {
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

          const montoCuota = redondear(Math.min(restante, cuotaConSaldo.saldo));
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
          restante = redondear(restante - montoCuota);
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
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);
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

  // ==========================================
  // HELPERS PRIVADOS
  // ==========================================

  private decimal(valor: number, escala = 2): Prisma.Decimal {
    return new Prisma.Decimal(redondear(valor, escala).toFixed(escala));
  }

  private decimalANumero(valor: Prisma.Decimal | null | undefined): number {
    if (valor === null || valor === undefined) return 0;
    return Number(valor);
  }

  private normalizarTextoOpcional(texto?: string | null): string | null {
    if (texto === undefined || texto === null) return null;
    const limpio = texto.trim();
    return limpio.length > 0 ? limpio : null;
  }

  private segundosAtras(segundos: number): Date {
    return new Date(Date.now() - segundos * 1000);
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
    const interes = Math.min(montoPagado, redondear(interesPendiente));
    const capital = redondear(montoPagado - interes);

    return {
      capital,
      interes: redondear(interes),
    };
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

  private nombreDesdeCodigo(codigo: string): string {
    return codigo
      .toLowerCase()
      .split('_')
      .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
      .join(' ');
  }

  // ==========================================
  // MÉTODOS DE INTEGRACIÓN CON CAJA MENOR (PAGOS SYNC)
  // ==========================================

  async actualizarPagoComoMovimientoCaja(
    pagoId: string,
    dto: {
      cajaMenorId: string;
      tipoMovimientoCodigo: string;
      fechaMovimiento: string;
      monto: number;
      motivo: string;
    },
    usuario: AuthenticatedUser,
  ) {
    if (dto.tipoMovimientoCodigo !== 'RECAUDO') {
      throw DomainError.conflict(
        'Los pagos deben conservar el tipo Recaudo',
        'PAGO_TIPO_NO_EDITABLE',
      );
    }

    const fechaPago = this.parsearFecha(dto.fechaMovimiento, 'fechaMovimiento');
    const montoPagado = redondear(dto.monto);
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

  async eliminarPagoComoMovimientoCaja(
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

    const presupuestoRows = await tx.$queryRaw<
      Array<{ presupuesto: Prisma.Decimal | null }>
    >(
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

    const cuotasConSaldo: Array<{
      cuota: CreditoCuotaParaPago;
      sumas: SumaAplicaciones;
      saldo: number;
    }> = [];

    for (const cuota of cuotas) {
      const sumasCuota =
        sumasPorCuota.get(cuota.creditoCuotaId) ??
        this.sumasAplicacionesVacias();
      const saldo = this.saldoCuota(cuota, sumasCuota);
      if (saldo > 0 && cuota.estadoCuota.codigo !== 'PAGADA') {
        cuotasConSaldo.push({ cuota, sumas: sumasCuota, saldo });
      }
    }

    const saldoCredito = redondear(
      cuotasConSaldo.reduce((total, item) => total + item.saldo, 0),
    );

    if (saldoCredito <= 0) {
      throw DomainError.conflict(
        'El credito ya esta pagado',
        'CREDITO_YA_PAGADO',
      );
    }

    if (redondear(input.montoPagado - saldoCredito) > 0) {
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

      const montoCuota = redondear(
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

      restante = redondear(restante - montoCuota);
    }

    if (aplicaciones.length > 0) {
      await tx.pagoAplicacion.createMany({ data: aplicaciones });
    }
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
    const caja = await this.prisma.cajaMenor.findFirst({
      where: {
        responsableUsuarioId: pago.ruta.responsableUsuarioId,
        monedaCodigo: pago.monedaCodigo,
        activa: true,
      },
      orderBy: [{ fechaApertura: 'desc' }, { creadaEn: 'desc' }],
    });
    const monto = this.decimalANumero(pago.totalPagado);

    if (!this.puedeVerDatosOrganizacion(usuario)) {
      this.asegurarResponsableRuta(pago.ruta.responsableUsuarioId, usuario);
    }

    return {
      id: `pago-${pago.pagoId}`,
      cajaMenorId: caja?.cajaMenorId ?? null,
      cajaMenor: caja?.nombre ?? pago.ruta.nombre,
      cliente: pago.cliente.nombreCompleto,
      clienteIdentificacion:
        pago.cliente.documentos?.[0]?.numeroDocumento ?? null,
      tipoMovimiento: {
        id: tipoRecaudo?.tipoMovimientoCajaId ?? 0,
        codigo: tipoRecaudo?.codigo ?? 'RECAUDO',
        nombre: tipoRecaudo?.nombre ?? 'Recaudo',
        naturaleza: tipoRecaudo?.naturaleza ?? 'E',
      },
      usuario: pago.cobrador
        ? {
            id: pago.cobrador.usuarioId,
            usuario: pago.cobrador.nombreUsuario,
            nombres: pago.cobrador.nombres,
            apellidos: pago.cobrador.apellidos,
            nombreCompleto: `${pago.cobrador.nombres} ${pago.cobrador.apellidos}`.trim(),
            correo: pago.cobrador.correo,
            telefono: pago.cobrador.telefono,
          }
        : null,
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

  private requerirTexto(
    valor: string | undefined | null,
    mensaje: string,
  ): string {
    const limpio = valor?.trim();
    if (!limpio) {
      throw DomainError.validation(mensaje, 'CAMPO_OBLIGATORIO');
    }
    return limpio;
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
    try {
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
          ${input.usuarioId ? Prisma.sql`${input.usuarioId}::uuid` : Prisma.sql`NULL`},
          ${input.tabla},
          ${input.registroId ? Prisma.sql`${input.registroId}::uuid` : Prisma.sql`NULL`},
          ${input.accion},
          ${input.descripcion},
          ${valoresAnteriores ? Prisma.sql`${valoresAnteriores}::jsonb` : Prisma.sql`NULL`},
          ${valoresNuevos ? Prisma.sql`${valoresNuevos}::jsonb` : Prisma.sql`NULL`},
          ${metadata ? Prisma.sql`${metadata}::jsonb` : Prisma.sql`NULL`}
        )
      `);
    } catch {
      // Ignorar si la tabla de auditoría no existe en el esquema actual
    }
  }
}
