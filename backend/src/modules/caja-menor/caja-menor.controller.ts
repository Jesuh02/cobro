import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { AuthenticatedUser } from '../auth/auth.types';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { ResourceIdPipe } from '../../common/validation/resource-id';
import { CajaMenorService } from './caja-menor.service';
import {
  ActualizarMovimientoCajaDto,
  CrearCajaMenorDto,
  CrearMovimientoCajaDto,
  ExportarMovimientosCajaQueryDto,
  ListarMovimientosCajaQueryDto,
} from './dto';

@Controller()
@UseGuards(AuthGuard)
export class CajaMenorController {
  constructor(private readonly cajaMenor: CajaMenorService) {}

  @Get('caja-menor/movimientos')
  listarMovimientosCaja(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarMovimientosCajaQueryDto,
  ) {
    return this.cajaMenor.listarMovimientosCaja(query, usuario);
  }

  @Get('exportaciones/caja-menor')
  exportarMovimientosCaja(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ExportarMovimientosCajaQueryDto,
  ) {
    return this.cajaMenor.exportarMovimientosCaja(query, usuario);
  }

  @Post('caja-menor/movimientos')
  crearMovimientoCaja(
    @CurrentUser() usuario: AuthenticatedUser,
    @Body() body: CrearMovimientoCajaDto,
  ) {
    return this.cajaMenor.crearMovimientoCaja(body, usuario);
  }

  @Patch('caja-menor/movimientos/:id')
  actualizarMovimientoCaja(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe(true)) id: string,
    @Body() body: ActualizarMovimientoCajaDto,
  ) {
    return this.cajaMenor.actualizarMovimientoCaja(id, body, usuario);
  }

  @Delete('caja-menor/movimientos/:id')
  eliminarMovimientoCaja(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe(true)) id: string,
  ) {
    return this.cajaMenor.eliminarMovimientoCaja(id, usuario);
  }

  @Post('caja-menor')
  crearCajaMenor(
    @CurrentUser() usuario: AuthenticatedUser,
    @Body() body: CrearCajaMenorDto,
  ) {
    return this.cajaMenor.crearCajaMenor(body, usuario);
  }

  @Post('caja-menor/:id/cerrar')
  cerrarCajaMenor(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe(true)) id: string,
  ) {
    return this.cajaMenor.cerrarCajaMenor(id, usuario);
  }
}
