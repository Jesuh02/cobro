import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { createHmac, randomUUID, timingSafeEqual } from 'node:crypto';

import { PrismaService } from '../../common/prisma/prisma.service';
import {
  ActualizarUsuarioDto,
  ActualizarEstadoUsuarioDto,
  ActualizarPermisosUsuariosDto,
  CrearUsuarioDto,
  LoginDto,
  RegistrarInstitucionDto,
} from './dto';
import {
  AuthSessionResponse,
  AuthenticatedUser,
  AuthUserResponse,
} from './auth.types';
import { PasswordService } from './password.service';
import {
  esPermisoEmpleado,
  permisosEmpleadoCodigos,
  permisosEmpleadoPredeterminadosCodigos,
  permisosEmpleadoPorCodigo,
} from './permissions';

const usuarioConRolesInclude = {
  estadoUsuario: true,
  roles: {
    include: {
      rol: true,
    },
  },
} satisfies Prisma.UsuarioInclude;

type UsuarioConRoles = Prisma.UsuarioGetPayload<{
  include: typeof usuarioConRolesInclude;
}>;

type UsuarioTblAuth = {
  id: string;
  usuario: string;
  passwordHash: string;
  nombres: string;
  apellidos: string;
  correo: string;
  activo: boolean;
  roles: string[];
  permisos: string[];
};

type TokenPayload = {
  aud: 'cobro-app';
  exp: number;
  iat: number;
  iss: 'cobro-api';
  jti: string;
  nbf: number;
  sub: string;
};

type RutaActividadEmpleado = {
  rutaId: string;
  nombre: string;
  creditos: number;
  clientes: number;
  debenHoy: number;
  cumplidosHoy: number;
  pendientesHoy: number;
  atrasados: number;
  recaudadoHoy: number;
};

type ActividadEmpleadoRow = {
  usuario_id: string;
  usuario: string;
  nombre_completo: string;
  correo: string;
  activo: boolean;
  rutas: unknown;
  total_creditos: number | bigint | null;
  creditos_hoy: number | bigint | null;
  creditos_mes: number | bigint | null;
  valor_creditos_total: Prisma.Decimal | number | string | null;
  recaudo_hoy: Prisma.Decimal | number | string | null;
  recaudo_mes: Prisma.Decimal | number | string | null;
  pagos_hoy: number | bigint | null;
  deberes_hoy: number | bigint | null;
  cumplidos_hoy: number | bigint | null;
  pendientes_hoy: number | bigint | null;
  atrasados: number | bigint | null;
  ultima_actividad: Date | null;
};

const tokenClockToleranceSeconds = 30;
const maxTokenLength = 2_048;

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordService,
    private readonly config: ConfigService,
  ) {}

  async login(dto: LoginDto): Promise<AuthSessionResponse> {
    const nombreUsuario = this.normalizarUsuario(dto.usuario);
    let usuario: UsuarioConRoles | null = null;

    try {
      usuario = await this.prisma.usuario.findUnique({
        where: { nombreUsuario },
        include: usuarioConRolesInclude,
      });
    } catch (error) {
      if (this.esErrorEsquemaAuthFaltante(error)) {
        return this.loginTbl(nombreUsuario, dto.contrasena);
      }
      throw error;
    }

    if (!usuario) {
      const usuarioTbl = await this.obtenerUsuarioTblPorNombre(nombreUsuario);

      if (usuarioTbl) {
        return this.loginTbl(nombreUsuario, dto.contrasena, usuarioTbl);
      }
    }

    const passwordHash = usuario?.passwordHash ?? 'disabled';
    const passwordIsValid = await this.passwords.verify(
      dto.contrasena,
      passwordHash,
    );

    if (!usuario || !passwordIsValid) {
      throw new UnauthorizedException('Usuario o contrasena invalidos');
    }

    if (usuario.estadoUsuario.codigo !== 'ACTIVO') {
      throw new UnauthorizedException('El usuario no esta activo');
    }

    if (this.passwords.needsRehash(usuario.passwordHash)) {
      const upgradedHash = await this.passwords.hash(dto.contrasena);
      await this.prisma.usuario.updateMany({
        where: {
          usuarioId: usuario.usuarioId,
          passwordHash: usuario.passwordHash,
        },
        data: { passwordHash: upgradedHash, actualizadoEn: new Date() },
      });
    }

    return this.crearSesion(usuario);
  }

  async registrarInstitucion(
    dto: RegistrarInstitucionDto,
  ): Promise<AuthSessionResponse> {
    const institucion = dto.institucion.trim();
    const nombreUsuario = this.normalizarUsuario(dto.usuario);
    const correo = dto.correo.trim().toLowerCase();
    const nombre = this.separarNombre(dto.nombreCompleto);
    const telefono = dto.telefono?.trim() || null;
    const passwordHash = await this.passwords.hash(dto.contrasena);

    return this.prisma.$transaction(async (tx) => {
      const [institucionExiste, usuarioExiste, correoExiste] =
        await Promise.all([
          this.existeOrganizacionTbl(tx, institucion),
          this.existeUsuarioTbl(tx, nombreUsuario),
          this.existeCorreoUsuarioTbl(tx, correo),
        ]);

      if (institucionExiste) {
        throw new ConflictException('La institucion ya esta registrada');
      }

      if (usuarioExiste) {
        throw new ConflictException('El usuario ya existe');
      }

      if (correoExiste) {
        throw new ConflictException('El correo ya esta registrado');
      }

      const rolAdministradorId =
        await this.obtenerOCrearRolAdministradorTbl(tx);
      const documento = `registro-${nombreUsuario}`;
      const [persona] = await tx.$queryRaw<Array<{ id: string }>>`
        INSERT INTO public.tbl_personas (
          per_primer_nombre,
          per_apellido,
          per_documento,
          per_num_celular
        )
        VALUES (
          ${nombre.nombres},
          ${nombre.apellidos || ' '},
          ${documento},
          ${telefono}
        )
        RETURNING id_per::text AS id
      `;
      const [usuario] = await tx.$queryRaw<Array<{ id: string }>>`
        INSERT INTO public.tbl_usuarios (
          usu_usuario,
          usu_password,
          usu_email,
          persona_id
        )
        VALUES (
          ${nombreUsuario},
          ${passwordHash},
          ${correo},
          ${BigInt(persona.id)}
        )
        RETURNING id_usu::text AS id
      `;
      const [organizacion] = await tx.$queryRaw<Array<{ id: string }>>`
        INSERT INTO public.tbl_organizaciones (
          org_nombre,
          org_email,
          org_telefono
        )
        VALUES (${institucion}, ${correo}, ${telefono})
        RETURNING id_org::text AS id
      `;

      await tx.$executeRaw`
        INSERT INTO public.tbl_usuarios_organizaciones (
          rol_id,
          usu_id,
          org_id
        )
        VALUES (
          ${BigInt(rolAdministradorId)},
          ${BigInt(usuario.id)},
          ${BigInt(organizacion.id)}
        )
      `;

      return this.crearSesionParaUsuario(
        this.formatearUsuarioTbl({
          id: usuario.id,
          usuario: nombreUsuario,
          passwordHash,
          nombres: nombre.nombres,
          apellidos: nombre.apellidos,
          correo,
          activo: true,
          roles: ['ADMINISTRADOR'],
          permisos: permisosEmpleadoCodigos,
        }),
      );
    });
  }

  async crearEmpleado(
    dto: CrearUsuarioDto,
    administrador: AuthenticatedUser,
  ): Promise<AuthUserResponse> {
    this.requerirAdministrador(administrador);
    return this.crearUsuario(dto, 'COBRADOR', administrador);
  }

  async obtenerUsuarioAutenticado(
    usuarioId: string,
  ): Promise<AuthUserResponse> {
    if (this.esIdTbl(usuarioId)) {
      const usuarioTbl = await this.obtenerUsuarioTblPorId(usuarioId);

      if (!usuarioTbl || !usuarioTbl.activo) {
        throw new UnauthorizedException('Sesion invalida');
      }

      return this.formatearUsuarioTbl(usuarioTbl);
    }

    let usuario: UsuarioConRoles | null = null;

    try {
      usuario = await this.prisma.usuario.findUnique({
        where: { usuarioId },
        include: usuarioConRolesInclude,
      });
    } catch (error) {
      if (this.esErrorEsquemaAuthFaltante(error)) {
        throw new UnauthorizedException('Sesion invalida');
      }
      throw error;
    }

    if (!usuario || usuario.estadoUsuario.codigo !== 'ACTIVO') {
      throw new UnauthorizedException('Sesion invalida');
    }

    return this.formatearUsuario(usuario);
  }

  async validarUsuarioAutenticado(
    usuarioId: string,
  ): Promise<AuthenticatedUser> {
    if (this.esIdTbl(usuarioId)) {
      const usuarioTbl = await this.obtenerUsuarioTblPorId(usuarioId);

      if (!usuarioTbl || !usuarioTbl.activo) {
        throw new UnauthorizedException('Sesion invalida');
      }

      const formateado = this.formatearUsuarioTbl(usuarioTbl);

      return {
        usuarioId: formateado.id,
        usuario: formateado.usuario,
        roles: formateado.roles,
        permisos: formateado.permisos,
      };
    }

    let usuario: UsuarioConRoles | null = null;

    try {
      usuario = await this.prisma.usuario.findUnique({
        where: { usuarioId },
        include: usuarioConRolesInclude,
      });
    } catch (error) {
      if (this.esErrorEsquemaAuthFaltante(error)) {
        throw new UnauthorizedException('Sesion invalida');
      }
      throw error;
    }

    if (!usuario || usuario.estadoUsuario.codigo !== 'ACTIVO') {
      throw new UnauthorizedException('Sesion invalida');
    }

    const formateado = this.formatearUsuario(usuario);

    return {
      usuarioId: formateado.id,
      usuario: formateado.usuario,
      roles: formateado.roles,
      permisos: formateado.permisos,
    };
  }

  async listarEmpleados(
    usuario: AuthenticatedUser,
  ): Promise<AuthUserResponse[]> {
    this.requerirVerEmpleados(usuario);

    if (await this.usarEsquemaTbl()) {
      return this.listarEmpleadosTbl();
    }

    try {
      const usuarios = await this.prisma.usuario.findMany({
        where: {
          roles: {
            some: { rol: { codigo: 'COBRADOR' } },
          },
        },
        include: usuarioConRolesInclude,
        orderBy: [{ estadoUsuarioId: 'asc' }, { nombres: 'asc' }],
      });

      return usuarios.map((usuario) => this.formatearUsuario(usuario));
    } catch (error) {
      if (this.esErrorEsquemaAuthFaltante(error)) {
        return this.listarEmpleadosTbl();
      }
      throw error;
    }
  }

  async actualizarEmpleado(
    administrador: AuthenticatedUser,
    empleadoId: string,
    dto: ActualizarUsuarioDto,
  ): Promise<AuthUserResponse> {
    this.requerirAdministrador(administrador);

    if (await this.usarEsquemaTbl()) {
      return this.actualizarEmpleadoTbl(administrador, empleadoId, dto);
    }

    const nombreUsuario = this.normalizarUsuario(dto.usuario);
    const correo = dto.correo.trim().toLowerCase();
    const nombre = this.separarNombre(dto.nombreCompleto);
    const contrasena = dto.contrasena?.trim();

    const actualizado = await this.prisma.$transaction(async (tx) => {
      const empleado = await tx.usuario.findFirst({
        where: {
          usuarioId: empleadoId,
          roles: {
            some: { rol: { codigo: 'COBRADOR' } },
          },
        },
        include: usuarioConRolesInclude,
      });

      if (!empleado) {
        throw new NotFoundException('Empleado no encontrado');
      }

      const [existenteUsuario, existenteCorreo] = await Promise.all([
        tx.usuario.findUnique({ where: { nombreUsuario } }),
        tx.usuario.findFirst({
          where: { correo: { equals: correo, mode: 'insensitive' } },
        }),
      ]);

      if (
        existenteUsuario &&
        existenteUsuario.usuarioId !== empleado.usuarioId
      ) {
        throw new ConflictException('El usuario ya existe');
      }

      if (existenteCorreo && existenteCorreo.usuarioId !== empleado.usuarioId) {
        throw new ConflictException('El correo ya esta registrado');
      }

      const usuarioActualizado = await tx.usuario.update({
        where: { usuarioId: empleadoId },
        data: {
          nombreUsuario,
          nombres: nombre.nombres,
          apellidos: nombre.apellidos,
          correo,
          ...(contrasena
            ? { passwordHash: await this.passwords.hash(contrasena) }
            : {}),
          actualizadoEn: new Date(),
        },
        include: usuarioConRolesInclude,
      });

      await this.registrarAuditoria(tx, {
        usuarioId: administrador.usuarioId,
        tabla: 'usuario',
        registroId: empleadoId,
        accion: 'MODIFICAR',
        descripcion: `Se modifico empleado ${empleado.nombreUsuario}`,
        valoresAnteriores: this.usuarioAuditoria(empleado),
        valoresNuevos: this.usuarioAuditoria(usuarioActualizado),
        metadata: { tipo: 'empleado', contrasenaCambiada: Boolean(contrasena) },
      });

      return usuarioActualizado;
    });

    return this.formatearUsuario(actualizado);
  }

  async listarActividadEmpleados(usuario: AuthenticatedUser) {
    this.requerirVerEmpleados(usuario);

    if (await this.usarEsquemaTbl()) {
      return this.listarActividadEmpleadosTbl();
    }

    const rows = await this.prisma.$queryRaw<ActividadEmpleadoRow[]>(Prisma.sql`
      WITH empleados AS (
        SELECT
          u.usuario_id,
          u.nombre_usuario,
          concat_ws(' ', u.nombres, u.apellidos) AS nombre_completo,
          u.correo,
          eu.codigo = 'ACTIVO' AS activo
        FROM public.usuario u
        JOIN public.estado_usuario eu
          ON eu.estado_usuario_id = u.estado_usuario_id
        JOIN public.usuario_rol ur
          ON ur.usuario_id = u.usuario_id
        JOIN public.rol r
          ON r.rol_id = ur.rol_id
         AND r.codigo = 'COBRADOR'
      ),
      abonos_cuota AS (
        SELECT
          cc.credito_cuota_id,
          COALESCE(
            SUM(
              pa.monto_capital
              + pa.monto_interes
              + pa.monto_mora
              - pa.monto_descuento
            ),
            0
          ) AS abonado
        FROM public.credito_cuota cc
        LEFT JOIN public.pago_aplicacion pa
          ON pa.credito_cuota_id = cc.credito_cuota_id
        GROUP BY cc.credito_cuota_id
      ),
      creditos_base AS (
        SELECT
          c.credito_id,
          c.creado_por_usuario_id AS usuario_id,
          c.ruta_id,
          c.cliente_id,
          c.valor_principal,
          c.creado_en
        FROM public.credito c
        JOIN public.estado_credito ec
          ON ec.estado_credito_id = c.estado_credito_id
        WHERE c.creado_por_usuario_id IS NOT NULL
          AND ec.codigo <> 'ANULADO'
      ),
      cuotas_estado AS (
        SELECT
          cb.usuario_id,
          cb.ruta_id,
          cb.cliente_id,
          cb.credito_id,
          cc.credito_cuota_id,
          cc.fecha_vencimiento,
          GREATEST(cc.valor_total - COALESCE(ac.abonado, 0), 0) AS saldo
        FROM creditos_base cb
        JOIN public.credito_plan_pago cpp
          ON cpp.credito_id = cb.credito_id
        JOIN public.credito_cuota cc
          ON cc.credito_plan_pago_id = cpp.credito_plan_pago_id
        JOIN public.estado_cuota ecu
          ON ecu.estado_cuota_id = cc.estado_cuota_id
        LEFT JOIN abonos_cuota ac
          ON ac.credito_cuota_id = cc.credito_cuota_id
        WHERE ecu.codigo <> 'ANULADA'
      ),
      pagos_hoy_cuota AS (
        SELECT DISTINCT pa.credito_cuota_id
        FROM public.pago_aplicacion pa
        JOIN public.pago p
          ON p.pago_id = pa.pago_id
        WHERE (p.fecha_pago AT TIME ZONE 'America/Bogota')::date =
          (now() AT TIME ZONE 'America/Bogota')::date
      ),
      agenda_hoy AS (
        SELECT
          ce.usuario_id,
          ce.ruta_id,
          COUNT(DISTINCT ce.credito_id)::int AS deberes_hoy,
          COUNT(DISTINCT ce.credito_id) FILTER (
            WHERE ce.saldo <= 0 OR phc.credito_cuota_id IS NOT NULL
          )::int AS cumplidos_hoy,
          COUNT(DISTINCT ce.credito_id) FILTER (
            WHERE ce.saldo > 0 AND phc.credito_cuota_id IS NULL
          )::int AS pendientes_hoy
        FROM cuotas_estado ce
        LEFT JOIN pagos_hoy_cuota phc
          ON phc.credito_cuota_id = ce.credito_cuota_id
        WHERE ce.fecha_vencimiento =
          (now() AT TIME ZONE 'America/Bogota')::date
        GROUP BY ce.usuario_id, ce.ruta_id
      ),
      proxima_cuota AS (
        SELECT DISTINCT ON (ce.credito_id)
          ce.usuario_id,
          ce.ruta_id,
          ce.credito_id,
          ce.fecha_vencimiento
        FROM cuotas_estado ce
        WHERE ce.saldo > 0
        ORDER BY ce.credito_id, ce.fecha_vencimiento ASC
      ),
      atrasos AS (
        SELECT
          usuario_id,
          ruta_id,
          COUNT(*)::int AS atrasados
        FROM proxima_cuota
        WHERE fecha_vencimiento < (now() AT TIME ZONE 'America/Bogota')::date
        GROUP BY usuario_id, ruta_id
      ),
      pagos_resumen AS (
        SELECT
          p.cobrador_usuario_id AS usuario_id,
          p.ruta_id,
          COALESCE(SUM(p.total_pagado) FILTER (
            WHERE (p.fecha_pago AT TIME ZONE 'America/Bogota')::date =
              (now() AT TIME ZONE 'America/Bogota')::date
          ), 0) AS recaudo_hoy,
          COALESCE(SUM(p.total_pagado) FILTER (
            WHERE date_trunc('month', p.fecha_pago AT TIME ZONE 'America/Bogota') =
              date_trunc('month', now() AT TIME ZONE 'America/Bogota')
          ), 0) AS recaudo_mes,
          COUNT(*) FILTER (
            WHERE (p.fecha_pago AT TIME ZONE 'America/Bogota')::date =
              (now() AT TIME ZONE 'America/Bogota')::date
          )::int AS pagos_hoy,
          MAX(p.fecha_pago) AS ultima_actividad
        FROM public.pago p
        WHERE p.cobrador_usuario_id IS NOT NULL
        GROUP BY p.cobrador_usuario_id, p.ruta_id
      ),
      rutas_creditos AS (
        SELECT
          cb.usuario_id,
          cb.ruta_id,
          r.nombre,
          COUNT(DISTINCT cb.credito_id)::int AS creditos,
          COUNT(DISTINCT cb.cliente_id)::int AS clientes
        FROM creditos_base cb
        JOIN public.ruta r
          ON r.ruta_id = cb.ruta_id
        GROUP BY cb.usuario_id, cb.ruta_id, r.nombre
      ),
      rutas_json AS (
        SELECT
          rc.usuario_id,
          jsonb_agg(
            jsonb_build_object(
              'rutaId', rc.ruta_id,
              'nombre', rc.nombre,
              'creditos', rc.creditos,
              'clientes', rc.clientes,
              'debenHoy', COALESCE(ah.deberes_hoy, 0),
              'cumplidosHoy', COALESCE(ah.cumplidos_hoy, 0),
              'pendientesHoy', COALESCE(ah.pendientes_hoy, 0),
              'atrasados', COALESCE(a.atrasados, 0),
              'recaudadoHoy', COALESCE(pr.recaudo_hoy, 0)
            )
            ORDER BY COALESCE(ah.pendientes_hoy, 0) DESC,
              COALESCE(a.atrasados, 0) DESC,
              rc.nombre ASC
          ) AS rutas
        FROM rutas_creditos rc
        LEFT JOIN agenda_hoy ah
          ON ah.usuario_id = rc.usuario_id
         AND ah.ruta_id = rc.ruta_id
        LEFT JOIN atrasos a
          ON a.usuario_id = rc.usuario_id
         AND a.ruta_id = rc.ruta_id
        LEFT JOIN pagos_resumen pr
          ON pr.usuario_id = rc.usuario_id
         AND pr.ruta_id = rc.ruta_id
        GROUP BY rc.usuario_id
      ),
      creditos_resumen AS (
        SELECT
          usuario_id,
          COUNT(*)::int AS total_creditos,
          COUNT(*) FILTER (
            WHERE (creado_en AT TIME ZONE 'America/Bogota')::date =
              (now() AT TIME ZONE 'America/Bogota')::date
          )::int AS creditos_hoy,
          COUNT(*) FILTER (
            WHERE date_trunc('month', creado_en AT TIME ZONE 'America/Bogota') =
              date_trunc('month', now() AT TIME ZONE 'America/Bogota')
          )::int AS creditos_mes,
          COALESCE(SUM(valor_principal), 0) AS valor_creditos_total,
          MAX(creado_en) AS ultima_actividad
        FROM creditos_base
        GROUP BY usuario_id
      ),
      agenda_resumen AS (
        SELECT
          usuario_id,
          COALESCE(SUM(deberes_hoy), 0)::int AS deberes_hoy,
          COALESCE(SUM(cumplidos_hoy), 0)::int AS cumplidos_hoy,
          COALESCE(SUM(pendientes_hoy), 0)::int AS pendientes_hoy
        FROM agenda_hoy
        GROUP BY usuario_id
      ),
      atrasos_resumen AS (
        SELECT
          usuario_id,
          COALESCE(SUM(atrasados), 0)::int AS atrasados
        FROM atrasos
        GROUP BY usuario_id
      ),
      pagos_totales AS (
        SELECT
          usuario_id,
          COALESCE(SUM(recaudo_hoy), 0) AS recaudo_hoy,
          COALESCE(SUM(recaudo_mes), 0) AS recaudo_mes,
          COALESCE(SUM(pagos_hoy), 0)::int AS pagos_hoy,
          MAX(ultima_actividad) AS ultima_actividad
        FROM pagos_resumen
        GROUP BY usuario_id
      )
      SELECT
        e.usuario_id,
        e.nombre_usuario AS usuario,
        e.nombre_completo,
        e.correo,
        e.activo,
        COALESCE(rj.rutas, '[]'::jsonb) AS rutas,
        COALESCE(cr.total_creditos, 0) AS total_creditos,
        COALESCE(cr.creditos_hoy, 0) AS creditos_hoy,
        COALESCE(cr.creditos_mes, 0) AS creditos_mes,
        COALESCE(cr.valor_creditos_total, 0) AS valor_creditos_total,
        COALESCE(pt.recaudo_hoy, 0) AS recaudo_hoy,
        COALESCE(pt.recaudo_mes, 0) AS recaudo_mes,
        COALESCE(pt.pagos_hoy, 0) AS pagos_hoy,
        COALESCE(ar.deberes_hoy, 0) AS deberes_hoy,
        COALESCE(ar.cumplidos_hoy, 0) AS cumplidos_hoy,
        COALESCE(ar.pendientes_hoy, 0) AS pendientes_hoy,
        COALESCE(atrasos_total.atrasados, 0) AS atrasados,
        COALESCE(
          GREATEST(cr.ultima_actividad, pt.ultima_actividad),
          cr.ultima_actividad,
          pt.ultima_actividad
        ) AS ultima_actividad
      FROM empleados e
      LEFT JOIN rutas_json rj
        ON rj.usuario_id = e.usuario_id
      LEFT JOIN creditos_resumen cr
        ON cr.usuario_id = e.usuario_id
      LEFT JOIN agenda_resumen ar
        ON ar.usuario_id = e.usuario_id
      LEFT JOIN atrasos_resumen atrasos_total
        ON atrasos_total.usuario_id = e.usuario_id
      LEFT JOIN pagos_totales pt
        ON pt.usuario_id = e.usuario_id
      ORDER BY e.activo DESC, e.nombre_completo ASC
    `);

    return this.formatearActividadEmpleados(rows);
  }

  private formatearActividadEmpleados(rows: ActividadEmpleadoRow[]) {
    return rows.map((row) => {
      const deberesHoy = this.entero(row.deberes_hoy);
      const cumplidosHoy = this.entero(row.cumplidos_hoy);
      const pendientesHoy = this.entero(row.pendientes_hoy);
      const atrasados = this.entero(row.atrasados);
      const porcentajeCumplimiento =
        deberesHoy === 0 ? 100 : Math.round((cumplidosHoy / deberesHoy) * 100);

      return {
        empleadoId: row.usuario_id,
        usuario: row.usuario,
        nombreCompleto: row.nombre_completo,
        correo: row.correo,
        activo: row.activo,
        estadoRuta:
          pendientesHoy > 0 || atrasados > 0
            ? 'PENDIENTE'
            : deberesHoy > 0
              ? 'CUMPLIDO'
              : 'SIN_RUTA_HOY',
        porcentajeCumplimiento,
        rutas: this.normalizarRutasActividad(row.rutas),
        resumen: {
          totalCreditos: this.entero(row.total_creditos),
          creditosHoy: this.entero(row.creditos_hoy),
          creditosMes: this.entero(row.creditos_mes),
          valorCreditosTotal: this.numero(row.valor_creditos_total),
          recaudoHoy: this.numero(row.recaudo_hoy),
          recaudoMes: this.numero(row.recaudo_mes),
          pagosHoy: this.entero(row.pagos_hoy),
          deberesHoy,
          cumplidosHoy,
          pendientesHoy,
          atrasados,
        },
        ultimaActividad: row.ultima_actividad?.toISOString() ?? null,
      };
    });
  }

  private async listarEmpleadosTbl(): Promise<AuthUserResponse[]> {
    const usuarios = await this.prisma.$queryRaw<UsuarioTblAuth[]>(Prisma.sql`
      SELECT
        tu.id_usu::text AS id,
        tu.usu_usuario AS usuario,
        tu.usu_password AS "passwordHash",
        p.per_primer_nombre AS nombres,
        p.per_apellido AS apellidos,
        tu.usu_email AS correo,
        tu.usu_activo AS activo,
        COALESCE(
          array_agg(DISTINCT tr.rol_tip::text)
            FILTER (WHERE tr.rol_tip IS NOT NULL),
          ARRAY[]::text[]
        ) AS roles,
        COALESCE(
          array_agg(DISTINCT rec.nom)
            FILTER (WHERE rec.nom IS NOT NULL),
          ARRAY[]::text[]
        ) AS permisos
      FROM public.tbl_usuarios tu
      JOIN public.tbl_personas p ON p.id_per = tu.persona_id
      JOIN public.tbl_usuarios_organizaciones uo
        ON uo.usu_id = tu.id_usu
       AND uo.urg_activo
      JOIN public.tbl_roles tr ON tr.id_rol = uo.rol_id
      LEFT JOIN public.tbl_roles_recursos rr ON rr.rol_id = tr.id_rol
      LEFT JOIN public.tbl_recursos rec ON rec.id_rec = rr.rec_id
      WHERE EXISTS (
        SELECT 1
        FROM public.tbl_usuarios_organizaciones uo_cobrador
        JOIN public.tbl_roles rol_cobrador
          ON rol_cobrador.id_rol = uo_cobrador.rol_id
        WHERE uo_cobrador.usu_id = tu.id_usu
          AND uo_cobrador.urg_activo
          AND rol_cobrador.rol_tip::text = 'COBRADOR'
      )
      GROUP BY
        tu.id_usu,
        tu.usu_usuario,
        tu.usu_password,
        p.per_primer_nombre,
        p.per_apellido,
        tu.usu_email,
        tu.usu_activo
      ORDER BY tu.usu_activo DESC, p.per_primer_nombre ASC, p.per_apellido ASC
    `);

    return usuarios.map((usuario) => this.formatearUsuarioTbl(usuario));
  }

  private async listarActividadEmpleadosTbl() {
    const rows = await this.prisma.$queryRaw<ActividadEmpleadoRow[]>(Prisma.sql`
      WITH empleados AS (
        SELECT DISTINCT
          tu.id_usu::text AS usuario_id,
          tu.usu_usuario AS nombre_usuario,
          concat_ws(' ', p.per_primer_nombre, p.per_apellido) AS nombre_completo,
          tu.usu_email AS correo,
          tu.usu_activo AS activo
        FROM public.tbl_usuarios tu
        JOIN public.tbl_personas p ON p.id_per = tu.persona_id
        JOIN public.tbl_usuarios_organizaciones uo
          ON uo.usu_id = tu.id_usu
         AND uo.urg_activo
        JOIN public.tbl_roles r
          ON r.id_rol = uo.rol_id
         AND r.rol_tip::text = 'COBRADOR'
      ),
      creditos_base AS (
        SELECT
          cr.id_cre,
          cr.usu_id::text AS usuario_id,
          ruta_credito.ruta_id::text AS ruta_id,
          COALESCE(ruta_credito.ruta, 'Sin ruta') AS ruta,
          cr.cli_id,
          cr.cre_total,
          cr.cre_fecha_inicio
        FROM public.tbl_creditos cr
        JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
        LEFT JOIN LATERAL (
          SELECT r.id_rut AS ruta_id, r.rut_nombre AS ruta
          FROM public.tbl_rutas_clientes rc
          JOIN public.tbl_rutas r ON r.id_rut = rc.rut_id
          WHERE rc.cli_id = cl.id_cli
            AND r.org_id = cl.org_id
            AND rc.rcl_activo
          ORDER BY (r.usu_id = cr.usu_id) DESC, r.rut_activa DESC, r.rut_nombre ASC
          LIMIT 1
        ) ruta_credito ON TRUE
        WHERE UPPER(cr.cre_estado::text) <> 'ANULADO'
      ),
      cuotas_estado AS (
        SELECT
          cb.usuario_id,
          cb.ruta_id,
          cb.ruta,
          cb.cli_id,
          cb.id_cre,
          cu.id_cuo,
          cu.cuo_fecha_vencimiento,
          GREATEST(
            cu.cuo_valor - GREATEST(
              COALESCE(cu.cuo_total_pagado, 0),
              COALESCE(SUM(cp.cpa_total), 0)
            ),
            0
          ) AS saldo
        FROM creditos_base cb
        JOIN public.tbl_cuotas cu ON cu.cre_id = cb.id_cre
        LEFT JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
        WHERE UPPER(cu.cuo_estado::text) <> 'ANULADA'
        GROUP BY
          cb.usuario_id,
          cb.ruta_id,
          cb.ruta,
          cb.cli_id,
          cb.id_cre,
          cu.id_cuo
      ),
      pagos_hoy_cuota AS (
        SELECT DISTINCT cp.cuo_id
        FROM public.tbl_cuotas_pagos cp
        JOIN public.tbl_pagos p ON p.id_pag = cp.pagos_id
        WHERE (p.pag_fecha AT TIME ZONE 'America/Bogota')::date =
          (now() AT TIME ZONE 'America/Bogota')::date
      ),
      agenda_hoy AS (
        SELECT
          ce.usuario_id,
          ce.ruta_id,
          COUNT(DISTINCT ce.id_cre)::int AS deberes_hoy,
          COUNT(DISTINCT ce.id_cre) FILTER (
            WHERE ce.saldo <= 0 OR phc.cuo_id IS NOT NULL
          )::int AS cumplidos_hoy,
          COUNT(DISTINCT ce.id_cre) FILTER (
            WHERE ce.saldo > 0 AND phc.cuo_id IS NULL
          )::int AS pendientes_hoy
        FROM cuotas_estado ce
        LEFT JOIN pagos_hoy_cuota phc ON phc.cuo_id = ce.id_cuo
        WHERE ce.cuo_fecha_vencimiento =
          (now() AT TIME ZONE 'America/Bogota')::date
        GROUP BY ce.usuario_id, ce.ruta_id
      ),
      proxima_cuota AS (
        SELECT DISTINCT ON (ce.id_cre)
          ce.usuario_id,
          ce.ruta_id,
          ce.id_cre,
          ce.cuo_fecha_vencimiento
        FROM cuotas_estado ce
        WHERE ce.saldo > 0
        ORDER BY ce.id_cre, ce.cuo_fecha_vencimiento ASC
      ),
      atrasos AS (
        SELECT
          usuario_id,
          ruta_id,
          COUNT(*)::int AS atrasados
        FROM proxima_cuota
        WHERE cuo_fecha_vencimiento <
          (now() AT TIME ZONE 'America/Bogota')::date
        GROUP BY usuario_id, ruta_id
      ),
      pagos_resumen AS (
        SELECT
          cr.usu_id::text AS usuario_id,
          ruta_credito.ruta_id::text AS ruta_id,
          COALESCE(SUM(p.pag_monto) FILTER (
            WHERE (p.pag_fecha AT TIME ZONE 'America/Bogota')::date =
              (now() AT TIME ZONE 'America/Bogota')::date
          ), 0) AS recaudo_hoy,
          COALESCE(SUM(p.pag_monto) FILTER (
            WHERE date_trunc('month', p.pag_fecha AT TIME ZONE 'America/Bogota') =
              date_trunc('month', now() AT TIME ZONE 'America/Bogota')
          ), 0) AS recaudo_mes,
          COUNT(*) FILTER (
            WHERE (p.pag_fecha AT TIME ZONE 'America/Bogota')::date =
              (now() AT TIME ZONE 'America/Bogota')::date
          )::int AS pagos_hoy,
          MAX(p.pag_fecha) AS ultima_actividad
        FROM public.tbl_pagos p
        JOIN public.tbl_creditos cr ON cr.id_cre = p.cre_id
        JOIN public.tbl_clientes cl ON cl.id_cli = cr.cli_id
        LEFT JOIN LATERAL (
          SELECT r.id_rut AS ruta_id
          FROM public.tbl_rutas_clientes rc
          JOIN public.tbl_rutas r ON r.id_rut = rc.rut_id
          WHERE rc.cli_id = cl.id_cli
            AND r.org_id = cl.org_id
            AND rc.rcl_activo
          ORDER BY (r.usu_id = cr.usu_id) DESC, r.rut_activa DESC, r.rut_nombre ASC
          LIMIT 1
        ) ruta_credito ON TRUE
        GROUP BY cr.usu_id, ruta_credito.ruta_id
      ),
      rutas_creditos AS (
        SELECT
          cb.usuario_id,
          cb.ruta_id,
          cb.ruta AS nombre,
          COUNT(DISTINCT cb.id_cre)::int AS creditos,
          COUNT(DISTINCT cb.cli_id)::int AS clientes
        FROM creditos_base cb
        GROUP BY cb.usuario_id, cb.ruta_id, cb.ruta
      ),
      rutas_json AS (
        SELECT
          rc.usuario_id,
          jsonb_agg(
            jsonb_build_object(
              'rutaId', COALESCE(rc.ruta_id, ''),
              'nombre', rc.nombre,
              'creditos', rc.creditos,
              'clientes', rc.clientes,
              'debenHoy', COALESCE(ah.deberes_hoy, 0),
              'cumplidosHoy', COALESCE(ah.cumplidos_hoy, 0),
              'pendientesHoy', COALESCE(ah.pendientes_hoy, 0),
              'atrasados', COALESCE(a.atrasados, 0),
              'recaudadoHoy', COALESCE(pr.recaudo_hoy, 0)
            )
            ORDER BY COALESCE(ah.pendientes_hoy, 0) DESC,
              COALESCE(a.atrasados, 0) DESC,
              rc.nombre ASC
          ) AS rutas
        FROM rutas_creditos rc
        LEFT JOIN agenda_hoy ah
          ON ah.usuario_id = rc.usuario_id
         AND ah.ruta_id IS NOT DISTINCT FROM rc.ruta_id
        LEFT JOIN atrasos a
          ON a.usuario_id = rc.usuario_id
         AND a.ruta_id IS NOT DISTINCT FROM rc.ruta_id
        LEFT JOIN pagos_resumen pr
          ON pr.usuario_id = rc.usuario_id
         AND pr.ruta_id IS NOT DISTINCT FROM rc.ruta_id
        GROUP BY rc.usuario_id
      ),
      creditos_resumen AS (
        SELECT
          usuario_id,
          COUNT(*)::int AS total_creditos,
          COUNT(*) FILTER (
            WHERE cre_fecha_inicio =
              (now() AT TIME ZONE 'America/Bogota')::date
          )::int AS creditos_hoy,
          COUNT(*) FILTER (
            WHERE date_trunc('month', cre_fecha_inicio::timestamp) =
              date_trunc('month', now() AT TIME ZONE 'America/Bogota')
          )::int AS creditos_mes,
          COALESCE(SUM(cre_total), 0) AS valor_creditos_total,
          MAX(cre_fecha_inicio::timestamp) AS ultima_actividad
        FROM creditos_base
        GROUP BY usuario_id
      ),
      agenda_resumen AS (
        SELECT
          usuario_id,
          COALESCE(SUM(deberes_hoy), 0)::int AS deberes_hoy,
          COALESCE(SUM(cumplidos_hoy), 0)::int AS cumplidos_hoy,
          COALESCE(SUM(pendientes_hoy), 0)::int AS pendientes_hoy
        FROM agenda_hoy
        GROUP BY usuario_id
      ),
      atrasos_resumen AS (
        SELECT
          usuario_id,
          COALESCE(SUM(atrasados), 0)::int AS atrasados
        FROM atrasos
        GROUP BY usuario_id
      ),
      pagos_totales AS (
        SELECT
          usuario_id,
          COALESCE(SUM(recaudo_hoy), 0) AS recaudo_hoy,
          COALESCE(SUM(recaudo_mes), 0) AS recaudo_mes,
          COALESCE(SUM(pagos_hoy), 0)::int AS pagos_hoy,
          MAX(ultima_actividad) AS ultima_actividad
        FROM pagos_resumen
        GROUP BY usuario_id
      )
      SELECT
        e.usuario_id,
        e.nombre_usuario AS usuario,
        e.nombre_completo,
        e.correo,
        e.activo,
        COALESCE(rj.rutas, '[]'::jsonb) AS rutas,
        COALESCE(cr.total_creditos, 0) AS total_creditos,
        COALESCE(cr.creditos_hoy, 0) AS creditos_hoy,
        COALESCE(cr.creditos_mes, 0) AS creditos_mes,
        COALESCE(cr.valor_creditos_total, 0) AS valor_creditos_total,
        COALESCE(pt.recaudo_hoy, 0) AS recaudo_hoy,
        COALESCE(pt.recaudo_mes, 0) AS recaudo_mes,
        COALESCE(pt.pagos_hoy, 0) AS pagos_hoy,
        COALESCE(ar.deberes_hoy, 0) AS deberes_hoy,
        COALESCE(ar.cumplidos_hoy, 0) AS cumplidos_hoy,
        COALESCE(ar.pendientes_hoy, 0) AS pendientes_hoy,
        COALESCE(atrasos_total.atrasados, 0) AS atrasados,
        CASE
          WHEN cr.ultima_actividad IS NULL AND pt.ultima_actividad IS NULL
            THEN NULL
          ELSE GREATEST(
            COALESCE(cr.ultima_actividad, '-infinity'::timestamp),
            COALESCE(pt.ultima_actividad, '-infinity'::timestamp)
          )
        END AS ultima_actividad
      FROM empleados e
      LEFT JOIN rutas_json rj
        ON rj.usuario_id = e.usuario_id
      LEFT JOIN creditos_resumen cr
        ON cr.usuario_id = e.usuario_id
      LEFT JOIN agenda_resumen ar
        ON ar.usuario_id = e.usuario_id
      LEFT JOIN atrasos_resumen atrasos_total
        ON atrasos_total.usuario_id = e.usuario_id
      LEFT JOIN pagos_totales pt
        ON pt.usuario_id = e.usuario_id
      ORDER BY e.activo DESC, e.nombre_completo ASC
    `);

    return this.formatearActividadEmpleados(rows);
  }

  async actualizarPermisosEmpleados(
    administrador: AuthenticatedUser,
    dto: ActualizarPermisosUsuariosDto,
  ): Promise<AuthUserResponse[]> {
    this.requerirAdministrador(administrador);

    if (await this.usarEsquemaTbl()) {
      return this.actualizarPermisosEmpleadosTbl(administrador, dto);
    }

    const permisos = this.validarPermisos(dto.permisos);
    const usuariosObjetivo = await this.obtenerEmpleadosObjetivo(dto);

    if (usuariosObjetivo.length === 0) {
      throw new BadRequestException('Selecciona al menos un empleado');
    }

    await this.prisma.$transaction(async (tx) => {
      const rolesPermiso = await this.asegurarRolesPermisos(tx);
      const rolesPermitidos = rolesPermiso.filter((rol) =>
        permisos.includes(rol.codigo),
      );
      const usuarioIds = usuariosObjetivo.map((empleado) => empleado.usuarioId);
      const usuariosAntes = await tx.usuario.findMany({
        where: { usuarioId: { in: usuarioIds } },
        include: usuarioConRolesInclude,
      });
      const permisosAntes = new Map(
        usuariosAntes.map((empleado) => [
          empleado.usuarioId,
          this.permisosUsuario(empleado),
        ]),
      );

      await tx.usuarioRol.deleteMany({
        where: {
          usuarioId: { in: usuarioIds },
          rol: { codigo: { in: permisosEmpleadoCodigos } },
        },
      });

      if (rolesPermitidos.length > 0) {
        await tx.usuarioRol.createMany({
          data: usuariosObjetivo.flatMap((empleado) =>
            rolesPermitidos.map((rol) => ({
              usuarioId: empleado.usuarioId,
              rolId: rol.rolId,
            })),
          ),
          skipDuplicates: true,
        });
      }

      for (const empleado of usuariosAntes) {
        const anteriores = permisosAntes.get(empleado.usuarioId) ?? [];
        await this.registrarAuditoria(tx, {
          usuarioId: administrador.usuarioId,
          tabla: 'usuario',
          registroId: empleado.usuarioId,
          accion: 'MODIFICAR_PERMISOS',
          descripcion: `Se actualizaron permisos de ${empleado.nombreUsuario}`,
          valoresAnteriores: { permisos: anteriores },
          valoresNuevos: { permisos },
          metadata: {
            tipo: 'empleado',
            aplicarATodos: dto.todos === true,
            agregados: permisos.filter(
              (permiso) => !anteriores.includes(permiso),
            ),
            quitados: anteriores.filter(
              (permiso) => !permisos.includes(permiso),
            ),
          },
        });
      }
    });

    return this.listarEmpleados(administrador);
  }

  private async actualizarPermisosEmpleadosTbl(
    administrador: AuthenticatedUser,
    dto: ActualizarPermisosUsuariosDto,
  ): Promise<AuthUserResponse[]> {
    const permisos = this.validarPermisos(dto.permisos);
    const usuarioIdsDto = dto.usuarioIds?.filter((id) => id.trim()) ?? [];

    if (!dto.todos && usuarioIdsDto.length === 0) {
      throw new BadRequestException('Selecciona al menos un empleado');
    }

    if (usuarioIdsDto.some((id) => !this.esIdTbl(id))) {
      throw new BadRequestException('Selecciona empleados validos');
    }

    await this.prisma.$transaction(async (tx) => {
      const orgId = await this.obtenerOrganizacionActivaAdministradorTbl(
        tx,
        administrador,
      );
      const filtroUsuarios = dto.todos
        ? Prisma.empty
        : Prisma.sql`AND tu.id_usu IN (${Prisma.join(
            usuarioIdsDto.map((id) => BigInt(id)),
          )})`;
      const usuariosObjetivo = await tx.$queryRaw<
        Array<{ usuario_id: string }>
      >(Prisma.sql`
        SELECT DISTINCT tu.id_usu::text AS usuario_id
        FROM public.tbl_usuarios tu
        JOIN public.tbl_usuarios_organizaciones uo
          ON uo.usu_id = tu.id_usu
         AND uo.urg_activo
         AND uo.org_id = ${BigInt(orgId)}
        JOIN public.tbl_roles rol ON rol.id_rol = uo.rol_id
        WHERE rol.rol_tip::text = 'COBRADOR'
          ${filtroUsuarios}
      `);

      if (usuariosObjetivo.length === 0) {
        throw new BadRequestException('Selecciona al menos un empleado');
      }

      const usuarioIds = usuariosObjetivo.map((empleado) =>
        BigInt(empleado.usuario_id),
      );

      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_usuarios_organizaciones uo
        USING public.tbl_roles rol
        WHERE rol.id_rol = uo.rol_id
          AND uo.org_id = ${BigInt(orgId)}
          AND uo.usu_id IN (${Prisma.join(usuarioIds)})
          AND rol.rol_tip::text IN (${Prisma.join(permisosEmpleadoCodigos)})
      `);

      if (permisos.length === 0) {
        return;
      }

      const rolesPermiso = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT id_rol::text AS id
          FROM public.tbl_roles
          WHERE rol_tip::text IN (${Prisma.join(permisos)})
        `,
      );

      if (rolesPermiso.length !== permisos.length) {
        throw new ConflictException(
          'Faltan roles de permisos en el esquema tbl_*',
        );
      }

      const usuariosValues = Prisma.join(
        usuarioIds.map((id) => Prisma.sql`(${id}::bigint)`),
      );

      await tx.$executeRaw(Prisma.sql`
        INSERT INTO public.tbl_usuarios_organizaciones (
          rol_id,
          usu_id,
          org_id
        )
        SELECT rol.id_rol, usuarios.usuario_id, ${BigInt(orgId)}
        FROM public.tbl_roles rol
        CROSS JOIN (VALUES ${usuariosValues}) AS usuarios(usuario_id)
        WHERE rol.rol_tip::text IN (${Prisma.join(permisos)})
        ON CONFLICT (usu_id, org_id, rol_id) DO UPDATE
        SET urg_activo = TRUE
      `);
    });

    return this.listarEmpleados(administrador);
  }

  private async actualizarEmpleadoTbl(
    administrador: AuthenticatedUser,
    empleadoId: string,
    dto: ActualizarUsuarioDto,
  ): Promise<AuthUserResponse> {
    if (!this.esIdTbl(empleadoId)) {
      throw new NotFoundException('Empleado no encontrado');
    }

    const nombreUsuario = this.normalizarUsuario(dto.usuario);
    const correo = dto.correo.trim().toLowerCase();
    const nombre = this.separarNombre(dto.nombreCompleto);
    const contrasena = dto.contrasena?.trim();
    const passwordHash = contrasena
      ? await this.passwords.hash(contrasena)
      : null;

    await this.prisma.$transaction(async (tx) => {
      const orgId = await this.obtenerOrganizacionActivaAdministradorTbl(
        tx,
        administrador,
      );
      const [empleado] = await tx.$queryRaw<
        Array<{ usuario_id: string; persona_id: string }>
      >(Prisma.sql`
        SELECT tu.id_usu::text AS usuario_id, tu.persona_id::text AS persona_id
        FROM public.tbl_usuarios tu
        JOIN public.tbl_usuarios_organizaciones uo
          ON uo.usu_id = tu.id_usu
         AND uo.urg_activo
         AND uo.org_id = ${BigInt(orgId)}
        JOIN public.tbl_roles rol ON rol.id_rol = uo.rol_id
        WHERE tu.id_usu = ${BigInt(empleadoId)}
          AND rol.rol_tip::text = 'COBRADOR'
        LIMIT 1
      `);

      if (!empleado) {
        throw new NotFoundException('Empleado no encontrado');
      }

      const [existenteUsuario, existenteCorreo] = await Promise.all([
        tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
          SELECT id_usu::text AS id
          FROM public.tbl_usuarios
          WHERE lower(usu_usuario) = lower(${nombreUsuario})
            AND id_usu <> ${BigInt(empleadoId)}
          LIMIT 1
        `),
        tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
          SELECT id_usu::text AS id
          FROM public.tbl_usuarios
          WHERE lower(usu_email) = lower(${correo})
            AND id_usu <> ${BigInt(empleadoId)}
          LIMIT 1
        `),
      ]);

      if (existenteUsuario[0]) {
        throw new ConflictException('El usuario ya existe');
      }

      if (existenteCorreo[0]) {
        throw new ConflictException('El correo ya esta registrado');
      }

      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_personas
        SET
          per_primer_nombre = ${nombre.nombres},
          per_apellido = ${nombre.apellidos || ' '},
          per_email = ${correo}
        WHERE id_per = ${BigInt(empleado.persona_id)}
      `);

      if (passwordHash) {
        await tx.$executeRaw(Prisma.sql`
          UPDATE public.tbl_usuarios
          SET
            usu_usuario = ${nombreUsuario},
            usu_email = ${correo},
            usu_password = ${passwordHash}
          WHERE id_usu = ${BigInt(empleadoId)}
        `);
        return;
      }

      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_usuarios
        SET
          usu_usuario = ${nombreUsuario},
          usu_email = ${correo}
        WHERE id_usu = ${BigInt(empleadoId)}
      `);
    });

    const actualizado = await this.obtenerUsuarioTblPorId(empleadoId);
    if (!actualizado) {
      throw new NotFoundException('Empleado no encontrado');
    }

    return this.formatearUsuarioTbl(actualizado);
  }

  private async actualizarEstadoEmpleadoTbl(
    administrador: AuthenticatedUser,
    empleadoId: string,
    dto: ActualizarEstadoUsuarioDto,
  ): Promise<AuthUserResponse> {
    if (!this.esIdTbl(empleadoId)) {
      throw new NotFoundException('Empleado no encontrado');
    }

    await this.prisma.$transaction(async (tx) => {
      const orgId = await this.obtenerOrganizacionActivaAdministradorTbl(
        tx,
        administrador,
      );
      const empleados = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        SELECT tu.id_usu::text AS id
        FROM public.tbl_usuarios tu
        JOIN public.tbl_usuarios_organizaciones uo
          ON uo.usu_id = tu.id_usu
         AND uo.urg_activo
         AND uo.org_id = ${BigInt(orgId)}
        JOIN public.tbl_roles rol ON rol.id_rol = uo.rol_id
        WHERE tu.id_usu = ${BigInt(empleadoId)}
          AND rol.rol_tip::text = 'COBRADOR'
        LIMIT 1
      `);

      if (!empleados[0]) {
        throw new NotFoundException('Empleado no encontrado');
      }

      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_usuarios
        SET usu_activo = ${dto.activo}
        WHERE id_usu = ${BigInt(empleadoId)}
      `);
    });

    const actualizado = await this.obtenerUsuarioTblPorId(empleadoId);
    if (!actualizado) {
      throw new NotFoundException('Empleado no encontrado');
    }

    return this.formatearUsuarioTbl(actualizado);
  }

  async actualizarEstadoEmpleado(
    administrador: AuthenticatedUser,
    empleadoId: string,
    dto: ActualizarEstadoUsuarioDto,
  ): Promise<AuthUserResponse> {
    this.requerirAdministrador(administrador);

    if (empleadoId === administrador.usuarioId) {
      throw new BadRequestException('No puedes desactivar tu propio usuario');
    }

    if (await this.usarEsquemaTbl()) {
      return this.actualizarEstadoEmpleadoTbl(
        administrador,
        empleadoId,
        dto,
      );
    }

    const empleado = await this.prisma.usuario.findFirst({
      where: {
        usuarioId: empleadoId,
        roles: {
          some: { rol: { codigo: 'COBRADOR' } },
        },
      },
      include: usuarioConRolesInclude,
    });

    if (!empleado) {
      throw new NotFoundException('Empleado no encontrado');
    }

    const estado = await this.prisma.estadoUsuario.findUnique({
      where: { codigo: dto.activo ? 'ACTIVO' : 'INACTIVO' },
    });

    if (!estado) {
      throw new ConflictException('No existe el estado solicitado');
    }

    const actualizado = await this.prisma.$transaction(async (tx) => {
      const usuarioActualizado = await tx.usuario.update({
        where: { usuarioId: empleadoId },
        data: {
          estadoUsuarioId: estado.estadoUsuarioId,
          actualizadoEn: new Date(),
        },
        include: usuarioConRolesInclude,
      });

      await this.registrarAuditoria(tx, {
        usuarioId: administrador.usuarioId,
        tabla: 'usuario',
        registroId: empleadoId,
        accion: dto.activo ? 'ACTIVAR' : 'ANULAR',
        descripcion: dto.activo
          ? `Se activo empleado ${empleado.nombreUsuario}`
          : `Se anulo empleado ${empleado.nombreUsuario}`,
        valoresAnteriores: {
          estado: empleado.estadoUsuario.codigo,
        },
        valoresNuevos: {
          estado: estado.codigo,
        },
        metadata: { tipo: 'empleado' },
      });

      return usuarioActualizado;
    });

    return this.formatearUsuario(actualizado);
  }

  verificarToken(token: string): AuthenticatedUser {
    if (token.length > maxTokenLength) {
      throw new UnauthorizedException('Token invalido');
    }

    const segments = token.split('.');
    if (segments.length !== 3) {
      throw new UnauthorizedException('Token invalido');
    }
    const [header, payload, signature] = segments;

    if (
      !header ||
      !payload ||
      !signature ||
      !/^[A-Za-z0-9_-]+$/.test(header) ||
      !/^[A-Za-z0-9_-]+$/.test(payload) ||
      !/^[A-Za-z0-9_-]{43}$/.test(signature)
    ) {
      throw new UnauthorizedException('Token invalido');
    }

    const expectedSignature = this.firmar(`${header}.${payload}`);

    if (!this.compararFirmas(signature, expectedSignature)) {
      throw new UnauthorizedException('Token invalido');
    }

    const decodedHeader = this.decodeTokenPart(header);
    const decoded = this.decodeTokenPart(payload);

    if (
      decodedHeader.alg !== 'HS256' ||
      decodedHeader.typ !== 'JWT' ||
      Object.keys(decodedHeader).length !== 2 ||
      typeof decoded.sub !== 'string' ||
      decoded.sub.length < 1 ||
      decoded.sub.length > 64 ||
      decoded.iss !== 'cobro-api' ||
      decoded.aud !== 'cobro-app' ||
      typeof decoded.jti !== 'string' ||
      decoded.jti.length < 1 ||
      decoded.jti.length > 64 ||
      !Number.isInteger(decoded.iat) ||
      !Number.isInteger(decoded.nbf) ||
      !Number.isInteger(decoded.exp)
    ) {
      throw new UnauthorizedException('Token invalido');
    }

    const now = Math.floor(Date.now() / 1000);
    const ttl = this.tokenTtlSeconds();
    if (
      (decoded.exp as number) <= now ||
      (decoded.nbf as number) > now + tokenClockToleranceSeconds ||
      (decoded.iat as number) > now + tokenClockToleranceSeconds ||
      (decoded.exp as number) - (decoded.iat as number) >
        ttl + tokenClockToleranceSeconds
    ) {
      throw new UnauthorizedException('La sesion expiro');
    }

    return {
      usuarioId: decoded.sub,
      usuario: '',
      roles: [],
      permisos: [],
    };
  }

  requerirAdministrador(usuario: AuthenticatedUser) {
    if (!usuario.roles.includes('ADMINISTRADOR')) {
      throw new ForbiddenException(
        'Solo el administrador puede gestionar empleados',
      );
    }
  }

  private requerirVerEmpleados(usuario: AuthenticatedUser) {
    if (
      usuario.roles.includes('ADMINISTRADOR') ||
      usuario.permisos.includes('VER_EMPLEADOS')
    ) {
      return;
    }

    throw new ForbiddenException('No tienes permiso para ver empleados');
  }

  private async crearUsuario(
    dto: CrearUsuarioDto,
    rolCodigo: string,
    administrador?: AuthenticatedUser,
  ): Promise<AuthUserResponse> {
    if (await this.usarEsquemaTbl()) {
      return this.crearUsuarioTbl(dto, rolCodigo, administrador);
    }

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

      const rolesEmpleado =
        rolCodigo === 'COBRADOR'
          ? (await this.asegurarRolesPermisos(tx)).filter((rolPermiso) =>
              permisosEmpleadoPredeterminadosCodigos.includes(
                rolPermiso.codigo,
              ),
            )
          : [];

      const creado = await tx.usuario.create({
        data: {
          estadoUsuarioId: estadoActivo.estadoUsuarioId,
          nombreUsuario,
          passwordHash,
          nombres: nombre.nombres,
          apellidos: nombre.apellidos,
          correo,
          roles: {
            create: [
              { rolId: rol.rolId },
              ...rolesEmpleado.map((rolPermiso) => ({
                rolId: rolPermiso.rolId,
              })),
            ],
          },
        },
        include: usuarioConRolesInclude,
      });

      if (administrador) {
        await this.registrarAuditoria(tx, {
          usuarioId: administrador.usuarioId,
          tabla: 'usuario',
          registroId: creado.usuarioId,
          accion: 'CREAR',
          descripcion: `Se creo empleado ${creado.nombreUsuario}`,
          valoresNuevos: this.usuarioAuditoria(creado),
          metadata: { tipo: 'empleado' },
        });
      }

      return creado;
    });

    return this.formatearUsuario(creado);
  }

  private async crearUsuarioTbl(
    dto: CrearUsuarioDto,
    rolCodigo: string,
    administrador?: AuthenticatedUser,
  ): Promise<AuthUserResponse> {
    const nombreUsuario = this.normalizarUsuario(dto.usuario);
    const correo = dto.correo.trim().toLowerCase();
    const nombre = this.separarNombre(dto.nombreCompleto);
    const passwordHash = await this.passwords.hash(dto.contrasena);
    const rolNivel =
      rolCodigo === 'ADMINISTRADOR' ? 1 : rolCodigo === 'AUDITOR' ? 3 : 2;

    const creadoId = await this.prisma.$transaction(async (tx) => {
      const orgId = await this.obtenerOrganizacionActivaAdministradorTbl(
        tx,
        administrador,
      );

      const [usuarioExiste, correoExiste] = await Promise.all([
        this.existeUsuarioTbl(tx, nombreUsuario),
        this.existeCorreoUsuarioTbl(tx, correo),
      ]);

      if (usuarioExiste) {
        throw new ConflictException('El usuario ya existe');
      }

      if (correoExiste) {
        throw new ConflictException('El correo ya esta registrado');
      }

      const [rol] = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        INSERT INTO public.tbl_roles (rol_tip, rol_nivel)
        VALUES (${rolCodigo}::public.rol_tipo_enum, ${rolNivel})
        ON CONFLICT (rol_tip) DO UPDATE
        SET rol_nivel = EXCLUDED.rol_nivel
        RETURNING id_rol::text AS id
      `);

      if (!rol) {
        throw new ConflictException(`No existe el rol ${rolCodigo}`);
      }

      const documento = `empleado-${nombreUsuario}`;
      const [persona] = await tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        INSERT INTO public.tbl_personas (
          per_primer_nombre,
          per_apellido,
          per_documento,
          per_email
        )
        VALUES (
          ${nombre.nombres},
          ${nombre.apellidos || ' '},
          ${documento},
          ${correo}
        )
        RETURNING id_per::text AS id
      `);

      const [usuarioCreado] = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          INSERT INTO public.tbl_usuarios (
            usu_usuario,
            usu_password,
            usu_email,
            persona_id
          )
          VALUES (
            ${nombreUsuario},
            ${passwordHash},
            ${correo},
            ${persona.id}::bigint
          )
          RETURNING id_usu::text AS id
        `,
      );

      await tx.$executeRaw(Prisma.sql`
        INSERT INTO public.tbl_usuarios_organizaciones (
          rol_id,
          usu_id,
          org_id
        )
        VALUES (
          ${rol.id}::bigint,
          ${usuarioCreado.id}::bigint,
          ${orgId}::bigint
        )
      `);

      if (rolCodigo === 'COBRADOR') {
        const rolesEmpleado = await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
            SELECT id_rol::text AS id
            FROM public.tbl_roles
            WHERE rol_tip::text IN (${Prisma.join(
              permisosEmpleadoPredeterminadosCodigos,
            )})
          `,
        );

        if (
          rolesEmpleado.length !== permisosEmpleadoPredeterminadosCodigos.length
        ) {
          throw new ConflictException(
            'Faltan roles predeterminados de empleados en el esquema tbl_*',
          );
        }

        await tx.$executeRaw(Prisma.sql`
          INSERT INTO public.tbl_usuarios_organizaciones (
            rol_id,
            usu_id,
            org_id
          )
          SELECT roles.id_rol, ${usuarioCreado.id}::bigint, ${orgId}::bigint
          FROM public.tbl_roles roles
          WHERE roles.rol_tip::text IN (${Prisma.join(
            permisosEmpleadoPredeterminadosCodigos,
          )})
          ON CONFLICT (usu_id, org_id, rol_id) DO UPDATE
          SET urg_activo = TRUE
        `);
      }

      return usuarioCreado.id;
    });

    const creado = await this.obtenerUsuarioTblPorId(creadoId);
    if (!creado) {
      throw new ConflictException('No se pudo crear el usuario');
    }

    return this.formatearUsuarioTbl(creado);
  }

  private async obtenerOrganizacionActivaAdministradorTbl(
    tx: Prisma.TransactionClient,
    administrador?: AuthenticatedUser,
  ) {
    const [scope] = administrador
      ? await tx.$queryRaw<Array<{ org_id: string }>>(Prisma.sql`
          SELECT uo.org_id::text AS org_id
          FROM public.tbl_usuarios tu
          JOIN public.tbl_usuarios_organizaciones uo
            ON uo.usu_id = tu.id_usu
           AND uo.urg_activo
          JOIN public.tbl_organizaciones org
            ON org.id_org = uo.org_id
           AND org.org_activo
          WHERE tu.usu_activo
            AND (
              tu.id_usu::text = ${administrador.usuarioId}
              OR lower(tu.usu_usuario) = lower(${administrador.usuario})
            )
          ORDER BY uo.id_urg ASC
          LIMIT 1
        `)
      : await tx.$queryRaw<Array<{ org_id: string }>>(Prisma.sql`
          SELECT id_org::text AS org_id
          FROM public.tbl_organizaciones
          WHERE org_activo
          ORDER BY id_org ASC
          LIMIT 1
        `);

    if (!scope) {
      throw new ConflictException('No existe una organizacion activa');
    }

    return scope.org_id;
  }

  private crearSesion(usuario: UsuarioConRoles): AuthSessionResponse {
    return this.crearSesionParaUsuario(this.formatearUsuario(usuario));
  }

  private crearSesionParaUsuario(
    usuarioResponse: AuthUserResponse,
  ): AuthSessionResponse {
    const issuedAt = Math.floor(Date.now() / 1000);

    return {
      token: this.firmarToken({
        aud: 'cobro-app',
        exp: this.expiracion(issuedAt),
        iat: issuedAt,
        iss: 'cobro-api',
        jti: randomUUID(),
        nbf: issuedAt,
        sub: usuarioResponse.id,
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

  private expiracion(issuedAt: number) {
    return issuedAt + this.tokenTtlSeconds();
  }

  private tokenTtlSeconds() {
    return this.config.get<number>('AUTH_TOKEN_TTL_SECONDS', 3600);
  }

  private base64UrlJson(value: object) {
    return Buffer.from(JSON.stringify(value)).toString('base64url');
  }

  private decodeTokenPart(value: string): Record<string, unknown> {
    try {
      const decoded: unknown = JSON.parse(
        Buffer.from(value, 'base64url').toString('utf8'),
      );
      if (
        typeof decoded !== 'object' ||
        decoded === null ||
        Array.isArray(decoded)
      ) {
        throw new Error('Invalid token object');
      }
      return decoded as Record<string, unknown>;
    } catch {
      throw new UnauthorizedException('Token invalido');
    }
  }

  private normalizarUsuario(usuario: string) {
    return usuario.trim().toLowerCase();
  }

  private async existeOrganizacionTbl(
    tx: Prisma.TransactionClient,
    institucion: string,
  ) {
    const rows = await tx.$queryRaw<Array<{ existe: boolean }>>`
      SELECT EXISTS (
        SELECT 1
        FROM public.tbl_organizaciones
        WHERE lower(org_nombre) = lower(${institucion})
      ) AS existe
    `;

    return rows[0]?.existe ?? false;
  }

  private async existeUsuarioTbl(
    tx: Prisma.TransactionClient,
    nombreUsuario: string,
  ) {
    const rows = await tx.$queryRaw<Array<{ existe: boolean }>>`
      SELECT EXISTS (
        SELECT 1
        FROM public.tbl_usuarios
        WHERE lower(usu_usuario) = ${nombreUsuario}
      ) AS existe
    `;

    return rows[0]?.existe ?? false;
  }

  private async existeCorreoUsuarioTbl(
    tx: Prisma.TransactionClient,
    correo: string,
  ) {
    const rows = await tx.$queryRaw<Array<{ existe: boolean }>>`
      SELECT EXISTS (
        SELECT 1
        FROM public.tbl_usuarios
        WHERE lower(usu_email) = ${correo}
      ) AS existe
    `;

    return rows[0]?.existe ?? false;
  }

  private async obtenerOCrearRolAdministradorTbl(tx: Prisma.TransactionClient) {
    const existente = await tx.$queryRaw<Array<{ id: string }>>`
      SELECT id_rol::text AS id
      FROM public.tbl_roles
      WHERE rol_tip::text = 'ADMINISTRADOR'
      LIMIT 1
    `;

    if (existente[0]?.id) {
      return existente[0].id;
    }

    const creado = await tx.$queryRaw<Array<{ id: string }>>`
      INSERT INTO public.tbl_roles (rol_tip, rol_nivel)
      VALUES ('ADMINISTRADOR'::public.rol_tipo_enum, 1)
      ON CONFLICT (rol_tip) DO UPDATE
      SET rol_nivel = LEAST(public.tbl_roles.rol_nivel, EXCLUDED.rol_nivel)
      RETURNING id_rol::text AS id
    `;

    return creado[0].id;
  }

  private async loginTbl(
    nombreUsuario: string,
    contrasena: string,
    usuario = undefined as UsuarioTblAuth | null | undefined,
  ): Promise<AuthSessionResponse> {
    const usuarioTbl =
      usuario ?? (await this.obtenerUsuarioTblPorNombre(nombreUsuario));
    const passwordHash = usuarioTbl?.passwordHash ?? 'disabled';
    const passwordIsValid = await this.passwords.verify(
      contrasena,
      passwordHash,
    );

    if (!usuarioTbl || !passwordIsValid) {
      throw new UnauthorizedException('Usuario o contrasena invalidos');
    }

    if (!usuarioTbl.activo) {
      throw new UnauthorizedException('El usuario no esta activo');
    }

    if (this.passwords.needsRehash(usuarioTbl.passwordHash)) {
      const upgradedHash = await this.passwords.hash(contrasena);
      await this.prisma.$executeRaw`
        UPDATE public.tbl_usuarios
        SET usu_password = ${upgradedHash}
        WHERE id_usu = ${BigInt(usuarioTbl.id)}
          AND usu_password = ${usuarioTbl.passwordHash}
      `;
    }

    return this.crearSesionParaUsuario(this.formatearUsuarioTbl(usuarioTbl));
  }

  private async obtenerUsuarioTblPorNombre(nombreUsuario: string) {
    const usuarios = await this.prisma.$queryRaw<UsuarioTblAuth[]>`
      SELECT
        tu.id_usu::text AS id,
        tu.usu_usuario AS usuario,
        tu.usu_password AS "passwordHash",
        p.per_primer_nombre AS nombres,
        p.per_apellido AS apellidos,
        tu.usu_email AS correo,
        tu.usu_activo AS activo,
        COALESCE(
          array_agg(DISTINCT tr.rol_tip::text)
            FILTER (WHERE tr.rol_tip IS NOT NULL),
          ARRAY[]::text[]
        ) AS roles,
        COALESCE(
          array_agg(DISTINCT rec.nom)
            FILTER (WHERE rec.nom IS NOT NULL),
          ARRAY[]::text[]
        ) AS permisos
      FROM public.tbl_usuarios tu
      JOIN public.tbl_personas p ON p.id_per = tu.persona_id
      LEFT JOIN public.tbl_usuarios_organizaciones uo
        ON uo.usu_id = tu.id_usu
       AND uo.urg_activo
      LEFT JOIN public.tbl_roles tr ON tr.id_rol = uo.rol_id
      LEFT JOIN public.tbl_roles_recursos rr ON rr.rol_id = tr.id_rol
      LEFT JOIN public.tbl_recursos rec ON rec.id_rec = rr.rec_id
      WHERE lower(tu.usu_usuario) = ${nombreUsuario}
      GROUP BY
        tu.id_usu,
        tu.usu_usuario,
        tu.usu_password,
        p.per_primer_nombre,
        p.per_apellido,
        tu.usu_email,
        tu.usu_activo
      LIMIT 1
    `;

    return usuarios[0] ?? null;
  }

  private async obtenerUsuarioTblPorId(usuarioId: string) {
    if (!this.esIdTbl(usuarioId)) {
      return null;
    }

    const usuarios = await this.prisma.$queryRaw<UsuarioTblAuth[]>`
      SELECT
        tu.id_usu::text AS id,
        tu.usu_usuario AS usuario,
        tu.usu_password AS "passwordHash",
        p.per_primer_nombre AS nombres,
        p.per_apellido AS apellidos,
        tu.usu_email AS correo,
        tu.usu_activo AS activo,
        COALESCE(
          array_agg(DISTINCT tr.rol_tip::text)
            FILTER (WHERE tr.rol_tip IS NOT NULL),
          ARRAY[]::text[]
        ) AS roles,
        COALESCE(
          array_agg(DISTINCT rec.nom)
            FILTER (WHERE rec.nom IS NOT NULL),
          ARRAY[]::text[]
        ) AS permisos
      FROM public.tbl_usuarios tu
      JOIN public.tbl_personas p ON p.id_per = tu.persona_id
      LEFT JOIN public.tbl_usuarios_organizaciones uo
        ON uo.usu_id = tu.id_usu
       AND uo.urg_activo
      LEFT JOIN public.tbl_roles tr ON tr.id_rol = uo.rol_id
      LEFT JOIN public.tbl_roles_recursos rr ON rr.rol_id = tr.id_rol
      LEFT JOIN public.tbl_recursos rec ON rec.id_rec = rr.rec_id
      WHERE tu.id_usu = ${BigInt(usuarioId)}
      GROUP BY
        tu.id_usu,
        tu.usu_usuario,
        tu.usu_password,
        p.per_primer_nombre,
        p.per_apellido,
        tu.usu_email,
        tu.usu_activo
      LIMIT 1
    `;

    return usuarios[0] ?? null;
  }

  private esIdTbl(value: string) {
    return /^[1-9]\d{0,18}$/.test(value);
  }

  private async usarEsquemaTbl() {
    try {
      const rows = await this.prisma.$queryRaw<Array<{ disponible: boolean }>>`
        SELECT (
          to_regclass('public.tbl_usuarios') IS NOT NULL
          AND to_regclass('public.tbl_roles') IS NOT NULL
          AND to_regclass('public.tbl_usuarios_organizaciones') IS NOT NULL
        ) AS disponible
      `;

      return rows[0]?.disponible ?? false;
    } catch {
      return false;
    }
  }

  private esErrorEsquemaAuthFaltante(error: unknown) {
    return (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      ['P2010', 'P2021', 'P2022'].includes(error.code)
    );
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

  private async asegurarRolesPermisos(tx: Prisma.TransactionClient) {
    const rolesPermiso: Array<{ rolId: number; codigo: string }> = [];
    const rolAdministrador = await tx.rol.findUnique({
      where: { codigo: 'ADMINISTRADOR' },
    });

    for (const codigo of permisosEmpleadoCodigos) {
      const permiso = permisosEmpleadoPorCodigo.get(codigo);

      if (!permiso) {
        continue;
      }

      const [rol, recurso] = await Promise.all([
        tx.rol.upsert({
          where: { codigo },
          create: { codigo, nombre: permiso.rolNombre },
          update: { nombre: permiso.rolNombre },
        }),
        tx.$queryRaw<Array<{ recurso_id: number }>>(Prisma.sql`
          INSERT INTO public.recurso (codigo, nombre)
          VALUES (${codigo}, ${permiso.nombre})
          ON CONFLICT (codigo) DO UPDATE
          SET nombre = EXCLUDED.nombre,
              actualizado_en = now()
          RETURNING recurso_id
        `),
      ]);
      const recursoId = recurso[0]?.recurso_id;

      if (!recursoId) {
        throw new ConflictException(`No existe el recurso ${codigo}`);
      }

      await tx.$executeRaw(Prisma.sql`
        INSERT INTO public.rol_recurso (rol_id, recurso_id)
        VALUES (${rol.rolId}, ${recursoId})
        ON CONFLICT DO NOTHING
      `);

      if (rolAdministrador) {
        await tx.$executeRaw(Prisma.sql`
          INSERT INTO public.rol_recurso (rol_id, recurso_id)
          VALUES (${rolAdministrador.rolId}, ${recursoId})
          ON CONFLICT DO NOTHING
        `);
      }

      rolesPermiso.push({ rolId: rol.rolId, codigo: rol.codigo });
    }

    return rolesPermiso;
  }

  private validarPermisos(permisos: string[]) {
    const unicos = [...new Set(permisos.map((permiso) => permiso.trim()))];
    const invalidos = unicos.filter((permiso) => !esPermisoEmpleado(permiso));

    if (invalidos.length > 0) {
      throw new BadRequestException(
        `Permisos no validos: ${invalidos.join(', ')}`,
      );
    }

    return unicos;
  }

  private async obtenerEmpleadosObjetivo(dto: ActualizarPermisosUsuariosDto) {
    const where: Prisma.UsuarioWhereInput = {
      roles: {
        some: { rol: { codigo: 'COBRADOR' } },
      },
    };

    if (!dto.todos) {
      const usuarioIds = dto.usuarioIds?.filter((id) => id.trim()) ?? [];

      if (usuarioIds.length === 0) {
        throw new BadRequestException('Selecciona al menos un empleado');
      }

      where.usuarioId = { in: usuarioIds };
    }

    return this.prisma.usuario.findMany({
      where,
      select: { usuarioId: true },
    });
  }

  private formatearUsuario(usuario: UsuarioConRoles): AuthUserResponse {
    const roles = usuario.roles.map((rol) => rol.rol.codigo);
    const esAdministrador = roles.includes('ADMINISTRADOR');
    const permisos = permisosEmpleadoCodigos.filter((codigo) =>
      roles.includes(codigo),
    );

    return {
      id: usuario.usuarioId,
      usuario: usuario.nombreUsuario,
      nombreCompleto: `${usuario.nombres} ${usuario.apellidos}`.trim(),
      correo: usuario.correo,
      roles,
      esAdministrador,
      activo: usuario.estadoUsuario.codigo === 'ACTIVO',
      estado: {
        codigo: usuario.estadoUsuario.codigo,
        nombre: usuario.estadoUsuario.nombre,
      },
      permisos: esAdministrador ? permisosEmpleadoCodigos : permisos,
    };
  }

  private formatearUsuarioTbl(usuario: UsuarioTblAuth): AuthUserResponse {
    const roles = usuario.roles.length > 0 ? usuario.roles : ['COBRADOR'];
    const esAdministrador = roles.includes('ADMINISTRADOR');
    const permisosDesdeRecursos = usuario.permisos.filter((permiso) =>
      esPermisoEmpleado(permiso),
    );
    const permisos =
      permisosDesdeRecursos.length > 0
        ? permisosDesdeRecursos
        : permisosEmpleadoCodigos.filter((codigo) => roles.includes(codigo));

    return {
      id: usuario.id,
      usuario: usuario.usuario,
      nombreCompleto: `${usuario.nombres} ${usuario.apellidos}`.trim(),
      correo: usuario.correo,
      roles,
      esAdministrador,
      activo: usuario.activo,
      estado: {
        codigo: usuario.activo ? 'ACTIVO' : 'INACTIVO',
        nombre: usuario.activo ? 'Activo' : 'Inactivo',
      },
      permisos: esAdministrador ? permisosEmpleadoCodigos : permisos,
    };
  }

  private permisosUsuario(usuario: UsuarioConRoles): string[] {
    const roles = usuario.roles.map((rol) => rol.rol.codigo);
    return permisosEmpleadoCodigos.filter((codigo) => roles.includes(codigo));
  }

  private usuarioAuditoria(usuario: UsuarioConRoles) {
    return {
      usuarioId: usuario.usuarioId,
      usuario: usuario.nombreUsuario,
      nombreCompleto: `${usuario.nombres} ${usuario.apellidos}`.trim(),
      correo: usuario.correo,
      estado: usuario.estadoUsuario.codigo,
      roles: usuario.roles.map((rol) => rol.rol.codigo),
      permisos: this.permisosUsuario(usuario),
    };
  }

  private normalizarRutasActividad(value: unknown): RutaActividadEmpleado[] {
    if (!Array.isArray(value)) {
      return [];
    }

    return value
      .filter((item): item is Record<string, unknown> => {
        return typeof item === 'object' && item !== null;
      })
      .map((item) => ({
        rutaId: typeof item.rutaId === 'string' ? item.rutaId : '',
        nombre: typeof item.nombre === 'string' ? item.nombre : 'Ruta',
        creditos: this.entero(item.creditos),
        clientes: this.entero(item.clientes),
        debenHoy: this.entero(item.debenHoy),
        cumplidosHoy: this.entero(item.cumplidosHoy),
        pendientesHoy: this.entero(item.pendientesHoy),
        atrasados: this.entero(item.atrasados),
        recaudadoHoy: this.numero(item.recaudadoHoy),
      }));
  }

  private entero(value: unknown) {
    if (typeof value === 'bigint') {
      return Number(value);
    }

    if (typeof value === 'number') {
      return Number.isFinite(value) ? Math.trunc(value) : 0;
    }

    if (typeof value === 'string') {
      return Number.parseInt(value, 10) || 0;
    }

    if (value instanceof Prisma.Decimal) {
      return value.toNumber();
    }

    return 0;
  }

  private numero(value: unknown) {
    if (typeof value === 'bigint') {
      return Number(value);
    }

    if (typeof value === 'number') {
      return Number.isFinite(value) ? value : 0;
    }

    if (typeof value === 'string') {
      return Number.parseFloat(value) || 0;
    }

    if (value instanceof Prisma.Decimal) {
      return value.toNumber();
    }

    return 0;
  }

  private async registrarAuditoria(
    tx: Prisma.TransactionClient,
    input: {
      usuarioId?: string | null;
      tabla: string;
      registroId?: string | null;
      accion: string;
      descripcion: string;
      valoresAnteriores?: unknown;
      valoresNuevos?: unknown;
      metadata?: unknown;
    },
  ) {
    const valoresAnteriores =
      input.valoresAnteriores === undefined
        ? null
        : JSON.stringify(input.valoresAnteriores);
    const valoresNuevos =
      input.valoresNuevos === undefined
        ? null
        : JSON.stringify(input.valoresNuevos);
    const metadata =
      input.metadata === undefined ? null : JSON.stringify(input.metadata);

    await tx.$executeRaw(Prisma.sql`
      INSERT INTO public.auditoria (
        usuario_id,
        tabla,
        registro_id,
        accion,
        descripcion,
        valores_anteriores,
        valores_nuevos,
        metadata
      )
      VALUES (
        ${input.usuarioId ?? null}::uuid,
        ${input.tabla},
        ${input.registroId ?? null},
        ${input.accion},
        ${input.descripcion},
        ${valoresAnteriores}::jsonb,
        ${valoresNuevos}::jsonb,
        ${metadata}::jsonb
      )
    `);
  }
}
