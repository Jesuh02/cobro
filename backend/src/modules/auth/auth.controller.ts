import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';

import { AuthGuard } from './auth.guard';
import { AuthService } from './auth.service';
import { AuthenticatedUser } from './auth.types';
import { CurrentUser } from './current-user.decorator';
import { CrearUsuarioDto, LoginDto } from './dto';

@Controller()
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('auth/login')
  login(@Body() body: LoginDto) {
    return this.auth.login(body);
  }

  @Post('auth/bootstrap-admin')
  crearAdministrador(@Body() body: CrearUsuarioDto) {
    return this.auth.crearAdministrador(body);
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
    this.auth.requerirAdministrador(usuario);
    return this.auth.crearEmpleado(body);
  }
}
