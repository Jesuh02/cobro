import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../common/prisma/prisma.service';
import { EmailNotificationService } from './email-notification.service';
import { NotificationTemplatesService } from './notification-templates.service';
import {
  CollectorOverdueCollection,
  CustomerNotification,
  NotificationContact,
} from './notification.types';
import { WhatsappNotificationService } from './whatsapp-notification.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly templates: NotificationTemplatesService,
    private readonly email: EmailNotificationService,
    private readonly whatsapp: WhatsappNotificationService,
  ) {}

  async notifyCreditApproved(creditId: string) {
    if (!this.enabled()) {
      return;
    }

    try {
      const credit = await this.prisma.credito.findUnique({
        where: { creditoId: creditId },
        include: {
          cliente: {
            include: {
              contactos: { include: { tipoContacto: true } },
            },
          },
          planPago: {
            include: {
              cuotas: { orderBy: { numeroCuota: 'asc' }, take: 1 },
            },
          },
        },
      });

      if (!credit?.planPago) {
        throw new Error(`No se encontro el plan del credito ${creditId}`);
      }

      await this.deliver({
        kind: 'credito_aprobado',
        eventId: credit.creditoId,
        contact: this.contact(credit.cliente),
        monedaCodigo: credit.monedaCodigo,
        valorPrincipal: this.number(credit.valorPrincipal),
        valorTotal: this.number(credit.planPago.valorTotal),
        numeroCuotas: credit.planPago.numeroCuotas,
        valorCuota: this.number(credit.planPago.valorCuota),
        primeraCuota: credit.planPago.cuotas[0]?.fechaVencimiento ?? null,
      });
    } catch (error) {
      this.logUnexpected('credito aprobado', creditId, error);
    }
  }

  async notifyPaymentReceived(paymentId: string) {
    if (!this.enabled()) {
      return;
    }

    try {
      const payment = await this.prisma.pago.findUnique({
        where: { pagoId: paymentId },
        include: {
          aplicaciones: {
            include: {
              creditoCuota: {
                include: {
                  planPago: {
                    include: {
                      credito: {
                        include: {
                          estadoCredito: true,
                          cliente: {
                            include: {
                              contactos: { include: { tipoContacto: true } },
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
      });

      const credit =
        payment?.aplicaciones[0]?.creditoCuota.planPago.credito ?? null;

      if (!payment || !credit) {
        throw new Error(`No se encontro el credito del pago ${paymentId}`);
      }

      const installments = await this.prisma.creditoCuota.findMany({
        where: {
          planPago: { creditoId: credit.creditoId },
          estadoCuota: { codigo: { not: 'ANULADA' } },
        },
        include: {
          aplicaciones: true,
        },
        orderBy: { numeroCuota: 'asc' },
      });

      const pending = installments
        .map((installment) => {
          const paid = installment.aplicaciones.reduce(
            (total, application) =>
              total +
              this.number(application.montoCapital) +
              this.number(application.montoInteres) +
              this.number(application.montoMora) -
              this.number(application.montoDescuento),
            0,
          );
          return {
            installment,
            balance: this.round(this.number(installment.valorTotal) - paid),
          };
        })
        .filter((item) => item.balance > 0);
      const next = pending[0] ?? null;
      const contact = this.contact(credit.cliente);
      const paymentNotification: CustomerNotification = {
        kind: 'pago_recibido',
        eventId: payment.pagoId,
        contact,
        monedaCodigo: payment.monedaCodigo,
        montoPagado: this.number(payment.totalPagado),
        saldoPendiente: this.round(
          pending.reduce((total, item) => total + item.balance, 0),
        ),
        cuotasRestantes: pending.length,
        proximaCuotaNumero: next?.installment.numeroCuota ?? null,
        proximaCuotaValor: next?.balance ?? null,
        proximaCuotaFecha: next?.installment.fechaVencimiento ?? null,
      };

      await this.deliver(paymentNotification);

      if (credit.estadoCredito.codigo === 'PAGADO' || pending.length === 0) {
        await this.deliver({
          kind: 'credito_finalizado',
          eventId: credit.creditoId,
          contact,
          monedaCodigo: credit.monedaCodigo,
          valorPrincipal: this.number(credit.valorPrincipal),
        });
      }
    } catch (error) {
      this.logUnexpected('pago recibido', paymentId, error);
    }
  }

  async notifyCollectorOverdueCollections(collectorId: string) {
    if (!this.enabled()) {
      return;
    }

    try {
      const rows = this.isUuid(collectorId)
        ? await this.overdueCollections(collectorId)
        : await this.overdueCollectionsTbl(collectorId);

      if (rows.length === 0) {
        return;
      }

      const first = rows[0];
      const cobros: CollectorOverdueCollection[] = rows.map((row) => ({
        cliente: row.cliente,
        ruta: row.ruta,
        fechaVencimiento: row.fecha_vencimiento,
        saldoCuota: this.numberLike(row.saldo_cuota),
        monedaCodigo: row.moneda_codigo,
      }));

      await this.deliver({
        kind: 'cobros_atrasados_cobrador',
        eventId: `${collectorId}-${this.todayKey()}`,
        contact: {
          nombre: first.cobrador_nombre,
          correo: this.normalizeEmail(first.cobrador_correo),
          whatsapp: this.normalizeText(first.cobrador_telefono),
        },
        totalAtrasados: rows.length,
        cobros,
      });
    } catch (error) {
      this.logger.error(
        `No se pudo preparar la alerta de cobros atrasados (${collectorId}): ${this.errorMessage(error)}`,
      );
    }
  }

  private async deliver(notification: CustomerNotification) {
    const rendered = this.templates.render(notification);
    const jobs: Array<Promise<void>> = [];

    if (notification.contact.correo) {
      jobs.push(
        this.email.send({
          to: notification.contact.correo,
          recipientName: notification.contact.nombre,
          subject: rendered.subject,
          html: rendered.emailHtml,
          text: rendered.emailText,
          idempotencyKey: `${notification.kind}-${notification.eventId}`,
        }),
      );
    } else {
      this.logger.warn(
        `No se envio ${notification.kind} por correo: el destinatario no tiene correo`,
      );
    }

    if (
      notification.contact.whatsapp &&
      (this.config.get<boolean>('YCLOUD_ENABLED') ?? false)
    ) {
      jobs.push(
        this.whatsapp.send({
          to: notification.contact.whatsapp,
          kind: notification.kind,
          text: rendered.whatsappText,
          templateParameters: rendered.whatsappTemplateParameters,
          externalId: `${notification.kind}-${notification.eventId}`,
        }),
      );
    } else if (!notification.contact.whatsapp) {
      this.logger.warn(
        `No se envio ${notification.kind} por WhatsApp: el destinatario no tiene numero`,
      );
    }

    const results = await Promise.allSettled(jobs);
    results.forEach((result) => {
      if (result.status === 'rejected') {
        this.logger.error(
          `Fallo el envio de ${notification.kind}: ${this.errorMessage(result.reason)}`,
        );
      }
    });
  }

  private contact(cliente: {
    nombreCompleto: string;
    contactos: Array<{
      valor: string;
      esPrincipal: boolean;
      tipoContacto: { codigo: string };
    }>;
  }): NotificationContact {
    const find = (code: string) =>
      cliente.contactos.find(
        (item) => item.tipoContacto.codigo === code && item.esPrincipal,
      ) ?? cliente.contactos.find((item) => item.tipoContacto.codigo === code);

    return {
      nombre: cliente.nombreCompleto,
      correo: this.normalizeEmail(find('CORREO')?.valor),
      whatsapp: this.normalizeText(
        find('WHATSAPP')?.valor ?? find('TELEFONO')?.valor,
      ),
    };
  }

  private normalizeEmail(value: string | null | undefined) {
    return this.normalizeText(value)?.toLowerCase() ?? null;
  }

  private normalizeText(value: string | null | undefined) {
    const normalized = value?.trim();
    return normalized ? normalized : null;
  }

  private enabled() {
    return this.config.get<boolean>('NOTIFICATIONS_ENABLED') ?? false;
  }

  private number(value: Prisma.Decimal) {
    return value.toNumber();
  }

  private numberLike(value: Prisma.Decimal | number | string | null) {
    if (value instanceof Prisma.Decimal) {
      return value.toNumber();
    }
    if (typeof value === 'number') {
      return Number.isFinite(value) ? value : 0;
    }
    if (typeof value === 'string') {
      return Number.parseFloat(value) || 0;
    }
    return 0;
  }

  private round(value: number) {
    return Math.round((value + Number.EPSILON) * 100) / 100;
  }

  private logUnexpected(event: string, id: string, error: unknown) {
    this.logger.error(
      `No se pudo preparar la notificacion de ${event} (${id}): ${this.errorMessage(error)}`,
    );
  }

  private errorMessage(error: unknown) {
    return error instanceof Error ? error.message : String(error);
  }

  private todayKey() {
    const timeZone =
      this.config.get<string>('NOTIFICATION_TIME_ZONE') ?? 'America/Bogota';
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(new Date());
    const value = (type: string) =>
      parts.find((part) => part.type === type)?.value ?? '00';
    return `${value('year')}-${value('month')}-${value('day')}`;
  }

  private isUuid(value: string) {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      value,
    );
  }

  private overdueCollections(collectorId: string) {
    return this.prisma.$queryRaw<CollectorOverdueRow[]>(Prisma.sql`
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
        u.usuario_id::text AS cobrador_id,
        TRIM(CONCAT_WS(' ', u.nombres, u.apellidos)) AS cobrador_nombre,
        u.correo AS cobrador_correo,
        u.telefono AS cobrador_telefono,
        cl.nombre_completo AS cliente,
        r.nombre AS ruta,
        c.moneda_codigo,
        prox.fecha_vencimiento,
        prox.saldo_cuota
      FROM public.credito c
      JOIN public.ruta r ON r.ruta_id = c.ruta_id
      JOIN public.usuario u ON u.usuario_id = r.responsable_usuario_id
      JOIN public.estado_credito ecr ON ecr.estado_credito_id = c.estado_credito_id
      JOIN public.cliente cl ON cl.cliente_id = c.cliente_id
      JOIN public.credito_plan_pago cpp ON cpp.credito_id = c.credito_id
      JOIN LATERAL (
        SELECT
          cc.fecha_vencimiento,
          GREATEST(cc.valor_total - COALESCE(ac.abonado, 0), 0) AS saldo_cuota
        FROM public.credito_cuota cc
        JOIN public.estado_cuota ecu ON ecu.estado_cuota_id = cc.estado_cuota_id
        LEFT JOIN abonos_cuota ac ON ac.credito_cuota_id = cc.credito_cuota_id
        WHERE cc.credito_plan_pago_id = cpp.credito_plan_pago_id
          AND ecu.codigo NOT IN ('PAGADA', 'ANULADA')
          AND (cc.valor_total - COALESCE(ac.abonado, 0)) > 0
        ORDER BY cc.fecha_vencimiento ASC, cc.numero_cuota ASC
        LIMIT 1
      ) prox ON TRUE
      WHERE u.usuario_id = ${collectorId}::uuid
        AND ecr.codigo NOT IN ('ANULADO', 'PAGADO')
        AND prox.fecha_vencimiento < CURRENT_DATE
      ORDER BY prox.fecha_vencimiento ASC, cl.nombre_completo ASC
    `);
  }

  private overdueCollectionsTbl(collectorId: string) {
    if (!/^\d+$/.test(collectorId)) {
      return Promise.resolve([]);
    }

    return this.prisma.$queryRaw<CollectorOverdueRow[]>(Prisma.sql`
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
      )
      SELECT
        tu.id_usu::text AS cobrador_id,
        TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS cobrador_nombre,
        tu.usu_email AS cobrador_correo,
        p.per_num_celular AS cobrador_telefono,
        TRIM(CONCAT_WS(' ', pc.per_primer_nombre, pc.per_apellido)) AS cliente,
        COALESCE(ruta_credito.ruta, 'Sin ruta') AS ruta,
        mon.mon_codigo::text AS moneda_codigo,
        prox.cuo_fecha_vencimiento AS fecha_vencimiento,
        prox.saldo_cuota
      FROM public.tbl_creditos cr
      JOIN public.tbl_usuarios tu ON tu.id_usu = cr.usu_id
      JOIN public.tbl_personas p ON p.id_per = tu.persona_id
      JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
      JOIN public.tbl_personas pc ON pc.id_per = cl.cli_persona
      JOIN public.tbl_monedas mon ON mon.id_mon = cr.mon_id
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
      JOIN LATERAL (
        SELECT
          cu.cuo_fecha_vencimiento,
          GREATEST(cu.cuo_valor - COALESCE(ac.abonado, 0), 0) AS saldo_cuota
        FROM public.tbl_cuotas cu
        LEFT JOIN abonos_cuota ac ON ac.id_cuo = cu.id_cuo
        WHERE cu.cre_id = cr.id_cre
          AND UPPER(cu.cuo_estado::text) NOT IN ('PAGADA', 'ANULADA')
          AND (cu.cuo_valor - COALESCE(ac.abonado, 0)) > 0
        ORDER BY cu.cuo_fecha_vencimiento ASC, cu.cuo_numero ASC
        LIMIT 1
      ) prox ON TRUE
      WHERE tu.id_usu = ${BigInt(collectorId)}
        AND UPPER(cr.cre_estado::text) NOT IN ('ANULADO', 'PAGADO')
        AND prox.cuo_fecha_vencimiento < CURRENT_DATE
      ORDER BY prox.cuo_fecha_vencimiento ASC, cliente ASC
    `);
  }
}

type CollectorOverdueRow = {
  cobrador_id: string;
  cobrador_nombre: string;
  cobrador_correo: string | null;
  cobrador_telefono: string | null;
  cliente: string;
  ruta: string;
  moneda_codigo: string;
  fecha_vencimiento: Date | null;
  saldo_cuota: Prisma.Decimal | number | string | null;
};
