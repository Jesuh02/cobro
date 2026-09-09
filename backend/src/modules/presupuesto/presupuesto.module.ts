import { Module } from '@nestjs/common';

import { PrismaModule } from '../../common/prisma/prisma.module';
import { TenancyModule } from '../../common/tenancy/tenancy.module';
import { AuthModule } from '../auth/auth.module';
import { PresupuestoController } from './presupuesto.controller';
import { PresupuestoService } from './presupuesto.service';

@Module({
  imports: [PrismaModule, TenancyModule, AuthModule],
  controllers: [PresupuestoController],
  providers: [PresupuestoService],
  exports: [PresupuestoService],
})
export class PresupuestoModule {}

