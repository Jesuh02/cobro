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
import { CobrosService } from './cobros.service';
import {
  ActualizarCreditoDto,
  CrearCreditoDto,
  ListarCobrosRutaQueryDto,
  ListarCreditosQueryDto,
  ObtenerPresupuestoQueryDto,
  RegistrarPagoDto,
  RefinanciarCreditoDto,
} from './dto';

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

  @Post('creditos')
  crearCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Body() body: CrearCreditoDto,
  ) {
    return this.cobros.crearCredito(body, usuario);
  }

  @Get('creditos')
  listarCreditos(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarCreditosQueryDto,
  ) {
    return this.cobros.listarCreditos(query, usuario);
  }

  @Get('creditos/resumen')
  resumenCreditos(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarCreditosQueryDto,
  ) {
    return this.cobros.resumenCreditos(query, usuario);
  }

  @Get('exportaciones/creditos')
  exportarCreditos(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarCreditosQueryDto,
  ) {
    return this.cobros.exportarCreditos(query, usuario);
  }

  @Patch('creditos/:id/refinanciar')
  refinanciarCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
    @Body() body: RefinanciarCreditoDto,
  ) {
    return this.cobros.refinanciarCredito(id, body, usuario);
  }

  @Patch('creditos/:id')
  actualizarCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
    @Body() body: ActualizarCreditoDto,
  ) {
    return this.cobros.actualizarCredito(id, body, usuario);
  }

  @Delete('creditos/:id')
  eliminarCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
  ) {
    return this.cobros.eliminarCredito(id, usuario);
  }

  @Get('creditos/:id')
  obtenerCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
  ) {
    return this.cobros.obtenerCredito(id, usuario);
  }

  @Get('creditos/:id/cuotas')
  listarCuotasCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
  ) {
    return this.cobros.listarCuotasCredito(id, usuario);
  }

  @Post('pagos')
  registrarPago(
    @CurrentUser() usuario: AuthenticatedUser,
    @Body() body: RegistrarPagoDto,
  ) {
    return this.cobros.registrarPago(body, usuario);
  }

  @Get('presupuesto')
  obtenerPresupuesto(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ObtenerPresupuestoQueryDto,
  ) {
    return this.cobros.obtenerPresupuesto(query, usuario);
  }
}
