import { Module } from '@nestjs/common';

import { CacheModule } from '../../common/cache/cache.module';
import { PrismaModule } from '../../common/prisma/prisma.module';
import { AuthController } from './auth.controller';
import { AuthGuard } from './auth.guard';
import { AuthService } from './auth.service';
import { PasswordService } from './password.service';

@Module({
  imports: [PrismaModule, CacheModule],
  controllers: [AuthController],
  providers: [AuthGuard, AuthService, PasswordService],
  exports: [AuthGuard, AuthService],
})
export class AuthModule {}
