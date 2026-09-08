import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { Buffer } from 'node:buffer';

import { DomainError } from '../../common/domain/domain-error';

type R2Config = {
  accessKeyId: string;
  accountId: string;
  bucketName: string;
  secretAccessKey: string;
  signedUrlTtlSeconds: number;
};

const maxExportBytes = 25 * 1024 * 1024;

@Injectable()
export class ExportacionesR2Service {
  private client?: S3Client;

  constructor(private readonly config: ConfigService) {}

  async subirExcel(input: {
    carpeta: string;
    nombreArchivo: string;
    contenido: Buffer;
  }) {
    const config = this.obtenerConfig();
    if (
      !/^[a-z0-9-]{1,40}$/.test(input.carpeta) ||
      !/^[a-z0-9][a-z0-9._-]{0,119}\.xlsx$/i.test(input.nombreArchivo) ||
      input.contenido.length === 0 ||
      input.contenido.length > maxExportBytes
    ) {
      throw DomainError.validation(
        'La exportacion contiene un nombre o tamano no permitido',
        'R2_EXPORTACION_INVALIDA',
      );
    }

    const key = [
      'exportaciones',
      input.carpeta,
      new Date().toISOString().slice(0, 10),
      input.nombreArchivo,
    ].join('/');

    try {
      await this.obtenerCliente(config).send(
        new PutObjectCommand({
          Bucket: config.bucketName,
          Key: key,
          Body: input.contenido,
          ContentType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ContentDisposition: `attachment; filename="${input.nombreArchivo}"`,
        }),
      );
    } catch {
      throw DomainError.conflict(
        'No se pudo guardar el Excel en Cloudflare R2',
        'R2_EXPORTACION_FALLO',
      );
    }

    const url = await getSignedUrl(
      this.obtenerCliente(config),
      new GetObjectCommand({
        Bucket: config.bucketName,
        Key: key,
        ResponseContentDisposition: `attachment; filename="${input.nombreArchivo}"`,
        ResponseContentType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      }),
      { expiresIn: config.signedUrlTtlSeconds },
    );

    return {
      archivo: input.nombreArchivo,
      key,
      url,
      urlExpiraEnSegundos: config.signedUrlTtlSeconds,
    };
  }

  private obtenerCliente(config: R2Config) {
    this.client ??= new S3Client({
      region: 'auto',
      endpoint: `https://${config.accountId}.r2.cloudflarestorage.com`,
      forcePathStyle: true,
      credentials: {
        accessKeyId: config.accessKeyId,
        secretAccessKey: config.secretAccessKey,
      },
    });

    return this.client;
  }

  private obtenerConfig(): R2Config {
    const accessKeyId = this.requerirVariable('R2_ACCESS_KEY_ID');
    const accountId = this.requerirVariable('R2_ACCOUNT_ID');
    const bucketName = this.requerirVariable('R2_BUCKET_NAME');
    const secretAccessKey = this.requerirVariable('R2_SECRET_ACCESS_KEY');

    if (!/^[a-f0-9]{32}$/i.test(accountId)) {
      throw DomainError.validation(
        'R2_ACCOUNT_ID no tiene un formato valido',
        'R2_CONFIG_INVALIDA',
      );
    }
    if (!/^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(bucketName)) {
      throw DomainError.validation(
        'R2_BUCKET_NAME no tiene un formato valido',
        'R2_CONFIG_INVALIDA',
      );
    }

    return {
      accessKeyId,
      accountId,
      bucketName,
      secretAccessKey,
      signedUrlTtlSeconds: this.config.get<number>(
        'R2_SIGNED_URL_TTL_SECONDS',
        300,
      ),
    };
  }

  private requerirVariable(nombre: string) {
    const value = this.config.get<string>(nombre)?.trim();

    if (!value) {
      throw DomainError.validation(
        `Configura ${nombre} para exportar Excel`,
        'R2_CONFIG_INCOMPLETA',
      );
    }

    return value;
  }
}

