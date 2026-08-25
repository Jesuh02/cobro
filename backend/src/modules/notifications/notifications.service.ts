import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../common/prisma/prisma.service';
import { EmailNotificationService } from './email-notification.service';
import { NotificationTemplatesService } from './notification-templates.service';
import { CustomerNotification, NotificationContact } from './notification.types';
import { WhatsappNotificationService } from './whatsapp-notification.service';
import { Prisma } from '@prisma/client';

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
        WHERE c.id_cre = ${BigInt(creditId)}
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
        contact: this.contact(credit.nombre, credit.per_email, credit.per_num_celular),
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
        JOIN tbl_creditos c ON c.id_cre = p.cre_id
        JOIN tbl_clientes cli ON cli.id_cli = c.cli_id
        JOIN tbl_personas per ON per.id_per = cli.cli_persona
        WHERE p.id_pag = ${BigInt(paymentId)}
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
      const contact = this.contact(payment.nombre, payment.per_email, payment.per_num_celular);
      
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
        `No se envio ${notification.kind} por correo: el cliente no tiene correo`,
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
        `No se envio ${notification.kind} por WhatsApp: el cliente no tiene numero`,
      );
    }


    const results = await Promise.allSettled(jobs);
    
    // Guardar el registro en la base de datos
    for (const result of results) {
      const canal = notification.contact.correo && result === results[0] ? 'CORREO' : 'WHATSAPP';
      const estado = result.status === 'fulfilled' ? 'ENVIADA' : 'FALLIDA';
      const errorMsg = result.status === 'rejected' ? this.errorMessage(result.reason) : null;
      const destinatario = canal === 'CORREO' ? notification.contact.correo : notification.contact.whatsapp;
      const pagId = notification.kind === 'pago_recibido' ? notification.eventId : null;
      const creId = notification.creId;
      
      if (destinatario) {
        try {
          await this.prisma.$executeRaw`
            INSERT INTO tbl_notificaciones (
              org_id, cli_id, cre_id, pag_id, not_tipo, not_canal, not_estado, not_destinatario, not_error, not_envio
            ) VALUES (
              ${BigInt(notification.orgId)}, 
              ${BigInt(notification.cliId)}, 
              ${creId ? BigInt(creId) : null}, 
              ${pagId ? BigInt(pagId) : null}, 
              ${notification.kind.toUpperCase()}::notificacion_tipo_enum, 
              ${canal}::notificacion_canal_enum, 
              ${estado}::notificacion_estado_enum, 
              ${destinatario}, 
              ${errorMsg}, 
              ${estado === 'ENVIADA' ? new Date() : null}
            )
          `;
        } catch (dbError) {
          this.logger.error(`No se pudo guardar el log de notificacion: ${this.errorMessage(dbError)}`);
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

  private contact(nombre: string, correo: string | null, telefono: string | null): NotificationContact {
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

  private number(value: Prisma.Decimal | string | number | bigint) {
    if (value === null || value === undefined) return 0;
    if (value instanceof Prisma.Decimal) return value.toNumber();
    return Number(value);
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
}
