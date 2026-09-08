import { Controller, Get, Query, UseGuards } from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { AuthenticatedUser } from '../auth/auth.types';
import { ObtenerPresupuestoQueryDto } from './dto';
import { PresupuestoService } from './presupuesto.service';

@Controller()
@UseGuards(AuthGuard)
export class PresupuestoController {
  constructor(private readonly presupuestoService: PresupuestoService) {}

  @Get('presupuesto')
  obtenerPresupuesto(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ObtenerPresupuestoQueryDto,
  ) {
    return this.presupuestoService.obtenerPresupuesto(query, usuario);
  }
}

