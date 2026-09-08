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

import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { AuthenticatedUser } from '../auth/auth.types';
import { ResourceIdPipe } from '../../common/validation/resource-id';
import { ClientesService } from './clientes.service';
import {
  ActualizarClienteDto,
  ActualizarUbicacionClienteDto,
  CrearClienteDto,
  ListarClientesQueryDto,
} from './dto';

@Controller()
@UseGuards(AuthGuard)
export class ClientesController {
  constructor(private readonly clientes: ClientesService) {}

  @Get('clientes')
  listarClientes(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarClientesQueryDto,
  ) {
    return this.clientes.listarClientes(query, usuario);
  }

  @Post('clientes')
  crearCliente(
    @CurrentUser() usuario: AuthenticatedUser,
    @Body() body: CrearClienteDto,
  ) {
    return this.clientes.crearCliente(body, usuario);
  }

  @Patch('clientes/:id')
  actualizarCliente(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
    @Body() body: ActualizarClienteDto,
  ) {
    return this.clientes.actualizarCliente(id, body, usuario);
  }

  @Delete('clientes/:id')
  eliminarCliente(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
  ) {
    return this.clientes.eliminarCliente(id, usuario);
  }

  @Patch('clientes/:id/ubicacion')
  actualizarUbicacionCliente(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
    @Body() body: ActualizarUbicacionClienteDto,
  ) {
    return this.clientes.actualizarUbicacionCliente(id, body, usuario);
  }
}
