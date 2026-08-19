import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { Buffer } from 'node:buffer';

import { DomainError } from '../../common/domain/domain-error';

type R2Config = {
  accessKeyId: string;
  accountId: string;
  bucketName: string;
  publicUrl: string;
  secretAccessKey: string;
};

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

    return {
      archivo: input.nombreArchivo,
      key,
      url: `${config.publicUrl}/${this.codificarKey(key)}`,
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
    const publicUrl = this.requerirVariable('R2_PUBLIC_URL').replace(/\/$/, '');
    const secretAccessKey = this.requerirVariable('R2_SECRET_ACCESS_KEY');

    return {
      accessKeyId,
      accountId,
      bucketName,
      publicUrl,
      secretAccessKey,
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

  private codificarKey(key: string) {
    return key.split('/').map(encodeURIComponent).join('/');
  }
}
