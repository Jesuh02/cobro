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
import { CobrosService } from './cobros.service';
import {
  ActualizarCreditoDto,
  ActualizarMovimientoCajaDto,
  CrearCajaMenorDto,
  CrearClienteDto,
  CrearCreditoDto,
  CrearMovimientoCajaDto,
  ExportarMovimientosCajaQueryDto,
  ListarClientesQueryDto,
  ListarCobrosRutaQueryDto,
  ListarCreditosQueryDto,
  ListarMovimientosCajaQueryDto,
  ObtenerPresupuestoQueryDto,
  RegistrarPagoDto,
  RefinanciarCreditoDto,
} from './dto';

@Controller()
@UseGuards(AuthGuard)
export class CobrosController {
  constructor(private readonly cobros: CobrosService) {}

  @Get('catalogos')
  obtenerCatalogos(@CurrentUser() usuario: AuthenticatedUser) {
    return this.cobros.obtenerCatalogos(usuario);
  }

  @Get('clientes')
  listarClientes(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarClientesQueryDto,
  ) {
    return this.cobros.listarClientes(query, usuario);
  }

  @Post('clientes')
  crearCliente(
    @CurrentUser() usuario: AuthenticatedUser,
    @Body() body: CrearClienteDto,
  ) {
    return this.cobros.crearCliente(body, usuario);
  }

  @Get('rutas')
  listarRutas(@CurrentUser() usuario: AuthenticatedUser) {
    return this.cobros.listarRutas(usuario);
  }

  @Get('cobros/ruta')
  listarCobrosRuta(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarCobrosRutaQueryDto,
  ) {
    return this.cobros.listarCobrosRuta(query, usuario);
  }

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
    @Param('id') id: string,
    @Body() body: RefinanciarCreditoDto,
  ) {
    return this.cobros.refinanciarCredito(id, body, usuario);
  }

  @Patch('creditos/:id')
  actualizarCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: ActualizarCreditoDto,
  ) {
    return this.cobros.actualizarCredito(id, body, usuario);
  }

  @Delete('creditos/:id')
  eliminarCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.cobros.eliminarCredito(id, usuario);
  }

  @Get('creditos/:id')
  obtenerCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.cobros.obtenerCredito(id, usuario);
  }

  @Get('creditos/:id/cuotas')
  listarCuotasCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id') id: string,
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

  @Get('caja-menor/movimientos')
  listarMovimientosCaja(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarMovimientosCajaQueryDto,
  ) {
    return this.cobros.listarMovimientosCaja(query, usuario);
  }

  @Get('exportaciones/caja-menor')
  exportarMovimientosCaja(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ExportarMovimientosCajaQueryDto,
  ) {
    return this.cobros.exportarMovimientosCaja(query, usuario);
  }

  @Post('caja-menor/movimientos')
  crearMovimientoCaja(
    @CurrentUser() usuario: AuthenticatedUser,
    @Body() body: CrearMovimientoCajaDto,
  ) {
    return this.cobros.crearMovimientoCaja(body, usuario);
  }

  @Patch('caja-menor/movimientos/:id')
  actualizarMovimientoCaja(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id') id: string,
    @Body() body: ActualizarMovimientoCajaDto,
  ) {
    return this.cobros.actualizarMovimientoCaja(id, body, usuario);
  }

  @Delete('caja-menor/movimientos/:id')
  eliminarMovimientoCaja(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.cobros.eliminarMovimientoCaja(id, usuario);
  }

  @Post('caja-menor')
  crearCajaMenor(
    @CurrentUser() usuario: AuthenticatedUser,
    @Body() body: CrearCajaMenorDto,
  ) {
    return this.cobros.crearCajaMenor(body, usuario);
  }

  @Get('presupuesto')
  obtenerPresupuesto(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ObtenerPresupuestoQueryDto,
  ) {
    return this.cobros.obtenerPresupuesto(query, usuario);
  }
}
