import {
  Body,
  Controller,
  Headers,
  HttpCode,
  Logger,
  Post,
} from '@nestjs/common';

type YcloudWebhookPayload = {
  id?: unknown;
  type?: unknown;
  [key: string]: unknown;
};

@Controller('webhooks/ycloud')
export class YcloudWebhookController {
  private readonly logger = new Logger(YcloudWebhookController.name);

  @Post()
  @HttpCode(200)
  handleWebhook(
    @Body() body: YcloudWebhookPayload,
    @Headers('ycloud-signature') signature?: string,
    @Headers('x-webhook-endpoint-id') endpointId?: string,
  ) {
    const eventId = typeof body.id === 'string' ? body.id : 'unknown';
    const eventType = typeof body.type === 'string' ? body.type : 'unknown';

    this.logger.log(
      `YCloud webhook received type=${eventType} id=${eventId} endpoint=${endpointId ?? 'unknown'} signed=${signature ? 'yes' : 'no'}`,
    );

    return { received: true };
  }
}
