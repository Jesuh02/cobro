import { ConfigService } from '@nestjs/config';

import { NotificationTemplatesService } from './notification-templates.service';

describe('NotificationTemplatesService', () => {
  const service = new NotificationTemplatesService(
    new ConfigService({ NOTIFICATION_BRAND_NAME: 'Cobro' }),
  );

  it('renders a professional credit approval in both channels', () => {
    const result = service.render({
      kind: 'credito_aprobado',
      eventId: 'credit-1',
      contact: {
        nombre: 'Ana Torres',
        correo: 'ana@example.com',
        whatsapp: '+573001112233',
      },
      monedaCodigo: 'COP',
      valorPrincipal: 1_000_000,
      valorTotal: 1_200_000,
      numeroCuotas: 30,
      valorCuota: 40_000,
      primeraCuota: new Date('2026-09-15T00:00:00.000Z'),
    });

    expect(result.subject).toContain('aprobado');
    expect(result.emailHtml).toContain('¡Buenas noticias!');
    expect(result.emailHtml).toContain('1.000.000');
    expect(result.emailText).toContain('15 de septiembre de 2026');
    expect(result.whatsappText).toContain('*¡Tu crédito ha sido aprobado!*');
    expect(result.whatsappTemplateParameters).toHaveLength(6);
  });

  it('includes remaining installments and the exact next due date on payment', () => {
    const result = service.render({
      kind: 'pago_recibido',
      eventId: 'payment-1',
      contact: {
        nombre: 'Carlos Díaz',
        correo: 'carlos@example.com',
        whatsapp: '+573004445566',
      },
      monedaCodigo: 'COP',
      montoPagado: 50_000,
      saldoPendiente: 450_000,
      cuotasRestantes: 9,
      proximaCuotaNumero: 2,
      proximaCuotaValor: 50_000,
      proximaCuotaFecha: new Date('2026-10-01T00:00:00.000Z'),
    });

    expect(result.emailText).toContain('Te quedan 9 cuotas');
    expect(result.emailText).toContain('1 de octubre de 2026');
    expect(result.whatsappText).toContain('Cuotas restantes: *9*');
    expect(result.whatsappTemplateParameters).toHaveLength(6);
  });

  it('renders the final congratulations message', () => {
    const result = service.render({
      kind: 'credito_finalizado',
      eventId: 'credit-1',
      contact: {
        nombre: 'Luisa Gómez',
        correo: 'luisa@example.com',
        whatsapp: '+573007778899',
      },
      monedaCodigo: 'COP',
      valorPrincipal: 500_000,
    });

    expect(result.subject).toContain('terminaste tu crédito');
    expect(result.emailText).toContain(
      'Si necesitas otro préstamo, no dudes en contactarte con nosotros.',
    );
    expect(result.whatsappText).toContain('*terminaste tu crédito*');
  });

  it('escapes customer data in HTML emails', () => {
    const result = service.render({
      kind: 'credito_finalizado',
      eventId: 'credit-2',
      contact: {
        nombre: '<script>alert(1)</script>',
        correo: 'safe@example.com',
        whatsapp: null,
      },
      monedaCodigo: 'COP',
      valorPrincipal: 100,
    });

    expect(result.emailHtml).not.toContain('<script>alert(1)</script>');
    expect(result.emailHtml).toContain('&lt;script&gt;');
  });

  it('renders collector overdue alerts with the overdue customer list', () => {
    const result = service.render({
      kind: 'cobros_atrasados_cobrador',
      eventId: 'collector-1-2026-08-27',
      contact: {
        nombre: 'Luis Perez',
        correo: 'luis@example.com',
        whatsapp: '+573001112233',
      },
      totalAtrasados: 2,
      cobros: [
        {
          cliente: 'Ana Torres',
          ruta: 'Centro',
          fechaVencimiento: new Date('2026-08-20T00:00:00.000Z'),
          saldoCuota: 50_000,
          monedaCodigo: 'COP',
        },
        {
          cliente: 'Carlos Diaz',
          ruta: 'Norte',
          fechaVencimiento: new Date('2026-08-21T00:00:00.000Z'),
          saldoCuota: 80_000,
          monedaCodigo: 'COP',
        },
      ],
    });

    expect(result.subject).toContain('2 cobros atrasados');
    expect(result.emailText).toContain('Ana Torres');
    expect(result.emailText).toContain('20 de agosto de 2026');
    expect(result.whatsappText).toContain('*2 cobros atrasados*');
    expect(result.whatsappTemplateParameters).toHaveLength(3);
  });
});
