import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';

import { AuthService } from './auth.service';
import { RequestWithUser } from './current-user.decorator';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly auth: AuthService) {}

  async canActivate(context: ExecutionContext) {
    const request = context.switchToHttp().getRequest<RequestWithUser>();
    const authorization = request.headers.authorization;

    if (!authorization || authorization.length > 2_100) {
      throw new UnauthorizedException('Debes iniciar sesion');
    }

    const match =
      /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/i.exec(
        authorization,
      );
    const token = match?.[1];

    if (!token) {
      throw new UnauthorizedException('Debes iniciar sesion');
    }

    const tokenUser = this.auth.verificarToken(token);
    request.user = await this.auth.validarUsuarioAutenticado(
      tokenUser.usuarioId,
    );
    return true;
  }
}
