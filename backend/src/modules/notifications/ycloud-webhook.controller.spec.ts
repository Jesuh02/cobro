import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'node:crypto';

import { YcloudWebhookController } from './ycloud-webhook.controller';

describe('YcloudWebhookController', () => {
  const secret = 'webhook-secret-that-is-longer-than-32-characters';
  const config = new ConfigService({
    YCLOUD_WEBHOOK_SECRET: secret,
    YCLOUD_WEBHOOK_ENDPOINT_ID: 'endpoint-1',
    YCLOUD_WEBHOOK_TOLERANCE_SECONDS: 300,
  });
  const body = { id: 'evt_123456', type: 'whatsapp.message.updated' };
  const rawBody = Buffer.from(JSON.stringify(body));

  function signature(timestamp: string, payload = rawBody) {
    const value = createHmac('sha256', secret)
      .update(timestamp)
      .update('.')
      .update(payload)
      .digest('hex');
    return `t=${timestamp},s=${value}`;
  }

  it('accepts a current valid signature', () => {
    const controller = new YcloudWebhookController(config);
    const timestamp = String(Math.floor(Date.now() / 1000));

    expect(
      controller.handleWebhook(
        body,
        { rawBody } as never,
        signature(timestamp),
        'endpoint-1',
      ),
    ).toEqual({ received: true });
  });

  it('rejects a tampered payload and stale signature', () => {
    const controller = new YcloudWebhookController(config);
    const now = String(Math.floor(Date.now() / 1000));
    const old = String(Math.floor(Date.now() / 1000) - 1_000);

    expect(() =>
      controller.handleWebhook(
        body,
        { rawBody: Buffer.from('{}') } as never,
        signature(now),
        'endpoint-1',
      ),
    ).toThrow(UnauthorizedException);
    expect(() =>
      controller.handleWebhook(
        body,
        { rawBody } as never,
        signature(old),
        'endpoint-1',
      ),
    ).toThrow(UnauthorizedException);
  });
});
