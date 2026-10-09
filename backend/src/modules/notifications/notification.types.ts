export type NotificationKind =
  | 'credito_aprobado'
  | 'pago_recibido'
  | 'credito_finalizado'
  | 'cobros_atrasados_cobrador';

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
  fechaPago?: Date | null;
  numeroRecibo?: string | null;
};

export type CreditCompletedNotification = BaseNotification & {
  kind: 'credito_finalizado';
  valorPrincipal: number;
};

export type CollectorOverdueCollection = {
  cliente: string;
  ruta: string;
  fechaVencimiento: Date | null;
  saldoCuota: number;
  monedaCodigo: string;
};

export type CollectorOverdueNotification = {
  kind: 'cobros_atrasados_cobrador';
  eventId: string;
  contact: NotificationContact;
  totalAtrasados: number;
  cobros: CollectorOverdueCollection[];
};

export type CustomerNotification =
  | CreditApprovedNotification
  | PaymentReceivedNotification
  | CreditCompletedNotification
  | CollectorOverdueNotification;

export type RenderedNotification = {
  subject: string;
  emailHtml: string;
  emailText: string;
  whatsappText: string;
  whatsappTemplateParameters: string[];
};
