import { RutasController } from './rutas.controller';
import { RutasService } from './rutas.service';
import { RoutingService } from './routing.service';
import { AuthenticatedUser } from '../auth/auth.types';

describe('RutasController', () => {
  let controller: RutasController;
  let mockRutasService: Record<string, jest.Mock>;
  let mockRoutingService: Record<string, jest.Mock>;

  const usuarioTest: AuthenticatedUser = {
    usuarioId: 'u-1',
    usuario: 'carlos',
    organizacionId: 'org-1',
    roles: ['ADMINISTRADOR'],
    permisos: [],
  };

  beforeEach(() => {
    mockRutasService = {
      listarRutas: jest.fn().mockResolvedValue([]),
      listarCobrosRuta: jest.fn().mockResolvedValue([]),
      exportarCobrosRuta: jest.fn().mockResolvedValue({
        archivo: 'cobros-ruta.xlsx',
        filas: 0,
      }),
    };

    mockRoutingService = {
      estimateTrips: jest.fn().mockResolvedValue({}),
      traceRoute: jest.fn().mockResolvedValue({}),
      traceRouteThrough: jest.fn().mockResolvedValue({}),
    };

    controller = new RutasController(
      mockRutasService as unknown as RutasService,
      mockRoutingService as unknown as RoutingService,
    );
  });

  it('listarRutas delegates to rutasService', async () => {
    await controller.listarRutas(usuarioTest);
    expect(mockRutasService.listarRutas).toHaveBeenCalledWith(usuarioTest);
  });

  it('listarCobrosRuta delegates to rutasService', async () => {
    const query = { rutaId: 'rut-1' };
    await controller.listarCobrosRuta(usuarioTest, query);
    expect(mockRutasService.listarCobrosRuta).toHaveBeenCalledWith(
      query,
      usuarioTest,
    );
  });

  it('exportarCobrosRuta delegates to rutasService', async () => {
    const query = { rutaId: 'rut-1' };
    await controller.exportarCobrosRuta(usuarioTest, query);
    expect(mockRutasService.exportarCobrosRuta).toHaveBeenCalledWith(
      query,
      usuarioTest,
    );
  });

  it('estimarTrayectos delegates to routingService', async () => {
    const body = {
      puntos: [
        { latitud: 4.6, longitud: -74.08 },
        { latitud: 4.7, longitud: -74.05 },
      ],
    };
    await controller.estimarTrayectos(body as never);
    expect(mockRoutingService.estimateTrips).toHaveBeenCalledWith(body);
  });
});
