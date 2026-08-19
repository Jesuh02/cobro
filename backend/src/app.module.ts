import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER } from '@nestjs/core';
import { resolve } from 'node:path';

import { DomainExceptionFilter } from './common/http/domain-exception.filter';
import { PrismaModule } from './common/prisma/prisma.module';
import { validateEnv } from './config/env.validation';
import { AuthModule } from './modules/auth/auth.module';
import { CobrosModule } from './modules/cobros/cobros.module';
import { HealthModule } from './modules/health/health.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      envFilePath: [
        resolve(process.cwd(), 'backend/.env'),
        resolve(process.cwd(), '.env'),
      ],
      isGlobal: true,
      validatePredefined: process.env.NODE_ENV === 'production',
      validate: validateEnv,
    }),
    PrismaModule,
    HealthModule,
    AuthModule,
    CobrosModule,
  ],
  providers: [
    {
      provide: APP_FILTER,
      useClass: DomainExceptionFilter,
    },
  ],
})
export class AppModule {}
