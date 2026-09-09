import { DomainError } from '../../common/domain/domain-error';
import { PlanCalculado } from './creditos.types';

export function redondear(value: number, decimales = 2): number {
  const factor = 10 ** decimales;
  return Math.round((value + Number.EPSILON) * factor) / factor;
}

export function fechaUtc(fecha: Date | string): Date {
  const d = typeof fecha === 'string' ? new Date(fecha) : fecha;
  return new Date(
    Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()),
  );
}

export function sumarDias(fecha: Date, dias: number): Date {
  const resultado = new Date(fecha);
  resultado.setUTCDate(resultado.getUTCDate() + dias);
  return resultado;
}

export function dineroAUnidades(value: number, decimales: number): number {
  const factor = 10 ** decimales;
  return Math.round((value + Number.EPSILON) * factor);
}

export function unidadesADinero(value: number, decimales: number): number {
  return redondear(value / 10 ** decimales, decimales);
}

export function distribuirUnidades(total: number, partes: number): number[] {
  const base = Math.floor(total / partes);
  let restante = total - base * partes;

  return Array.from({ length: partes }, (_, index) => {
    const partesPendientes = partes - index;
    if (restante <= 0) {
      return base;
    }

    if (restante >= partesPendientes) {
      restante--;
      return base + 1;
    }

    return base;
  });
}

export function distribuirUnidadesAcotadas(
  total: number,
  topes: number[],
): number[] {
  const distribucion = distribuirUnidades(total, topes.length).map(
    (valor, index) => Math.min(valor, topes[index]),
  );
  let restante = total - distribucion.reduce((sum, value) => sum + value, 0);

  for (
    let index = distribucion.length - 1;
    index >= 0 && restante > 0;
    index--
  ) {
    const disponible = topes[index] - distribucion[index];
    const asignado = Math.min(disponible, restante);
    distribucion[index] += asignado;
    restante -= asignado;
  }

  if (restante > 0) {
    throw DomainError.validation(
      'No se pudo distribuir el interes del credito en cuotas validas',
      'PLAN_CREDITO_INTERES_INVALIDO',
    );
  }

  return distribucion;
}

export function calcularPlan(input: {
  fechaInicio: Date;
  valorPrincipal: number;
  porcentajeInteres: number;
  plazoDias: number;
  diasIntervalo: number;
  omitirDomingos: boolean;
  decimales: number;
}): PlanCalculado {
  const numeroCuotas = Math.max(
    1,
    Math.ceil(input.plazoDias / input.diasIntervalo),
  );
  const unidadesPrincipal = dineroAUnidades(
    input.valorPrincipal,
    input.decimales,
  );
  const unidadesTotal = dineroAUnidades(
    input.valorPrincipal +
      input.valorPrincipal * (input.porcentajeInteres / 100),
    input.decimales,
  );
  const unidadesInteres = Math.max(0, unidadesTotal - unidadesPrincipal);
  const valorTotal = unidadesADinero(unidadesTotal, input.decimales);
  const valorCuota = redondear(valorTotal / numeroCuotas, input.decimales);
  const totalesPorCuota = distribuirUnidades(unidadesTotal, numeroCuotas);
  const interesesPorCuota = distribuirUnidadesAcotadas(
    unidadesInteres,
    totalesPorCuota,
  );
  const capitalesPorCuota = totalesPorCuota.map(
    (totalCuota, index) => totalCuota - interesesPorCuota[index],
  );
  const totalCapitalCalculado = capitalesPorCuota.reduce(
    (sum, value) => sum + value,
    0,
  );

  if (totalCapitalCalculado !== unidadesPrincipal) {
    throw DomainError.validation(
      'No se pudo distribuir el capital del credito en cuotas validas',
      'PLAN_CREDITO_DISTRIBUCION_INVALIDA',
    );
  }

  let cursor = fechaUtc(input.fechaInicio);
  let domingosOmitidos = 0;

  const cuotas = Array.from({ length: numeroCuotas }, (_, index) => {
    if (input.diasIntervalo === 1 && input.omitirDomingos) {
      do {
        cursor = sumarDias(cursor, 1);
        if (cursor.getUTCDay() === 0) {
          domingosOmitidos++;
        }
      } while (cursor.getUTCDay() === 0);
    } else {
      cursor = sumarDias(cursor, input.diasIntervalo);
    }

    return {
      numeroCuota: index + 1,
      fechaVencimiento: cursor,
      valorCapital: unidadesADinero(capitalesPorCuota[index], input.decimales),
      valorInteres: unidadesADinero(interesesPorCuota[index], input.decimales),
    };
  });

  return {
    numeroCuotas,
    valorCuota,
    valorTotal,
    fechaMaxima: cuotas[cuotas.length - 1].fechaVencimiento,
    domingosOmitidos,
    cuotas,
  };
}

export function calcularPlanPendiente(input: {
  fechaInicio: Date;
  valorCapital: number;
  valorInteres: number;
  plazoDias: number;
  diasIntervalo: number;
  omitirDomingos: boolean;
  decimales: number;
}): PlanCalculado {
  const numeroCuotas = Math.max(
    1,
    Math.ceil(input.plazoDias / input.diasIntervalo),
  );
  const unidadesCapital = dineroAUnidades(input.valorCapital, input.decimales);
  const unidadesInteres = dineroAUnidades(input.valorInteres, input.decimales);
  const unidadesTotal = unidadesCapital + unidadesInteres;
  const valorTotal = unidadesADinero(unidadesTotal, input.decimales);
  const valorCuota = redondear(valorTotal / numeroCuotas, input.decimales);
  const totalesPorCuota = distribuirUnidades(unidadesTotal, numeroCuotas);
  const interesesPorCuota = distribuirUnidadesAcotadas(
    unidadesInteres,
    totalesPorCuota,
  );
  const capitalesPorCuota = totalesPorCuota.map(
    (totalCuota, index) => totalCuota - interesesPorCuota[index],
  );

  let cursor = fechaUtc(input.fechaInicio);
  let domingosOmitidos = 0;

  const cuotas = Array.from({ length: numeroCuotas }, (_, index) => {
    if (input.diasIntervalo === 1 && input.omitirDomingos) {
      do {
        cursor = sumarDias(cursor, 1);
        if (cursor.getUTCDay() === 0) {
          domingosOmitidos++;
        }
      } while (cursor.getUTCDay() === 0);
    } else {
      cursor = sumarDias(cursor, input.diasIntervalo);
    }

    return {
      numeroCuota: index + 1,
      fechaVencimiento: cursor,
      valorCapital: unidadesADinero(capitalesPorCuota[index], input.decimales),
      valorInteres: unidadesADinero(interesesPorCuota[index], input.decimales),
    };
  });

  return {
    numeroCuotas,
    valorCuota,
    valorTotal,
    fechaMaxima: cuotas[cuotas.length - 1].fechaVencimiento,
    domingosOmitidos,
    cuotas,
  };
}

