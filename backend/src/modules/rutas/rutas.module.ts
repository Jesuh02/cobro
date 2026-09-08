import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { PrismaModule } from '../../common/prisma/prisma.module';
import { TenancyModule } from '../../common/tenancy/tenancy.module';
import { AuthModule } from '../auth/auth.module';
import { RoutingService } from './routing.service';
import { RutasController } from './rutas.controller';
import { RutasService } from './rutas.service';

@Module({
  imports: [ConfigModule, PrismaModule, TenancyModule, AuthModule],
  controllers: [RutasController],
  providers: [RutasService, RoutingService],
  exports: [RutasService, RoutingService],
})
export class RutasModule {}
