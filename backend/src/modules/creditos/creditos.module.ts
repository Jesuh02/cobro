import { Module, forwardRef } from '@nestjs/common';

import { CacheModule } from '../../common/cache/cache.module';
import { PrismaModule } from '../../common/prisma/prisma.module';
import { TenancyModule } from '../../common/tenancy/tenancy.module';
import { AuthModule } from '../auth/auth.module';
import { CajaMenorModule } from '../caja-menor/caja-menor.module';
import { ExportacionesModule } from '../exportaciones/exportaciones.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { RutasModule } from '../rutas/rutas.module';
import { CobrosModule } from '../cobros/cobros.module';
import { CreditosController } from './creditos.controller';
import { CreditosService } from './creditos.service';
import { PagosService } from './pagos.service';

@Module({
  imports: [
    PrismaModule,
    TenancyModule,
    AuthModule,
    CacheModule,
    ExportacionesModule,
    NotificationsModule,
    CajaMenorModule,
    forwardRef(() => RutasModule),
    forwardRef(() => CobrosModule),
  ],
  controllers: [CreditosController],
  providers: [CreditosService, PagosService],
  exports: [CreditosService, PagosService],
})
export class CreditosModule {}

