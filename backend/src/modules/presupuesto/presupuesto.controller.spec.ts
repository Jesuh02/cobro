import { PresupuestoController } from './presupuesto.controller';
import { PresupuestoService } from './presupuesto.service';
import { ObtenerPresupuestoQueryDto } from './dto';
import { AuthenticatedUser } from '../auth/auth.types';

describe('PresupuestoController', () => {
  it('delegates obtenerPresupuesto to PresupuestoService', async () => {
    const mockPresupuestoService = {
      obtenerPresupuesto: jest.fn().mockResolvedValue({
        items: [],
        totales: {
          cajaMenor: 0,
          recaudado: 0,
          gastos: 0,
          creditos: 0,
          presupuesto: 0,
        },
      }),
    };

    const controller = new PresupuestoController(
      mockPresupuestoService as unknown as PresupuestoService,
    );

    const query: ObtenerPresupuestoQueryDto = {
      alcance: 'cobrador',
      search: 'principal',
    };
    const user: AuthenticatedUser = {
      usuarioId: 'u-1',
      usuario: 'carlos',
      organizacionId: 'org-1',
      roles: ['ADMINISTRADOR'],
      permisos: [],
    };

    const result = await controller.obtenerPresupuesto(user, query);

    expect(mockPresupuestoService.obtenerPresupuesto).toHaveBeenCalledWith(
      query,
      user,
    );
    expect(result.items).toEqual([]);
    expect(result.totales.presupuesto).toBe(0);
  });
});
