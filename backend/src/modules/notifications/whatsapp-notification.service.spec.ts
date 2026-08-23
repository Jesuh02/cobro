import { ConfigService } from '@nestjs/config';

import { WhatsappNotificationService } from './whatsapp-notification.service';

describe('WhatsappNotificationService', () => {
  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
    jest.restoreAllMocks();
  });

  it('sends a utility Direct Send message and normalizes Colombian phones', async () => {
    const fetchMock = jest
      .fn()
      .mockResolvedValue(
        new Response(JSON.stringify({ id: 'message-1' }), { status: 200 }),
      );
    global.fetch = fetchMock;
    const service = new WhatsappNotificationService(
      new ConfigService({
        YCLOUD_API_KEY: 'test-key',
        YCLOUD_BASE_URL: 'https://api.ycloud.com/v2',
        YCLOUD_WHATSAPP_NUMBER: '+573044271932',
        YCLOUD_USE_DIRECT_SEND: true,
        WHATSAPP_DEFAULT_COUNTRY_CODE: '57',
      }),
    );

    await service.send({
      to: '300 111 22 33',
      kind: 'pago_recibido',
      text: 'Pago recibido',
      templateParameters: [],
      externalId: 'pago-1',
    });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [, request] = fetchMock.mock.calls[0] as [string, RequestInit];
    if (typeof request.body !== 'string') {
      throw new Error('Expected a JSON string body');
    }
    const body = JSON.parse(request.body) as Record<string, unknown>;
    expect(body).toMatchObject({
      from: '+573044271932',
      to: '+573001112233',
      type: 'text',
      category: 'utility',
      useDirectSend: true,
      externalId: 'pago-1',
    });
  });

  it('uses an approved template when its name is configured', async () => {
    const fetchMock = jest
      .fn()
      .mockResolvedValue(
        new Response(JSON.stringify({ id: 'message-2' }), { status: 200 }),
      );
    global.fetch = fetchMock;
    const service = new WhatsappNotificationService(
      new ConfigService({
        YCLOUD_API_KEY: 'test-key',
        YCLOUD_BASE_URL: 'https://api.ycloud.com/v2',
        YCLOUD_WHATSAPP_NUMBER: '+573044271932',
        YCLOUD_TEMPLATE_CREDIT_APPROVED: 'credito_aprobado',
        YCLOUD_TEMPLATE_LANGUAGE: 'es_CO',
      }),
    );

    await service.send({
      to: '+573001112233',
      kind: 'credito_aprobado',
      text: 'Tu crédito fue aprobado',
      templateParameters: ['Ana', '$ 1.000.000'],
      externalId: 'credito-1',
    });

    const [, request] = fetchMock.mock.calls[0] as [string, RequestInit];
    if (typeof request.body !== 'string') {
      throw new Error('Expected a JSON string body');
    }
    const body = JSON.parse(request.body) as {
      type: string;
      template: { name: string; language: { code: string } };
    };
    expect(body.type).toBe('template');
    expect(body.template.name).toBe('credito_aprobado');
    expect(body.template.language.code).toBe('es_CO');
  });

  it('skips malformed local recipient phones before calling YCloud', async () => {
    const fetchMock = jest.fn();
    global.fetch = fetchMock;
    const service = new WhatsappNotificationService(
      new ConfigService({
        YCLOUD_API_KEY: 'test-key',
        YCLOUD_BASE_URL: 'https://api.ycloud.com/v2',
        YCLOUD_WHATSAPP_NUMBER: '+573044271932',
        YCLOUD_TEMPLATE_CREDIT_APPROVED: 'credito_aprobado',
        WHATSAPP_DEFAULT_COUNTRY_CODE: '57',
      }),
    );

    await service.send({
      to: '28928932832',
      kind: 'credito_aprobado',
      text: 'Tu credito fue aprobado',
      templateParameters: ['Ana', '$ 1.000.000'],
      externalId: 'credito-1',
    });

    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('does not fail when YCloud rejects an invalid recipient phone', async () => {
    const fetchMock = jest.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          error: {
            status: 400,
            code: 'PARAM_INVALID',
            message: 'Invalid E.164 phone number: +28928932832',
            target: 'to',
          },
        }),
        { status: 400 },
      ),
    );
    global.fetch = fetchMock;
    const service = new WhatsappNotificationService(
      new ConfigService({
        YCLOUD_API_KEY: 'test-key',
        YCLOUD_BASE_URL: 'https://api.ycloud.com/v2',
        YCLOUD_WHATSAPP_NUMBER: '+573044271932',
        YCLOUD_TEMPLATE_CREDIT_APPROVED: 'credito_aprobado',
      }),
    );

    await expect(
      service.send({
        to: '+28928932832',
        kind: 'credito_aprobado',
        text: 'Tu credito fue aprobado',
        templateParameters: ['Ana', '$ 1.000.000'],
        externalId: 'credito-1',
      }),
    ).resolves.toBeUndefined();
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});
