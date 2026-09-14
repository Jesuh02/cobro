import { ForbiddenException } from '@nestjs/common';

import { ClientesService } from './clientes.service';

describe('ClientesService', () => {
  it('lists clients formatted for tbl schema', async () => {
    const queryRaw = jest
      .fn()
      // 1. listarClientesTbl
      .mockResolvedValueOnce([
        {
          id: 'cli-1',
          nombre_completo: 'Juan Gomez',
          nombre_comercial: 'Tienda Juan',
          notas: null,
          cedula: '123456',
          direccion: 'Calle 1 # 2-3',
          correo: 'juan@test.com',
          latitud: null,
          longitud: null,
          telefono: '3001234567',
          creado_en: new Date('2026-09-01T00:00:00.000Z'),
          actualizado_en: new Date('2026-09-01T00:00:00.000Z'),
          activo: true,
        },
      ]);

    const tenantScope = {
      obtenerScopeOrganizacionTbl: jest.fn().mockResolvedValue({
        usuarioId: 'u-1',
        organizacionId: 'org-1',
      }),
      puedeVerDatosOrganizacion: jest.fn().mockReturnValue(true),
    };

    const cache = { deleteByPrefix: jest.fn() };
    const service = new ClientesService(
      { $queryRaw: queryRaw } as never,
      tenantScope as never,
      {} as never,
      cache as never,
    );

    const result = await service.listarClientes(
      {},
      {
        usuarioId: 'u-1',
        usuario: 'admin',
        organizacionId: 'org-1',
        roles: ['ADMINISTRADOR'],
        permisos: [],
      },
    );

    expect(result).toHaveLength(1);
    expect(result[0].id).toBe('cli-1');
    expect(result[0].nombreCompleto).toBe('Juan Gomez');
    expect(result[0].cedula).toBe('123456');
    expect(result[0].estado.codigo).toBe('ACTIVO');
  });

  it('rejects invalid coordinates on client creation', async () => {
    const service = new ClientesService(
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );

    await expect(
      service.crearCliente(
        {
          nombreCompleto: 'Test Invalido',
          latitud: Number.NaN,
          longitud: -74,
          direccion: 'Calle 1',
        },
        {
          usuarioId: 'u-1',
          usuario: 'admin',
          organizacionId: 'org-1',
          roles: ['ADMINISTRADOR'],
          permisos: [],
        },
      ),
    ).rejects.toThrow('Las coordenadas deben ser números finitos');
  });

  it('creates client in tbl schema and links route', async () => {
    const queryRaw = jest
      .fn()
      // 1. select duplicates
      .mockResolvedValueOnce([{ existe: false }])
      // 2. insert persona
      .mockResolvedValueOnce([{ id: 'per-1' }])
      // 3. insert cliente
      .mockResolvedValueOnce([{ id: 'cli-1' }])
      // 4. select creados
      .mockResolvedValueOnce([
        {
          id: 'cli-1',
          nombre_completo: 'Maria Perez',
          nombre_comercial: null,
          notas: null,
          cedula: '987654',
          direccion: 'Carrera 5',
          correo: null,
          latitud: null,
          longitud: null,
          telefono: '3119876543',
          creado_en: new Date('2026-09-01T00:00:00.000Z'),
          actualizado_en: new Date('2026-09-01T00:00:00.000Z'),
          activo: true,
        },
      ]);

    const executeRaw = jest.fn().mockResolvedValue(1);

    const tx = {
      $queryRaw: queryRaw,
      $executeRaw: executeRaw,
    };

    const prisma = {
      $queryRaw: queryRaw,
      $executeRaw: executeRaw,
      $transaction: async (cb: (t: unknown) => Promise<unknown>) => cb(tx),
    };

    const tenantScope = {
      obtenerScopeOrganizacionTbl: jest.fn().mockResolvedValue({
        usuarioId: 'u-1',
        organizacionId: 'org-1',
      }),
      puedeVerDatosOrganizacion: jest.fn().mockReturnValue(true),
    };

    const rutas = {
      obtenerOCrearRutaCreditoTbl: jest.fn().mockResolvedValue('rut-1'),
    };

    const cache = { deleteByPrefix: jest.fn() };

    const service = new ClientesService(
      prisma as never,
      tenantScope as never,
      rutas as never,
      cache as never,
    );

    const result = await service.crearCliente(
      {
        nombreCompleto: 'Maria Perez',
        cedula: '987654',
        direccion: 'Carrera 5',
        telefono: '3119876543',
      },
      {
        usuarioId: 'u-1',
        usuario: 'admin',
        organizacionId: 'org-1',
        roles: ['ADMINISTRADOR'],
        permisos: [],
      },
    );

    expect(result.id).toBe('cli-1');
    expect(result.nombreCompleto).toBe('Maria Perez');
    expect(rutas.obtenerOCrearRutaCreditoTbl).toHaveBeenCalled();
    expect(cache.deleteByPrefix).toHaveBeenCalledWith('cobros:');
  });

  it('rejects client deletion for non-administrators', async () => {
    const tenantScope = {
      esAdministrador: jest.fn().mockReturnValue(false),
    };

    const service = new ClientesService(
      {} as never,
      tenantScope as never,
      {} as never,
      {} as never,
    );

    await expect(
      service.eliminarCliente('cli-1', {
        usuarioId: 'u-cobrador',
        usuario: 'cobrador',
        organizacionId: 'org-1',
        roles: ['COBRADOR'],
        permisos: [],
      }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('rejects client update when employee lacks MODIFICAR_CLIENTES permission', async () => {
    const tenantScope = {
      esAdministrador: jest.fn().mockReturnValue(false),
    };

    const service = new ClientesService(
      {} as never,
      tenantScope as never,
      {} as never,
      {} as never,
    );

    await expect(
      service.actualizarCliente(
        'cli-1',
        { nombreCompleto: 'Nuevo Nombre' },
        {
          usuarioId: 'u-cobrador',
          usuario: 'cobrador',
          organizacionId: 'org-1',
          roles: ['COBRADOR'],
          permisos: ['CREAR_CREDITOS'],
        },
      ),
    ).rejects.toThrow(ForbiddenException);
  });

  it('allows client update when employee has MODIFICAR_CLIENTES permission', async () => {
    const actual = {
      id: 'cli-1',
      persona_id: 'per-1',
      nombre_completo: 'Juan Gomez',
      nombre_comercial: null,
      notas: null,
      cedula: '123456',
      direccion: 'Calle 1',
      correo: null,
      latitud: null,
      longitud: null,
      telefono: '3001234567',
      creado_en: new Date('2026-09-01T00:00:00.000Z'),
      actualizado_en: new Date('2026-09-01T00:00:00.000Z'),
      activo: true,
    };

    const actualizado = {
      ...actual,
      nombre_completo: 'Juan Gomez Actualizado',
    };

    const queryRaw = jest
      .fn()
      // 1. tx: query existing
      .mockResolvedValueOnce([actual])
      // 2. after tx: query updated
      .mockResolvedValueOnce([actualizado]);

    const executeRaw = jest.fn().mockResolvedValue(1);

    const tx = {
      $queryRaw: queryRaw,
      $executeRaw: executeRaw,
    };

    const prisma = {
      $queryRaw: queryRaw,
      $executeRaw: executeRaw,
      $transaction: async (cb: (t: unknown) => Promise<unknown>) => cb(tx),
    };

    const tenantScope = {
      esAdministrador: jest.fn().mockReturnValue(false),
      obtenerScopeOrganizacionTbl: jest.fn().mockResolvedValue({
        usuarioId: 'u-cobrador',
        organizacionId: 'org-1',
      }),
    };

    const cache = { deleteByPrefix: jest.fn() };

    const service = new ClientesService(
      prisma as never,
      tenantScope as never,
      {} as never,
      cache as never,
    );

    const result = await service.actualizarCliente(
      'cli-1',
      { nombreCompleto: 'Juan Gomez Actualizado' },
      {
        usuarioId: 'u-cobrador',
        usuario: 'cobrador',
        organizacionId: 'org-1',
        roles: ['COBRADOR'],
        permisos: ['MODIFICAR_CLIENTES'],
      },
    );

    expect(result.id).toBe('cli-1');
    expect(result.nombreCompleto).toBe('Juan Gomez Actualizado');
    expect(cache.deleteByPrefix).toHaveBeenCalledWith('cobros:');
  });
});

