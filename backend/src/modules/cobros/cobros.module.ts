import { Module } from '@nestjs/common';

import { CacheModule } from '../../common/cache/cache.module';
import { PrismaModule } from '../../common/prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { CobrosController } from './cobros.controller';
import { CobrosService } from './cobros.service';
import { ExportacionesR2Service } from './exportaciones-r2.service';

@Module({
  imports: [AuthModule, PrismaModule, NotificationsModule, CacheModule],
  controllers: [CobrosController],
  providers: [CobrosService, ExportacionesR2Service],
})
export class CobrosModule {}
