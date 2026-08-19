import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpStatus,
} from '@nestjs/common';
import { Request, Response } from 'express';

import { DomainError } from '../domain/domain-error';

@Catch(DomainError)
export class DomainExceptionFilter implements ExceptionFilter<DomainError> {
  catch(exception: DomainError, host: ArgumentsHost) {
    const context = host.switchToHttp();
    const response = context.getResponse<Response>();
    const request = context.getRequest<Request>();
    const statusCode = this.mapStatus(exception);

    response.status(statusCode).json({
      statusCode,
      code: exception.code,
      message: exception.message,
      path: request.url,
      timestamp: new Date().toISOString(),
    });
  }

  private mapStatus(exception: DomainError) {
    switch (exception.kind) {
      case 'validation':
        return HttpStatus.BAD_REQUEST;
      case 'not_found':
        return HttpStatus.NOT_FOUND;
      case 'conflict':
        return HttpStatus.CONFLICT;
    }
  }
}
