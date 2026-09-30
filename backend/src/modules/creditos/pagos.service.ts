import {
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  Optional,
  forwardRef,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { InMemoryCacheService } from '../../common/cache/in-memory-cache.service';
import { DomainError } from '../../common/domain/domain-error';
import { PrismaService } from '../../common/prisma/prisma.service';
import { TenantScopeService } from '../../common/tenancy/tenant-scope.service';
import { AuthenticatedUser } from '../auth/auth.types';
import { CajaMenorService } from '../caja-menor/caja-menor.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RegistrarPagoDto } from './dto';
import { PagoTblRow } from './creditos.types';
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

@Injectable()
export class PagosService {
  private readonly logger = new Logger(PagosService.name);
  private esquemaTblDisponible?: boolean;

  constructor(
    private readonly prisma: PrismaService,
    private readonly tenantScope: TenantScopeService,
    private readonly cache: InMemoryCacheService,
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

  async registrarPago(dto: RegistrarPagoDto, usuario: AuthenticatedUser) {
    this.asegurarPermiso(usuario, 'AGREGAR_CUOTA');
    return this.registrarPagoTbl(dto, usuario);
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

    const resultadoPago = await this.ejecutarTransaccionConReintentos(
      async (tx) => {
        const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(
          usuario,
          tx,
        );
        await tx.$queryRaw(Prisma.sql`
          SELECT cu.id_cuo
          FROM public.tbl_cuotas cu
          JOIN public.tbl_creditos cr ON cr.id_cre = cu.cre_id
          WHERE cu.id_cuo = ${dto.creditoCuotaId}::uuid
          FOR UPDATE OF cr
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
          ORDER BY cuo_numero ASC
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

        if (this.cajaMenorService) {
          await this.cajaMenorService.registrarMovimientoRecaudoTbl(tx, {
            monto: montoPagado,
            pagoId: pago.id,
            fecha: new Date(),
            organizacionId: cuota.org_id,
            usuarioId: scope.usuarioId,
            cobradorId: cuota.usuario_id,
          });
        } else {
          const sesiones = await tx.$queryRaw<
            Array<{ sesion_id: string; usuario_id: string }>
          >(Prisma.sql`
            SELECT
              sca.id_sca::text AS sesion_id,
              sca.usu_id::text AS usuario_id
            FROM public.tbl_sesiones_cajas sca
            JOIN public.tbl_cajas c ON c.id_caj = sca.caj_id
            WHERE c.org_id = ${cuota.org_id}::uuid
              AND c.caj_tipo::text = 'MENOR'
              AND c.caj_activa
              AND sca.sca_estado::text = 'ABIERTA'
              AND (sca.sca_fecha_cierre IS NULL OR sca.sca_fecha_cierre > now())
            ORDER BY
              CASE
                WHEN sca.usu_id = ${scope.usuarioId}::uuid THEN 0
                WHEN sca.usu_id = ${cuota.usuario_id}::uuid THEN 1
                ELSE 2
              END,
              sca.sca_fecha_apertura DESC,
              sca.id_sca DESC
            LIMIT 1
            FOR UPDATE OF sca
          `);

          const sesion = sesiones[0];
          const usuarioMov = sesion?.usuario_id ?? scope.usuarioId;
          const sesionIdSql = sesion?.sesion_id
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
              ${this.decimal(montoPagado)},
              ${pago.id}::uuid,
              'PAGO'::public.movimiento_referencia_tipo_enum,
              now(),
              ${cuota.org_id}::uuid,
              ${usuarioMov}::uuid,
              ${sesionIdSql}
            )
          `);

          if (sesion?.sesion_id) {
            await tx.$executeRaw(Prisma.sql`
              UPDATE public.tbl_sesiones_cajas
              SET sca_total_cobrado = sca_total_cobrado + ${this.decimal(montoPagado)}
              WHERE id_sca = ${sesion.sesion_id}::uuid
            `);
          }
        }

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
    return this.obtenerPagoTbl(pagoId, usuario);
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

  private async ejecutarTransaccionConReintentos<T>(
    operacion: (tx: Prisma.TransactionClient) => Promise<T>,
    opciones?: {
      maxWait?: number;
      timeout?: number;
      retries?: number;
      delayBaseMs?: number;
    },
  ): Promise<T> {
    const maxRetries = opciones?.retries ?? 3;
    const delayBaseMs = opciones?.delayBaseMs ?? 50;
    let intento = 0;

    while (true) {
      try {
        return await this.prisma.$transaction(
          async (tx) => operacion(tx),
          {
            maxWait: opciones?.maxWait ?? 10_000,
            timeout: opciones?.timeout ?? 15_000,
          },
        );
      } catch (error: unknown) {
        intento++;
        const esPrismaP2034 =
          error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === 'P2034';
        const mensaje =
          typeof (error as { message?: unknown })?.message === 'string'
            ? (error as { message: string }).message.toLowerCase()
            : '';
        const esConflictoEscrituraODeadlock =
          esPrismaP2034 ||
          mensaje.includes('write conflict') ||
          mensaje.includes('deadlock') ||
          mensaje.includes('restart transaction') ||
          mensaje.includes('could not serialize') ||
          mensaje.includes('40001') ||
          mensaje.includes('40p01');

        if (esConflictoEscrituraODeadlock && intento <= maxRetries) {
          const jitter = Math.floor(Math.random() * 40);
          const delay = delayBaseMs * Math.pow(2, intento - 1) + jitter;
          this.logger.warn(
            `Conflicto de concurrencia al registrar pago (intento ${intento}/${maxRetries}). Reintentando en ${delay}ms...`,
          );
          await new Promise((resolve) => setTimeout(resolve, delay));
          continue;
        }

        throw error;
      }
    }
  }

  private nombreDesdeCodigo(codigo: string): string {
    return codigo
      .toLowerCase()
      .split('_')
      .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
      .join(' ');
  }
}
