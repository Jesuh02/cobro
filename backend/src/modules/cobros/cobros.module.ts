import { Module } from '@nestjs/common';

import { PrismaModule } from '../../common/prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { CobrosController } from './cobros.controller';
import { CobrosService } from './cobros.service';

@Module({
  imports: [AuthModule, PrismaModule, NotificationsModule],
  controllers: [CobrosController],
  providers: [CobrosService],
})
export class CobrosModule {}
