import { Controller, Get, UseGuards } from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard';
import { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { CatalogosService } from './catalogos.service';

@Controller()
@UseGuards(AuthGuard)
export class CatalogosController {
  constructor(private readonly catalogos: CatalogosService) {}

  @Get('catalogos')
  obtenerCatalogos(@CurrentUser() usuario: AuthenticatedUser) {
    return this.catalogos.obtenerCatalogos(usuario);
  }
}

