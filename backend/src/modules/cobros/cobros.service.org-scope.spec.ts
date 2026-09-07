import { CobrosService } from './cobros.service';

describe('CobrosService organization scope', () => {
  it('filters tbl clients by the authenticated organization', async () => {
    const queryRaw = jest
      .fn<Promise<unknown[]>, [unknown]>()
      .mockResolvedValueOnce([{ usuario_id: '7', organizacion_id: '10' }])
      .mockResolvedValueOnce([
        {
          id: '21',
          nombre_completo: 'Cliente Org A',
          nombre_comercial: null,
          notas: null,
          cedula: '123',
          direccion: null,
          latitud: null,
          longitud: null,
          telefono: null,
          creado_en: new Date('2026-08-29T00:00:00.000Z'),
          actualizado_en: new Date('2026-08-29T00:00:00.000Z'),
          activo: true,
        },
      ]);
    const service = createService(queryRaw);

    const result = await servicePrivate(service).listarClientesTbl(
      {},
      usuarioOrganizacion('10'),
    );

    expect(result).toHaveLength(1);
    const [, clientesQuery] = queryRaw.mock.calls;
    expect(sqlText(clientesQuery[0])).toContain('c.org_id =');
    expect(sqlValues(clientesQuery[0])).toContain('10');
  });

  it('keeps administrator tbl routes inside their organization', async () => {
    const queryRaw = jest
      .fn<Promise<unknown[]>, [unknown]>()
      .mockResolvedValueOnce([{ usuario_id: '7', organizacion_id: '10' }])
      .mockResolvedValueOnce([]);
    const service = createService(queryRaw);

    await servicePrivate(service).listarRutasTbl(usuarioOrganizacion('10'));

    const [, rutasQuery] = queryRaw.mock.calls;
    expect(sqlText(rutasQuery[0])).toContain('r.org_id =');
    expect(sqlValues(rutasQuery[0])).toContain('10');
  });

  it('limits tbl clients to routes assigned to the authenticated collector', async () => {
    const queryRaw = jest
      .fn<Promise<unknown[]>, [unknown]>()
      .mockResolvedValueOnce([{ usuario_id: '7', organizacion_id: '10' }])
      .mockResolvedValueOnce([]);
    const service = createService(queryRaw);

    await servicePrivate(service).listarClientesTbl(
      {},
      usuarioOrganizacion('10', ['COBRADOR']),
    );

    const [, clientesQuery] = queryRaw.mock.calls;
    const text = sqlText(clientesQuery[0]);
    const values = sqlValues(clientesQuery[0]);
    expect(text).toContain('public.tbl_rutas_clientes rc_acl');
    expect(text).toContain('r_acl.usu_id =');
    expect(values).toContain('7');
    expect(values).toContain('10');
  });

  it('allows auditors to see all tbl routes in their organization', async () => {
    const queryRaw = jest
      .fn<Promise<unknown[]>, [unknown]>()
      .mockResolvedValueOnce([{ usuario_id: '7', organizacion_id: '10' }])
      .mockResolvedValueOnce([]);
    const service = createService(queryRaw);

    await servicePrivate(service).listarRutasTbl(
      usuarioOrganizacion('10', ['AUDITOR']),
    );

    const [, rutasQuery] = queryRaw.mock.calls;
    expect(sqlText(rutasQuery[0])).toContain('r.org_id =');
    expect(sqlValues(rutasQuery[0])).toEqual(['10']);
  });

  it('rejects cobrador without CREAR_CAJA_MENOR permission from creating caja menor', async () => {
    const queryRaw = jest.fn<Promise<unknown[]>, [unknown]>();
    const service = createService(queryRaw);
    const usuarioCobrador = {
      usuarioId: '7',
      usuario: 'cobre',
      organizacionId: '10',
      roles: ['COBRADOR'],
      permisos: [],
    };

    await expect(
      service.crearCajaMenor({ nombre: 'Caja 1' }, usuarioCobrador as never),
    ).rejects.toThrow('No tienes permiso para crear caja menor');
  });

  it('allows administrator to target an employee in the same organization for caja menor', async () => {
    const queryRaw = jest
      .fn<Promise<unknown[]>, [unknown]>()
      .mockResolvedValueOnce([{ usuario_id: '7', organizacion_id: '10' }])
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
      .mockResolvedValueOnce([])
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
    (service as unknown as { esquemaTblDisponible: boolean }).esquemaTblDisponible = true;

    const result = await service.crearCajaMenor(
      { nombre: 'Caja Carlos', responsableUsuarioId: '22' },
      usuarioOrganizacion('10') as never,
    );

    expect(result.id).toBe('caj-1');
    expect(result.responsable.id).toBe('22');
    const [, responsableQuery] = queryRaw.mock.calls;
    expect(sqlText(responsableQuery[0])).toContain('tu.id_usu =');
    expect(sqlValues(responsableQuery[0])).toContain('22');
    expect(sqlValues(responsableQuery[0])).toContain('10');
  });

  it('forces cobrador with CREAR_CAJA_MENOR permission to target themselves', async () => {
    const queryRaw = jest
      .fn<Promise<unknown[]>, [unknown]>()
      .mockResolvedValueOnce([{ usuario_id: '7', organizacion_id: '10' }])
      .mockResolvedValueOnce([
        {
          id: '7',
          usuario: 'cobre',
          nombres: 'Jesus',
          apellidos: 'Herazo',
          correo: 'jesus@mail.com',
          telefono: '3001234567',
          organizacion_id: '10',
        },
      ])
      .mockResolvedValueOnce([{ id: 'mon-1', codigo: 'COP' }])
      .mockResolvedValueOnce([])
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
    (service as unknown as { esquemaTblDisponible: boolean }).esquemaTblDisponible = true;

    const usuarioCobradorConPermiso = {
      usuarioId: '7',
      usuario: 'cobre',
      organizacionId: '10',
      roles: ['COBRADOR'],
      permisos: ['CREAR_CAJA_MENOR'],
    };

    const result = await service.crearCajaMenor(
      { nombre: 'Caja Propia', responsableUsuarioId: '99' },
      usuarioCobradorConPermiso as never,
    );

    expect(result.id).toBe('caj-7');
    expect(result.responsable.id).toBe('7');
    const [, responsableQuery] = queryRaw.mock.calls;
    expect(sqlValues(responsableQuery[0])).toContain('7');
    expect(sqlValues(responsableQuery[0])).not.toContain('99');
  });
});

type QueryRawMock = jest.Mock<Promise<unknown[]>, [unknown]>;

function createService(queryRaw: QueryRawMock, executeRaw?: jest.Mock) {
  const txClient = {
    $queryRaw: queryRaw,
    $executeRaw: executeRaw ?? jest.fn().mockResolvedValue(1),
  };
  return new CobrosService(
    {
      $queryRaw: queryRaw,
      $executeRaw: txClient.$executeRaw,
      $transaction: async (cb: (tx: unknown) => Promise<unknown>) => cb(txClient),
    } as never,
    {} as never,
    {} as never,
    { deleteByPrefix: jest.fn() } as never,
  );
}

function servicePrivate(service: CobrosService) {
  return service as unknown as {
    listarClientesTbl: (query: unknown, usuario: unknown) => Promise<unknown[]>;
    listarRutasTbl: (usuario: unknown) => Promise<unknown[]>;
  };
}

function usuarioOrganizacion(
  organizacionId: string,
  roles: string[] = ['ADMINISTRADOR'],
) {
  return {
    usuarioId: '7',
    usuario: 'admin',
    organizacionId,
    roles,
    permisos: [],
  };
}

function sqlText(value: unknown) {
  const sql = value as { strings?: string[]; sql?: string };
  return sql.strings?.join(' ') ?? sql.sql ?? String(value);
}

function sqlValues(value: unknown) {
  return ((value as { values?: unknown[] }).values ?? []).map(String);
}
