import { Prisma } from '@prisma/client';

export type CreditoListadoRow = {
  credito_id: string;
  cliente_id: string;
  cliente: string;
  cedula: string | null;
  negocio: string | null;
  direccion: string | null;
  ruta_id: string;
  ruta: string;
  caja_menor_id: string | null;
  caja_menor: string | null;
  moneda_codigo: string;
  frecuencia_pago_id: number;
  frecuencia_codigo: string;
  frecuencia_nombre: string;
  dias_intervalo: number;
  estado_codigo: string;
  estado_nombre: string;
  valor_principal: Prisma.Decimal;
  porcentaje_interes: Prisma.Decimal;
  plazo_dias: number;
  omitir_domingos: boolean;
  valor_total: Prisma.Decimal;
  valor_cuota: Prisma.Decimal;
  total_abonado: Prisma.Decimal;
  saldo: Prisma.Decimal;
  numero_cuotas: number;
  cuotas_restantes: number;
  fecha_inicio: Date;
  fecha_maxima: Date;
  refinanciado_en: Date | null;
  valor_principal_anterior: Prisma.Decimal | null;
  valor_principal_refinanciado: Prisma.Decimal | null;
  observacion: string | null;
  creado_en: Date;
  actualizado_en: Date;
};

export type CreditoTblRow = {
  credito_id: string;
  cliente_id: string;
  cliente: string;
  cedula: string | null;
  negocio: string | null;
  direccion: string | null;
  ruta_id: string | null;
  ruta: string | null;
  caja_menor_id: string | null;
  caja_menor: string | null;
  moneda_codigo: string;
  frecuencia_id: string;
  frecuencia_codigo: string;
  frecuencia_nombre: string;
  estado_codigo: string;
  fecha_inicio: Date;
  fecha_fin: Date;
  valor_principal: Prisma.Decimal;
  porcentaje_interes: Prisma.Decimal;
  interes_total: Prisma.Decimal;
  valor_total: Prisma.Decimal;
  numero_cuotas: number;
  valor_cuota: Prisma.Decimal;
  total_abonado: Prisma.Decimal;
  cuotas_restantes: number;
};

export type CuotaCreditoRow = {
  credito_cuota_id: string;
  numero_cuota: number;
  fecha_vencimiento: Date;
  estado_codigo: string;
  estado_nombre: string;
  valor_capital: Prisma.Decimal;
  valor_interes: Prisma.Decimal;
  valor_total: Prisma.Decimal;
  abonado: Prisma.Decimal;
  saldo: Prisma.Decimal;
};

export type CuotaCreditoTblRow = {
  credito_cuota_id: string;
  numero_cuota: number;
  fecha_vencimiento: Date;
  estado_codigo: string;
  estado_nombre: string;
  valor_capital: Prisma.Decimal;
  valor_interes: Prisma.Decimal;
  valor_total: Prisma.Decimal;
  abonado: Prisma.Decimal;
  saldo: Prisma.Decimal;
};

export type PagoTblRow = {
  pago_id: string;
  credito_id: string;
  cliente_id: string;
  cliente: string;
  ruta_id: string | null;
  ruta: string | null;
  medio_pago_id: string;
  medio_pago_codigo: string;
  medio_pago_nombre: string;
  moneda_codigo: string;
  fecha_pago: Date;
  total_pagado: Prisma.Decimal;
  referencia_externa: string | null;
};

export type PlanCalculado = {
  numeroCuotas: number;
  valorCuota: number;
  valorTotal: number;
  fechaMaxima: Date;
  domingosOmitidos: number;
  cuotas: Array<{
    numeroCuota: number;
    fechaVencimiento: Date;
    valorCapital: number;
    valorInteres: number;
  }>;
};

export type SumaAplicaciones = {
  _sum: {
    montoCapital: Prisma.Decimal | null;
    montoInteres: Prisma.Decimal | null;
    montoMora: Prisma.Decimal | null;
    montoDescuento: Prisma.Decimal | null;
  };
};

export type CreditoExportado = {
  cliente: string;
  cedula: string | null;
  negocio: string | null;
  direccion: string | null;
  ruta: string;
  cajaMenor: string | null;
  estado: { codigo: string; nombre: string };
  monedaCodigo: string;
  frecuenciaPago: {
    id: number;
    codigo: string;
    nombre: string;
    diasIntervalo: number;
  };
  valorPrincipal: number;
  porcentajeInteres: number;
  valorTotal: number;
  valorCuota: number;
  totalAbonado: number;
  saldo: number;
  numeroCuotas: number;
  cuotasRestantes: number;
  fechaInicio: string;
  fechaMaxima: string;
  refinanciacion?: {
    valorAnterior: number;
    valorNuevo: number;
  } | null;
  observacion?: string | null;
  creadoEn: string;
};

