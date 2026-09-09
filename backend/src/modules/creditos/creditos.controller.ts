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

import { ResourceIdPipe } from '../../common/validation/resource-id';
import { AuthGuard } from '../auth/auth.guard';
import { AuthenticatedUser } from '../auth/auth.types';
import { CurrentUser } from '../auth/current-user.decorator';
import { CreditosService } from './creditos.service';
import { PagosService } from './pagos.service';
import {
  ActualizarCreditoDto,
  CrearCreditoDto,
  ListarCreditosQueryDto,
  RefinanciarCreditoDto,
  RegistrarPagoDto,
} from './dto';

@Controller()
@UseGuards(AuthGuard)
export class CreditosController {
  constructor(
    private readonly creditos: CreditosService,
    private readonly pagos: PagosService,
  ) {}

  @Post('creditos')
  crearCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Body() body: CrearCreditoDto,
  ) {
    return this.creditos.crearCredito(body, usuario);
  }

  @Get('creditos')
  listarCreditos(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarCreditosQueryDto,
  ) {
    return this.creditos.listarCreditos(query, usuario);
  }

  @Get('creditos/resumen')
  resumenCreditos(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarCreditosQueryDto,
  ) {
    return this.creditos.resumenCreditos(query, usuario);
  }

  @Get('exportaciones/creditos')
  exportarCreditos(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarCreditosQueryDto,
  ) {
    return this.creditos.exportarCreditos(query, usuario);
  }

  @Patch('creditos/:id/refinanciar')
  refinanciarCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
    @Body() body: RefinanciarCreditoDto,
  ) {
    return this.creditos.refinanciarCredito(id, body, usuario);
  }

  @Patch('creditos/:id')
  actualizarCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
    @Body() body: ActualizarCreditoDto,
  ) {
    return this.creditos.actualizarCredito(id, body, usuario);
  }

  @Delete('creditos/:id')
  eliminarCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
  ) {
    return this.creditos.eliminarCredito(id, usuario);
  }

  @Get('creditos/:id')
  obtenerCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
  ) {
    return this.creditos.obtenerCredito(id, usuario);
  }

  @Get('creditos/:id/cuotas')
  listarCuotasCredito(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
  ) {
    return this.creditos.listarCuotasCredito(id, usuario);
  }

  @Post('pagos')
  registrarPago(
    @CurrentUser() usuario: AuthenticatedUser,
    @Body() body: RegistrarPagoDto,
  ) {
    return this.pagos.registrarPago(body, usuario);
  }

  @Get('pagos/:id')
  obtenerPago(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
  ) {
    return this.pagos.obtenerPago(id, usuario);
  }
}

