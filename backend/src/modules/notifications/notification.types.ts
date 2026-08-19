export type NotificationKind =
  'credito_aprobado' | 'pago_recibido' | 'credito_finalizado';

export type NotificationContact = {
  nombre: string;
  correo: string | null;
  whatsapp: string | null;
};

export type CreditApprovedNotification = {
  kind: 'credito_aprobado';
  eventId: string;
  contact: NotificationContact;
  monedaCodigo: string;
  valorPrincipal: number;
  valorTotal: number;
  numeroCuotas: number;
  valorCuota: number;
  primeraCuota: Date | null;
};

export type PaymentReceivedNotification = {
  kind: 'pago_recibido';
  eventId: string;
  contact: NotificationContact;
  monedaCodigo: string;
  montoPagado: number;
  saldoPendiente: number;
  cuotasRestantes: number;
  proximaCuotaNumero: number | null;
  proximaCuotaValor: number | null;
  proximaCuotaFecha: Date | null;
};

export type CreditCompletedNotification = {
  kind: 'credito_finalizado';
  eventId: string;
  contact: NotificationContact;
  monedaCodigo: string;
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
