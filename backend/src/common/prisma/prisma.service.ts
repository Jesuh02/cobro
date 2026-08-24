import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { Prisma, PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(PrismaService.name);

  async onModuleInit() {
    try {
      await this.$connect();
    } catch (error) {
      if (!this.isDatabaseUnavailable(error)) {
        throw error;
      }

      this.logger.warn(
        'No hay conexion inicial con la base de datos; la API iniciara y las consultas responderan 503 hasta que Supabase este disponible.',
      );
    }
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }

  private isDatabaseUnavailable(error: unknown) {
    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      return ['P1001', 'P1002', 'P1008', 'P1017', 'P2024'].includes(error.code);
    }

    return (
      error instanceof Prisma.PrismaClientInitializationError ||
      error instanceof Prisma.PrismaClientRustPanicError
    );
  }
}
