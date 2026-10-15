import { Module } from '@nestjs/common';

import { PrismaModule } from '../../common/prisma/prisma.module';
import { TenancyModule } from '../../common/tenancy/tenancy.module';
import { CacheModule } from '../../common/cache/cache.module';
import { AuthModule } from '../auth/auth.module';
import { PapeleraController } from './papelera.controller';
import { PapeleraService } from './papelera.service';

@Module({
  imports: [PrismaModule, TenancyModule, CacheModule, AuthModule],
  controllers: [PapeleraController],
  providers: [PapeleraService],
  exports: [PapeleraService],
})
export class PapeleraModule {}
