import { ForbiddenException } from '@nestjs/common';
import { TenantScopeService } from './tenant-scope.service';

describe('TenantScopeService', () => {
  it('identifies numeric and uuid IDs correctly', () => {
    const service = new TenantScopeService({} as never);

    expect(service.esIdTbl('123')).toBe(true);
    expect(service.esIdTbl('a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d')).toBe(true);
    expect(service.esIdTbl('invalid_id!')).toBe(false);
  });

  it('validates administrator and organization visibility', () => {
    const service = new TenantScopeService({} as never);

    const admin = {
      usuarioId: '1',
      usuario: 'admin',
      organizacionId: 'org-1',
      roles: ['ADMINISTRADOR'],
      permisos: [],
    };
    const auditor = {
      usuarioId: '2',
      usuario: 'auditor',
      organizacionId: 'org-1',
      roles: ['AUDITOR'],
      permisos: [],
    };
    const cobrador = {
      usuarioId: '3',
      usuario: 'cobrador',
      organizacionId: 'org-1',
      roles: ['COBRADOR'],
      permisos: [],
    };

    expect(service.esAdministrador(admin)).toBe(true);
    expect(service.esAdministrador(cobrador)).toBe(false);
    expect(service.puedeVerDatosOrganizacion(admin)).toBe(true);
    expect(service.puedeVerDatosOrganizacion(auditor)).toBe(true);
    expect(service.puedeVerDatosOrganizacion(cobrador)).toBe(false);
  });

  it('returns scope when user belongs to an active organization', async () => {
    const queryRaw = jest
      .fn()
      .mockResolvedValueOnce([{ usuario_id: 'u-1', organizacion_id: 'org-1' }]);
    const service = new TenantScopeService({ $queryRaw: queryRaw } as never);

    const scope = await service.obtenerScopeOrganizacionTbl({
      usuarioId: 'u-1',
      usuario: 'testuser',
      organizacionId: 'org-1',
      roles: ['ADMINISTRADOR'],
      permisos: [],
    });

    expect(scope).toEqual({
      usuarioId: 'u-1',
      organizacionId: 'org-1',
    });
    expect(queryRaw).toHaveBeenCalled();
  });

  it('throws ForbiddenException when no active organization is found', async () => {
    const queryRaw = jest.fn().mockResolvedValueOnce([]);
    const service = new TenantScopeService({ $queryRaw: queryRaw } as never);

    await expect(
      service.obtenerScopeOrganizacionTbl({
        usuarioId: 'u-1',
        usuario: 'testuser',
        organizacionId: 'org-inactive',
        roles: ['COBRADOR'],
        permisos: [],
      }),
    ).rejects.toThrow(ForbiddenException);
  });

  it('detects tbl schema availability and caches result', async () => {
    const queryRaw = jest.fn().mockResolvedValueOnce([{ disponible: true }]);
    const service = new TenantScopeService({ $queryRaw: queryRaw } as never);

    const first = await service.usarEsquemaTbl();
    const second = await service.usarEsquemaTbl();

    expect(first).toBe(true);
    expect(second).toBe(true);
    expect(queryRaw).toHaveBeenCalledTimes(1);
  });
});
