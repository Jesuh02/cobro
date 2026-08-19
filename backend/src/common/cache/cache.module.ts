import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

import { InMemoryCacheService } from './in-memory-cache.service';

@Module({
  imports: [ConfigModule],
  providers: [InMemoryCacheService],
  exports: [InMemoryCacheService],
})
export class CacheModule {}
