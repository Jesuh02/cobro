import { Module, forwardRef } from '@nestjs/common';

import { CacheModule } from '../../common/cache/cache.module';
import { PrismaModule } from '../../common/prisma/prisma.module';
import { TenancyModule } from '../../common/tenancy/tenancy.module';
import { AuthModule } from '../auth/auth.module';
import { ExportacionesModule } from '../exportaciones/exportaciones.module';
import { CobrosModule } from '../cobros/cobros.module';
import { CajaMenorController } from './caja-menor.controller';
import { CajaMenorService } from './caja-menor.service';

@Module({
  imports: [
    PrismaModule,
    TenancyModule,
    AuthModule,
    CacheModule,
    ExportacionesModule,
    forwardRef(() => CobrosModule),
  ],
  controllers: [CajaMenorController],
  providers: [CajaMenorService],
  exports: [CajaMenorService],
})
export class CajaMenorModule {}
