import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { ExportacionesR2Service } from './exportaciones-r2.service';
import { ExportacionesService } from './exportaciones.service';

@Module({
  imports: [ConfigModule],
  providers: [ExportacionesR2Service, ExportacionesService],
  exports: [ExportacionesR2Service, ExportacionesService],
})
export class ExportacionesModule {}
