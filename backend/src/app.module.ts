import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
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
    ThrottlerModule.forRoot([
      {
        name: 'burst',
        ttl: 1_000,
        limit: 20,
        blockDuration: 2_000,
      },
      {
        name: 'minute',
        ttl: 60_000,
        limit: 180,
        blockDuration: 60_000,
      },
      {
        name: 'hour',
        ttl: 3_600_000,
        limit: 3_000,
        blockDuration: 300_000,
      },
    ]),
    PrismaModule,
    HealthModule,
    AuthModule,
    CobrosModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      provide: APP_FILTER,
      useClass: DomainExceptionFilter,
    },
  ],
})
export class AppModule {}
