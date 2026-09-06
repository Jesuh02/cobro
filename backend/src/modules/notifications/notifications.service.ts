import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../common/prisma/prisma.service';
import { EmailNotificationService } from './email-notification.service';
import { NotificationTemplatesService } from './notification-templates.service';
import {
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

  async notifyCreditApproved(creditId: string | number) {
    if (!this.enabled()) {
      return;
    }

    try {
      const [credit] = await this.prisma.$queryRaw<any[]>`
        SELECT
          c.id_cre,
          c.cre_total,
          c.cre_total_pagar,
          m.mon_codigo,
          cli.id_cli,
          cli.org_id,
          per.per_primer_nombre || ' ' || per.per_apellido AS nombre,
          per.per_email,
          per.per_num_celular,
          (SELECT COUNT(*) FROM tbl_cuotas cuo WHERE cuo.cre_id = c.id_cre AND cuo.cuo_estado != 'ANULADA') AS numero_cuotas,
          (SELECT cuo_valor FROM tbl_cuotas cuo WHERE cuo.cre_id = c.id_cre AND cuo.cuo_estado != 'ANULADA' ORDER BY cuo.cuo_numero ASC LIMIT 1) AS valor_cuota,
          (SELECT cuo_fecha_vencimiento FROM tbl_cuotas cuo WHERE cuo.cre_id = c.id_cre AND cuo.cuo_estado != 'ANULADA' ORDER BY cuo.cuo_numero ASC LIMIT 1) AS primera_cuota
        FROM tbl_creditos c
        JOIN tbl_clientes cli ON cli.id_cli = c.cli_id
        JOIN tbl_personas per ON per.id_per = cli.cli_persona
        JOIN tbl_monedas m ON m.id_mon = c.mon_id
        WHERE c.id_cre = ${String(creditId)}::uuid
      `;

      if (!credit) {
        throw new Error(`No se encontro el credito ${creditId}`);
      }

      await this.deliver({
        kind: 'credito_aprobado',
        eventId: String(credit.id_cre),
        orgId: String(credit.org_id),
        cliId: String(credit.id_cli),
        creId: String(credit.id_cre),
        contact: this.contact(
          credit.nombre,
          credit.per_email,
          credit.per_num_celular,
        ),
        monedaCodigo: credit.mon_codigo,
        valorPrincipal: this.number(credit.cre_total),
        valorTotal: this.number(credit.cre_total_pagar),
        numeroCuotas: Number(credit.numero_cuotas),
        valorCuota: this.number(credit.valor_cuota),
        primeraCuota: credit.primera_cuota ?? null,
      });
    } catch (error) {
      this.logUnexpected('credito aprobado', String(creditId), error);
    }
  }

  async notifyPaymentReceived(paymentId: string | number) {
    if (!this.enabled()) {
      return;
    }

    try {
      const [payment] = await this.prisma.$queryRaw<any[]>`
        SELECT 
          p.id_pag,
          p.pag_monto,
          m.mon_codigo,
          c.id_cre,
          c.cre_total,
          c.cre_estado,
          cli.id_cli,
          cli.org_id,
          per.per_primer_nombre || ' ' || per.per_apellido AS nombre,
          per.per_email,
          per.per_num_celular
        FROM tbl_pagos p
        JOIN tbl_monedas m ON m.id_mon = p.mon_id
        JOIN tbl_cuotas_pagos cp_pago ON cp_pago.pagos_id = p.id_pag
        JOIN tbl_cuotas cu_pago ON cu_pago.id_cuo = cp_pago.cuo_id
        JOIN tbl_creditos c ON c.id_cre = cu_pago.cre_id
        JOIN tbl_clientes cli ON cli.id_cli = c.cli_id
        JOIN tbl_personas per ON per.id_per = cli.cli_persona
        WHERE p.id_pag = ${String(paymentId)}::uuid
        ORDER BY c.id_cre
        LIMIT 1
      `;

      if (!payment) {
        throw new Error(`No se encontro el pago ${paymentId}`);
      }

      const installments = await this.prisma.$queryRaw<any[]>`
        SELECT 
          cuo.id_cuo,
          cuo.cuo_numero,
          cuo.cuo_valor,
          cuo.cuo_total_pagado,
          cuo.cuo_fecha_vencimiento,
          (cuo.cuo_valor - cuo.cuo_total_pagado) AS saldo_pendiente
        FROM tbl_cuotas cuo
        WHERE cuo.cre_id = ${payment.id_cre}
          AND cuo.cuo_estado != 'ANULADA'
        ORDER BY cuo.cuo_numero ASC
      `;

      const pending = installments
        .map((installment) => ({
          installment,
          balance: this.round(this.number(installment.saldo_pendiente)),
        }))
        .filter((item) => item.balance > 0);

      const next = pending[0] ?? null;
      const contact = this.contact(
        payment.nombre,
        payment.per_email,
        payment.per_num_celular,
      );

      const paymentNotification: CustomerNotification = {
        kind: 'pago_recibido',
        eventId: String(payment.id_pag),
        orgId: String(payment.org_id),
        cliId: String(payment.id_cli),
        creId: String(payment.id_cre),
        contact,
        monedaCodigo: payment.mon_codigo,
        montoPagado: this.number(payment.pag_monto),
        saldoPendiente: this.round(
          pending.reduce((total, item) => total + item.balance, 0),
        ),
        cuotasRestantes: pending.length,
        proximaCuotaNumero: next ? Number(next.installment.cuo_numero) : null,
        proximaCuotaValor: next?.balance ?? null,
        proximaCuotaFecha: next?.installment.cuo_fecha_vencimiento ?? null,
      };

      await this.deliver(paymentNotification);

      if (payment.cre_estado === 'PAGADO' || pending.length === 0) {
        await this.deliver({
          kind: 'credito_finalizado',
          eventId: String(payment.id_cre),
          orgId: String(payment.org_id),
          cliId: String(payment.id_cli),
          creId: String(payment.id_cre),
          contact,
          monedaCodigo: payment.mon_codigo,
          valorPrincipal: this.number(payment.cre_total),
        });
      }
    } catch (error) {
      this.logUnexpected('pago recibido', String(paymentId), error);
    }
  }

  async notifyCollectorOverdueCollections(collectorId: string) {
    if (!this.enabled()) {
      return;
    }

    try {
      const rows = /^\d+$/.test(collectorId)
        ? await this.overdueCollectionsTbl(collectorId)
        : this.isUuid(collectorId)
          ? await this.overdueCollections(collectorId)
          : [];

      if (rows.length === 0) {
        return;
      }

      const collector = rows[0];
      await this.deliver({
        kind: 'cobros_atrasados_cobrador',
        eventId: `${collectorId}-${this.todayKey()}`,
        contact: this.contact(
          collector.cobrador_nombre,
          collector.cobrador_correo,
          collector.cobrador_telefono,
        ),
        totalAtrasados: rows.length,
        cobros: rows.map((row) => ({
          cliente: row.cliente,
          ruta: row.ruta,
          fechaVencimiento: row.fecha_vencimiento,
          saldoCuota: this.number(row.saldo_cuota),
          monedaCodigo: row.moneda_codigo,
        })),
      });
    } catch (error) {
      this.logUnexpected('cobros atrasados cobrador', collectorId, error);
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

    if (this.isPersistableNotification(notification)) {
      // Guardar el registro en la base de datos
      for (const result of results) {
        const canal =
          notification.contact.correo && result === results[0]
            ? 'CORREO'
            : 'WHATSAPP';
        const estado = result.status === 'fulfilled' ? 'ENVIADA' : 'FALLIDA';
        const errorMsg =
          result.status === 'rejected'
            ? this.errorMessage(result.reason)
            : null;
        const destinatario =
          canal === 'CORREO'
            ? notification.contact.correo
            : notification.contact.whatsapp;
        const pagId =
          notification.kind === 'pago_recibido' ? notification.eventId : null;
        const creId = notification.creId;

        if (destinatario) {
          try {
            await this.prisma.$executeRaw`
              INSERT INTO tbl_notificaciones (
                org_id, cli_id, cre_id, pag_id, not_tipo, not_canal, not_estado, not_destinatario, not_error, not_envio
              ) VALUES (
                ${notification.orgId}::uuid,
                ${notification.cliId}::uuid,
                ${creId ? creId : null}::uuid,
                ${pagId ? pagId : null}::uuid,
                ${notification.kind.toUpperCase()}::notificacion_tipo_enum,
                ${canal}::notificacion_canal_enum,
                ${estado}::notificacion_estado_enum,
                ${destinatario},
                ${errorMsg},
                ${estado === 'ENVIADA' ? new Date() : null}
              )
            `;
          } catch (dbError) {
            this.logger.error(
              `No se pudo guardar el log de notificacion: ${this.errorMessage(dbError)}`,
            );
          }
        }
      }
    }

    results.forEach((result) => {
      if (result.status === 'rejected') {
        this.logger.error(
          `Fallo el envio de ${notification.kind}: ${this.errorMessage(result.reason)}`,
        );
      }
    });
  }

  private contact(
    nombre: string,
    correo: string | null,
    telefono: string | null,
  ): NotificationContact {
    return {
      nombre: nombre,
      correo: this.normalizeEmail(correo),
      whatsapp: this.normalizeText(telefono),
    };
  }

  private normalizeEmail(value: string | undefined | null) {
    return this.normalizeText(value)?.toLowerCase() ?? null;
  }

  private normalizeText(value: string | undefined | null) {
    const normalized = value?.trim();
    return normalized ? normalized : null;
  }

  private enabled() {
    return this.config.get<boolean>('NOTIFICATIONS_ENABLED') ?? false;
  }

  private number(
    value: Prisma.Decimal | string | number | bigint | null | undefined,
  ) {
    if (value === null || value === undefined) return 0;
    if (value instanceof Prisma.Decimal) return value.toNumber();
    return Number(value);
  }

  private isPersistableNotification(notification: CustomerNotification) {
    return notification.kind !== 'cobros_atrasados_cobrador';
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
        COALESCE(p.per_email, '') AS cobrador_correo,
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
      WHERE tu.id_usu = ${String(collectorId)}::uuid
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
