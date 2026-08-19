import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { NotificationKind } from './notification.types';

@Injectable()
export class WhatsappNotificationService {
  constructor(private readonly config: ConfigService) {}

  async send(input: {
    to: string;
    kind: NotificationKind;
    text: string;
    templateParameters: string[];
    externalId: string;
  }) {
    const apiKey = this.config.getOrThrow<string>('YCLOUD_API_KEY');
    const from = this.normalizePhone(
      this.config.getOrThrow<string>('YCLOUD_WHATSAPP_NUMBER'),
    );
    const to = this.normalizePhone(input.to);
    const baseUrl = (
      this.config.get<string>('YCLOUD_BASE_URL') ?? 'https://api.ycloud.com/v2'
    ).replace(/\/$/, '');
    const templateName = this.templateName(input.kind);
    const useDirectSend =
      this.config.get<boolean>('YCLOUD_USE_DIRECT_SEND') ?? false;

    if (!templateName && !useDirectSend) {
      throw new Error(
        `Falta la plantilla de WhatsApp para ${input.kind} y YCLOUD_USE_DIRECT_SEND esta desactivado`,
      );
    }

    const payload = templateName
      ? this.templatePayload({
          from,
          to,
          externalId: input.externalId,
          templateName,
          parameters: input.templateParameters,
        })
      : {
          from,
          to,
          type: 'text',
          text: { body: input.text, preview_url: false },
          externalId: input.externalId,
          category: 'utility',
          ttlSeconds: 43_200,
          useDirectSend: true,
          filterUnsubscribed: true,
          filterBlocked: true,
        };

    const response = await fetch(`${baseUrl}/whatsapp/messages`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': apiKey,
      },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(10_000),
    });

    if (!response.ok) {
      throw new Error(
        `YCloud respondio ${response.status}: ${await this.safeResponse(response)}`,
      );
    }
  }

  private templatePayload(input: {
    from: string;
    to: string;
    externalId: string;
    templateName: string;
    parameters: string[];
  }) {
    return {
      from: input.from,
      to: input.to,
      type: 'template',
      externalId: input.externalId,
      filterUnsubscribed: true,
      filterBlocked: true,
      template: {
        name: input.templateName,
        language: {
          code: this.config.get<string>('YCLOUD_TEMPLATE_LANGUAGE') ?? 'es_CO',
        },
        components: [
          {
            type: 'body',
            parameters: input.parameters.map((text) => ({
              type: 'text',
              text,
            })),
          },
        ],
      },
    };
  }

  private templateName(kind: NotificationKind) {
    const keyByKind: Record<NotificationKind, string> = {
      credito_aprobado: 'YCLOUD_TEMPLATE_CREDIT_APPROVED',
      pago_recibido: 'YCLOUD_TEMPLATE_PAYMENT_RECEIVED',
      credito_finalizado: 'YCLOUD_TEMPLATE_CREDIT_COMPLETED',
    };

    return this.config.get<string>(keyByKind[kind]);
  }

  private normalizePhone(value: string) {
    const trimmed = value.trim();
    const digits = trimmed.replace(/\D/g, '');
    const defaultCountryCode =
      this.config.get<string>('WHATSAPP_DEFAULT_COUNTRY_CODE') ?? '57';

    if (!digits) {
      throw new Error('El numero de WhatsApp esta vacio');
    }

    if (trimmed.startsWith('+')) {
      return `+${digits}`;
    }

    if (digits.length === 10) {
      return `+${defaultCountryCode}${digits}`;
    }

    return `+${digits}`;
  }

  private async safeResponse(response: Response) {
    const body = await response.text();
    return body.slice(0, 500);
  }
}
