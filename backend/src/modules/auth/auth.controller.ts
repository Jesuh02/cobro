import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';

import { AuthGuard } from './auth.guard';
import { AuthService } from './auth.service';
import { AuthenticatedUser } from './auth.types';
import { CurrentUser } from './current-user.decorator';
import { ResourceIdPipe } from '../../common/validation/resource-id';
import {
  ActualizarEstadoUsuarioDto,
  ActualizarPermisosUsuariosDto,
  ActualizarUsuarioDto,
  CrearUsuarioDto,
  LoginDto,
  RegistrarInstitucionDto,
} from './dto';

@Controller()
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('auth/login')
  @Throttle({
    burst: { limit: 2, ttl: 1_000, blockDuration: 5_000 },
    minute: { limit: 5, ttl: 60_000, blockDuration: 300_000 },
    hour: { limit: 30, ttl: 3_600_000, blockDuration: 3_600_000 },
  })
  login(@Body() body: LoginDto) {
    return this.auth.login(body);
  }

  @Post('auth/register')
  @Throttle({
    burst: { limit: 1, ttl: 1_000, blockDuration: 5_000 },
    minute: { limit: 3, ttl: 60_000, blockDuration: 300_000 },
    hour: { limit: 10, ttl: 3_600_000, blockDuration: 3_600_000 },
  })
  registrarInstitucion(@Body() body: RegistrarInstitucionDto) {
    return this.auth.registrarInstitucion(body);
  }

  @Get('auth/me')
  @UseGuards(AuthGuard)
  obtenerSesion(@CurrentUser() usuario: AuthenticatedUser) {
    return this.auth.obtenerUsuarioAutenticado(usuario.usuarioId);
  }

  @Post('usuarios')
  @UseGuards(AuthGuard)
  crearEmpleado(
    @CurrentUser() usuario: AuthenticatedUser,
    @Body() body: CrearUsuarioDto,
  ) {
    return this.auth.crearEmpleado(body, usuario);
  }

  @Get('usuarios')
  @UseGuards(AuthGuard)
  listarEmpleados(@CurrentUser() usuario: AuthenticatedUser) {
    return this.auth.listarEmpleados(usuario);
  }

  @Get('usuarios/actividad')
  @UseGuards(AuthGuard)
  listarActividadEmpleados(@CurrentUser() usuario: AuthenticatedUser) {
    return this.auth.listarActividadEmpleados(usuario);
  }

  @Patch('usuarios/permisos')
  @UseGuards(AuthGuard)
  actualizarPermisosEmpleados(
    @CurrentUser() usuario: AuthenticatedUser,
    @Body() body: ActualizarPermisosUsuariosDto,
  ) {
    return this.auth.actualizarPermisosEmpleados(usuario, body);
  }

  @Patch('usuarios/:id')
  @UseGuards(AuthGuard)
  actualizarEmpleado(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
    @Body() body: ActualizarUsuarioDto,
  ) {
    return this.auth.actualizarEmpleado(usuario, id, body);
  }

  @Patch('usuarios/:id/estado')
  @UseGuards(AuthGuard)
  actualizarEstadoEmpleado(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
    @Body() body: ActualizarEstadoUsuarioDto,
  ) {
    return this.auth.actualizarEstadoEmpleado(usuario, id, body);
  }
}
