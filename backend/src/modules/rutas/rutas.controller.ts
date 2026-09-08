import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { AuthenticatedUser } from '../auth/auth.types';
import {
  EstimarTrayectosDto,
  ListarCobrosRutaQueryDto,
  TrazarRutaCompletaDto,
  TrazarRutaDto,
} from './dto';
import { RoutingService } from './routing.service';
import { RutasService } from './rutas.service';

@Controller()
@UseGuards(AuthGuard)
export class RutasController {
  constructor(
    private readonly rutas: RutasService,
    private readonly routing: RoutingService,
  ) {}

  @Get('rutas')
  listarRutas(@CurrentUser() usuario: AuthenticatedUser) {
    return this.rutas.listarRutas(usuario);
  }

  @Get('cobros/ruta')
  listarCobrosRuta(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarCobrosRutaQueryDto,
  ) {
    return this.rutas.listarCobrosRuta(query, usuario);
  }

  @Post('routing/estimates')
  estimarTrayectos(@Body() body: EstimarTrayectosDto) {
    return this.routing.estimateTrips(body);
  }

  @Post('routing/route')
  trazarRuta(@Body() body: TrazarRutaDto) {
    return this.routing.traceRoute(body);
  }

  @Post('routing/route-through')
  trazarRutaCompleta(@Body() body: TrazarRutaCompletaDto) {
    return this.routing.traceRouteThrough(body);
  }
}
