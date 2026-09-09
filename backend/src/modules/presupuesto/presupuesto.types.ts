import { Prisma } from '@prisma/client';

export type PresupuestoRow = {
  caja_menor_id: string;
  caja_menor_nombre: string;
  responsable_usuario_id: string;
  moneda_codigo: string;
  caja_menor: Prisma.Decimal;
  recaudado: Prisma.Decimal;
  gastos: Prisma.Decimal;
  creditos: Prisma.Decimal;
  presupuesto: Prisma.Decimal;
};

export type PresupuestoTblRow = {
  caja_menor_id: string;
  caja_menor_nombre: string;
  responsable_usuario_id: string;
  moneda_codigo: string;
  caja_menor: Prisma.Decimal;
  recaudado: Prisma.Decimal;
  gastos: Prisma.Decimal;
  creditos: Prisma.Decimal;
  presupuesto: Prisma.Decimal;
};

export type PresupuestoItem = {
  cajaMenorId: string;
  cajaMenorNombre: string;
  responsableUsuarioId: string;
  monedaCodigo: string;
  cajaMenor: number;
  recaudado: number;
  gastos: number;
  creditos: number;
  presupuesto: number;
};

export type PresupuestoTotales = {
  cajaMenor: number;
  recaudado: number;
  gastos: number;
  creditos: number;
  presupuesto: number;
};

export type PresupuestoRespuesta = {
  items: PresupuestoItem[];
  totales: PresupuestoTotales;
};

