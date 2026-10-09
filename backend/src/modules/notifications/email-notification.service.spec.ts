import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { EmailNotificationService } from './email-notification.service';

jest.mock('nodemailer');

describe('EmailNotificationService', () => {
  let service: EmailNotificationService;
  let mockSendMail: jest.Mock;
  let mockVerify: jest.Mock;

  beforeEach(() => {
    jest.clearAllMocks();
    mockSendMail = jest.fn().mockResolvedValue({
      messageId: 'test-message-id',
      accepted: ['destinatario@example.com'],
      rejected: [],
    });
    mockVerify = jest.fn().mockResolvedValue(true);

    (nodemailer.createTransport as jest.Mock).mockReturnValue({
      sendMail: mockSendMail,
      verify: mockVerify,
    });
  });

  it('fails if SMTP credentials are not configured', async () => {
    const config = new ConfigService({});
    service = new EmailNotificationService(config);

    await expect(
      service.send({
        to: 'test@example.com',
        recipientName: 'Test User',
        subject: 'Prueba',
        html: '<p>Hola</p>',
        text: 'Hola',
        idempotencyKey: 'test-1',
      }),
    ).rejects.toThrow('No hay credenciales SMTP configuradas');
  });

  it('sends email with default Gmail SMTP settings and custom alias', async () => {
    const config = new ConfigService({
      SMTP_USER: 'cobro.empresa@gmail.com',
      SMTP_PASSWORD: 'app-password-16-chars',
      SMTP_FROM_NAME: 'Cobro Notificaciones',
      SMTP_FROM_EMAIL: 'cobro.empresa@gmail.com',
      SMTP_REPLY_TO: 'soporte@empresa.com',
    });
    service = new EmailNotificationService(config);

    await service.send({
      to: 'cliente@gmail.com',
      recipientName: 'Carlos Gómez',
      subject: 'Recibo de pago',
      html: '<h1>Pago recibido</h1>',
      text: 'Pago recibido',
      idempotencyKey: 'pago-100',
    });

    expect(nodemailer.createTransport).toHaveBeenCalledWith(
      expect.objectContaining({
        host: 'smtp.gmail.com',
        port: 465,
        secure: true,
        auth: {
          user: 'cobro.empresa@gmail.com',
          pass: 'app-password-16-chars',
        },
      }),
    );

    expect(mockSendMail).toHaveBeenCalledWith({
      from: '"Cobro Notificaciones" <cobro.empresa@gmail.com>',
      to: {
        address: 'cliente@gmail.com',
        name: 'Carlos Gómez',
      },
      subject: 'Recibo de pago',
      html: '<h1>Pago recibido</h1>',
      text: 'Pago recibido',
      replyTo: 'soporte@empresa.com',
      headers: {
        'X-Notification-Id': 'pago-100',
      },
    });
  });

  it('verifies SMTP connection successfully', async () => {
    const config = new ConfigService({
      SMTP_USER: 'test@gmail.com',
      SMTP_PASSWORD: 'password123',
    });
    service = new EmailNotificationService(config);

    const result = await service.verifyConnection();
    expect(result.success).toBe(true);
    expect(mockVerify).toHaveBeenCalled();
  });

  it('handles verify error gracefully', async () => {
    mockVerify.mockRejectedValueOnce(new Error('Invalid login'));

    const config = new ConfigService({
      SMTP_USER: 'test@gmail.com',
      SMTP_PASSWORD: 'wrong-password',
    });
    service = new EmailNotificationService(config);

    const result = await service.verifyConnection();
    expect(result.success).toBe(false);
    expect(result.message).toContain('Invalid login');
  });
});
