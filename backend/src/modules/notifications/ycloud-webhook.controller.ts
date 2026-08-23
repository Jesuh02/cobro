import {
  Body,
  Controller,
  Headers,
  HttpCode,
  Logger,
  Post,
  RawBodyRequest,
  Req,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Throttle } from '@nestjs/throttler';
import { Request } from 'express';
import { createHmac, timingSafeEqual } from 'node:crypto';

type YcloudWebhookPayload = {
  id?: unknown;
  type?: unknown;
  [key: string]: unknown;
};

@Controller('webhooks/ycloud')
export class YcloudWebhookController {
  private readonly logger = new Logger(YcloudWebhookController.name);
  private readonly processedEvents = new Map<string, number>();

  constructor(private readonly config: ConfigService) {}

  @Post()
  @HttpCode(200)
  @Throttle({
    burst: { limit: 10, ttl: 1_000, blockDuration: 5_000 },
    minute: { limit: 120, ttl: 60_000, blockDuration: 60_000 },
    hour: { limit: 2_000, ttl: 3_600_000, blockDuration: 300_000 },
  })
  handleWebhook(
    @Body() body: YcloudWebhookPayload,
    @Req() request: RawBodyRequest<Request>,
    @Headers('ycloud-signature') signature?: string,
    @Headers('x-webhook-endpoint-id') endpointId?: string,
  ) {
    this.verifyRequest(request.rawBody, signature, endpointId);

    const eventId = this.safeEventValue(body.id);
    const eventType = this.safeEventValue(body.type);
    if (!eventId || !eventType) {
      throw new UnauthorizedException('Webhook invalido');
    }

    const now = Date.now();
    this.evictProcessedEvents(now);
    if (this.processedEvents.has(eventId)) {
      return { received: true };
    }
    this.processedEvents.set(eventId, now + 24 * 60 * 60 * 1000);

    this.logger.log(`YCloud webhook verified type=${eventType} id=${eventId}`);

    return { received: true };
  }

  private verifyRequest(
    rawBody: Buffer | undefined,
    signatureHeader: string | undefined,
    endpointId: string | undefined,
  ) {
    const secret = this.config.get<string>('YCLOUD_WEBHOOK_SECRET');
    if (
      !secret ||
      !rawBody ||
      !signatureHeader ||
      signatureHeader.length > 200
    ) {
      throw new UnauthorizedException('Webhook no autorizado');
    }

    const configuredEndpointId = this.config.get<string>(
      'YCLOUD_WEBHOOK_ENDPOINT_ID',
    );
    if (
      configuredEndpointId &&
      (!endpointId || !this.safeEqual(endpointId, configuredEndpointId))
    ) {
      throw new UnauthorizedException('Webhook no autorizado');
    }

    const parts = signatureHeader.split(',').map((part) => part.trim());
    const timestampParts = parts.filter((part) => part.startsWith('t='));
    const signatureParts = parts.filter((part) => part.startsWith('s='));
    if (timestampParts.length !== 1 || signatureParts.length !== 1) {
      throw new UnauthorizedException('Webhook no autorizado');
    }

    const timestamp = timestampParts[0].slice(2);
    const suppliedSignature = signatureParts[0].slice(2).toLowerCase();
    if (
      !/^\d{10}$/.test(timestamp) ||
      !/^[a-f0-9]{64}$/.test(suppliedSignature)
    ) {
      throw new UnauthorizedException('Webhook no autorizado');
    }

    const tolerance = this.config.get<number>(
      'YCLOUD_WEBHOOK_TOLERANCE_SECONDS',
      300,
    );
    const age = Math.abs(Math.floor(Date.now() / 1000) - Number(timestamp));
    if (age > tolerance) {
      throw new UnauthorizedException('Webhook no autorizado');
    }

    const expected = createHmac('sha256', secret)
      .update(timestamp)
      .update('.')
      .update(rawBody)
      .digest('hex');
    if (!this.safeEqual(suppliedSignature, expected)) {
      throw new UnauthorizedException('Webhook no autorizado');
    }
  }

  private safeEqual(left: string, right: string) {
    const leftBuffer = Buffer.from(left);
    const rightBuffer = Buffer.from(right);
    return (
      leftBuffer.length === rightBuffer.length &&
      timingSafeEqual(leftBuffer, rightBuffer)
    );
  }

  private safeEventValue(value: unknown) {
    if (
      typeof value !== 'string' ||
      value.length < 1 ||
      value.length > 255 ||
      !/^[A-Za-z0-9_.:-]+$/.test(value)
    ) {
      return null;
    }
    return value;
  }

  private evictProcessedEvents(now: number) {
    for (const [eventId, expiresAt] of this.processedEvents) {
      if (expiresAt <= now) {
        this.processedEvents.delete(eventId);
      }
    }
    while (this.processedEvents.size >= 2_000) {
      const oldest = this.processedEvents.keys().next().value;
      if (!oldest) {
        break;
      }
      this.processedEvents.delete(oldest);
    }
  }
}
