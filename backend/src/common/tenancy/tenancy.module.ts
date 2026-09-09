import { Module } from '@nestjs/common';

import { PrismaModule } from '../prisma/prisma.module';
import { TenantScopeService } from './tenant-scope.service';

@Module({
  imports: [PrismaModule],
  providers: [TenantScopeService],
  exports: [TenantScopeService],
})
export class TenancyModule {}
