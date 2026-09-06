import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Request, Response } from 'express';

import { DomainError } from '../domain/domain-error';

@Catch()
export class DomainExceptionFilter implements ExceptionFilter<unknown> {
  private readonly logger = new Logger(DomainExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const context = host.switchToHttp();
    const response = context.getResponse<Response>();
    const request = context.getRequest<Request>();
    const requestId = String(response.getHeader('X-Request-ID') ?? 'unknown');
    const { statusCode, code, message } = this.mapException(exception);

    if (statusCode >= 500) {
      const errorType =
        exception instanceof Error ? exception.name : typeof exception;
      const prismaCode =
        exception instanceof Prisma.PrismaClientKnownRequestError
          ? ` code=${exception.code}`
          : '';
      const errorMessage =
        exception instanceof Error ? exception.message : String(exception);
      const errorStack =
        exception instanceof Error ? exception.stack : undefined;
      this.logger.error(
        `Unhandled error requestId=${requestId} method=${request.method} path=${request.path} type=${errorType}${prismaCode} message="${errorMessage}"`,
        errorStack,
      );
    }

    response.status(statusCode).json({
      statusCode,
      code,
      message,
      path: request.path,
      requestId,
      timestamp: new Date().toISOString(),
    });
  }

  private mapException(exception: unknown) {
    if (exception instanceof DomainError) {
      return {
        statusCode: this.mapDomainStatus(exception),
        code: exception.code,
        message: exception.message,
      };
    }

    if (exception instanceof HttpException) {
      const statusCode = exception.getStatus();
      const response = exception.getResponse();
      return {
        statusCode,
        code: this.httpCode(statusCode, response),
        message: this.httpMessage(statusCode, response),
      };
    }

    if (this.isDatabaseUnavailable(exception)) {
      return {
        statusCode: HttpStatus.SERVICE_UNAVAILABLE,
        code: 'DATABASE_UNAVAILABLE',
        message:
          'No hay conexion con la base de datos. La accion puede guardarse para sincronizar luego.',
      };
    }

    return {
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      code: 'INTERNAL_ERROR',
      message: 'Ocurrio un error interno',
    };
  }

  private mapDomainStatus(exception: DomainError) {
    switch (exception.kind) {
      case 'validation':
        return HttpStatus.BAD_REQUEST;
      case 'not_found':
        return HttpStatus.NOT_FOUND;
      case 'conflict':
        return HttpStatus.CONFLICT;
    }
  }

  private httpCode(statusCode: number, response: string | object) {
    if (
      typeof response === 'object' &&
      response !== null &&
      'code' in response
    ) {
      const code = (response as { code?: unknown }).code;
      if (typeof code === 'string' && /^[A-Z0-9_]{1,64}$/.test(code)) {
        return code;
      }
    }

    const knownCodes: Record<number, string> = {
      400: 'BAD_REQUEST',
      401: 'UNAUTHORIZED',
      403: 'FORBIDDEN',
      404: 'NOT_FOUND',
      413: 'PAYLOAD_TOO_LARGE',
      415: 'UNSUPPORTED_MEDIA_TYPE',
      429: 'RATE_LIMITED',
    };
    return knownCodes[statusCode] ?? `HTTP_${statusCode}`;
  }

  private httpMessage(statusCode: number, response: string | object) {
    if (statusCode >= 500) {
      return 'Ocurrio un error interno';
    }
    if (statusCode === 404) {
      return 'Recurso no encontrado';
    }
    if (statusCode === 413) {
      return 'La solicitud supera el tamano permitido';
    }
    if (statusCode === 429) {
      return 'Demasiadas solicitudes; intenta mas tarde';
    }

    const rawMessage =
      typeof response === 'object' && response !== null && 'message' in response
        ? (response as { message?: unknown }).message
        : response;

    if (Array.isArray(rawMessage)) {
      return rawMessage
        .filter((item): item is string => typeof item === 'string')
        .slice(0, 10)
        .map((item) => item.slice(0, 240));
    }
    if (typeof rawMessage === 'string') {
      return rawMessage.slice(0, 500);
    }
    return 'Solicitud no valida';
  }

  private isDatabaseUnavailable(exception: unknown) {
    if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      return ['P1001', 'P1002', 'P1008', 'P1017', 'P2024'].includes(
        exception.code,
      );
    }

    if (exception instanceof Prisma.PrismaClientInitializationError) {
      return true;
    }

    if (exception instanceof Prisma.PrismaClientRustPanicError) {
      return true;
    }

    return false;
  }
}
