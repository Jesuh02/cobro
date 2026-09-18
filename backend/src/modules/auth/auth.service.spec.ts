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
});
