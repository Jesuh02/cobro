import {
  ConflictException,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { createHmac, timingSafeEqual } from 'crypto';

import { PrismaService } from '../../common/prisma/prisma.service';
import { CrearUsuarioDto, LoginDto } from './dto';
import {
  AuthSessionResponse,
  AuthenticatedUser,
  AuthUserResponse,
} from './auth.types';
import { PasswordService } from './password.service';

type UsuarioConRoles = Prisma.UsuarioGetPayload<{
  include: {
    estadoUsuario: true;
    roles: { include: { rol: true } };
  };
}>;

type TokenPayload = {
  sub: string;
  usuario: string;
  roles: string[];
  exp: number;
};

const tokenTtlSeconds = 12 * 60 * 60;

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordService,
    private readonly config: ConfigService,
  ) {}

  async login(dto: LoginDto): Promise<AuthSessionResponse> {
    const nombreUsuario = this.normalizarUsuario(dto.usuario);
    const usuario = await this.prisma.usuario.findUnique({
      where: { nombreUsuario },
      include: {
        estadoUsuario: true,
        roles: { include: { rol: true } },
      },
    });

    if (
      !usuario ||
      !(await this.passwords.verify(dto.contrasena, usuario.passwordHash))
    ) {
      throw new UnauthorizedException('Usuario o contrasena invalidos');
    }

    if (usuario.estadoUsuario.codigo !== 'ACTIVO') {
      throw new UnauthorizedException('El usuario no esta activo');
    }

    return this.crearSesion(usuario);
  }

  async crearAdministrador(dto: CrearUsuarioDto): Promise<AuthSessionResponse> {
    const usuario = await this.crearUsuario(dto, 'ADMINISTRADOR');
    return {
      token: this.firmarToken({
        sub: usuario.id,
        usuario: usuario.usuario,
        roles: usuario.roles,
        exp: this.expiracion(),
      }),
      usuario,
    };
  }

  async crearEmpleado(dto: CrearUsuarioDto): Promise<AuthUserResponse> {
    return this.crearUsuario(dto, 'COBRADOR');
  }

  async obtenerUsuarioAutenticado(
    usuarioId: string,
  ): Promise<AuthUserResponse> {
    const usuario = await this.prisma.usuario.findUnique({
      where: { usuarioId },
      include: {
        estadoUsuario: true,
        roles: { include: { rol: true } },
      },
    });

    if (!usuario || usuario.estadoUsuario.codigo !== 'ACTIVO') {
      throw new UnauthorizedException('Sesion invalida');
    }

    return this.formatearUsuario(usuario);
  }

  verificarToken(token: string): AuthenticatedUser {
    const [header, payload, signature] = token.split('.');

    if (!header || !payload || !signature) {
      throw new UnauthorizedException('Token invalido');
    }

    const expectedSignature = this.firmar(`${header}.${payload}`);

    if (!this.compararFirmas(signature, expectedSignature)) {
      throw new UnauthorizedException('Token invalido');
    }

    const decoded = JSON.parse(
      Buffer.from(payload, 'base64url').toString('utf8'),
    ) as Record<string, unknown>;

    if (
      typeof decoded.sub !== 'string' ||
      typeof decoded.usuario !== 'string' ||
      !Array.isArray(decoded.roles) ||
      !decoded.roles.every((role) => typeof role === 'string') ||
      typeof decoded.exp !== 'number'
    ) {
      throw new UnauthorizedException('Token invalido');
    }

    if (decoded.exp <= Math.floor(Date.now() / 1000)) {
      throw new UnauthorizedException('La sesion expiro');
    }

    return {
      usuarioId: decoded.sub,
      usuario: decoded.usuario,
      roles: decoded.roles,
    };
  }

  requerirAdministrador(usuario: AuthenticatedUser) {
    if (!usuario.roles.includes('ADMINISTRADOR')) {
      throw new ForbiddenException(
        'Solo el administrador puede crear usuarios',
      );
    }
  }

  private async crearUsuario(
    dto: CrearUsuarioDto,
    rolCodigo: string,
  ): Promise<AuthUserResponse> {
    const nombreUsuario = this.normalizarUsuario(dto.usuario);
    const correo = dto.correo.trim().toLowerCase();
    const nombre = this.separarNombre(dto.nombreCompleto);
    const passwordHash = await this.passwords.hash(dto.contrasena);

    const creado = await this.prisma.$transaction(async (tx) => {
      const [estadoActivo, rol, existenteUsuario, existenteCorreo] =
        await Promise.all([
          tx.estadoUsuario.findUnique({ where: { codigo: 'ACTIVO' } }),
          tx.rol.findUnique({ where: { codigo: rolCodigo } }),
          tx.usuario.findUnique({ where: { nombreUsuario } }),
          tx.usuario.findFirst({
            where: { correo: { equals: correo, mode: 'insensitive' } },
          }),
        ]);

      if (!estadoActivo) {
        throw new ConflictException('No existe el estado ACTIVO de usuario');
      }

      if (!rol) {
        throw new ConflictException(`No existe el rol ${rolCodigo}`);
      }

      if (existenteUsuario) {
        throw new ConflictException('El usuario ya existe');
      }

      if (existenteCorreo) {
        throw new ConflictException('El correo ya esta registrado');
      }

      return tx.usuario.create({
        data: {
          estadoUsuarioId: estadoActivo.estadoUsuarioId,
          nombreUsuario,
          passwordHash,
          nombres: nombre.nombres,
          apellidos: nombre.apellidos,
          correo,
          roles: {
            create: {
              rolId: rol.rolId,
            },
          },
        },
        include: {
          estadoUsuario: true,
          roles: { include: { rol: true } },
        },
      });
    });

    return this.formatearUsuario(creado);
  }

  private crearSesion(usuario: UsuarioConRoles): AuthSessionResponse {
    const usuarioResponse = this.formatearUsuario(usuario);

    return {
      token: this.firmarToken({
        sub: usuario.usuarioId,
        usuario: usuario.nombreUsuario,
        roles: usuarioResponse.roles,
        exp: this.expiracion(),
      }),
      usuario: usuarioResponse,
    };
  }

  private firmarToken(payload: TokenPayload) {
    const header = this.base64UrlJson({ alg: 'HS256', typ: 'JWT' });
    const body = this.base64UrlJson(payload);
    const signature = this.firmar(`${header}.${body}`);
    return `${header}.${body}.${signature}`;
  }

  private firmar(value: string) {
    return createHmac('sha256', this.tokenSecret())
      .update(value)
      .digest('base64url');
  }

  private compararFirmas(actual: string, expected: string) {
    const actualBuffer = Buffer.from(actual);
    const expectedBuffer = Buffer.from(expected);
    return (
      actualBuffer.length === expectedBuffer.length &&
      timingSafeEqual(actualBuffer, expectedBuffer)
    );
  }

  private tokenSecret() {
    return this.config.get<string>(
      'AUTH_TOKEN_SECRET',
      'local-development-secret-change-me-please',
    );
  }

  private expiracion() {
    return Math.floor(Date.now() / 1000) + tokenTtlSeconds;
  }

  private base64UrlJson(value: object) {
    return Buffer.from(JSON.stringify(value)).toString('base64url');
  }

  private normalizarUsuario(usuario: string) {
    return usuario.trim().toLowerCase();
  }

  private separarNombre(nombreCompleto: string) {
    const partes = nombreCompleto.trim().split(/\s+/);

    if (partes.length === 1) {
      return { nombres: partes[0], apellidos: '' };
    }

    return {
      nombres: partes.slice(0, -1).join(' '),
      apellidos: partes[partes.length - 1],
    };
  }

  private formatearUsuario(usuario: UsuarioConRoles): AuthUserResponse {
    const roles = usuario.roles.map((rol) => rol.rol.codigo);

    return {
      id: usuario.usuarioId,
      usuario: usuario.nombreUsuario,
      nombreCompleto: `${usuario.nombres} ${usuario.apellidos}`.trim(),
      correo: usuario.correo,
      roles,
      esAdministrador: roles.includes('ADMINISTRADOR'),
    };
  }
}
