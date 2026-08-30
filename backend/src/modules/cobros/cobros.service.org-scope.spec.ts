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
});

type QueryRawMock = jest.Mock<Promise<unknown[]>, [unknown]>;

function createService(queryRaw: QueryRawMock) {
  return new CobrosService(
    { $queryRaw: queryRaw } as never,
    {} as never,
    {} as never,
    {} as never,
  );
}

function servicePrivate(service: CobrosService) {
  return service as unknown as {
    listarClientesTbl: (query: unknown, usuario: unknown) => Promise<unknown[]>;
    listarRutasTbl: (usuario: unknown) => Promise<unknown[]>;
  };
}

function usuarioOrganizacion(organizacionId: string) {
  return {
    usuarioId: '7',
    usuario: 'admin',
    organizacionId,
    roles: ['ADMINISTRADOR'],
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
