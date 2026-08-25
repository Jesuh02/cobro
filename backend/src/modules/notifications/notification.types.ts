export type NotificationKind =
  'credito_aprobado' | 'pago_recibido' | 'credito_finalizado';

export type NotificationContact = {
  nombre: string;
  correo: string | null;
  whatsapp: string | null;
};

export type BaseNotification = {
  kind: NotificationKind;
  eventId: string;
  orgId: string;
  cliId: string;
  creId: string;
  contact: NotificationContact;
  monedaCodigo: string;
};

export type CreditApprovedNotification = BaseNotification & {
  kind: 'credito_aprobado';
  valorPrincipal: number;
  valorTotal: number;
  numeroCuotas: number;
  valorCuota: number;
  primeraCuota: Date | null;
};

export type PaymentReceivedNotification = BaseNotification & {
  kind: 'pago_recibido';
  montoPagado: number;
  saldoPendiente: number;
  cuotasRestantes: number;
  proximaCuotaNumero: number | null;
  proximaCuotaValor: number | null;
  proximaCuotaFecha: Date | null;
};

export type CreditCompletedNotification = BaseNotification & {
  kind: 'credito_finalizado';
  valorPrincipal: number;
};

export type CustomerNotification =
  | CreditApprovedNotification
  | PaymentReceivedNotification
  | CreditCompletedNotification;

export type RenderedNotification = {
  subject: string;
  emailHtml: string;
  emailText: string;
  whatsappText: string;
  whatsappTemplateParameters: string[];
};
