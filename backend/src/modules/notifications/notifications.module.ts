import { Module } from '@nestjs/common';

import { PrismaModule } from '../../common/prisma/prisma.module';
import { EmailNotificationService } from './email-notification.service';
import { NotificationTemplatesService } from './notification-templates.service';
import { NotificationsService } from './notifications.service';
import { WhatsappNotificationService } from './whatsapp-notification.service';
import { YcloudWebhookController } from './ycloud-webhook.controller';

@Module({
  imports: [PrismaModule],
  controllers: [YcloudWebhookController],
  providers: [
    EmailNotificationService,
    NotificationTemplatesService,
    NotificationsService,
    WhatsappNotificationService,
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
