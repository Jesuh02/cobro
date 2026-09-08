import { Module } from '@nestjs/common';

import { CacheModule } from '../../common/cache/cache.module';
import { PrismaModule } from '../../common/prisma/prisma.module';
import { TenancyModule } from '../../common/tenancy/tenancy.module';
import { AuthModule } from '../auth/auth.module';
import { ExportacionesModule } from '../exportaciones/exportaciones.module';
import { ExportacionesService } from '../exportaciones/exportaciones.service';
import { NotificationsModule } from '../notifications/notifications.module';
import { CobrosController } from './cobros.controller';
import { CobrosService } from './cobros.service';
import { ExportacionesR2Service } from './exportaciones-r2.service';
import { RoutingService } from './routing.service';

@Module({
  imports: [
    AuthModule,
    PrismaModule,
    TenancyModule,
    NotificationsModule,
    CacheModule,
    ExportacionesModule,
  ],
  controllers: [CobrosController],
  providers: [
    CobrosService,
    ExportacionesService,
    ExportacionesR2Service,
    RoutingService,
  ],
})
export class CobrosModule {}
