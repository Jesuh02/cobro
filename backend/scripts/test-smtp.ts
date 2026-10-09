import { config } from 'dotenv';
import { ConfigService } from '@nestjs/config';
import { EmailNotificationService } from '../src/modules/notifications/email-notification.service';
import { NotificationTemplatesService } from '../src/modules/notifications/notification-templates.service';

config();

async function main() {
  const targetEmail = process.argv[2];

  console.log('--- Diagnóstico y Prueba de Correo SMTP (Gmail / Alias) ---');
  console.log(`Host: ${process.env.SMTP_HOST || 'smtp.gmail.com'}`);
  console.log(`Puerto: ${process.env.SMTP_PORT || '465'}`);
  console.log(`Seguro (SSL): ${process.env.SMTP_SECURE || 'true'}`);
  console.log(`Usuario autenticación: ${process.env.SMTP_USER || '(no configurado)'}`);
  console.log(`Nombre remitente (Alias): ${process.env.SMTP_FROM_NAME || 'Cobro Notificaciones'}`);
  console.log(`Correo remitente: ${process.env.SMTP_FROM_EMAIL || process.env.SMTP_USER || '(no configurado)'}`);

  const configService = new ConfigService(process.env);
  const emailService = new EmailNotificationService(configService);
  const templatesService = new NotificationTemplatesService(configService);

  console.log('\n1. Verificando conexión y credenciales con el servidor SMTP...');
  const verifyResult = await emailService.verifyConnection();

  if (!verifyResult.success) {
    console.error(`❌ Error en handshake SMTP: ${verifyResult.message}`);
    console.log('\nConsejos para Gmail:');
    console.log('1. Asegúrate de tener activa la verificación en 2 pasos en tu cuenta de Google.');
    console.log('2. Genera una "Contraseña de aplicación" en: https://myaccount.google.com/apppasswords');
    console.log('3. Coloca esa contraseña de 16 caracteres en SMTP_PASSWORD en backend/.env.');
    process.exit(1);
  }

  console.log(`✅ ${verifyResult.message}`);

  if (!targetEmail) {
    console.log('\n💡 Conexión verificada con éxito. Para enviar un correo de prueba real con la plantilla institucional, ejecuta:');
    console.log('   pnpm tsx scripts/test-smtp.ts tu_correo_personal@dominio.com\n');
    return;
  }

  console.log(`\n2. Generando plantilla institucional HTML y enviando correo de prueba a ${targetEmail}...`);

  const rendered = templatesService.render({
    kind: 'credito_aprobado',
    eventId: `test-${Date.now()}`,
    orgId: '00000000-0000-0000-0000-000000000000',
    cliId: '00000000-0000-0000-0000-000000000000',
    creId: '00000000-0000-0000-0000-000000000000',
    contact: {
      nombre: 'Usuario de Prueba',
      correo: targetEmail,
      whatsapp: null,
    },
    monedaCodigo: 'COP',
    valorPrincipal: 1500000,
    valorTotal: 1800000,
    numeroCuotas: 24,
    valorCuota: 75000,
    primeraCuota: new Date(),
  });

  await emailService.send({
    to: targetEmail,
    recipientName: 'Usuario de Prueba',
    subject: `[Prueba SMTP] ${rendered.subject}`,
    html: rendered.emailHtml,
    text: rendered.emailText,
    idempotencyKey: `test-smtp-${Date.now()}`,
  });

  console.log('🎉 ¡Correo de prueba enviado con éxito! Revisa tu bandeja de entrada o carpeta de spam.');
}

main().catch((err) => {
  console.error('\n❌ Error al ejecutar prueba:', err.message || err);
  process.exit(1);
});
