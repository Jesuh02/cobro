import { CajaMenorService } from './caja-menor.service';

describe('CajaMenorService', () => {
  type QueryRawMock = jest.Mock<Promise<unknown[]>, [unknown]>;

  function createService(queryRaw: QueryRawMock, executeRaw?: jest.Mock) {
    const txClient = {
      $queryRaw: queryRaw,
      $executeRaw: executeRaw ?? jest.fn().mockResolvedValue(1),
    };
    const prismaMock = {
      $queryRaw: queryRaw,
      $executeRaw: txClient.$executeRaw,
      $transaction: async (cb: (tx: unknown) => Promise<unknown>) => cb(txClient),
      cajaMenor: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
      usuario: {
        findUnique: jest.fn(),
      },
      moneda: {
        findUnique: jest.fn(),
      },
      tipoMovimientoCaja: {
        findUnique: jest.fn(),
      },
    };
    const tenantScopeMock = {
      usarEsquemaTbl: jest.fn().mockResolvedValue(true),
      obtenerScopeOrganizacionTbl: jest
        .fn()
        .mockResolvedValue({ usuarioId: '7', organizacionId: '10' }),
      puedeVerDatosOrganizacion: jest.fn().mockImplementation((u) =>
        u.roles?.includes('ADMINISTRADOR') || u.roles?.includes('AUDITOR'),
      ),
      esAdministrador: jest.fn().mockImplementation((u) =>
        u.roles?.includes('ADMINISTRADOR'),
      ),
    };
    const cacheMock = {
      remember: jest.fn((_key, cb) => cb()),
      deleteByPrefix: jest.fn(),
    };
    const exportacionesMock = {
      asegurarTamanoExportacion: jest.fn(),
      formatearHojaExportacion: jest.fn(),
      crearVistaPreviaExportacion: jest.fn(),
      subirWorkbookExportacion: jest.fn(),
    };

    return new CajaMenorService(
      prismaMock as never,
      tenantScopeMock as never,
      cacheMock as never,
      exportacionesMock as never,
    );
  }

  function usuario(
    usuarioId: string,
    roles: string[] = ['ADMINISTRADOR'],
    permisos: string[] = [],
  ) {
    return {
      usuarioId,
      usuario: 'test_user',
      organizacionId: '10',
      roles,
      permisos,
    };
  }

  it('rejects user without CREAR_CAJA_MENOR permission from creating caja menor', async () => {
    const queryRaw = jest.fn<Promise<unknown[]>, [unknown]>();
    const service = createService(queryRaw);
    const user = usuario('7', ['COBRADOR'], []);

    await expect(
      service.crearCajaMenor({ nombre: 'Caja Cobrador' }, user as never),
    ).rejects.toThrow('No tienes permiso para crear caja menor');
  });

  it('allows administrator to target an employee in the organization in tbl mode', async () => {
    const queryRaw = jest
      .fn<Promise<unknown[]>, [unknown]>()
      .mockResolvedValueOnce([
        {
          id: '22',
          usuario: 'empleado1',
          nombres: 'Carlos',
          apellidos: 'Ruiz',
          correo: 'carlos@mail.com',
          telefono: '3001234567',
          organizacion_id: '10',
        },
      ])
      .mockResolvedValueOnce([{ id: 'mon-1', codigo: 'COP' }])
      .mockResolvedValueOnce([]) // cajaAbierta (ninguna)
      .mockResolvedValueOnce([]) // existente (ninguna)
      .mockResolvedValueOnce([
        {
          id: 'caj-1',
          nombre: 'Caja Carlos',
          activa: true,
          fecha_apertura: new Date('2026-09-01T00:00:00.000Z'),
        },
      ]);
    const executeRaw = jest.fn().mockResolvedValue(1);
    const service = createService(queryRaw, executeRaw);

    const result = await service.crearCajaMenor(
      { nombre: 'Caja Carlos', responsableUsuarioId: '22' },
      usuario('7', ['ADMINISTRADOR']) as never,
    );

    expect(result.id).toBe('caj-1');
    expect(result.nombre).toBe('Caja Carlos');
    expect(result.responsable.id).toBe('22');
    expect(executeRaw).toHaveBeenCalled();
  });

  it('forces cobrador with CREAR_CAJA_MENOR permission to target themselves', async () => {
    const queryRaw = jest
      .fn<Promise<unknown[]>, [unknown]>()
      .mockResolvedValueOnce([
        {
          id: '7',
          usuario: 'cobre',
          nombres: 'Juan',
          apellidos: 'Perez',
          correo: 'juan@mail.com',
          telefono: '3009998877',
          organizacion_id: '10',
        },
      ])
      .mockResolvedValueOnce([{ id: 'mon-1', codigo: 'COP' }])
      .mockResolvedValueOnce([]) // cajaAbierta
      .mockResolvedValueOnce([]) // existente
      .mockResolvedValueOnce([
        {
          id: 'caj-7',
          nombre: 'Caja Propia',
          activa: true,
          fecha_apertura: new Date('2026-09-01T00:00:00.000Z'),
        },
      ]);
    const executeRaw = jest.fn().mockResolvedValue(1);
    const service = createService(queryRaw, executeRaw);

    const result = await service.crearCajaMenor(
      { nombre: 'Caja Propia', responsableUsuarioId: '99' },
      usuario('7', ['COBRADOR'], ['CREAR_CAJA_MENOR']) as never,
    );

    expect(result.id).toBe('caj-7');
    expect(result.responsable.id).toBe('7');
  });

  it('rejects creating caja menor if closing date is before opening date', async () => {
    const queryRaw = jest.fn<Promise<unknown[]>, [unknown]>();
    const service = createService(queryRaw);

    await expect(
      service.crearCajaMenor(
        {
          nombre: 'Caja Invalida',
          fechaApertura: '2026-09-02T12:00:00.000Z',
          fechaCierre: '2026-09-01T12:00:00.000Z',
        },
        usuario('7', ['ADMINISTRADOR']) as never,
      ),
    ).rejects.toThrow(
      'La fecha de cierre debe ser posterior a la fecha de apertura',
    );
  });

  it('rejects creating caja menor if target employee already has an open caja menor', async () => {
    const queryRaw = jest
      .fn<Promise<unknown[]>, [unknown]>()
      .mockResolvedValueOnce([
        {
          id: '22',
          usuario: 'empleado1',
          nombres: 'Carlos',
          apellidos: 'Ruiz',
          correo: 'carlos@mail.com',
          telefono: '3001234567',
          organizacion_id: '10',
        },
      ])
      .mockResolvedValueOnce([{ id: 'mon-1', codigo: 'COP' }])
      .mockResolvedValueOnce([
        {
          id: 'caj-activa',
          nombre: 'Caja Carlos Activa',
          fecha_cierre: null,
        },
      ]);
    const service = createService(queryRaw);

    await expect(
      service.crearCajaMenor(
        { nombre: 'Caja Carlos 2', responsableUsuarioId: '22' },
        usuario('7', ['ADMINISTRADOR']) as never,
      ),
    ).rejects.toThrow(
      'El usuario Carlos Ruiz ya tiene una caja menor abierta (Caja Carlos Activa)',
    );
  });

  it('allows administrator to close a caja menor in tbl mode', async () => {
    const queryRaw = jest
      .fn<Promise<unknown[]>, [unknown]>()
      .mockResolvedValueOnce([
        {
          id: 'caj-1',
          nombre: 'Caja Carlos',
          activa: true,
          usuario_id: '22',
        },
      ]);
    const executeRaw = jest.fn().mockResolvedValue(1);
    const service = createService(queryRaw, executeRaw);

    const result = await service.cerrarCajaMenor(
      'caj-1',
      usuario('7', ['ADMINISTRADOR']) as never,
    );

    expect(result.id).toBe('caj-1');
    expect(result.activa).toBe(false);
    expect(result.mensaje).toBe('Caja menor cerrada exitosamente');
    expect(executeRaw).toHaveBeenCalled();
  });

  it('rejects non-administrator from closing someone elses caja menor', async () => {
    const queryRaw = jest
      .fn<Promise<unknown[]>, [unknown]>()
      .mockResolvedValueOnce([
        {
          id: 'caj-1',
          nombre: 'Caja Carlos',
          activa: true,
          usuario_id: '22', // belongs to user 22
        },
      ]);
    const service = createService(queryRaw);

    await expect(
      service.cerrarCajaMenor(
        'caj-1',
        usuario('7', ['COBRADOR'], ['REGISTRAR_FLUJO_CAJA']) as never, // caller is user 7
      ),
    ).rejects.toThrow('No tienes permiso para cerrar esta caja menor');
  });

  it('creates a movement in caja menor and updates session totals in tbl mode', async () => {
    const queryRaw = jest
      .fn<Promise<unknown[]>, [unknown]>()
      .mockResolvedValueOnce([
        {
          caja_menor_id: 'caj-1',
          caja_menor: 'Caja Principal',
          activa: true,
          org_id: '10',
          sesion_id: 'ses-1',
          fecha_cierre: null,
          usuario_id: '7',
          usuario: 'cobre',
          nombres: 'Juan',
          apellidos: 'Perez',
          correo: 'juan@mail.com',
          telefono: '3001234567',
        },
      ])
      .mockResolvedValueOnce([{ id: '100' }]) // INSERT INTO tbl_movimientos_cajas
      .mockResolvedValueOnce([
        {
          id: 'mov-100',
          caja_menor_id: 'caj-1',
          caja_menor: 'Caja Principal',
          cliente: null,
          cliente_identificacion: null,
          tipo_codigo: 'GASTO',
          tipo_nombre: 'Gasto',
          naturaleza: 'S',
          usuario_id: '7',
          usuario: 'cobre',
          nombres: 'Juan',
          apellidos: 'Perez',
          correo: 'juan@mail.com',
          telefono: '3001234567',
          fecha_movimiento: new Date('2026-09-08T12:00:00.000Z'),
          monto: '50000',
          motivo: 'Compra de papeleria',
          referencia_tabla: null,
          referencia_id: null,
          creado_en: new Date('2026-09-08T12:00:00.000Z'),
        },
      ]);
    const executeRaw = jest.fn().mockResolvedValue(1);
    const service = createService(queryRaw, executeRaw);

    const result = await service.crearMovimientoCaja(
      {
        cajaMenorId: 'caj-1',
        tipoMovimientoCodigo: 'GASTO',
        fechaMovimiento: '2026-09-08T12:00:00.000Z',
        monto: 50000,
        motivo: 'Compra de papeleria',
      },
      usuario('7', ['ADMINISTRADOR']) as never,
    );

    expect(result.id).toBe('mov-100');
    expect(result.monto).toBe(50000);
    expect(result.montoConNaturaleza).toBe(-50000);
    expect(result.tipoMovimiento.naturaleza).toBe('S');
    expect(executeRaw).toHaveBeenCalled();
  });
});
