import { Prisma } from '@prisma/client';
import { PapeleraService } from './papelera.service';
import { AuthenticatedUser } from '../auth/auth.types';

function usuarioTest(roles: string[] = ['ADMINISTRADOR'], permisos: string[] = []): AuthenticatedUser {
  return {
    usuarioId: '11111111-1111-4111-8111-111111111111',
    usuario: 'admin',
    organizacionId: '22222222-2222-4222-8222-222222222222',
    roles,
    permisos,
  };
}

describe('PapeleraService', () => {
  let service: PapeleraService;
  let mockPrisma: {
    $queryRaw: jest.Mock;
    $executeRaw: jest.Mock;
    $transaction: jest.Mock;
  };
  let mockTenantScope: {
    obtenerScopeOrganizacionTbl: jest.Mock;
    esAdministrador: jest.Mock;
  };
  let mockCache: {
    deleteByPrefix: jest.Mock;
  };

  beforeEach(() => {
    mockPrisma = {
      $queryRaw: jest.fn(),
      $executeRaw: jest.fn(),
      $transaction: jest.fn(),
    };
    mockTenantScope = {
      obtenerScopeOrganizacionTbl: jest.fn().mockResolvedValue({
        usuarioId: '11111111-1111-4111-8111-111111111111',
        organizacionId: '22222222-2222-4222-8222-222222222222',
      }),
      esAdministrador: jest.fn().mockReturnValue(true),
    };
    mockCache = {
      deleteByPrefix: jest.fn(),
    };

    service = new PapeleraService(
      mockPrisma as never,
      mockTenantScope as never,
      mockCache as never,
    );
  });

  describe('listarPapelera', () => {
    it('retorna registros de papelera con campos de frecuencia y crédito mapeados', async () => {
      mockPrisma.$queryRaw.mockResolvedValueOnce([
        {
          id_pap: 'pap-1',
          pap_fecha: new Date('2026-10-10T12:00:00Z'),
          pap_motivo: 'Borrado por cobrador',
          pap_datos: { tipo: 'CREDITO' },
          cli_id: 'cli-1',
          cliente_nombre: 'Pedro Perez',
          cliente_documento: '12345678',
          cliente_telefono: '3001234567',
          cliente_direccion: 'Calle 10 # 5-20',
          cliente_negocio: 'Tienda Pedro',
          cre_id: 'cre-1',
          cre_total: new Prisma.Decimal('200000'),
          cre_total_pagar: new Prisma.Decimal('240000'),
          cre_saldo: new Prisma.Decimal('150000'),
          cre_tasa_interes: new Prisma.Decimal('20'),
          cre_fecha_inicio: new Date('2026-09-01T00:00:00Z'),
          cre_fecha_fin: new Date('2026-10-01T00:00:00Z'),
          frecuencia_codigo: 'DIARIO',
          moneda_codigo: 'COP',
          rut_id: 'rut-1',
          ruta_nombre: 'Ruta Centro',
          usu_id: '11111111-1111-4111-8111-111111111111',
          usuario_login: 'admin',
          usuario_nombre: 'Administrador General',
        },
      ]);

      const res = await service.listarPapelera({}, usuarioTest());

      expect(res).toHaveLength(1);
      expect(res[0].id).toBe('pap-1');
      expect(res[0].tipo).toBe('CREDITO');
      expect(res[0].credito).toBeDefined();
      expect(res[0].credito?.frecuencia).toBe('DIARIO');
      expect(res[0].credito?.saldoPendiente).toBe(150000);
      expect(res[0].credito?.tasaInteres).toBe(20);
    });
  });

  describe('restaurarCliente', () => {
    it('bloquea la restauración si el cliente ya posee un crédito activo', async () => {
      const mockTx = {
        $queryRaw: jest
          .fn()
          // 1. Obtener registro de papelera
          .mockResolvedValueOnce([
            {
              id_pap: 'pap-1',
              cli_id: 'cli-1',
              cre_id: 'cre-viejo',
              rut_id: 'rut-1',
              pap_datos: { tipo: 'CREDITO' },
            },
          ])
          // 2. Cliente activo y no en papelera
          .mockResolvedValueOnce([{ id_cli: 'cli-1', cli_activo: true }])
          .mockResolvedValueOnce([]) // clienteEnPapelera
          // 3. Buscar si tiene crédito ACTIVO actualmente
          .mockResolvedValueOnce([{ id_cre: 'cre-nuevo-activo', cre_total: new Prisma.Decimal('100000') }]),
        $executeRaw: jest.fn(),
      };

      mockPrisma.$transaction.mockImplementation(async (cb: (tx: unknown) => unknown) => cb(mockTx));

      await expect(
        service.restaurarCliente('pap-1', usuarioTest()),
      ).rejects.toThrow('El cliente ya posee un crédito activo. Debe unificarlo para restaurar este crédito.');
    });

    it('permite la restauración directa si el cliente NO tiene crédito activo', async () => {
      const mockTx = {
        $queryRaw: jest
          .fn()
          // 1. Obtener registro de papelera
          .mockResolvedValueOnce([
            {
              id_pap: 'pap-1',
              cli_id: 'cli-1',
              cre_id: 'cre-viejo',
              rut_id: 'rut-1',
              pap_datos: { tipo: 'CREDITO' },
            },
          ])
          // 2. Cliente activo y no en papelera
          .mockResolvedValueOnce([{ id_cli: 'cli-1', cli_activo: true }])
          .mockResolvedValueOnce([]) // clienteEnPapelera
          // 3. Buscar si tiene crédito ACTIVO (ninguno)
          .mockResolvedValueOnce([]),
        $executeRaw: jest.fn().mockResolvedValue(1),
      };

      mockPrisma.$transaction.mockImplementation(async (cb: (tx: unknown) => unknown) => cb(mockTx));

      const res = await service.restaurarCliente('pap-1', usuarioTest());

      expect(res.ok).toBe(true);
      expect(res.mensaje).toBe('Crédito restaurado exitosamente');
      expect(mockCache.deleteByPrefix).toHaveBeenCalledWith('cobros:');
    });
  });

  describe('unificarYRefinanciarCredito', () => {
    it('rechaza la unificación si el cliente no tiene un crédito activo', async () => {
      const mockTx = {
        $queryRaw: jest
          .fn()
          // 1. Obtener registro de papelera
          .mockResolvedValueOnce([
            {
              id_pap: 'pap-1',
              cli_id: 'cli-1',
              cre_id: 'cre-papelera',
              rut_id: 'rut-1',
              usu_id: '11111111-1111-4111-8111-111111111111',
              pap_datos: { tipo: 'CREDITO' },
            },
          ])
          // 2. Obtener crédito de papelera
          .mockResolvedValueOnce([
            {
              id_cre: 'cre-papelera',
              cli_id: 'cli-1',
              cre_total: new Prisma.Decimal('200000'),
              cre_tasa_interes: new Prisma.Decimal('20'),
              cre_total_pagar: new Prisma.Decimal('240000'),
              cre_estado: 'ANULADO',
              mon_id: 'mon-cop',
              pcr_id: 'pcr-diario',
              frecuencia_codigo: 'DIARIO',
            },
          ])
          // Abonos crédito papelera
          .mockResolvedValueOnce([
            { capital_abonado: new Prisma.Decimal('50000'), total_pagado: new Prisma.Decimal('60000') },
          ])
          // 3. Buscar crédito ACTIVO del cliente (ninguno encontrado)
          .mockResolvedValueOnce([]),
        $executeRaw: jest.fn(),
      };

      mockPrisma.$transaction.mockImplementation(async (cb: (tx: unknown) => unknown) => cb(mockTx));

      await expect(
        service.unificarYRefinanciarCredito(
          'pap-1',
          { frecuenciaCodigo: 'SEMANAL' },
          usuarioTest(),
        ),
      ).rejects.toThrow('El cliente no tiene un crédito activo con el cual unificar');
    });

    it('unifica exitosamente el saldo de papelera al crédito activo con reinicio de plazo (Opción B)', async () => {
      const mockTx = {
        $queryRaw: jest
          .fn()
          // 1. Registro papelera
          .mockResolvedValueOnce([
            {
              id_pap: 'pap-1',
              cli_id: 'cli-1',
              cre_id: 'cre-papelera',
              rut_id: 'rut-1',
              usu_id: '11111111-1111-4111-8111-111111111111',
              pap_datos: { tipo: 'CREDITO' },
            },
          ])
          // 2. Crédito de papelera
          .mockResolvedValueOnce([
            {
              id_cre: 'cre-papelera',
              cli_id: 'cli-1',
              cre_total: new Prisma.Decimal('200000'),
              cre_tasa_interes: new Prisma.Decimal('20'),
              cre_total_pagar: new Prisma.Decimal('240000'),
              cre_estado: 'ANULADO',
              mon_id: 'mon-cop',
              pcr_id: 'pcr-diario',
              frecuencia_codigo: 'DIARIO',
            },
          ])
          // Abonos papelera (200k - 50k capital abonado = 150k pendiente)
          .mockResolvedValueOnce([
            { capital_abonado: new Prisma.Decimal('50000'), total_pagado: new Prisma.Decimal('60000') },
          ])
          // 3. Crédito ACTIVO del cliente (100k principal)
          .mockResolvedValueOnce([
            {
              id_cre: 'cre-activo',
              cli_id: 'cli-1',
              cre_total: new Prisma.Decimal('100000'),
              cre_tasa_interes: new Prisma.Decimal('20'),
              cre_total_pagar: new Prisma.Decimal('120000'),
              cre_estado: 'ACTIVO',
              mon_id: 'mon-cop',
              pcr_id: 'pcr-semanal',
              frecuencia_codigo: 'SEMANAL',
              decimales: 2,
            },
          ])
          // 4. Producto según frecuencia deseada ('SEMANAL')
          .mockResolvedValueOnce([
            { id: 'pcr-semanal', dias_intervalo: 7, pcr_frecuencia: 'SEMANAL' },
          ])
          // 5. Cuotas activas existentes
          .mockResolvedValueOnce([
            {
              id: 'cuo-1',
              numero: 1,
              valor: new Prisma.Decimal('30000'),
              total_pagado: new Prisma.Decimal('0'),
              estado: 'PENDIENTE',
            },
          ])
          // Abonos crédito activo (0 abonos previos)
          .mockResolvedValueOnce([
            { capital_abonado: new Prisma.Decimal('0'), interes_abonado: new Prisma.Decimal('0') },
          ]),
        $executeRaw: jest.fn().mockResolvedValue(1),
      };

      mockPrisma.$transaction.mockImplementation(async (cb: (tx: unknown) => unknown) => cb(mockTx));

      const res = await service.unificarYRefinanciarCredito(
        'pap-1',
        { frecuenciaCodigo: 'SEMANAL' },
        usuarioTest(),
      );

      expect(res.ok).toBe(true);
      expect(res.creditoActivoId).toBe('cre-activo');
      expect(res.creditoPapeleraId).toBe('cre-papelera');
      // Nuevo principal: 100k (activo) + 150k (pendiente papelera) = 250k
      expect(res.valorNuevo).toBe(250000);
      expect(res.frecuencia).toBe('SEMANAL');
      expect(mockCache.deleteByPrefix).toHaveBeenCalledWith('cobros:');
      expect(mockTx.$executeRaw).toHaveBeenCalled();
    });
  });
});
