import { ForbiddenException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { AuthenticatedUser } from '../auth/auth.types';
import { CreditosService } from './creditos.service';
import { PagosService } from './pagos.service';
import {
  calcularPlan,
  calcularPlanPendiente,
  redondear,
} from './creditos-amortizacion.util';

function usuarioTest(
  roles: string[] = ['ADMINISTRADOR'],
  permisos: string[] = [
    'CREAR_CREDITOS',
    'MODIFICAR_CREDITOS',
    'ELIMINAR_CREDITOS',
    'REFINANCIAR_CREDITOS',
    'AGREGAR_CUOTA',
  ],
): AuthenticatedUser {
  return {
    usuarioId: '11111111-1111-4111-8111-111111111111',
    usuario: 'admin_test',
    organizacionId: '22222222-2222-4222-8222-222222222222',
    roles,
    permisos,
  };
}

describe('CreditosAmortizacionUtil', () => {
  it('calculates plan with exact distribution and interest', () => {
    const plan = calcularPlan({
      fechaInicio: new Date('2026-09-01T00:00:00.000Z'),
      valorPrincipal: 100_000,
      porcentajeInteres: 20,
      plazoDias: 30,
      diasIntervalo: 1,
      omitirDomingos: false,
      decimales: 2,
    });

    expect(plan.numeroCuotas).toBe(30);
    expect(plan.valorTotal).toBe(120_000);
    expect(plan.valorCuota).toBe(4_000);
    expect(plan.cuotas).toHaveLength(30);

    const sumaCapital = redondear(
      plan.cuotas.reduce((sum, c) => sum + c.valorCapital, 0),
    );
    const sumaInteres = redondear(
      plan.cuotas.reduce((sum, c) => sum + c.valorInteres, 0),
    );

    expect(sumaCapital).toBe(100_000);
    expect(sumaInteres).toBe(20_000);
    expect(plan.domingosOmitidos).toBe(0);
  });

  it('skips Sundays when omitirDomingos is true and diasIntervalo is 1', () => {
    // 2026-09-05 is a Saturday. Daily plan of 3 days with omitirDomingos should schedule:
    // cuota 1: Sunday is skipped -> Monday 2026-09-07
    // cuota 2: Tuesday 2026-09-08
    // cuota 3: Wednesday 2026-09-09
    const plan = calcularPlan({
      fechaInicio: new Date('2026-09-05T00:00:00.000Z'),
      valorPrincipal: 30_000,
      porcentajeInteres: 0,
      plazoDias: 3,
      diasIntervalo: 1,
      omitirDomingos: true,
      decimales: 2,
    });

    expect(plan.numeroCuotas).toBe(3);
    expect(plan.domingosOmitidos).toBe(1);
    expect(plan.cuotas[0].fechaVencimiento.getUTCDay()).not.toBe(0);
    expect(plan.cuotas[1].fechaVencimiento.getUTCDay()).not.toBe(0);
    expect(plan.cuotas[2].fechaVencimiento.getUTCDay()).not.toBe(0);
  });

  it('calculates plan pendiente correctly for refinancing', () => {
    const plan = calcularPlanPendiente({
      fechaInicio: new Date('2026-09-01T00:00:00.000Z'),
      valorCapital: 50_000,
      valorInteres: 10_000,
      plazoDias: 10,
      diasIntervalo: 1,
      omitirDomingos: false,
      decimales: 2,
    });

    expect(plan.numeroCuotas).toBe(10);
    expect(plan.valorTotal).toBe(60_000);
    expect(plan.valorCuota).toBe(6_000);

    const sumaCapital = redondear(
      plan.cuotas.reduce((sum, c) => sum + c.valorCapital, 0),
    );
    const sumaInteres = redondear(
      plan.cuotas.reduce((sum, c) => sum + c.valorInteres, 0),
    );

    expect(sumaCapital).toBe(50_000);
    expect(sumaInteres).toBe(10_000);
  });
});

describe('CreditosService', () => {
  let service: CreditosService;
  let mockPrisma: {
    $transaction: jest.Mock;
    $queryRaw: jest.Mock;
    $executeRaw: jest.Mock;
    credito: {
      findUnique: jest.Mock;
      create: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
    };
    cliente: { findUnique: jest.Mock };
    moneda: { findUnique: jest.Mock };
    frecuenciaPago: { findUnique: jest.Mock };
    estadoCredito: { findUnique: jest.Mock };
    estadoCuota: { findUnique: jest.Mock };
    ruta: {
      findUnique: jest.Mock;
      findFirst: jest.Mock;
      findMany: jest.Mock;
      create: jest.Mock;
    };
    cajaMenor: { findUnique: jest.Mock };
    cajaMenorMovimiento: {
      create: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
    };
    tipoMovimientoCaja: { findUnique: jest.Mock };
    creditoPlanPago: { create: jest.Mock; update: jest.Mock };
    creditoCuota: {
      createMany: jest.Mock;
      deleteMany: jest.Mock;
      updateMany: jest.Mock;
    };
    creditoDesembolso: {
      create: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
    };
    pagoAplicacion: { count: jest.Mock; groupBy: jest.Mock };
    rutaCliente: { findFirst: jest.Mock; create: jest.Mock; update: jest.Mock };
  };
  let mockTenantScope: {
    obtenerScopeOrganizacionTbl: jest.Mock;
  };
  let mockCache: {
    remember: jest.Mock;
    clear: jest.Mock;
  };
  let mockExportaciones: {
    asegurarTamanoExportacion: jest.Mock;
    formatearHojaExportacion: jest.Mock;
    subirWorkbookExportacion: jest.Mock;
    crearVistaPreviaExportacion: jest.Mock;
  };
  let mockNotifications: {
    notifyCreditApproved: jest.Mock;
    notifyPaymentReceived: jest.Mock;
  };

  beforeEach(() => {
    mockPrisma = {
      $transaction: jest.fn(
        (callback: (tx: unknown) => unknown): unknown => callback(mockPrisma),
      ),
      $queryRaw: jest.fn(),
      $executeRaw: jest.fn(),
      credito: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      cliente: { findUnique: jest.fn() },
      moneda: { findUnique: jest.fn() },
      frecuenciaPago: { findUnique: jest.fn() },
      estadoCredito: { findUnique: jest.fn() },
      estadoCuota: { findUnique: jest.fn() },
      ruta: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn(),
        create: jest.fn(),
      },
      cajaMenor: { findUnique: jest.fn() },
      cajaMenorMovimiento: {
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      tipoMovimientoCaja: { findUnique: jest.fn() },
      creditoPlanPago: { create: jest.fn(), update: jest.fn() },
      creditoCuota: {
        createMany: jest.fn(),
        deleteMany: jest.fn(),
        updateMany: jest.fn(),
      },
      creditoDesembolso: {
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      pagoAplicacion: { count: jest.fn(), groupBy: jest.fn() },
      rutaCliente: {
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
    };

    mockTenantScope = {
      obtenerScopeOrganizacionTbl: jest.fn().mockResolvedValue({
        usuarioId: '11111111-1111-4111-8111-111111111111',
        organizacionId: '22222222-2222-4222-8222-222222222222',
      }),
    };

    mockCache = {
      remember: jest.fn(
        (_k: string, fn: () => unknown): unknown => fn(),
      ),
      clear: jest.fn(),
    };

    mockExportaciones = {
      asegurarTamanoExportacion: jest.fn(),
      formatearHojaExportacion: jest.fn(),
      subirWorkbookExportacion: jest.fn(),
      crearVistaPreviaExportacion: jest.fn(),
    };

    mockNotifications = {
      notifyCreditApproved: jest.fn().mockResolvedValue(undefined),
      notifyPaymentReceived: jest.fn().mockResolvedValue(undefined),
    };

    service = new CreditosService(
      mockPrisma as unknown as never,
      mockTenantScope as unknown as never,
      mockCache as unknown as never,
      mockExportaciones as unknown as never,
      mockNotifications as unknown as never,
    );
  });

  it('rejects crearCredito if user lacks CREAR_CREDITOS permission', async () => {
    const usuarioSinPermiso = usuarioTest(['COBRADOR'], []);

    await expect(
      service.crearCredito(
        {
          clienteId: 'cli-1',
          monedaCodigo: 'COP',
          frecuenciaPagoId: 1,
          fechaInicio: '2026-09-01',
          valorPrincipal: 100_000,
          porcentajeInteres: 20,
          plazoDias: 30,
        },
        usuarioSinPermiso,
      ),
    ).rejects.toThrow(ForbiddenException);
  });

  it('rejects crearCredito if client does not exist in Prisma mode', async () => {
    mockPrisma.cliente.findUnique.mockResolvedValue(null);
    mockPrisma.moneda.findUnique.mockResolvedValue({
      codigoMoneda: 'COP',
      decimales: 2,
    });
    mockPrisma.frecuenciaPago.findUnique.mockResolvedValue({
      frecuenciaPagoId: 1,
      diasIntervalo: 1,
    });
    mockPrisma.estadoCredito.findUnique.mockResolvedValue({
      estadoCreditoId: 1,
      codigo: 'ACTIVO',
    });
    mockPrisma.estadoCuota.findUnique.mockResolvedValue({
      estadoCuotaId: 1,
      codigo: 'PENDIENTE',
    });

    await expect(
      service.crearCredito(
        {
          clienteId: 'cli-inexistente',
          monedaCodigo: 'COP',
          frecuenciaPagoId: 1,
          fechaInicio: '2026-09-01',
          valorPrincipal: 100_000,
          porcentajeInteres: 20,
          plazoDias: 30,
        },
        usuarioTest(),
      ),
    ).rejects.toThrow('Cliente no encontrado');
  });

  it('rejects refinanciarCredito if new principal is not greater than previous principal', async () => {
    mockPrisma.credito.findUnique.mockResolvedValue({
      creditoId: 'cred-1',
      valorPrincipal: new Prisma.Decimal('100000'),
      monedaCodigo: 'COP',
      estadoCredito: { codigo: 'ACTIVO' },
      planPago: { cuotas: [] },
      ruta: { responsableUsuarioId: '11111111-1111-4111-8111-111111111111' },
      cliente: { nombreCompleto: 'Juan Perez' },
    });

    await expect(
      service.refinanciarCredito(
        'cred-1',
        {
          frecuenciaPagoId: 1,
          fechaInicio: '2026-09-01',
          valorPrincipal: 90_000,
          porcentajeInteres: 20,
          plazoDias: 30,
          cajaMenorId: 'caj-1',
        },
        usuarioTest(),
      ),
    ).rejects.toThrow(
      'El nuevo valor debe ser mayor al valor actual del credito',
    );
  });
});

describe('PagosService', () => {
  let pagosService: PagosService;
  let mockPrisma: {
    $transaction: jest.Mock;
    $queryRaw: jest.Mock;
    $executeRaw: jest.Mock;
    creditoCuota: {
      findUnique: jest.Mock;
      findMany: jest.Mock;
      updateMany: jest.Mock;
      count: jest.Mock;
    };
    medioPago: { findUnique: jest.Mock };
    pago: { findFirst: jest.Mock; create: jest.Mock; findUnique: jest.Mock };
    pagoAplicacion: { groupBy: jest.Mock; createMany: jest.Mock };
    estadoCuota: { findUnique: jest.Mock };
    estadoCredito: { findUnique: jest.Mock };
    credito: { update: jest.Mock };
  };
  let mockTenantScope: {
    obtenerScopeOrganizacionTbl: jest.Mock;
  };
  let mockCache: {
    clear: jest.Mock;
  };
  let mockNotifications: {
    notifyPaymentReceived: jest.Mock;
  };

  beforeEach(() => {
    mockPrisma = {
      $transaction: jest.fn(
        (callback: (tx: unknown) => unknown): unknown => callback(mockPrisma),
      ),
      $queryRaw: jest.fn(),
      $executeRaw: jest.fn(),
      creditoCuota: {
        findUnique: jest.fn(),
        findMany: jest.fn(),
        updateMany: jest.fn(),
        count: jest.fn(),
      },
      medioPago: { findUnique: jest.fn() },
      pago: {
        findFirst: jest.fn(),
        create: jest.fn(),
        findUnique: jest.fn(),
      },
      pagoAplicacion: {
        groupBy: jest.fn(),
        createMany: jest.fn(),
      },
      estadoCuota: { findUnique: jest.fn() },
      estadoCredito: { findUnique: jest.fn() },
      credito: { update: jest.fn() },
    };

    mockTenantScope = {
      obtenerScopeOrganizacionTbl: jest.fn().mockResolvedValue({
        usuarioId: '11111111-1111-4111-8111-111111111111',
        organizacionId: '22222222-2222-4222-8222-222222222222',
      }),
    };

    mockCache = { clear: jest.fn() };
    mockNotifications = {
      notifyPaymentReceived: jest.fn().mockResolvedValue(undefined),
    };

    pagosService = new PagosService(
      mockPrisma as unknown as never,
      mockTenantScope as unknown as never,
      mockCache as unknown as never,
      mockNotifications as unknown as never,
    );
  });

  it('rejects registrarPago if user lacks AGREGAR_CUOTA permission', async () => {
    const usuarioSinPermiso = usuarioTest(['COBRADOR'], []);

    await expect(
      pagosService.registrarPago(
        {
          creditoCuotaId: 'cuota-1',
          montoPagado: 50_000,
        },
        usuarioSinPermiso,
      ),
    ).rejects.toThrow(ForbiddenException);
  });

  it('rejects registrarPago if cuota is anulada', async () => {
    mockPrisma.creditoCuota.findUnique.mockResolvedValue({
      creditoCuotaId: 'cuota-1',
      estadoCuota: { codigo: 'ANULADA' },
      planPago: {
        credito: {
          ruta: {
            responsableUsuarioId: '11111111-1111-4111-8111-111111111111',
          },
          cliente: { nombreCompleto: 'Juan Perez' },
        },
      },
    });

    await expect(
      pagosService.registrarPago(
        {
          creditoCuotaId: 'cuota-1',
          montoPagado: 50_000,
        },
        usuarioTest(),
      ),
    ).rejects.toThrow('La cuota esta anulada');
  });
});
