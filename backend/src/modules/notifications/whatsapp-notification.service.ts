import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { NotificationKind } from './notification.types';

@Injectable()
export class WhatsappNotificationService {
  private readonly logger = new Logger(WhatsappNotificationService.name);

  constructor(private readonly config: ConfigService) {}

  async send(input: {
    to: string;
    kind: NotificationKind;
    text: string;
    templateParameters: string[];
    externalId: string;
  }) {
    const explicitProvider =
      this.config.get<string>('WHATSAPP_PROVIDER')?.toLowerCase();
    const provider =
      explicitProvider ??
      (this.config.get<string>('OPENWA_BASE_URL') || !this.config.get<string>('YCLOUD_API_KEY')
        ? 'openwa'
        : 'ycloud');

    if (provider === 'openwa') {
      return this.sendOpenWa(input);
    }

    return this.sendYcloud(input);
  }

  private async sendOpenWa(input: {
    to: string;
    kind: NotificationKind;
    text: string;
    externalId: string;
  }) {
    const chatId = this.toOpenWaChatId(input.to);
    if (!chatId) {
      this.logger.warn(
        `No se envio ${input.kind} por Open-WA: numero invalido (${this.maskPhone(input.to)})`,
      );
      return;
    }

    const baseUrl = (
      this.config.get<string>('OPENWA_BASE_URL') ?? 'http://127.0.0.1:8080'
    ).replace(/\/$/, '');
    const apiKey = this.config.get<string>('OPENWA_API_KEY');

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    if (apiKey) {
      headers['api_key'] = apiKey;
      headers['X-API-Key'] = apiKey;
    }

    const payload = {
      args: {
        to: chatId,
        content: input.text,
      },
      to: chatId,
      content: input.text,
    };

    let response: Response;
    try {
      response = await fetch(`${baseUrl}/api/sendText`, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(15_000),
      });

      if (response.status === 404) {
        response = await fetch(`${baseUrl}/sendText`, {
          method: 'POST',
          headers,
          body: JSON.stringify(payload),
          signal: AbortSignal.timeout(15_000),
        });
      }
    } catch (networkError) {
      throw new Error(
        `No se pudo conectar con Open-WA en ${baseUrl}: ${networkError instanceof Error ? networkError.message : String(networkError)}`,
      );
    }

    if (!response.ok) {
      const responseBody = await this.safeResponse(response);
      throw new Error(
        `Open-WA respondio ${response.status}: ${responseBody}`,
      );
    }

    this.logger.log(
      `Mensaje ${input.kind} enviado via Open-WA a ${this.maskPhone(chatId)} (id=${input.externalId})`,
    );
  }

  private async sendYcloud(input: {
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
    const to = this.normalizeRecipientPhone(input.to);
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

    if (!to) {
      this.logger.warn(
        `No se envio ${input.kind} por WhatsApp: numero invalido (${this.maskPhone(input.to)})`,
      );
      return;
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
      const responseBody = await this.safeResponse(response);

      if (this.isInvalidRecipientPhone(response.status, responseBody)) {
        this.logger.warn(
          `No se envio ${input.kind} por WhatsApp: YCloud rechazo el numero ${this.maskPhone(to)}`,
        );
        return;
      }

      throw new Error(`YCloud respondio ${response.status}: ${responseBody}`);
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
      cobros_atrasados_cobrador: 'YCLOUD_TEMPLATE_COLLECTOR_OVERDUE',
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

  private normalizeRecipientPhone(value: string) {
    const trimmed = value.trim();
    const digits = trimmed.replace(/\D/g, '');
    const defaultCountryCode =
      this.config.get<string>('WHATSAPP_DEFAULT_COUNTRY_CODE') ?? '57';

    if (!digits) {
      return null;
    }

    if (trimmed.startsWith('+')) {
      return this.isLikelyE164(`+${digits}`) ? `+${digits}` : null;
    }

    if (digits.length === 10) {
      return `+${defaultCountryCode}${digits}`;
    }

    if (
      digits.startsWith(defaultCountryCode) &&
      digits.length === defaultCountryCode.length + 10
    ) {
      return `+${digits}`;
    }

    return null;
  }

  private toOpenWaChatId(value: string): string | null {
    const trimmed = value.trim();
    if (trimmed.endsWith('@c.us')) {
      return trimmed;
    }

    const digits = trimmed.replace(/\D/g, '');
    const defaultCountryCode =
      this.config.get<string>('WHATSAPP_DEFAULT_COUNTRY_CODE') ?? '57';

    if (!digits) {
      return null;
    }

    // Si tiene 10 dígitos (ej: número celular en Colombia: 3044271932)
    if (digits.length === 10) {
      return `${defaultCountryCode}${digits}@c.us`;
    }

    // Si ya empieza con el código de país y tiene 12 dígitos
    if (
      digits.startsWith(defaultCountryCode) &&
      digits.length === defaultCountryCode.length + 10
    ) {
      return `${digits}@c.us`;
    }

    // Teléfonos internacionales entre 10 y 15 dígitos
    if (digits.length >= 10 && digits.length <= 15) {
      return `${digits}@c.us`;
    }

    return null;
  }

  private isLikelyE164(value: string) {
    return /^\+[1-9]\d{7,14}$/.test(value);
  }

  private isInvalidRecipientPhone(status: number, responseBody: string) {
    if (status !== 400) {
      return false;
    }

    try {
      const parsed = JSON.parse(responseBody) as {
        error?: { code?: string; target?: string; message?: string };
      };

      return (
        parsed.error?.code === 'PARAM_INVALID' &&
        parsed.error?.target === 'to' &&
        (parsed.error.message ?? '').toLowerCase().includes('phone number')
      );
    } catch {
      return false;
    }
  }

  private maskPhone(value: string) {
    const normalized = value.trim();

    if (normalized.length <= 6) {
      return '***';
    }

    return `${normalized.slice(0, 3)}***${normalized.slice(-2)}`;
  }

  private async safeResponse(response: Response) {
    const body = await response.text();
    return body.slice(0, 500);
  }
}
