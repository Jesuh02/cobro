import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../common/prisma/prisma.service';
import { EmailNotificationService } from './email-notification.service';
import { NotificationTemplatesService } from './notification-templates.service';
import { NotificationsService } from './notifications.service';
import { WhatsappNotificationService } from './whatsapp-notification.service';

describe('NotificationsService', () => {
  let service: NotificationsService;
  let prismaMock: {
    $queryRaw: jest.Mock;
    $executeRaw: jest.Mock;
  };
  let emailMock: {
    send: jest.Mock;
  };
  let whatsappMock: {
    send: jest.Mock;
  };

  beforeEach(() => {
    prismaMock = {
      $queryRaw: jest.fn(),
      $executeRaw: jest.fn().mockResolvedValue(1),
    };
    emailMock = {
      send: jest.fn().mockResolvedValue(undefined),
    };
    whatsappMock = {
      send: jest.fn().mockResolvedValue(undefined),
    };

    const config = new ConfigService({
      NOTIFICATIONS_ENABLED: true,
      WHATSAPP_PROVIDER: 'evolution',
      EVOLUTION_ENABLED: true,
      EVOLUTION_BASE_URL: 'http://localhost:8080',
      EVOLUTION_API_KEY: 'test-key',
      EVOLUTION_INSTANCE_NAME: 'cobrod',
      NOTIFICATION_BRAND_NAME: 'Cobro',
    });

    const templates = new NotificationTemplatesService(config);

    service = new NotificationsService(
      prismaMock as unknown as PrismaService,
      config,
      templates,
      emailMock as unknown as EmailNotificationService,
      whatsappMock as unknown as WhatsappNotificationService,
    );
  });

  it('notifies payment received via WhatsApp and logs to tbl_notificaciones', async () => {
    const paymentId = '11111111-1111-1111-1111-111111111111';
    const creditId = '22222222-2222-2222-2222-222222222222';
    const orgId = '33333333-3333-3333-3333-333333333333';
    const clientId = '44444444-4444-4444-4444-444444444444';

    // Query 1: Pago
    prismaMock.$queryRaw.mockResolvedValueOnce([
      {
        id_pag: paymentId,
        pag_monto: '50000',
        mon_codigo: 'COP',
        id_cre: creditId,
        cre_total: '500000',
        cre_estado: 'ACTIVO',
        id_cli: clientId,
        org_id: orgId,
        nombre: 'Carlos Perez',
        per_email: null,
        per_num_celular: '3044271932',
      },
    ]);

    // Query 2: Cuotas
    prismaMock.$queryRaw.mockResolvedValueOnce([
      {
        id_cuo: '55555555-5555-5555-5555-555555555555',
        cuo_numero: 2,
        cuo_valor: '50000',
        cuo_total_pagado: '0',
        cuo_fecha_vencimiento: new Date('2026-09-15T00:00:00.000Z'),
        saldo_pendiente: '50000',
      },
    ]);

    await service.notifyPaymentReceived(paymentId);

    // No debe enviar email porque per_email es null
    expect(emailMock.send).not.toHaveBeenCalled();

    // Debe enviar WhatsApp
    expect(whatsappMock.send).toHaveBeenCalledTimes(1);
    expect(whatsappMock.send).toHaveBeenCalledWith(
      expect.objectContaining({
        to: '3044271932',
        kind: 'pago_recibido',
        text: expect.stringContaining('Pago recibido'),
      }),
    );

    // Debe guardar registro en tbl_notificaciones
    expect(prismaMock.$executeRaw).toHaveBeenCalledTimes(1);
  });

  it('records FALLIDA status in tbl_notificaciones if WhatsApp sending rejects', async () => {
    const paymentId = '11111111-1111-1111-1111-111111111111';

    prismaMock.$queryRaw.mockResolvedValueOnce([
      {
        id_pag: paymentId,
        pag_monto: '50000',
        mon_codigo: 'COP',
        id_cre: '22222222-2222-2222-2222-222222222222',
        cre_total: '500000',
        cre_estado: 'ACTIVO',
        id_cli: '44444444-4444-4444-4444-444444444444',
        org_id: '33333333-3333-3333-3333-333333333333',
        nombre: 'Carlos Perez',
        per_email: null,
        per_num_celular: '3044271932',
      },
    ]);

    prismaMock.$queryRaw.mockResolvedValueOnce([
      {
        id_cuo: '55555555-5555-5555-5555-555555555555',
        cuo_numero: 2,
        cuo_valor: '50000',
        cuo_total_pagado: '0',
        cuo_fecha_vencimiento: new Date('2026-09-15T00:00:00.000Z'),
        saldo_pendiente: '50000',
      },
    ]);

    whatsappMock.send.mockRejectedValueOnce(
      new Error('WhatsApp connection timeout'),
    );

    await expect(
      service.notifyPaymentReceived(paymentId),
    ).resolves.toBeUndefined();

    expect(prismaMock.$executeRaw).toHaveBeenCalledTimes(1);
  });
});

