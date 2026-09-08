import { Controller, Get, Query, UseGuards } from '@nestjs/common';

import { AuthenticatedUser } from '../auth/auth.types';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { CobrosService } from './cobros.service';
import { ListarCobrosRutaQueryDto, ObtenerPresupuestoQueryDto } from './dto';

@Controller()
@UseGuards(AuthGuard)
export class CobrosController {
  constructor(private readonly cobros: CobrosService) {}

  @Get('exportaciones/cobros-ruta')
  exportarCobrosRuta(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarCobrosRutaQueryDto,
  ) {
    return this.cobros.exportarCobrosRuta(query, usuario);
  }

  @Get('presupuesto')
  obtenerPresupuesto(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ObtenerPresupuestoQueryDto,
  ) {
    return this.cobros.obtenerPresupuesto(query, usuario);
  }
}
