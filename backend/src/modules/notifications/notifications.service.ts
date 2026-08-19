import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';

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

  private normalizeEmail(value: string | undefined) {
    return this.normalizeText(value)?.toLowerCase() ?? null;
  }

  private normalizeText(value: string | undefined) {
    const normalized = value?.trim();
    return normalized ? normalized : null;
  }

  private enabled() {
    return this.config.get<boolean>('NOTIFICATIONS_ENABLED') ?? false;
  }

  private number(value: Prisma.Decimal) {
    return value.toNumber();
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
