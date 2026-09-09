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

  it('rejects crearCredito if client does not exist', async () => {
    mockPrisma.$queryRaw.mockResolvedValueOnce([]);

    await expect(
      service.crearCredito(
        {
          clienteId: '11111111-1111-4111-8111-111111111111',
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
    mockPrisma.$queryRaw.mockResolvedValueOnce([
      {
        id: '11111111-1111-4111-8111-111111111111',
        cliente_id: '22222222-2222-4222-8222-222222222222',
        mon_id: '33333333-3333-4333-8333-333333333333',
        org_id: '22222222-2222-4222-8222-222222222222',
        valor_principal: new Prisma.Decimal('100000'),
        porcentaje_interes: new Prisma.Decimal('20'),
        estado: 'ACTIVO',
        ruta_id: null,
        cliente_nombre: 'Juan Perez',
      },
    ]);

    await expect(
      service.refinanciarCredito(
        '11111111-1111-4111-8111-111111111111',
        {
          frecuenciaPagoId: 1,
          fechaInicio: '2026-09-01',
          valorPrincipal: 90_000,
          porcentajeInteres: 20,
          plazoDias: 30,
          cajaMenorId: '88888888-8888-4888-8888-888888888888',
        },
        usuarioTest(),
      ),
    ).rejects.toThrow(
      'El nuevo valor debe ser mayor al valor actual del credito',
    );
  });

  it('refinances a credit in tbl mode correctly', async () => {
    jest.spyOn(service, 'usarEsquemaTbl').mockResolvedValue(true);
    const mockTx = {
      $queryRaw: jest
        .fn()
        // 1: lock and fetch credit
        .mockResolvedValueOnce([
          {
            id: '11111111-1111-4111-8111-111111111111',
            cliente_id: '22222222-2222-4222-8222-222222222222',
            valor_principal: new Prisma.Decimal('1000'),
            tasa_interes: new Prisma.Decimal('20'),
            total_pagar: new Prisma.Decimal('1200'),
            estado: 'ACTIVO',
            mon_id: '33333333-3333-4333-8333-333333333333',
            usu_id: '44444444-4444-4444-8444-444444444444',
            pcr_id: '55555555-5555-4555-8555-555555555555',
            moneda_codigo: 'COP',
            decimales: 2,
            org_id: '66666666-6666-4666-8666-666666666666',
            cliente_nombre: 'Juan Perez',
            ruta_id: '77777777-7777-4777-8777-777777777777',
          },
        ])
        // 2: frecuencia / producto
        .mockResolvedValueOnce([
          { id: '55555555-5555-4555-8555-555555555555', dias_intervalo: 1 },
        ])
        // 3: caja
        .mockResolvedValueOnce([
          {
            id: '88888888-8888-4888-8888-888888888888',
            nombre: 'Caja 1',
            sesion_id: '99999999-9999-4999-8999-999999999999',
          },
        ])
        // 4: presupuesto
        .mockResolvedValueOnce([{ presupuesto: new Prisma.Decimal('5000') }])
        // 5: ruta
        .mockResolvedValueOnce([
          { id: '77777777-7777-4777-8777-777777777777' },
        ])
        // 6: cuotasExistentes
        .mockResolvedValueOnce([
          {
            id: 'c1',
            numero: 1n,
            valor: new Prisma.Decimal('80'),
            total_pagado: new Prisma.Decimal('80'),
            estado: 'PAGADA',
          },
          {
            id: 'c2',
            numero: 2n,
            valor: new Prisma.Decimal('80'),
            total_pagado: new Prisma.Decimal('0'),
            estado: 'PENDIENTE',
          },
        ])
        // 7: abonosRow
        .mockResolvedValueOnce([
          {
            capital_abonado: new Prisma.Decimal('80'),
            interes_abonado: new Prisma.Decimal('0'),
          },
        ]),
      $executeRaw: jest.fn().mockResolvedValue(1),
    };

    mockPrisma.$transaction.mockImplementation(async (cb: (tx: unknown) => unknown) => cb(mockTx));
    jest
      .spyOn(service as unknown as { obtenerCreditoTbl: () => Promise<unknown> }, 'obtenerCreditoTbl')
      .mockResolvedValue({ id: '11111111-1111-4111-8111-111111111111' } as never);

    const res = await service.refinanciarCredito(
      '11111111-1111-4111-8111-111111111111',
      {
        frecuenciaPagoId: 1,
        fechaInicio: '2026-09-08',
        valorPrincipal: 2000,
        porcentajeInteres: 20,
        plazoDias: 30,
        cajaMenorId: '88888888-8888-4888-8888-888888888888',
      },
      usuarioTest(['COBRADOR'], ['REFINANCIAR_CREDITOS']),
    );

    expect(res).toBeDefined();
    expect(mockTx.$executeRaw).toHaveBeenCalled();
  });

  it('rejects refinanciarCredito if saldo de caja menor is insufficient for the increment', async () => {
    const mockTx = {
      $queryRaw: jest
        .fn()
        // 1: credito
        .mockResolvedValueOnce([
          {
            id: '11111111-1111-4111-8111-111111111111',
            cliente_id: '22222222-2222-4222-8222-222222222222',
            mon_id: '33333333-3333-4333-8333-333333333333',
            org_id: '22222222-2222-4222-8222-222222222222',
            valor_principal: new Prisma.Decimal('1000'),
            tasa_interes: new Prisma.Decimal('20'),
            total_pagar: new Prisma.Decimal('1200'),
            estado: 'ACTIVO',
            ruta_id: null,
            cliente_nombre: 'Juan Perez',
            decimales: 2,
            moneda_codigo: 'COP',
          },
        ])
        // 2: producto
        .mockResolvedValueOnce([
          {
            id: '44444444-4444-4444-8444-444444444444',
            dias_intervalo: 1,
          },
        ])
        // 3: caja
        .mockResolvedValueOnce([
          {
            id: '88888888-8888-4888-8888-888888888888',
            nombre: 'Caja 1',
            sesion_id: '99999999-9999-4999-8999-999999999999',
          },
        ])
        // 4: saldo disponible en caja (4000)
        .mockResolvedValueOnce([{ saldo_disponible: new Prisma.Decimal('4000') }]),
      $executeRaw: jest.fn().mockResolvedValue(1),
    };

    mockPrisma.$transaction.mockImplementation(async (cb: (tx: unknown) => unknown) => cb(mockTx));

    await expect(
      service.refinanciarCredito(
        '11111111-1111-4111-8111-111111111111',
        {
          frecuenciaPagoId: 1,
          fechaInicio: '2026-09-08',
          valorPrincipal: 6000,
          porcentajeInteres: 20,
          plazoDias: 30,
          cajaMenorId: '88888888-8888-4888-8888-888888888888',
        },
        usuarioTest(['COBRADOR'], ['REFINANCIAR_CREDITOS']),
      ),
    ).rejects.toThrow('No se puede refinanciar credito sin saldo suficiente en caja menor');
  });

  it('permite obtenerCredito y listarCuotasCredito a empleados autorizados sin requerir VER_CREDITOS', async () => {
    jest
      .spyOn(service as unknown as { obtenerCreditoTbl: () => Promise<unknown> }, 'obtenerCreditoTbl')
      .mockResolvedValue({ id: 'credito-1' } as never);
    jest
      .spyOn(service as unknown as { listarCuotasCreditoTbl: () => Promise<unknown> }, 'listarCuotasCreditoTbl')
      .mockResolvedValue([{ id: 'cuota-1' }] as never);

    const empleado = usuarioTest(['COBRADOR'], []);
    await expect(service.obtenerCredito('credito-1', empleado)).resolves.toEqual({ id: 'credito-1' });
    await expect(service.listarCuotasCredito('credito-1', empleado)).resolves.toEqual([{ id: 'cuota-1' }]);
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
    mockPrisma.$queryRaw
      .mockResolvedValueOnce([{ id_cuo: 'cuota-1' }])
      .mockResolvedValueOnce([
        {
          cuota_id: 'cuota-1',
          cuota_estado: 'ANULADA',
          credito_id: 'credito-1',
          credito_estado: 'ACTIVO',
          cliente_id: 'cliente-1',
          cliente: 'Juan Perez',
          org_id: '22222222-2222-4222-8222-222222222222',
          usuario_id: '11111111-1111-4111-8111-111111111111',
          usuario: 'admin_test',
          moneda_id: 'moneda-1',
          moneda_codigo: 'COP',
        },
      ]);

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
