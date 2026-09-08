import { Module } from '@nestjs/common';

import { CacheModule } from '../../common/cache/cache.module';
import { PrismaModule } from '../../common/prisma/prisma.module';
import { TenancyModule } from '../../common/tenancy/tenancy.module';
import { AuthModule } from '../auth/auth.module';
import { RutasModule } from '../rutas/rutas.module';
import { ClientesController } from './clientes.controller';
import { ClientesService } from './clientes.service';

@Module({
  imports: [PrismaModule, TenancyModule, AuthModule, CacheModule, RutasModule],
  controllers: [ClientesController],
  providers: [ClientesService],
  exports: [ClientesService],
})
export class ClientesModule {}
