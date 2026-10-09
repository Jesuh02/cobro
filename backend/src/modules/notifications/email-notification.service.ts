import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { Transporter } from 'nodemailer';

export type SendEmailInput = {
  to: string;
  recipientName: string;
  subject: string;
  html: string;
  text: string;
  idempotencyKey: string;
};

@Injectable()
export class EmailNotificationService {
  private readonly logger = new Logger(EmailNotificationService.name);
  private transporter: Transporter | null = null;

  constructor(private readonly config: ConfigService) {}

  async send(input: SendEmailInput): Promise<void> {
    const smtp = this.getTransporter();

    const fromName =
      this.config.get<string>('SMTP_FROM_NAME') ||
      this.config.get<string>('NOTIFICATION_BRAND_NAME') ||
      'Cobro';

    const fromEmail =
      this.config.get<string>('SMTP_FROM_EMAIL') ||
      this.config.get<string>('SMTP_USER');

    if (!fromEmail) {
      throw new Error(
        'SMTP_FROM_EMAIL o SMTP_USER es obligatorio para enviar correos',
      );
    }

    const replyTo =
      this.config.get<string>('SMTP_REPLY_TO') ||
      this.config.get<string>('NOTIFICATION_REPLY_TO') ||
      undefined;

    // Encabezado From con Alias según RFC 5322 (ej: "Cobro Notificaciones" <micorreo@gmail.com>)
    const fromHeader = `"${fromName}" <${fromEmail}>`;

    try {
      const result: unknown = await smtp.sendMail({
        from: fromHeader,
        to: {
          address: input.to,
          name: input.recipientName,
        },
        subject: input.subject,
        html: input.html,
        text: input.text,
        replyTo,
        headers: {
          'X-Notification-Id': input.idempotencyKey,
        },
      });

      this.logger.log(
        `Correo enviado por SMTP: ${input.idempotencyKey}; destino=${this.maskEmail(input.to)}; remitente="${fromName}" <${fromEmail}>; ${this.mailResultSummary(result)}`,
      );
    } catch (error) {
      const errorMsg = this.errorMessage(error);
      this.logger.error(
        `Fallo al enviar correo por SMTP: ${input.idempotencyKey}; destino=${this.maskEmail(input.to)}; error=${errorMsg}`,
      );
      throw new Error(`SMTP no pudo enviar ${input.idempotencyKey}: ${errorMsg}`);
    }
  }

  /**
   * Verifica la conexión y autenticación con el servidor SMTP (ej: Gmail).
   */
  async verifyConnection(): Promise<{ success: boolean; message: string }> {
    try {
      const smtp = this.getTransporter();
      await smtp.verify();
      return {
        success: true,
        message: 'Conexión SMTP verificada y autenticada exitosamente',
      };
    } catch (error) {
      return {
        success: false,
        message: `Error al verificar conexión SMTP: ${this.errorMessage(error)}`,
      };
    }
  }

  private getTransporter(): Transporter {
    if (this.transporter) {
      return this.transporter;
    }

    const host = this.config.get<string>('SMTP_HOST') || 'smtp.gmail.com';
    const port = Number(this.config.get<number>('SMTP_PORT') ?? 465);
    const secure = this.config.get<boolean>('SMTP_SECURE') ?? (port === 465);
    const user = this.config.get<string>('SMTP_USER');
    const pass = this.config.get<string>('SMTP_PASSWORD');

    if (!user || !pass) {
      throw new Error(
        'No hay credenciales SMTP configuradas (SMTP_USER y SMTP_PASSWORD son obligatorios)',
      );
    }

    this.transporter = nodemailer.createTransport({
      host,
      port,
      secure,
      auth: {
        user,
        pass,
      },
      connectionTimeout: 10_000,
      greetingTimeout: 10_000,
      socketTimeout: 15_000,
      disableFileAccess: true,
      disableUrlAccess: true,
    });

    return this.transporter;
  }

  private mailResultSummary(result: unknown): string {
    if (!this.isRecord(result)) {
      return 'resultado=smtp_aceptado';
    }

    const accepted = Array.isArray(result.accepted)
      ? result.accepted.length
      : 0;
    const rejected = Array.isArray(result.rejected)
      ? result.rejected.length
      : 0;
    const messageId = typeof result.messageId === 'string' ? result.messageId : 'sin_id';

    return `messageId=${messageId}; aceptados=${accepted}; rechazados=${rejected}`;
  }

  private isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === 'object' && value !== null;
  }

  private maskEmail(email: string): string {
    const [localPart, domain] = email.split('@');

    if (!domain) {
      return 'correo_invalido';
    }

    const visibleLocal = localPart.slice(0, 2);
    return `${visibleLocal}${'*'.repeat(Math.max(localPart.length - 2, 2))}@${domain}`;
  }

  private errorMessage(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
  }
}

