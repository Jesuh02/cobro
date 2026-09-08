import { Prisma } from '@prisma/client';

import { AuthenticatedUser } from '../auth/auth.types';
import { PresupuestoService } from './presupuesto.service';

describe('PresupuestoService', () => {
  type QueryRawMock = jest.Mock<Promise<unknown[]>, [unknown]>;

  function createService(queryRaw: QueryRawMock, usarTbl = true) {
    const prismaMock = {
      $queryRaw: queryRaw,
    };
    const tenantScopeMock = {
      usarEsquemaTbl: jest.fn().mockResolvedValue(usarTbl),
      obtenerScopeOrganizacionTbl: jest
        .fn()
        .mockResolvedValue({ usuarioId: '7', organizacionId: '10' }),
      puedeVerDatosOrganizacion: jest
        .fn()
        .mockImplementation(
          (u: AuthenticatedUser) =>
            Boolean(u.roles?.includes('ADMINISTRADOR') || u.roles?.includes('AUDITOR')),
        ),
      esAdministrador: jest
        .fn()
        .mockImplementation((u: AuthenticatedUser) =>
          Boolean(u.roles?.includes('ADMINISTRADOR')),
        ),
    };

    return new PresupuestoService(
      prismaMock as never,
      tenantScopeMock as never,
    );
  }

  function usuario(
    usuarioId: string,
    roles: string[] = ['ADMINISTRADOR'],
    permisos: string[] = [],
  ): AuthenticatedUser {
    return {
      usuarioId,
      usuario: 'test_user',
      organizacionId: '10',
      roles,
      permisos,
    };
  }

  it('calculates budget items and totals correctly in tbl schema', async () => {
    const queryRaw = jest.fn<Promise<unknown[]>, [unknown]>().mockResolvedValueOnce([
      {
        caja_menor_id: 'caj-1',
        caja_menor_nombre: 'Caja Principal',
        responsable_usuario_id: '7',
        moneda_codigo: 'COP',
        caja_menor: new Prisma.Decimal('100000'),
        recaudado: new Prisma.Decimal('50000'),
        gastos: new Prisma.Decimal('20000'),
        creditos: new Prisma.Decimal('80000'),
        presupuesto: new Prisma.Decimal('130000'),
      },
      {
        caja_menor_id: 'caj-2',
        caja_menor_nombre: 'Caja Secundaria',
        responsable_usuario_id: '8',
        moneda_codigo: 'COP',
        caja_menor: new Prisma.Decimal('50000'),
        recaudado: new Prisma.Decimal('10000'),
        gastos: new Prisma.Decimal('5000'),
        creditos: new Prisma.Decimal('30000'),
        presupuesto: new Prisma.Decimal('55000'),
      },
    ]);

    const service = createService(queryRaw, true);
    const result = await service.obtenerPresupuesto({}, usuario('7'));

    expect(result.items).toHaveLength(2);
    expect(result.items[0]).toEqual({
      cajaMenorId: 'caj-1',
      cajaMenorNombre: 'Caja Principal',
      responsableUsuarioId: '7',
      monedaCodigo: 'COP',
      cajaMenor: 100000,
      recaudado: 50000,
      gastos: 20000,
      creditos: 80000,
      presupuesto: 130000,
    });

    expect(result.totales).toEqual({
      cajaMenor: 150000,
      recaudado: 60000,
      gastos: 25000,
      creditos: 110000,
      presupuesto: 185000,
    });
  });

  it('filters by collector scope when alcance is cobrador', async () => {
    const queryRaw = jest.fn<Promise<unknown[]>, [unknown]>().mockResolvedValueOnce([]);
    const service = createService(queryRaw, true);

    await service.obtenerPresupuesto(
      { alcance: 'cobrador' },
      usuario('7', ['ADMINISTRADOR']),
    );

    const [sqlCall] = queryRaw.mock.calls;
    const sqlText = (sqlCall[0] as { strings?: string[] }).strings?.join(' ') ?? '';
    expect(sqlText).toContain('public.tbl_sesiones_cajas sc_acl');
  });

  it('calculates budget in prisma schema correctly', async () => {
    const queryRaw = jest.fn<Promise<unknown[]>, [unknown]>().mockResolvedValueOnce([
      {
        caja_menor_id: 'caj-p1',
        caja_menor_nombre: 'Caja Prisma',
        responsable_usuario_id: '7',
        moneda_codigo: 'COP',
        caja_menor: new Prisma.Decimal('200000'),
        recaudado: new Prisma.Decimal('100000'),
        gastos: new Prisma.Decimal('50000'),
        creditos: new Prisma.Decimal('150000'),
        presupuesto: new Prisma.Decimal('250000'),
      },
    ]);

    const service = createService(queryRaw, false);
    const result = await service.obtenerPresupuesto(
      { search: 'Prisma', fechaDesde: '2026-09-01', fechaHasta: '2026-09-08' },
      usuario('7'),
    );

    expect(result.items).toHaveLength(1);
    expect(result.items[0].presupuesto).toBe(250000);
    expect(result.totales.presupuesto).toBe(250000);
  });

  it('throws validation error on invalid date', async () => {
    const queryRaw = jest.fn<Promise<unknown[]>, [unknown]>();
    const service = createService(queryRaw, false);

    await expect(
      service.obtenerPresupuesto({ fechaDesde: 'invalida' }, usuario('7')),
    ).rejects.toThrow('La fecha enviada en fechaDesde no es valida');
  });
});

