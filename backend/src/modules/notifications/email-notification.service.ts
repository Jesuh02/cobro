import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { Transporter } from 'nodemailer';

@Injectable()
export class EmailNotificationService {
  private readonly logger = new Logger(EmailNotificationService.name);
  private transporter: Transporter | null = null;

  constructor(private readonly config: ConfigService) {}

  async send(input: {
    to: string;
    recipientName: string;
    subject: string;
    html: string;
    text: string;
    idempotencyKey: string;
  }) {
    const resendKey = this.config.get<string>('RESEND_API_KEY');
    const fromEmail = this.config.get<string>('RESEND_FROM_EMAIL');

    if (resendKey && fromEmail) {
      try {
        const resendId = await this.sendWithResend(input, resendKey, fromEmail);
        this.logger.log(
          `Correo enviado por Resend: ${input.idempotencyKey}; destino=${this.maskEmail(input.to)}; resendId=${resendId}`,
        );
        return;
      } catch (error) {
        throw new Error(
          `Resend no pudo enviar ${input.idempotencyKey}; destino=${this.maskEmail(input.to)}; ${this.errorMessage(error)}`,
        );
      }
    }

    if (this.hasBrevoConfiguration()) {
      await this.sendWithBrevo(input, fromEmail);
      return;
    }

    throw new Error(
      'No hay un proveedor de correo configurado (Resend o Brevo)',
    );
  }

  private async sendWithResend(
    input: {
      to: string;
      recipientName: string;
      subject: string;
      html: string;
      text: string;
      idempotencyKey: string;
    },
    apiKey: string,
    fromEmail: string,
  ) {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': input.idempotencyKey,
        'User-Agent': 'cobro-notifications/1.0',
      },
      body: JSON.stringify({
        from: this.sender(fromEmail),
        to: [input.to],
        subject: input.subject,
        html: input.html,
        text: input.text,
        reply_to: this.config.get<string>('NOTIFICATION_REPLY_TO') || undefined,
      }),
      signal: AbortSignal.timeout(10_000),
    });

    const body = await this.safeJson(response);

    if (!response.ok) {
      throw new Error(
        `Resend respondio ${response.status}: ${JSON.stringify(body).slice(0, 500)}`,
      );
    }

    return this.isRecord(body) && typeof body.id === 'string'
      ? body.id
      : 'sin_id';
  }

  private async sendWithBrevo(
    input: {
      to: string;
      recipientName: string;
      subject: string;
      html: string;
      text: string;
      idempotencyKey: string;
    },
    preferredFromEmail: string | undefined,
  ) {
    const smtp = this.getTransporter();
    const fromEmail =
      this.config.get<string>('BREVO_FROM_EMAIL') ?? preferredFromEmail;

    if (!fromEmail) {
      throw new Error('BREVO_FROM_EMAIL o RESEND_FROM_EMAIL es obligatorio');
    }

    const result: unknown = await smtp.sendMail({
      from: this.sender(fromEmail),
      to: {
        address: input.to,
        name: input.recipientName,
      },
      subject: input.subject,
      html: input.html,
      text: input.text,
      replyTo: this.config.get<string>('NOTIFICATION_REPLY_TO') || undefined,
      headers: {
        'X-Notification-Id': input.idempotencyKey,
      },
    });

    this.logger.log(
      `Correo enviado por Brevo: ${input.idempotencyKey}; destino=${this.maskEmail(input.to)}; ${this.mailResultSummary(result)}`,
    );
  }

  private getTransporter() {
    if (this.transporter) {
      return this.transporter;
    }

    const port = this.config.get<number>('BREVO_SMTP_PORT') ?? 587;
    this.transporter = nodemailer.createTransport({
      host:
        this.config.get<string>('BREVO_SMTP_HOST') ??
        'smtp-relay.sendinblue.com',
      port,
      secure: port === 465,
      auth: {
        user: this.config.getOrThrow<string>('BREVO_SMTP_USER'),
        pass: this.config.getOrThrow<string>('BREVO_SMTP_PASSWORD'),
      },
      connectionTimeout: 10_000,
      greetingTimeout: 10_000,
      socketTimeout: 15_000,
    });

    return this.transporter;
  }

  private hasBrevoConfiguration() {
    return Boolean(
      this.config.get<string>('BREVO_SMTP_USER') &&
      this.config.get<string>('BREVO_SMTP_PASSWORD'),
    );
  }

  private sender(email: string) {
    const brand = this.config.get<string>('NOTIFICATION_BRAND_NAME') ?? 'Cobro';
    return `${brand} <${email}>`;
  }

  private mailResultSummary(result: unknown) {
    if (!this.isRecord(result)) {
      return 'resultado=smtp_aceptado';
    }

    const accepted = Array.isArray(result.accepted)
      ? result.accepted.length
      : 0;
    const rejected = Array.isArray(result.rejected)
      ? result.rejected.length
      : 0;

    return `aceptados=${accepted}; rechazados=${rejected}`;
  }

  private isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === 'object' && value !== null;
  }

  private async safeJson(response: Response) {
    const text = await response.text();

    try {
      return JSON.parse(text) as unknown;
    } catch {
      return { raw: text.slice(0, 500) };
    }
  }

  private maskEmail(email: string) {
    const [localPart, domain] = email.split('@');

    if (!domain) {
      return 'correo_invalido';
    }

    const visibleLocal = localPart.slice(0, 2);
    return `${visibleLocal}${'*'.repeat(Math.max(localPart.length - 2, 2))}@${domain}`;
  }

  private errorMessage(error: unknown) {
    return error instanceof Error ? error.message : String(error);
  }
}
