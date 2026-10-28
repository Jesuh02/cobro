import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AuthenticatedUser } from './auth.types';

import { InMemoryCacheService } from '../../common/cache/in-memory-cache.service';
import { AuthService } from './auth.service';
import { PasswordService } from './password.service';

describe('AuthService - Account Lockout (SEC-COBRO-04)', () => {
  let authService: AuthService;
  let cacheService: InMemoryCacheService;
  let mockPrisma: any;
  let mockPasswords: any;
  let mockConfig: any;

  const mockUserTbl = {
    id: '11111111-1111-1111-1111-111111111111',
    usuario: 'testuser',
    passwordHash: 'argon2id$mocked$hash',
    nombres: 'Test',
    apellidos: 'User',
    correo: 'test@example.com',
    activo: true,
    organizacionId: '22222222-2222-2222-2222-222222222222',
    roles: ['ADMINISTRADOR'],
    permisos: [],
    tieneAccesoOrganizacion: true,
    organizacionSuspendida: false,
  };

  beforeEach(() => {
    mockConfig = {
      get: jest.fn((key: string, defaultValue?: any) => {
        if (key === 'AUTH_TOKEN_SECRET') return 'super-secret-key-that-is-long-enough-32';
        if (key === 'TOKEN_EXPIRATION') return '24h';
        if (key === 'CACHE_TTL_MS') return 30000;
        if (key === 'CACHE_MAX_ENTRIES') return 2000;
        return defaultValue ?? null;
      }),
    };

    cacheService = new InMemoryCacheService(mockConfig as unknown as ConfigService);

    mockPasswords = {
      verify: jest.fn(),
      hash: jest.fn(),
      needsRehash: jest.fn().mockReturnValue(false),
    };

    mockPrisma = {
      $queryRaw: jest.fn().mockResolvedValue([mockUserTbl]),
      $executeRaw: jest.fn().mockResolvedValue(1),
    };

    authService = new AuthService(
      mockPrisma,
      mockPasswords as unknown as PasswordService,
      mockConfig as unknown as ConfigService,
      cacheService,
    );
  });

  it('allows successful login and clears failed attempts', async () => {
    cacheService.set('auth:failed:testuser', 2);
    mockPasswords.verify.mockResolvedValue(true);

    const session = await authService.login({
      usuario: 'TestUser',
      contrasena: 'ValidPassword123!',
    });

    expect(session).toBeDefined();
    expect(session.usuario.usuario).toBe('testuser');
    expect(cacheService.get('auth:failed:testuser').hit).toBe(false);
    expect(cacheService.get('auth:lockout:testuser').hit).toBe(false);
  });

  it('increments failed attempts on incorrect password', async () => {
    mockPasswords.verify.mockResolvedValue(false);

    await expect(
      authService.login({
        usuario: 'testuser',
        contrasena: 'WrongPassword',
      }),
    ).rejects.toThrow('Usuario o contrasena invalidos');

    const cached = cacheService.get<number>('auth:failed:testuser');
    expect(cached.hit).toBe(true);
    if (cached.hit) {
      expect(cached.value).toBe(1);
    }
  });

  it('locks out account for 5 minutes on the 5th consecutive failed attempt', async () => {
    mockPasswords.verify.mockResolvedValue(false);

    // First 4 failed attempts
    for (let i = 1; i <= 4; i++) {
      await expect(
        authService.login({
          usuario: 'testuser',
          contrasena: 'WrongPassword',
        }),
      ).rejects.toThrow('Usuario o contrasena invalidos');
    }

    // 5th failed attempt should trigger lockout
    await expect(
      authService.login({
        usuario: 'testuser',
        contrasena: 'WrongPassword',
      }),
    ).rejects.toThrow(
      'Cuenta bloqueada temporalmente por demasiados intentos fallidos. Intenta más tarde en 5 minutos.',
    );

    // Verify lockout entry exists and failed entry was deleted
    const lockout = cacheService.get<number>('auth:lockout:testuser');
    expect(lockout.hit).toBe(true);
    expect(cacheService.get('auth:failed:testuser').hit).toBe(false);
  });

  it('rejects login immediately while account is locked out without checking password', async () => {
    cacheService.set('auth:lockout:testuser', Date.now(), { ttlMs: 300_000 });

    await expect(
      authService.login({
        usuario: 'testuser',
        contrasena: 'ValidPassword123!',
      }),
    ).rejects.toThrow(
      'Cuenta bloqueada temporalmente por demasiados intentos fallidos. Intenta más tarde en 5 minutos.',
    );

    // Password verification and DB queries should NOT have been invoked
    expect(mockPasswords.verify).not.toHaveBeenCalled();
    expect(mockPrisma.$queryRaw).not.toHaveBeenCalled();
  });

  describe('actualizarEmpleado', () => {
    const adminUser = {
      usuarioId: '11111111-1111-1111-1111-111111111111',
      usuario: 'adminuser',
      organizacionId: '22222222-2222-2222-2222-222222222222',
      roles: ['ADMINISTRADOR'],
      permisos: [],
    };

    const empleadoId = '33333333-3333-3333-3333-333333333333';

    it('updates employee information successfully without changing password', async () => {
      const tx = {
        $queryRaw: jest
          .fn()
          // 1. obtenerOrganizacionActivaAdministradorTbl
          .mockResolvedValueOnce([{ org_id: adminUser.organizacionId }])
          // 2. buscar empleado
          .mockResolvedValueOnce([
            { usuario_id: empleadoId, persona_id: '44444444-4444-4444-4444-444444444444' },
          ])
          // 3. existenteUsuario (Promise.all item 0)
          .mockResolvedValueOnce([])
          // 4. existenteCorreo (Promise.all item 1)
          .mockResolvedValueOnce([]),
        $executeRaw: jest.fn().mockResolvedValue(1),
      };

      mockPrisma.$transaction = jest.fn(async (cb) => cb(tx));
      mockPrisma.$queryRaw = jest.fn().mockResolvedValueOnce([
        {
          ...mockUserTbl,
          id: empleadoId,
          usuario: 'empleado_modificado',
          nombres: 'Juan',
          apellidos: 'Perez',
          correo: 'juan.perez@example.com',
          roles: ['COBRADOR'],
        },
      ]);

      const resultado = await authService.actualizarEmpleado(adminUser, empleadoId, {
        nombreCompleto: 'Juan Perez',
        usuario: 'empleado_modificado',
        correo: 'juan.perez@example.com',
      });

      expect(resultado.usuario).toBe('empleado_modificado');
      expect(resultado.nombreCompleto).toBe('Juan Perez');
      expect(tx.$executeRaw).toHaveBeenCalledTimes(2);
      expect(mockPasswords.hash).not.toHaveBeenCalled();
    });

    it('updates employee information and password, clearing lockout cache', async () => {
      const tx = {
        $queryRaw: jest
          .fn()
          // 1. obtenerOrganizacionActivaAdministradorTbl
          .mockResolvedValueOnce([{ org_id: adminUser.organizacionId }])
          // 2. buscar empleado
          .mockResolvedValueOnce([
            { usuario_id: empleadoId, persona_id: '44444444-4444-4444-4444-444444444444' },
          ])
          // 3. existenteUsuario
          .mockResolvedValueOnce([])
          // 4. existenteCorreo
          .mockResolvedValueOnce([]),
        $executeRaw: jest.fn().mockResolvedValue(1),
      };

      mockPrisma.$transaction = jest.fn(async (cb) => cb(tx));
      mockPasswords.hash.mockResolvedValue('new-hashed-password');
      mockPrisma.$queryRaw = jest.fn().mockResolvedValueOnce([
        {
          ...mockUserTbl,
          id: empleadoId,
          usuario: 'empleado_nuevo',
          roles: ['COBRADOR'],
        },
      ]);

      cacheService.set('auth:failed:empleado_nuevo', 3);
      cacheService.set('auth:lockout:empleado_nuevo', Date.now());

      const resultado = await authService.actualizarEmpleado(adminUser, empleadoId, {
        nombreCompleto: 'Juan Perez',
        usuario: 'empleado_nuevo',
        correo: 'juan.nuevo@example.com',
        contrasena: 'NuevaClaveSegura123!',
      });

      expect(resultado.usuario).toBe('empleado_nuevo');
      expect(mockPasswords.hash).toHaveBeenCalledWith('NuevaClaveSegura123!');
      expect(cacheService.get('auth:failed:empleado_nuevo').hit).toBe(false);
      expect(cacheService.get('auth:lockout:empleado_nuevo').hit).toBe(false);
    });

    it('rejects update if username already exists', async () => {
      const tx = {
        $queryRaw: jest
          .fn()
          // 1. obtenerOrganizacionActivaAdministradorTbl
          .mockResolvedValueOnce([{ org_id: adminUser.organizacionId }])
          // 2. buscar empleado
          .mockResolvedValueOnce([
            { usuario_id: empleadoId, persona_id: '44444444-4444-4444-4444-444444444444' },
          ])
          // 3. existenteUsuario -> DUPLICADO
          .mockResolvedValueOnce([{ id: 'otro-usuario-id' }])
          // 4. existenteCorreo
          .mockResolvedValueOnce([]),
        $executeRaw: jest.fn(),
      };

      mockPrisma.$transaction = jest.fn(async (cb) => cb(tx));

      await expect(
        authService.actualizarEmpleado(adminUser, empleadoId, {
          nombreCompleto: 'Juan Perez',
          usuario: 'existente',
          correo: 'juan@example.com',
        }),
      ).rejects.toThrow('El usuario ya existe');
    });

    it('rejects update if email already exists', async () => {
      const tx = {
        $queryRaw: jest
          .fn()
          // 1. obtenerOrganizacionActivaAdministradorTbl
          .mockResolvedValueOnce([{ org_id: adminUser.organizacionId }])
          // 2. buscar empleado
          .mockResolvedValueOnce([
            { usuario_id: empleadoId, persona_id: '44444444-4444-4444-4444-444444444444' },
          ])
          // 3. existenteUsuario
          .mockResolvedValueOnce([])
          // 4. existenteCorreo -> DUPLICADO
          .mockResolvedValueOnce([{ id: 'otro-usuario-id' }]),
        $executeRaw: jest.fn(),
      };

      mockPrisma.$transaction = jest.fn(async (cb) => cb(tx));

      await expect(
        authService.actualizarEmpleado(adminUser, empleadoId, {
          nombreCompleto: 'Juan Perez',
          usuario: 'empleado_1',
          correo: 'existente@example.com',
        }),
      ).rejects.toThrow('El correo ya esta registrado');
    });
  });

  describe('listarEmpleados', () => {
    it('rejects non-admin users from viewing employees', async () => {
      const cobradorUser = {
        usuarioId: '55555555-5555-5555-5555-555555555555',
        usuario: 'cobrador1',
        organizacionId: '22222222-2222-2222-2222-222222222222',
        roles: ['COBRADOR'],
        permisos: [],
      };

      await expect(authService.listarEmpleados(cobradorUser)).rejects.toThrow(
        'Solo el administrador puede ver empleados',
      );
    });

    it('allows admin users to view employees', async () => {
      const adminUser = {
        usuarioId: '11111111-1111-1111-1111-111111111111',
        usuario: 'adminuser',
        organizacionId: '22222222-2222-2222-2222-222222222222',
        roles: ['ADMINISTRADOR'],
        permisos: [],
      };

      mockPrisma.$transaction = jest.fn(async (cb) => cb(mockPrisma));
      mockPrisma.$queryRaw = jest
        .fn()
        // 1. obtenerOrganizacionActivaAdministradorTbl
        .mockResolvedValueOnce([{ org_id: adminUser.organizacionId }])
        // 2. listar empleados
        .mockResolvedValueOnce([]);

      const resultado = await authService.listarEmpleados(adminUser);
      expect(Array.isArray(resultado)).toBe(true);
    });
  });

  describe('cerrarSesion (Token Revocation)', () => {
    it('revokes an active token so subsequent verification throws', async () => {
      const session = (authService as any).crearSesionParaUsuario(mockUserTbl);
      const token = session.token;

      // 1. First verification succeeds
      const verified = authService.verificarToken(token);
      expect(verified.usuarioId).toBe(mockUserTbl.id);

      // 2. User logs out
      const logoutResult = await authService.cerrarSesion(`Bearer ${token}`);
      expect(logoutResult.ok).toBe(true);

      // 3. Subsequent verification fails because token is revoked
      expect(() => authService.verificarToken(token)).toThrow(
        new UnauthorizedException('La sesion fue cerrada'),
      );
    });

    it('handles missing or malformed token gracefully', async () => {
      const emptyResult = await authService.cerrarSesion();
      expect(emptyResult.ok).toBe(true);

      const invalidResult = await authService.cerrarSesion('invalid.token');
      expect(invalidResult.ok).toBe(true);
    });
  });

  describe('SuperAdmin - Gestion de Acceso / Usuarios', () => {
    const superAdminUser: AuthenticatedUser = {
      usuarioId: '33333333-3333-3333-3333-333333333333',
      usuario: 'superadmin',
      organizacionId: null,
      roles: ['SUPER_ADMIN'],
      permisos: [],
    };

    const regularUser: AuthenticatedUser = {
      usuarioId: '44444444-4444-4444-4444-444444444444',
      usuario: 'regular',
      organizacionId: '22222222-2222-2222-2222-222222222222',
      roles: ['ADMINISTRADOR'],
      permisos: [],
    };

    const mockSuperAdminUserRow = {
      id: '55555555-5555-5555-5555-555555555555',
      usuario: 'empleado1',
      activo: true,
      creado_en: new Date('2026-01-01T00:00:00Z'),
      nombres: 'Juan',
      apellidos: 'Perez',
      nombre_completo: 'Juan Perez',
      identificacion: '12345678',
      correo: 'juan@test.com',
      telefono: '3001234567',
      organizacion_id: '22222222-2222-2222-2222-222222222222',
      organizacion_nombre: 'Organizacion A',
      organizacion_suspendida: false,
      roles: ['COBRADOR'],
    };

    describe('listarUsuariosSuperAdmin', () => {
      it('rejects non-superadmin users', async () => {
        await expect(
          authService.listarUsuariosSuperAdmin(regularUser, {}),
        ).rejects.toThrow(ForbiddenException);
      });

      it('lists users successfully for superadmin', async () => {
        mockPrisma.$queryRaw = jest
          .fn()
          .mockResolvedValueOnce([mockSuperAdminUserRow]);

        const resultado = await authService.listarUsuariosSuperAdmin(
          superAdminUser,
          {},
        );

        expect(Array.isArray(resultado)).toBe(true);
        expect(resultado.length).toBe(1);
        expect(resultado[0].usuario).toBe('empleado1');
        expect(resultado[0].nombreCompleto).toBe('Juan Perez');
        expect(resultado[0].organizacionNombre).toBe('Organizacion A');
        expect(resultado[0].roles).toContain('COBRADOR');
      });

      it('applies organization filter when provided', async () => {
        mockPrisma.$queryRaw = jest
          .fn()
          .mockResolvedValueOnce([mockSuperAdminUserRow]);

        const resultado = await authService.listarUsuariosSuperAdmin(
          superAdminUser,
          { organizacionId: '22222222-2222-2222-2222-222222222222' },
        );

        expect(resultado.length).toBe(1);
      });

      it('normalizes accents and punctuation for search and cache keys', async () => {
        mockPrisma.$queryRaw = jest
          .fn()
          .mockResolvedValueOnce([mockSuperAdminUserRow]);

        await authService.listarUsuariosSuperAdmin(superAdminUser, {
          q: 'Jésús.Pérez',
        });
        await authService.listarUsuariosSuperAdmin(superAdminUser, {
          q: 'jesus perez',
        });

        expect(mockPrisma.$queryRaw).toHaveBeenCalledTimes(1);
        const sql = mockPrisma.$queryRaw.mock.calls[0][0] as {
          strings: string[];
          values: unknown[];
        };
        expect(sql.strings.join(' ')).toContain('regexp_replace');
        expect(sql.values).toContain('%jesusperez%');
      });
    });

    describe('actualizarEstadoUsuarioSuperAdmin', () => {
      it('rejects non-superadmin users', async () => {
        await expect(
          authService.actualizarEstadoUsuarioSuperAdmin(
            regularUser,
            '55555555-5555-5555-5555-555555555555',
            { activo: false },
          ),
        ).rejects.toThrow(ForbiddenException);
      });

      it('prevents superadmin from deactivating themselves (anti-lockout)', async () => {
        await expect(
          authService.actualizarEstadoUsuarioSuperAdmin(
            superAdminUser,
            superAdminUser.usuarioId,
            { activo: false },
          ),
        ).rejects.toThrow(
          new BadRequestException('No puedes desactivar tu propio usuario'),
        );
      });

      it('throws NotFoundException when user does not exist', async () => {
        mockPrisma.$queryRaw = jest
          .fn()
          .mockResolvedValueOnce([]);

        await expect(
          authService.actualizarEstadoUsuarioSuperAdmin(
            superAdminUser,
            '99999999-9999-9999-9999-999999999999',
            { activo: false },
          ),
        ).rejects.toThrow(NotFoundException);
      });

      it('updates user status and returns updated user', async () => {
        const targetUserId = '55555555-5555-5555-5555-555555555555';
        const updatedRow = { ...mockSuperAdminUserRow, activo: false };

        mockPrisma.$queryRaw = jest
          .fn()
          // 1. existing user check
          .mockResolvedValueOnce([{ id: targetUserId }])
          // 2. obtenerUsuarioSuperAdminPorId
          .mockResolvedValueOnce([updatedRow]);

        mockPrisma.$executeRaw = jest.fn().mockResolvedValueOnce(1);

        const resultado =
          await authService.actualizarEstadoUsuarioSuperAdmin(
            superAdminUser,
            targetUserId,
            { activo: false },
          );

        expect(resultado.id).toBe(targetUserId);
        expect(resultado.activo).toBe(false);
        expect(mockPrisma.$executeRaw).toHaveBeenCalled();
      });

      it('invalidates cache when user status is updated', async () => {
        const targetUserId = '55555555-5555-5555-5555-555555555555';
        const updatedRow = { ...mockSuperAdminUserRow, id: targetUserId, activo: false };

        // 1. Prime cache
        mockPrisma.$queryRaw = jest
          .fn()
          .mockResolvedValueOnce([mockSuperAdminUserRow]);
        await authService.listarUsuariosSuperAdmin(superAdminUser, { q: 'invalcache' });
        expect(mockPrisma.$queryRaw).toHaveBeenCalledTimes(1);

        // 2. Perform status update
        mockPrisma.$queryRaw = jest
          .fn()
          .mockResolvedValueOnce([{ id: targetUserId }])
          .mockResolvedValueOnce([updatedRow]);
        mockPrisma.$executeRaw = jest.fn().mockResolvedValueOnce(1);

        await authService.actualizarEstadoUsuarioSuperAdmin(
          superAdminUser,
          targetUserId,
          { activo: false },
        );

        // 3. Querying again should re-fetch from DB because cache was invalidated
        mockPrisma.$queryRaw = jest
          .fn()
          .mockResolvedValueOnce([updatedRow]);
        const freshList = await authService.listarUsuariosSuperAdmin(
          superAdminUser,
          { q: 'invalcache' },
        );

        expect(freshList[0].activo).toBe(false);
        expect(mockPrisma.$queryRaw).toHaveBeenCalledTimes(1);
      });
    });

    describe('SuperAdmin - Organizaciones Caching', () => {
      it('caches organizaciones query and serves subsequent calls from cache', async () => {
        cacheService.delete('superadmin:organizaciones');
        mockPrisma.$queryRaw = jest
          .fn()
          .mockResolvedValueOnce([]);

        await authService.listarOrganizacionesSuperAdmin(superAdminUser);
        await authService.listarOrganizacionesSuperAdmin(superAdminUser);

        expect(mockPrisma.$queryRaw).toHaveBeenCalledTimes(1);
      });
    });
  });
});


