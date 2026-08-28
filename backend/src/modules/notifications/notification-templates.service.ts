import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import {
  CreditApprovedNotification,
  CreditCompletedNotification,
  CollectorOverdueNotification,
  CustomerNotification,
  PaymentReceivedNotification,
  RenderedNotification,
} from './notification.types';

@Injectable()
export class NotificationTemplatesService {
  private readonly brandName: string;

  constructor(private readonly config: ConfigService) {
    this.brandName =
      this.config.get<string>('NOTIFICATION_BRAND_NAME') ?? 'Cobro';
  }

  render(notification: CustomerNotification): RenderedNotification {
    switch (notification.kind) {
      case 'credito_aprobado':
        return this.creditApproved(notification);
      case 'pago_recibido':
        return this.paymentReceived(notification);
      case 'credito_finalizado':
        return this.creditCompleted(notification);
      case 'cobros_atrasados_cobrador':
        return this.collectorOverdue(notification);
    }
  }

  private creditApproved(
    notification: CreditApprovedNotification,
  ): RenderedNotification {
    const principal = this.money(
      notification.valorPrincipal,
      notification.monedaCodigo,
    );
    const total = this.money(
      notification.valorTotal,
      notification.monedaCodigo,
    );
    const installment = this.money(
      notification.valorCuota,
      notification.monedaCodigo,
    );
    const firstDate = this.date(notification.primeraCuota);
    const firstName = this.firstName(notification.contact.nombre);

    const emailText = [
      `Hola ${firstName},`,
      '',
      `¡Tu crédito por ${principal} ha sido aprobado!`,
      `El valor total a pagar es ${total}, distribuido en ${notification.numeroCuotas} cuotas de aproximadamente ${installment}.`,
      notification.primeraCuota
        ? `Tu primera cuota vence el ${firstDate}.`
        : null,
      '',
      `Gracias por confiar en ${this.brandName}.`,
    ]
      .filter((line): line is string => line !== null)
      .join('\n');

    const whatsappText = [
      `🎉 *¡Tu crédito ha sido aprobado!*`,
      '',
      `Hola ${firstName}, tu crédito por *${principal}* fue aprobado.`,
      `Total: ${total}`,
      `Cuotas: ${notification.numeroCuotas} de ${installment}`,
      notification.primeraCuota ? `Primera cuota: ${firstDate}` : null,
      '',
      `Gracias por confiar en *${this.brandName}*.`,
    ]
      .filter((line): line is string => line !== null)
      .join('\n');

    return {
      subject: `¡Tu crédito por ${principal} fue aprobado!`,
      emailText,
      emailHtml: this.layout({
        eyebrow: 'Crédito aprobado',
        title: '¡Buenas noticias!',
        greeting: `Hola ${this.escape(firstName)},`,
        lead: `Tu crédito por <strong>${this.escape(principal)}</strong> ha sido aprobado.`,
        rows: [
          ['Monto aprobado', principal],
          ['Total a pagar', total],
          ['Número de cuotas', String(notification.numeroCuotas)],
          ['Valor por cuota', installment],
          ...(notification.primeraCuota
            ? ([['Primera cuota', firstDate]] as Array<[string, string]>)
            : []),
        ],
        closing: `Gracias por confiar en ${this.escape(this.brandName)}. Estamos para acompañarte durante todo tu crédito.`,
      }),
      whatsappText,
      whatsappTemplateParameters: [
        firstName,
        principal,
        total,
        String(notification.numeroCuotas),
        installment,
        firstDate,
      ],
    };
  }

  private paymentReceived(
    notification: PaymentReceivedNotification,
  ): RenderedNotification {
    const amount = this.money(
      notification.montoPagado,
      notification.monedaCodigo,
    );
    const balance = this.money(
      notification.saldoPendiente,
      notification.monedaCodigo,
    );
    const nextAmount =
      notification.proximaCuotaValor === null
        ? '—'
        : this.money(notification.proximaCuotaValor, notification.monedaCodigo);
    const nextDate = this.date(notification.proximaCuotaFecha);
    const firstName = this.firstName(notification.contact.nombre);
    const remainingLabel = `${notification.cuotasRestantes} ${notification.cuotasRestantes === 1 ? 'cuota' : 'cuotas'}`;

    const nextPaymentLine =
      notification.proximaCuotaFecha && notification.proximaCuotaValor !== null
        ? `Tu próxima cuota es de ${nextAmount} y vence el ${nextDate}.`
        : 'No tienes una próxima cuota pendiente.';

    const emailText = [
      `Hola ${firstName},`,
      '',
      `Recibimos correctamente tu pago de ${amount}.`,
      `Te quedan ${remainingLabel} y un saldo pendiente de ${balance}.`,
      nextPaymentLine,
      '',
      `Gracias por tu pago puntual. — ${this.brandName}`,
    ].join('\n');

    const whatsappText = [
      `✅ *Pago recibido*`,
      '',
      `Hola ${firstName}, registramos tu pago de *${amount}*.`,
      `Cuotas restantes: *${notification.cuotasRestantes}*`,
      `Saldo pendiente: *${balance}*`,
      notification.proximaCuotaFecha && notification.proximaCuotaValor !== null
        ? `Próxima cuota: *${nextAmount}* — ${nextDate}`
        : 'No tienes cuotas pendientes.',
      '',
      `Gracias por confiar en *${this.brandName}*.`,
    ].join('\n');

    return {
      subject: `Confirmación de pago por ${amount}`,
      emailText,
      emailHtml: this.layout({
        eyebrow: 'Pago confirmado',
        title: 'Recibimos tu pago',
        greeting: `Hola ${this.escape(firstName)},`,
        lead: `Registramos correctamente tu pago de <strong>${this.escape(amount)}</strong>.`,
        rows: [
          ['Pago realizado', amount],
          ['Cuotas restantes', String(notification.cuotasRestantes)],
          ['Saldo pendiente', balance],
          ...(notification.proximaCuotaFecha &&
          notification.proximaCuotaValor !== null
            ? ([
                ['Próxima cuota', nextAmount],
                ['Fecha de vencimiento', nextDate],
              ] as Array<[string, string]>)
            : []),
        ],
        closing:
          notification.cuotasRestantes === 0
            ? 'Tu crédito ya no tiene cuotas pendientes.'
            : 'Gracias por tu pago. Continúa así para mantener tu crédito al día.',
      }),
      whatsappText,
      whatsappTemplateParameters: [
        firstName,
        amount,
        String(notification.cuotasRestantes),
        balance,
        nextAmount,
        nextDate,
      ],
    };
  }

  private creditCompleted(
    notification: CreditCompletedNotification,
  ): RenderedNotification {
    const principal = this.money(
      notification.valorPrincipal,
      notification.monedaCodigo,
    );
    const firstName = this.firstName(notification.contact.nombre);
    const message = `¡Felicitaciones, terminaste tu crédito! Si necesitas otro préstamo, no dudes en contactarte con nosotros.`;

    return {
      subject: '¡Felicitaciones, terminaste tu crédito!',
      emailText: [
        `Hola ${firstName},`,
        '',
        message,
        '',
        `Gracias por confiar en ${this.brandName}.`,
      ].join('\n'),
      emailHtml: this.layout({
        eyebrow: 'Crédito finalizado',
        title: '¡Lo lograste!',
        greeting: `Hola ${this.escape(firstName)},`,
        lead: '<strong>Terminaste tu crédito.</strong> Gracias por cumplir cada una de tus cuotas.',
        rows: [['Crédito finalizado', principal]],
        closing:
          'Si necesitas otro préstamo, no dudes en contactarte con nosotros. Será un gusto volver a ayudarte.',
      }),
      whatsappText: [
        '🎊 *¡Felicitaciones!*',
        '',
        `Hola ${firstName}, *terminaste tu crédito*.`,
        'Gracias por cumplir cada una de tus cuotas.',
        '',
        'Si necesitas otro préstamo, no dudes en contactarte con nosotros.',
        `— *${this.brandName}*`,
      ].join('\n'),
      whatsappTemplateParameters: [firstName, principal, this.brandName],
    };
  }

  private collectorOverdue(
    notification: CollectorOverdueNotification,
  ): RenderedNotification {
    const firstName = this.firstName(notification.contact.nombre);
    const totalLabel = `${notification.totalAtrasados} ${notification.totalAtrasados === 1 ? 'cobro atrasado' : 'cobros atrasados'}`;
    const listLines = notification.cobros.map((cobro, index) => {
      const amount = this.money(cobro.saldoCuota, cobro.monedaCodigo);
      return `${index + 1}. ${cobro.cliente} - ${cobro.ruta} - ${this.date(cobro.fechaVencimiento)} - ${amount}`;
    });
    const whatsappLines = listLines.slice(0, 12);
    const remaining = notification.cobros.length - whatsappLines.length;

    const emailText = [
      `Hola ${firstName},`,
      '',
      `Tienes ${totalLabel}.`,
      '',
      ...listLines,
      '',
      `Revisa la ruta activa en ${this.brandName}.`,
    ].join('\n');

    const whatsappText = [
      `*${this.brandName}: cobros atrasados*`,
      '',
      `Hola ${firstName}, tienes *${totalLabel}*.`,
      '',
      ...whatsappLines,
      remaining > 0 ? `Y ${remaining} mas en la app.` : null,
    ]
      .filter((line): line is string => line !== null)
      .join('\n');

    return {
      subject: `${totalLabel} pendientes por gestionar`,
      emailText,
      emailHtml: this.layout({
        eyebrow: 'Cobros atrasados',
        title: 'Cartera vencida por gestionar',
        greeting: `Hola ${this.escape(firstName)},`,
        lead: `Tienes <strong>${this.escape(totalLabel)}</strong>.`,
        rows: notification.cobros.map((cobro) => [
          cobro.cliente,
          `${cobro.ruta} - ${this.date(cobro.fechaVencimiento)} - ${this.money(
            cobro.saldoCuota,
            cobro.monedaCodigo,
          )}`,
        ]),
        closing: `Revisa tu ruta activa en ${this.escape(this.brandName)} para gestionar estos cobros.`,
      }),
      whatsappText,
      whatsappTemplateParameters: [
        firstName,
        totalLabel,
        whatsappLines.join('\n'),
      ],
    };
  }

  private layout(input: {
    eyebrow: string;
    title: string;
    greeting: string;
    lead: string;
    rows: Array<[string, string]>;
    closing: string;
  }) {
    const rows = input.rows
      .map(
        ([label, value]) => `
          <tr>
            <td style="padding:12px 0;border-bottom:1px solid #e9eeec;color:#64706b;font-size:14px;">${this.escape(label)}</td>
            <td style="padding:12px 0;border-bottom:1px solid #e9eeec;color:#13251d;font-size:14px;font-weight:600;text-align:right;">${this.escape(value)}</td>
          </tr>`,
      )
      .join('');

    return `<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;background:#f4f7f5;font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;color:#13251d;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f7f5;padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;background:#ffffff;border:1px solid #e3eae6;border-radius:16px;overflow:hidden;">
        <tr><td style="height:6px;background:#1e7a50;"></td></tr>
        <tr><td style="padding:36px 40px 18px;">
          <div style="color:#1e7a50;font-size:12px;font-weight:700;letter-spacing:1.4px;text-transform:uppercase;">${this.escape(input.eyebrow)}</div>
          <h1 style="margin:12px 0 20px;font-size:30px;line-height:1.2;letter-spacing:-0.7px;color:#13251d;">${this.escape(input.title)}</h1>
          <p style="margin:0 0 12px;color:#34483f;font-size:16px;line-height:1.65;">${input.greeting}</p>
          <p style="margin:0;color:#34483f;font-size:16px;line-height:1.65;">${input.lead}</p>
        </td></tr>
        <tr><td style="padding:12px 40px 24px;">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0">${rows}</table>
        </td></tr>
        <tr><td style="padding:0 40px 36px;">
          <p style="margin:0;padding:18px 20px;background:#f1f7f4;border-radius:10px;color:#34483f;font-size:14px;line-height:1.6;">${input.closing}</p>
        </td></tr>
        <tr><td style="padding:20px 40px;background:#fafcfb;border-top:1px solid #e9eeec;color:#7a8680;font-size:12px;line-height:1.6;">
          Este es un mensaje automático de ${this.escape(this.brandName)}. Por favor, no compartas información sensible por correo.
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
  }

  private money(value: number, currency: string) {
    try {
      return new Intl.NumberFormat('es-CO', {
        style: 'currency',
        currency,
        maximumFractionDigits: 2,
      }).format(value);
    } catch {
      return `${currency} ${new Intl.NumberFormat('es-CO', {
        maximumFractionDigits: 2,
      }).format(value)}`;
    }
  }

  private date(value: Date | null) {
    if (!value) {
      return '—';
    }

    return new Intl.DateTimeFormat('es-CO', {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
      // Prisma entrega las columnas DATE a medianoche UTC. Formatearlas en la
      // zona local podria mostrar el dia anterior en Colombia.
      timeZone: 'UTC',
    }).format(value);
  }

  private firstName(fullName: string) {
    return fullName.trim().split(/\s+/)[0] || 'cliente';
  }

  private escape(value: string) {
    return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#039;');
  }
}
