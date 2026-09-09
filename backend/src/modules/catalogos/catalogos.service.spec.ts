import { CatalogosService } from './catalogos.service';

describe('CatalogosService', () => {
  it('returns catalogos formatted for tbl schema', async () => {
    const queryRaw = jest
      .fn()
      // 1. obtenerMonedasTbl
      .mockResolvedValueOnce([
        {
          codigo: 'COP',
          nombre: 'Peso colombiano',
          simbolo: '$',
          decimales: 0,
        },
      ])
      // 2. catalogos (frecuencia_pago, medio_pago, etc.)
      .mockResolvedValueOnce([
        {
          tipo: 'frecuencia_pago',
          id: '1',
          codigo: 'DIARIO',
          nombre: 'Diario',
          extra: '1',
          activo: true,
        },
        {
          tipo: 'medio_pago',
          id: '1',
          codigo: 'EFECTIVO',
          nombre: 'Efectivo',
          extra: null,
          activo: true,
        },
        {
          tipo: 'tipo_movimiento_caja',
          id: '1',
          codigo: 'APERTURA',
          nombre: 'Apertura',
          extra: 'E',
          activo: true,
        },
        {
          tipo: 'categoria_gasto',
          id: '1',
          codigo: 'TRANSPORTE',
          nombre: 'Transporte',
          extra: null,
          activo: true,
        },
      ])
      // 3. listarRutasTbl
      .mockResolvedValueOnce([])
      // 4. cajasMenores
      .mockResolvedValueOnce([])
      // 5. usuarios
      .mockResolvedValueOnce([
        {
          id: 'u-1',
          usuario: 'testuser',
          nombres: 'Test',
          apellidos: 'User',
          correo: 'test@example.com',
          telefono: null,
        },
      ]);

    const tenantScope = {
      obtenerScopeOrganizacionTbl: jest.fn().mockResolvedValue({
        usuarioId: 'u-1',
        organizacionId: 'org-1',
      }),
      puedeVerDatosOrganizacion: jest.fn().mockReturnValue(true),
    };

    const service = new CatalogosService(
      { $queryRaw: queryRaw } as never,
      tenantScope as never,
    );

    const result = await service.obtenerCatalogos({
      usuarioId: 'u-1',
      usuario: 'testuser',
      organizacionId: 'org-1',
      roles: ['ADMINISTRADOR'],
      permisos: [],
    });

    expect(result).toHaveProperty('monedas');
    expect(result.monedas).toHaveLength(1);
    expect(result.monedas[0].codigo).toBe('COP');
    expect(result.frecuenciasPago[0].codigo).toBe('DIARIO');
    expect(result.mediosPago[0].codigo).toBe('EFECTIVO');
    expect(result.usuarios[0].usuario).toBe('testuser');

    // Verify raw SQL avoids non-existent columns (pcr_activo, med_codigo, frecuencia_pago_enum)
    const sqlObj = queryRaw.mock.calls[1][0];
    const rawSql = Array.isArray(sqlObj.strings)
      ? sqlObj.strings.join('')
      : (sqlObj.sql ?? '');
    expect(rawSql).not.toContain('pcr_activo');
    expect(rawSql).not.toContain('med_codigo');
    expect(rawSql).not.toContain('frecuencia_pago_enum');
    expect(rawSql).toContain('med_tipo');
  });

  it('provides default COP currency fallback when tbl_monedas is empty', async () => {
    const queryRaw = jest
      .fn()
      .mockResolvedValueOnce([]) // empty monedas
      .mockResolvedValueOnce([]) // catalogos
      .mockResolvedValueOnce([]) // rutas
      .mockResolvedValueOnce([]) // cajas
      .mockResolvedValueOnce([]); // usuarios

    const tenantScope = {
      obtenerScopeOrganizacionTbl: jest.fn().mockResolvedValue({
        usuarioId: 'u-1',
        organizacionId: 'org-1',
      }),
      puedeVerDatosOrganizacion: jest.fn().mockReturnValue(true),
    };

    const service = new CatalogosService(
      { $queryRaw: queryRaw } as never,
      tenantScope as never,
    );

    const result = await service.obtenerCatalogos({
      usuarioId: 'u-1',
      usuario: 'testuser',
      organizacionId: 'org-1',
      roles: ['ADMINISTRADOR'],
      permisos: [],
    });

    expect(result.monedas).toHaveLength(1);
    expect(result.monedas[0].codigo).toBe('COP');
  });
});
