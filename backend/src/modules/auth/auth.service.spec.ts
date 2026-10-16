import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

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
});

