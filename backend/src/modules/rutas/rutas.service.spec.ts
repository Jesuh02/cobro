import { ForbiddenException } from '@nestjs/common';

import { RutasService } from './rutas.service';

describe('RutasService', () => {
  it('lists routes formatted for tbl schema', async () => {
    const queryRaw = jest
      .fn()
      // listarRutasTbl
      .mockResolvedValueOnce([
        {
          id: 'rut-1',
          nombre: 'Ruta Centro',
          descripcion: 'Zona centro',
          activa: true,
          responsable_id: 'u-1',
          responsable_usuario: 'carlos',
          responsable_nombres: 'Carlos',
          responsable_apellidos: 'Perez',
          responsable_correo: 'carlos@test.com',
          responsable_telefono: '3001234567',
          clientes: 5,
          creditos: 10,
        },
      ]);

    const tenantScope = {
      obtenerScopeOrganizacionTbl: jest.fn().mockResolvedValue({
        usuarioId: 'u-1',
        organizacionId: 'org-1',
      }),
      puedeVerDatosOrganizacion: jest.fn().mockReturnValue(true),
    };

    const service = new RutasService(
      { $queryRaw: queryRaw } as never,
      tenantScope as never,
      {} as never,
    );

    const result = await service.listarRutas({
      usuarioId: 'u-1',
      usuario: 'carlos',
      organizacionId: 'org-1',
      roles: ['ADMINISTRADOR'],
      permisos: [],
    });

    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('rut-1');
    expect(result[0].nombre).toBe('Ruta Centro');
    expect(result[0].estado.codigo).toBe('ABIERTA');
    expect(result[0].responsable.nombreCompleto).toBe('Carlos Perez');
    expect(result[0].clientes).toBe(5);
    expect(result[0].creditos).toBe(10);
  });

  it('lists cobros ruta for tbl schema', async () => {
    const queryRaw = jest
      .fn()
      // listarCobrosRutaTbl
      .mockResolvedValueOnce([
        {
          credito_id: 'cre-1',
          cliente_id: 'cli-1',
          cliente: 'Juan Gomez',
          cedula: '123456',
          negocio: 'Tienda Juan',
          direccion: 'Calle 1 # 2-3',
          latitud: null,
          longitud: null,
          ruta_id: 'rut-1',
          ruta: 'Ruta Centro',
          moneda_codigo: 'COP',
          valor_principal: '100000',
          valor_total: '120000',
          valor_cuota: '10000',
          total_abonado: '20000',
          saldo: '100000',
          numero_cuotas: 12,
          cuotas_restantes: 10,
          fecha_inicio: new Date('2026-09-01T00:00:00.000Z'),
          fecha_maxima: new Date('2026-09-30T00:00:00.000Z'),
          proxima_cuota_id: 'cuo-3',
          proxima_numero_cuota: 3,
          proxima_fecha_pago: new Date('2026-09-10T00:00:00.000Z'),
          proximo_valor_cuota: '10000',
          proximo_saldo_cuota: '10000',
          estado_cobro: 'PENDIENTE',
        },
      ]);

    const tenantScope = {
      obtenerScopeOrganizacionTbl: jest.fn().mockResolvedValue({
        usuarioId: 'u-1',
        organizacionId: 'org-1',
      }),
      puedeVerDatosOrganizacion: jest.fn().mockReturnValue(true),
    };

    const service = new RutasService(
      { $queryRaw: queryRaw } as never,
      tenantScope as never,
      {} as never,
    );

    const result = await service.listarCobrosRuta(
      { rutaId: 'rut-1' },
      {
        usuarioId: 'u-1',
        usuario: 'carlos',
        organizacionId: 'org-1',
        roles: ['ADMINISTRADOR'],
        permisos: [],
      },
    );

    expect(result).toHaveLength(1);
    expect(result[0].creditoId).toBe('cre-1');
    expect(result[0].cliente).toBe('Juan Gomez');
    expect(result[0].saldo).toBe(100000);
    expect(result[0].proximaNumeroCuota).toBe(3);
    expect(result[0].estadoCobro).toBe('PENDIENTE');
  });

  it('exportarCobrosRuta generates excel export from cobros ruta', async () => {
    const queryRaw = jest
      .fn()
      // listarCobrosRutaTbl
      .mockResolvedValueOnce([
        {
          credito_id: 'cre-1',
          cliente_id: 'cli-1',
          cliente: 'Juan Gomez',
          cedula: '123456',
          negocio: 'Tienda Juan',
          direccion: 'Calle 1 # 2-3',
          latitud: null,
          longitud: null,
          ruta_id: 'rut-1',
          ruta: 'Ruta Centro',
          moneda_codigo: 'COP',
          valor_principal: '100000',
          valor_total: '120000',
          valor_cuota: '10000',
          total_abonado: '20000',
          saldo: '100000',
          numero_cuotas: 12,
          cuotas_restantes: 10,
          fecha_inicio: new Date('2026-09-01T00:00:00.000Z'),
          fecha_maxima: new Date('2026-09-30T00:00:00.000Z'),
          proxima_cuota_id: 'cuo-3',
          proxima_numero_cuota: 3,
          proxima_fecha_pago: new Date('2026-09-10T00:00:00.000Z'),
          proximo_valor_cuota: '10000',
          proximo_saldo_cuota: '10000',
          estado_cobro: 'PENDIENTE',
        },
      ]);

    const tenantScope = {
      obtenerScopeOrganizacionTbl: jest.fn().mockResolvedValue({
        usuarioId: 'u-1',
        organizacionId: 'org-1',
      }),
      puedeVerDatosOrganizacion: jest.fn().mockReturnValue(true),
    };

    const exportaciones = {
      asegurarTamanoExportacion: jest.fn(),
      formatearHojaExportacion: jest.fn(),
      crearVistaPreviaExportacion: jest.fn().mockReturnValue({
        columnas: [],
        filas: [],
      }),
      subirWorkbookExportacion: jest.fn().mockResolvedValue({
        archivo: 'cobros-ruta-2026-09-08.xlsx',
        key: 'cobros-ruta/cobros-ruta-2026-09-08.xlsx',
        url: 'https://storage.example.com/cobros-ruta.xlsx',
        urlExpiraEnSegundos: 3600,
        filas: 1,
        generadoEn: new Date().toISOString(),
        vistaPrevia: { columnas: [], filas: [] },
      }),
    };

    const service = new RutasService(
      { $queryRaw: queryRaw } as never,
      tenantScope as never,
      exportaciones as never,
    );

    const result = await service.exportarCobrosRuta(
      { rutaId: 'rut-1' },
      {
        usuarioId: 'u-1',
        usuario: 'carlos',
        organizacionId: 'org-1',
        roles: ['ADMINISTRADOR'],
        permisos: [],
      },
    );

    expect(exportaciones.asegurarTamanoExportacion).toHaveBeenCalledWith(1);
    expect(exportaciones.formatearHojaExportacion).toHaveBeenCalled();
    expect(exportaciones.crearVistaPreviaExportacion).toHaveBeenCalled();
    expect(exportaciones.subirWorkbookExportacion).toHaveBeenCalled();
    expect(result.archivo).toBe('cobros-ruta-2026-09-08.xlsx');
    expect(result.filas).toBe(1);
    expect(result.url).toBe('https://storage.example.com/cobros-ruta.xlsx');
  });

  it('obtenerOCrearRutaCreditoTbl returns existing route if found', async () => {
    const tx = {
      $queryRaw: jest.fn().mockResolvedValueOnce([{ id: 'rut-existing' }]),
    };

    const service = new RutasService({} as never, {} as never, {} as never);

    const id = await service.obtenerOCrearRutaCreditoTbl(
      tx as never,
      'rut-existing',
      'org-1',
      'u-1',
      'carlos',
    );

    expect(id).toBe('rut-existing');
  });

  it('obtenerOCrearRutaCreditoTbl throws not found if routeId does not exist', async () => {
    const tx = {
      $queryRaw: jest.fn().mockResolvedValueOnce([]),
    };

    const service = new RutasService({} as never, {} as never, {} as never);

    await expect(
      service.obtenerOCrearRutaCreditoTbl(
        tx as never,
        'rut-nonexistent',
        'org-1',
        'u-1',
        'carlos',
      ),
    ).rejects.toThrow('Ruta no encontrada');
  });

  it('obtenerOCrearRutaCreditoTbl creates new route if none exists', async () => {
    const tx = {
      $queryRaw: jest
        .fn()
        // 1. SELECT existente -> none
        .mockResolvedValueOnce([])
        // 2. INSERT nueva ruta
        .mockResolvedValueOnce([{ id: 'rut-new' }]),
    };

    const service = new RutasService({} as never, {} as never, {} as never);

    const id = await service.obtenerOCrearRutaCreditoTbl(
      tx as never,
      undefined,
      'org-1',
      'u-1',
      'carlos',
    );

    expect(id).toBe('rut-new');
  });

  it('asegurarResponsableRuta verifies user access', () => {
    const tenantScope = {
      puedeVerDatosOrganizacion: jest
        .fn()
        .mockReturnValueOnce(true)
        .mockReturnValueOnce(false)
        .mockReturnValueOnce(false),
    };

    const service = new RutasService(
      {} as never,
      tenantScope as never,
      {} as never,
    );

    const admin = {
      usuarioId: 'u-admin',
      usuario: 'admin',
      organizacionId: 'org-1',
      roles: ['ADMINISTRADOR'],
      permisos: [],
    };
    const user1 = {
      usuarioId: 'u-1',
      usuario: 'user1',
      organizacionId: 'org-1',
      roles: ['COBRADOR'],
      permisos: [],
    };

    // Admin passes
    expect(() => service.asegurarResponsableRuta('u-2', admin)).not.toThrow();

    // User matching responsible passes
    expect(() => service.asegurarResponsableRuta('u-1', user1)).not.toThrow();

    // User not matching responsible throws ForbiddenException
    expect(() => service.asegurarResponsableRuta('u-2', user1)).toThrow(
      ForbiddenException,
    );
  });
});
