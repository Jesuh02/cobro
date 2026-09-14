import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { json, NextFunction, Request, Response } from 'express';
import helmet from 'helmet';
import { randomUUID } from 'node:crypto';
import 'reflect-metadata';

import { AppModule } from './app.module';

// Permite serializar campos BigInt a JSON como numeros seguros (evitando TypeErrors de serializacion y en frontend)
(BigInt.prototype as any).toJSON = function () {
  const num = Number(this);
  return Number.isSafeInteger(num) ? num : this.toString();
};

async function bootstrap() {
  const requestLogger = new Logger('HTTP');
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bodyParser: false,
  });
  const config = app.get(ConfigService);
  const port = config.get<number>('PORT', 3000);
  const host = config.get<string>('HOST', process.env.PORT ? '0.0.0.0' : '127.0.0.1');
  const corsOrigin = config.get<string>('CORS_ORIGIN', '*');
  const trustProxyHops = config.get<number>('TRUST_PROXY_HOPS', 0);
  const enforceHttps = config.get<boolean>('ENFORCE_HTTPS', false);

  app.disable('x-powered-by');
  if (trustProxyHops > 0) {
    app.set('trust proxy', trustProxyHops);
  }

  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'none'"],
          baseUri: ["'none'"],
          frameAncestors: ["'none'"],
          formAction: ["'none'"],
        },
      },
      crossOriginResourcePolicy: { policy: 'same-site' },
      referrerPolicy: { policy: 'no-referrer' },
    }),
  );

  app.use((request: Request, response: Response, next: NextFunction) => {
    const requestId = randomUUID();
    const startedAt = Date.now();
    response.setHeader('X-Request-ID', requestId);
    response.setHeader('Cache-Control', 'no-store, max-age=0');
    response.setHeader('Pragma', 'no-cache');
    response.setHeader('Expires', '0');

    response.on('finish', () => {
      requestLogger.log(
        `${request.method} ${request.originalUrl} ${response.statusCode} ${Date.now() - startedAt}ms requestId=${requestId}`,
      );
    });

    if (enforceHttps && !request.secure) {
      response.status(426).json({
        statusCode: 426,
        code: 'HTTPS_REQUIRED',
        message: 'HTTPS es obligatorio',
        requestId,
      });
      return;
    }

    next();
  });

  app.use(
    json({
      limit: '64kb',
      strict: true,
      type: ['application/json', 'application/*+json'],
      verify: (request, _response, buffer) => {
        (request as Request & { rawBody?: Buffer }).rawBody =
          Buffer.from(buffer);
      },
    }),
  );

  app.setGlobalPrefix('api/v1');
  app.enableCors({
    origin:
      corsOrigin === '*'
        ? true
        : corsOrigin.split(',').map((origin) => origin.trim()),
    allowedHeaders: ['Authorization', 'Content-Type', 'X-Request-ID'],
    exposedHeaders: [
      'X-Request-ID',
      'Retry-After',
      'X-RateLimit-Limit',
      'X-RateLimit-Remaining',
      'X-RateLimit-Reset',
    ],
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    maxAge: 600,
    optionsSuccessStatus: 204,
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      forbidUnknownValues: true,
      transform: true,
      transformOptions: { enableImplicitConversion: false },
      validationError: { target: false, value: false },
      stopAtFirstError: true,
    }),
  );

  app.enableShutdownHooks();
  await app.listen(port, host);

  const server = app.getHttpServer() as {
    headersTimeout: number;
    keepAliveTimeout: number;
    maxRequestsPerSocket: number;
    requestTimeout: number;
  };
  server.headersTimeout = 15_000;
  server.keepAliveTimeout = 5_000;
  server.requestTimeout = 60_000;
  server.maxRequestsPerSocket = 1_000;
}

void bootstrap();
