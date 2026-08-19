import { Module } from '@nestjs/common';

import { PrismaModule } from '../../common/prisma/prisma.module';
import { EmailNotificationService } from './email-notification.service';
import { NotificationTemplatesService } from './notification-templates.service';
import { NotificationsService } from './notifications.service';
import { WhatsappNotificationService } from './whatsapp-notification.service';

@Module({
  imports: [PrismaModule],
  providers: [
    EmailNotificationService,
    NotificationTemplatesService,
    NotificationsService,
    WhatsappNotificationService,
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
