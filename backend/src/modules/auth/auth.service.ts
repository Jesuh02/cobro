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
  ActualizarOrganizacionSuperAdminDto,
  ActualizarUsuarioDto,
  ActualizarEstadoUsuarioDto,
  ActualizarPermisosUsuariosDto,
  CrearAdministradorSuperAdminDto,
  CrearOrganizacionSuperAdminDto,
  CrearUsuarioDto,
  ExtenderAccesoOrganizacionDto,
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
} from './permissions';

type UsuarioTblAuth = {
  id: string;
  usuario: string;
  passwordHash: string;
  nombres: string;
  apellidos: string;
  correo: string;
  activo: boolean;
  organizacionId: string | null;
  roles: string[];
  permisos: string[];
  tieneAccesoOrganizacion: boolean;
  organizacionSuspendida: boolean;
};

type OrganizacionSuperAdminRow = {
  id: string;
  nombre: string;
  telefono: string | null;
  correo: string | null;
  activo: boolean;
  es_sistema: boolean;
  monto_plan: Prisma.Decimal | number | string | null;
  moneda_plan: string | null;
  acceso_hasta: Date | string | null;
  suspendida_en: Date | string | null;
  motivo_suspension: string | null;
  usuarios_total: number | bigint | null;
  usuarios_activos: number | bigint | null;
  administradores: string[] | null;
  suspendida: boolean;
  dias_restantes: number | null;
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
  valor_creditos_hoy: Prisma.Decimal | number | string | null;
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

type ActividadEmpleadosFiltros = {
  inicio?: string;
  fin?: string;
  empleadoId?: string;
};

type RangoActividadEmpleados = {
  fechaInicio: string;
  fechaFin: string;
  empleadoId: string | null;
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
    return this.loginTbl(nombreUsuario, dto.contrasena);
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
          per_email,
          per_num_celular
        )
        VALUES (
          ${nombre.nombres},
          ${nombre.apellidos || ' '},
          ${documento},
          ${correo},
          ${telefono}
        )
        RETURNING id_per::text AS id
      `;
      const [usuario] = await tx.$queryRaw<Array<{ id: string }>>`
        INSERT INTO public.tbl_usuarios (
          usu_usuario,
          usu_password,
          persona_id
        )
        VALUES (
          ${nombreUsuario},
          ${passwordHash},
          ${persona.id}::uuid
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
          ${rolAdministradorId}::uuid,
          ${usuario.id}::uuid,
          ${organizacion.id}::uuid
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
          tieneAccesoOrganizacion: true,
          organizacionSuspendida: false,
          organizacionId: organizacion.id,
        }),
      );
    });
  }

  async listarOrganizacionesSuperAdmin(usuario: AuthenticatedUser) {
    this.requerirSuperAdmin(usuario);
    await this.requerirEsquemaTblSuperAdmin();

    const rows = await this.prisma.$queryRaw<
      OrganizacionSuperAdminRow[]
    >(Prisma.sql`
      SELECT
        org.id_org::text AS id,
        org.org_nombre AS nombre,
        org.org_telefono AS telefono,
        org.org_email AS correo,
        org.org_activo AS activo,
        COALESCE(org.org_es_sistema, FALSE) AS es_sistema,
        org.org_monto_plan AS monto_plan,
        org.org_moneda_plan AS moneda_plan,
        org.org_acceso_hasta AS acceso_hasta,
        org.org_suspendida_en AS suspendida_en,
        org.org_motivo_suspension AS motivo_suspension,
        COUNT(DISTINCT uo.usu_id)::int AS usuarios_total,
        COUNT(DISTINCT uo.usu_id) FILTER (WHERE tu.usu_activo)::int
          AS usuarios_activos,
        COALESCE(
          array_agg(DISTINCT tu.usu_usuario)
            FILTER (
              WHERE rol.rol_tip::text = 'ADMINISTRADOR'
                AND tu.usu_usuario IS NOT NULL
            ),
          ARRAY[]::text[]
        ) AS administradores,
        (
          NOT org.org_activo
          OR (
            org.org_acceso_hasta IS NOT NULL
            AND org.org_acceso_hasta < CURRENT_DATE
          )
        ) AS suspendida,
        CASE
          WHEN org.org_acceso_hasta IS NULL THEN NULL
          ELSE (org.org_acceso_hasta - CURRENT_DATE)::int
        END AS dias_restantes
      FROM public.tbl_organizaciones org
      LEFT JOIN public.tbl_usuarios_organizaciones uo
        ON uo.org_id = org.id_org
       AND uo.urg_activo
      LEFT JOIN public.tbl_usuarios tu ON tu.id_usu = uo.usu_id
      LEFT JOIN public.tbl_roles rol ON rol.id_rol = uo.rol_id
      WHERE NOT COALESCE(org.org_es_sistema, FALSE)
      GROUP BY org.id_org
      ORDER BY suspendida DESC, org.org_acceso_hasta ASC NULLS LAST, org.org_nombre ASC
    `);

    return rows.map((row) => this.formatearOrganizacionSuperAdmin(row));
  }

  async crearOrganizacionSuperAdmin(
    usuario: AuthenticatedUser,
    dto: CrearOrganizacionSuperAdminDto,
  ) {
    this.requerirSuperAdmin(usuario);
    await this.requerirEsquemaTblSuperAdmin();

    const nombre = dto.nombre.trim();
    const telefono = dto.telefono?.trim() || null;
    const correo = dto.correo?.trim().toLowerCase() || null;
    const montoPlan = dto.montoPlan ?? 0;
    const monedaPlan = dto.monedaPlan ?? 'COP';
    const accesoHasta = dto.accesoHasta ?? null;

    const organizacionId = await this.prisma.$transaction(async (tx) => {
      if (await this.existeOrganizacionTbl(tx, nombre)) {
        throw new ConflictException('La institucion ya esta registrada');
      }

      const [organizacion] = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          INSERT INTO public.tbl_organizaciones (
            org_nombre,
            org_telefono,
            org_email,
            org_monto_plan,
            org_moneda_plan,
            org_acceso_hasta,
            org_activo,
            org_es_sistema
          )
          VALUES (
            ${nombre},
            ${telefono},
            ${correo},
            ${montoPlan},
            ${monedaPlan},
            ${accesoHasta}::date,
            TRUE,
            FALSE
          )
          RETURNING id_org::text AS id
        `,
      );

      return organizacion.id;
    });

    return this.obtenerOrganizacionSuperAdminPorId(organizacionId);
  }

  async actualizarOrganizacionSuperAdmin(
    usuario: AuthenticatedUser,
    organizacionId: string,
    dto: ActualizarOrganizacionSuperAdminDto,
  ) {
    this.requerirSuperAdmin(usuario);
    await this.requerirEsquemaTblSuperAdmin();
    this.requerirIdTbl(organizacionId, 'Institucion no encontrada');

    const setters: Prisma.Sql[] = [];

    if (dto.nombre !== undefined) {
      const nombre = dto.nombre.trim();
      const duplicados = await this.prisma.$queryRaw<
        Array<{ existe: boolean }>
      >(
        Prisma.sql`
          SELECT EXISTS (
            SELECT 1
            FROM public.tbl_organizaciones
            WHERE lower(org_nombre) = lower(${nombre})
              AND id_org <> ${organizacionId}::uuid
          ) AS existe
        `,
      );

      if (duplicados[0]?.existe) {
        throw new ConflictException('La institucion ya esta registrada');
      }

      setters.push(Prisma.sql`org_nombre = ${nombre}`);
    }

    if (dto.telefono !== undefined) {
      setters.push(Prisma.sql`org_telefono = ${dto.telefono?.trim() || null}`);
    }

    if (dto.correo !== undefined) {
      setters.push(
        Prisma.sql`org_email = ${dto.correo?.trim().toLowerCase() || null}`,
      );
    }

    if (dto.activo !== undefined) {
      setters.push(Prisma.sql`org_activo = ${dto.activo}`);
      setters.push(
        dto.activo
          ? Prisma.sql`org_suspendida_en = NULL`
          : Prisma.sql`org_suspendida_en = COALESCE(org_suspendida_en, now())`,
      );

      if (dto.activo && dto.motivoSuspension === undefined) {
        setters.push(Prisma.sql`org_motivo_suspension = NULL`);
      }
    }

    if (dto.accesoHasta !== undefined) {
      setters.push(Prisma.sql`org_acceso_hasta = ${dto.accesoHasta}::date`);
    }

    if (dto.montoPlan !== undefined) {
      setters.push(Prisma.sql`org_monto_plan = ${dto.montoPlan}`);
    }

    if (dto.monedaPlan !== undefined) {
      setters.push(Prisma.sql`org_moneda_plan = ${dto.monedaPlan}`);
    }

    if (dto.motivoSuspension !== undefined) {
      setters.push(Prisma.sql`org_motivo_suspension = ${dto.motivoSuspension}`);
    } else if (dto.activo === false) {
      setters.push(
        Prisma.sql`org_motivo_suspension = 'Suspendido por falta de pagos'`,
      );
    }

    if (setters.length === 0) {
      throw new BadRequestException('No hay cambios para guardar');
    }

    const actualizado = await this.prisma.$queryRaw<
      OrganizacionSuperAdminRow[]
    >(
      Prisma.sql`
        WITH actualizada AS (
          UPDATE public.tbl_organizaciones
          SET ${Prisma.join(setters, ', ')}
          WHERE id_org = ${organizacionId}::uuid
            AND NOT COALESCE(org_es_sistema, FALSE)
          RETURNING *
        )
        SELECT
          org.id_org::text AS id,
          org.org_nombre AS nombre,
          org.org_telefono AS telefono,
          org.org_email AS correo,
          org.org_activo AS activo,
          COALESCE(org.org_es_sistema, FALSE) AS es_sistema,
          org.org_monto_plan AS monto_plan,
          org.org_moneda_plan AS moneda_plan,
          org.org_acceso_hasta AS acceso_hasta,
          org.org_suspendida_en AS suspendida_en,
          org.org_motivo_suspension AS motivo_suspension,
          COUNT(DISTINCT uo.usu_id)::int AS usuarios_total,
          COUNT(DISTINCT uo.usu_id) FILTER (WHERE tu.usu_activo)::int
            AS usuarios_activos,
          COALESCE(
            array_agg(DISTINCT tu.usu_usuario)
              FILTER (
                WHERE rol.rol_tip::text = 'ADMINISTRADOR'
                  AND tu.usu_usuario IS NOT NULL
              ),
            ARRAY[]::text[]
          ) AS administradores,
          (
            NOT org.org_activo
            OR (
              org.org_acceso_hasta IS NOT NULL
              AND org.org_acceso_hasta < CURRENT_DATE
            )
          ) AS suspendida,
          CASE
            WHEN org.org_acceso_hasta IS NULL THEN NULL
            ELSE (org.org_acceso_hasta - CURRENT_DATE)::int
          END AS dias_restantes
        FROM actualizada org
        LEFT JOIN public.tbl_usuarios_organizaciones uo
          ON uo.org_id = org.id_org
         AND uo.urg_activo
        LEFT JOIN public.tbl_usuarios tu ON tu.id_usu = uo.usu_id
        LEFT JOIN public.tbl_roles rol ON rol.id_rol = uo.rol_id
        GROUP BY org.id_org, org.org_nombre, org.org_telefono, org.org_email,
          org.org_activo, org.org_es_sistema, org.org_monto_plan,
          org.org_moneda_plan, org.org_acceso_hasta, org.org_suspendida_en,
          org.org_motivo_suspension
      `,
    );

    if (!actualizado[0]) {
      throw new NotFoundException('Institucion no encontrada');
    }

    return this.formatearOrganizacionSuperAdmin(actualizado[0]);
  }

  async extenderAccesoOrganizacion(
    usuario: AuthenticatedUser,
    organizacionId: string,
    dto: ExtenderAccesoOrganizacionDto,
  ) {
    this.requerirSuperAdmin(usuario);
    await this.requerirEsquemaTblSuperAdmin();
    this.requerirIdTbl(organizacionId, 'Institucion no encontrada');

    const actualizado = await this.prisma.$queryRaw<
      OrganizacionSuperAdminRow[]
    >(
      Prisma.sql`
        WITH actualizada AS (
          UPDATE public.tbl_organizaciones
          SET
            org_activo = TRUE,
            org_acceso_hasta =
              GREATEST(CURRENT_DATE, COALESCE(org_acceso_hasta, CURRENT_DATE))
              + ${dto.dias}::integer,
            org_suspendida_en = NULL,
            org_motivo_suspension = NULL
          WHERE id_org = ${organizacionId}::uuid
            AND NOT COALESCE(org_es_sistema, FALSE)
          RETURNING *
        )
        SELECT
          org.id_org::text AS id,
          org.org_nombre AS nombre,
          org.org_telefono AS telefono,
          org.org_email AS correo,
          org.org_activo AS activo,
          COALESCE(org.org_es_sistema, FALSE) AS es_sistema,
          org.org_monto_plan AS monto_plan,
          org.org_moneda_plan AS moneda_plan,
          org.org_acceso_hasta AS acceso_hasta,
          org.org_suspendida_en AS suspendida_en,
          org.org_motivo_suspension AS motivo_suspension,
          COUNT(DISTINCT uo.usu_id)::int AS usuarios_total,
          COUNT(DISTINCT uo.usu_id) FILTER (WHERE tu.usu_activo)::int
            AS usuarios_activos,
          COALESCE(
            array_agg(DISTINCT tu.usu_usuario)
              FILTER (
                WHERE rol.rol_tip::text = 'ADMINISTRADOR'
                  AND tu.usu_usuario IS NOT NULL
              ),
            ARRAY[]::text[]
          ) AS administradores,
          (
            NOT org.org_activo
            OR (
              org.org_acceso_hasta IS NOT NULL
              AND org.org_acceso_hasta < CURRENT_DATE
            )
          ) AS suspendida,
          CASE
            WHEN org.org_acceso_hasta IS NULL THEN NULL
            ELSE (org.org_acceso_hasta - CURRENT_DATE)::int
          END AS dias_restantes
        FROM actualizada org
        LEFT JOIN public.tbl_usuarios_organizaciones uo
          ON uo.org_id = org.id_org
         AND uo.urg_activo
        LEFT JOIN public.tbl_usuarios tu ON tu.id_usu = uo.usu_id
        LEFT JOIN public.tbl_roles rol ON rol.id_rol = uo.rol_id
        GROUP BY org.id_org, org.org_nombre, org.org_telefono, org.org_email,
          org.org_activo, org.org_es_sistema, org.org_monto_plan,
          org.org_moneda_plan, org.org_acceso_hasta, org.org_suspendida_en,
          org.org_motivo_suspension
      `,
    );

    if (!actualizado[0]) {
      throw new NotFoundException('Institucion no encontrada');
    }

    return this.formatearOrganizacionSuperAdmin(actualizado[0]);
  }

  async crearAdministradorSuperAdmin(
    usuario: AuthenticatedUser,
    dto: CrearAdministradorSuperAdminDto,
  ): Promise<AuthUserResponse> {
    this.requerirSuperAdmin(usuario);
    await this.requerirEsquemaTblSuperAdmin();
    this.requerirIdTbl(dto.organizacionId, 'Institucion no encontrada');

    const nombreUsuario = this.normalizarUsuario(dto.usuario);
    const correo = dto.correo.trim().toLowerCase();
    const nombre = this.separarNombre(dto.nombreCompleto);
    const passwordHash = await this.passwords.hash(dto.contrasena);

    const creadoId = await this.prisma.$transaction(async (tx) => {
      const [organizacion] = await tx.$queryRaw<
        Array<{ id: string }>
      >(Prisma.sql`
        SELECT id_org::text AS id
        FROM public.tbl_organizaciones
        WHERE id_org = ${dto.organizacionId}::uuid
          AND NOT COALESCE(org_es_sistema, FALSE)
        LIMIT 1
      `);

      if (!organizacion) {
        throw new NotFoundException('Institucion no encontrada');
      }

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

      const rolAdministradorId =
        await this.obtenerOCrearRolAdministradorTbl(tx);
      const documento = `admin-${nombreUsuario}-${randomUUID().slice(0, 8)}`;

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
            persona_id
          )
          VALUES (
            ${nombreUsuario},
            ${passwordHash},
            ${persona.id}::uuid
          )
          RETURNING id_usu::text AS id
        `,
      );

      await tx.$executeRaw(Prisma.sql`
        INSERT INTO public.tbl_usuarios_organizaciones (
          rol_id,
          usu_id,
          org_id,
          urg_activo
        )
        VALUES (
          ${rolAdministradorId}::uuid,
          ${usuarioCreado.id}::uuid,
          ${organizacion.id}::uuid,
          TRUE
        )
      `);

      return usuarioCreado.id;
    });

    const creado = await this.obtenerUsuarioTblPorId(creadoId);
    if (!creado) {
      throw new ConflictException('No se pudo crear el administrador');
    }

    return this.formatearUsuarioTbl(creado);
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
    const usuarioTbl = await this.obtenerUsuarioTblPorId(usuarioId);

    if (!usuarioTbl || !usuarioTbl.activo) {
      throw new UnauthorizedException('Sesion invalida');
    }

    this.validarAccesoUsuarioTbl(usuarioTbl);

    return this.formatearUsuarioTbl(usuarioTbl);
  }

  async validarUsuarioAutenticado(
    usuarioId: string,
  ): Promise<AuthenticatedUser> {
    const usuarioTbl = await this.obtenerUsuarioTblPorId(usuarioId);

    if (!usuarioTbl || !usuarioTbl.activo) {
      throw new UnauthorizedException('Sesion invalida');
    }

    this.validarAccesoUsuarioTbl(usuarioTbl);

    const formateado = this.formatearUsuarioTbl(usuarioTbl);

    return {
      usuarioId: formateado.id,
      usuario: formateado.usuario,
      organizacionId: formateado.organizacionId,
      roles: formateado.roles,
      permisos: formateado.permisos,
    };
  }

  async listarEmpleados(
    usuario: AuthenticatedUser,
  ): Promise<AuthUserResponse[]> {
    this.requerirVerEmpleados(usuario);
    return this.listarEmpleadosTbl(usuario);
  }

  async actualizarEmpleado(
    administrador: AuthenticatedUser,
    empleadoId: string,
    dto: ActualizarUsuarioDto,
  ): Promise<AuthUserResponse> {
    this.requerirAdministrador(administrador);
    return this.actualizarEmpleadoTbl(administrador, empleadoId, dto);
  }

  private normalizarRangoActividad(
    filtros: ActividadEmpleadosFiltros,
  ): RangoActividadEmpleados {
    const hoy = this.fechaActualColombia();
    const fechaInicio = filtros.inicio
      ? this.validarFechaActividad(filtros.inicio, 'inicio')
      : hoy;
    const fechaFin = filtros.fin
      ? this.validarFechaActividad(filtros.fin, 'fin')
      : fechaInicio;

    if (fechaInicio > fechaFin) {
      throw new BadRequestException(
        'La fecha de inicio no puede ser posterior a la fecha de fin',
      );
    }

    const empleadoId = filtros.empleadoId?.trim() || null;

    return {
      fechaInicio,
      fechaFin,
      empleadoId,
    };
  }

  private validarFechaActividad(value: string, campo: string) {
    const fecha = value.trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(fecha)) {
      throw new BadRequestException(
        `La fecha ${campo} debe tener formato YYYY-MM-DD`,
      );
    }

    const parsed = new Date(`${fecha}T00:00:00.000Z`);
    if (Number.isNaN(parsed.getTime())) {
      throw new BadRequestException(`La fecha ${campo} no es valida`);
    }

    const reconstruida = parsed.toISOString().slice(0, 10);
    if (reconstruida !== fecha) {
      throw new BadRequestException(`La fecha ${campo} no es valida`);
    }

    return fecha;
  }

  private fechaActualColombia() {
    return new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString().slice(0, 10);
  }

  async listarActividadEmpleados(
    usuario: AuthenticatedUser,
    filtros: ActividadEmpleadosFiltros = {},
  ) {
    this.requerirVerEmpleados(usuario);
    const rango = this.normalizarRangoActividad(filtros);

    return this.listarActividadEmpleadosTbl(usuario, rango);
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
          valorCreditosHoy: this.numero(row.valor_creditos_hoy),
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

  private async listarEmpleadosTbl(
    usuario: AuthenticatedUser,
  ): Promise<AuthUserResponse[]> {
    const orgId = await this.prisma.$transaction((tx) =>
      this.obtenerOrganizacionActivaAdministradorTbl(tx, usuario),
    );
    const usuarios = await this.prisma.$queryRaw<UsuarioTblAuth[]>(Prisma.sql`
      SELECT
        tu.id_usu::text AS id,
        tu.usu_usuario AS usuario,
        tu.usu_password AS "passwordHash",
        p.per_primer_nombre AS nombres,
        p.per_apellido AS apellidos,
        COALESCE(p.per_email, '') AS correo,
        tu.usu_activo AS activo,
        ${orgId}::text AS "organizacionId",
        TRUE AS "tieneAccesoOrganizacion",
        FALSE AS "organizacionSuspendida",
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
       AND uo.org_id = ${orgId}::uuid
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
          AND uo_cobrador.org_id = ${orgId}::uuid
          AND rol_cobrador.rol_tip::text = 'COBRADOR'
      )
      GROUP BY
        tu.id_usu,
        tu.usu_usuario,
        tu.usu_password,
        p.per_primer_nombre,
        p.per_apellido,
        p.per_email,
        tu.usu_activo
      ORDER BY tu.usu_activo DESC, p.per_primer_nombre ASC, p.per_apellido ASC
    `);

    return usuarios.map((usuario) => this.formatearUsuarioTbl(usuario));
  }

  private async listarActividadEmpleadosTbl(
    usuario: AuthenticatedUser,
    rango: RangoActividadEmpleados,
  ) {
    const orgId = await this.prisma.$transaction((tx) =>
      this.obtenerOrganizacionActivaAdministradorTbl(tx, usuario),
    );
    const rows = await this.prisma.$queryRaw<ActividadEmpleadoRow[]>(Prisma.sql`
      WITH parametros AS (
        SELECT
          ${rango.fechaInicio}::date AS fecha_inicio,
          ${rango.fechaFin}::date AS fecha_fin,
          ${rango.empleadoId}::text AS empleado_id
      ),
      empleados AS (
        SELECT DISTINCT
          tu.id_usu::text AS usuario_id,
          tu.usu_usuario AS nombre_usuario,
          concat_ws(' ', p.per_primer_nombre, p.per_apellido) AS nombre_completo,
          COALESCE(p.per_email, '') AS correo,
          tu.usu_activo AS activo
        FROM public.tbl_usuarios tu
        JOIN public.tbl_personas p ON p.id_per = tu.persona_id
        JOIN public.tbl_usuarios_organizaciones uo
          ON uo.usu_id = tu.id_usu
         AND uo.urg_activo
         AND uo.org_id = ${orgId}::uuid
        JOIN public.tbl_roles r
          ON r.id_rol = uo.rol_id
         AND r.rol_tip::text = 'COBRADOR'
        CROSS JOIN parametros params
        WHERE params.empleado_id IS NULL
          OR tu.id_usu::text = params.empleado_id
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
        WHERE cl.org_id = ${orgId}::uuid
          AND UPPER(cr.cre_estado::text) <> 'ANULADO'
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
        WHERE (p.pag_fecha AT TIME ZONE 'America/Bogota')::date
          BETWEEN (SELECT fecha_inicio FROM parametros)
          AND (SELECT fecha_fin FROM parametros)
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
        WHERE ce.cuo_fecha_vencimiento
          BETWEEN (SELECT fecha_inicio FROM parametros)
          AND (SELECT fecha_fin FROM parametros)
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
        WHERE cuo_fecha_vencimiento < (SELECT fecha_inicio FROM parametros)
        GROUP BY usuario_id, ruta_id
      ),
      pagos_resumen AS (
        SELECT
          cr.usu_id::text AS usuario_id,
          ruta_credito.ruta_id::text AS ruta_id,
          COALESCE(SUM(p.pag_monto) FILTER (
            WHERE (p.pag_fecha AT TIME ZONE 'America/Bogota')::date
              BETWEEN (SELECT fecha_inicio FROM parametros)
              AND (SELECT fecha_fin FROM parametros)
          ), 0) AS recaudo_hoy,
          COALESCE(SUM(p.pag_monto) FILTER (
            WHERE date_trunc('month', p.pag_fecha AT TIME ZONE 'America/Bogota') =
              date_trunc(
                'month',
                (SELECT fecha_fin FROM parametros)::timestamp
              )
          ), 0) AS recaudo_mes,
          COUNT(*) FILTER (
            WHERE (p.pag_fecha AT TIME ZONE 'America/Bogota')::date
              BETWEEN (SELECT fecha_inicio FROM parametros)
              AND (SELECT fecha_fin FROM parametros)
          )::int AS pagos_hoy,
          MAX(p.pag_fecha) FILTER (
            WHERE (p.pag_fecha AT TIME ZONE 'America/Bogota')::date
              BETWEEN (SELECT fecha_inicio FROM parametros)
              AND (SELECT fecha_fin FROM parametros)
          ) AS ultima_actividad
        FROM (
          SELECT DISTINCT
            p.id_pag,
            p.pag_monto,
            p.pag_fecha,
            cr.id_cre AS credito_id,
            cr.usu_id,
            cr.cli_id
          FROM public.tbl_pagos p
          JOIN public.tbl_cuotas_pagos cp ON cp.pagos_id = p.id_pag
          JOIN public.tbl_cuotas cu ON cu.id_cuo = cp.cuo_id
          JOIN public.tbl_creditos cr ON cr.id_cre = cu.cre_id
        ) p
        JOIN public.tbl_creditos cr ON cr.id_cre = p.credito_id
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
        WHERE cl.org_id = ${orgId}::uuid
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
            WHERE cre_fecha_inicio
              BETWEEN (SELECT fecha_inicio FROM parametros)
              AND (SELECT fecha_fin FROM parametros)
          )::int AS creditos_hoy,
          COUNT(*) FILTER (
            WHERE date_trunc('month', cre_fecha_inicio::timestamp) =
              date_trunc(
                'month',
                (SELECT fecha_fin FROM parametros)::timestamp
              )
          )::int AS creditos_mes,
          COALESCE(SUM(cre_total) FILTER (
            WHERE cre_fecha_inicio
              BETWEEN (SELECT fecha_inicio FROM parametros)
              AND (SELECT fecha_fin FROM parametros)
          ), 0) AS valor_creditos_hoy,
          COALESCE(SUM(cre_total), 0) AS valor_creditos_total,
          MAX(cre_fecha_inicio::timestamptz) FILTER (
            WHERE cre_fecha_inicio
              BETWEEN (SELECT fecha_inicio FROM parametros)
              AND (SELECT fecha_fin FROM parametros)
          ) AS ultima_actividad
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
        COALESCE(cr.valor_creditos_hoy, 0) AS valor_creditos_hoy,
        COALESCE(cr.valor_creditos_total, 0) AS valor_creditos_total,
        COALESCE(pt.recaudo_hoy, 0) AS recaudo_hoy,
        COALESCE(pt.recaudo_mes, 0) AS recaudo_mes,
        COALESCE(pt.pagos_hoy, 0) AS pagos_hoy,
        COALESCE(ar.deberes_hoy, 0) AS deberes_hoy,
        COALESCE(ar.cumplidos_hoy, 0) AS cumplidos_hoy,
        COALESCE(ar.pendientes_hoy, 0) AS pendientes_hoy,
        COALESCE(atrasos_total.atrasados, 0) AS atrasados,
        CASE
          WHEN cr.ultima_actividad IS NULL THEN pt.ultima_actividad
          WHEN pt.ultima_actividad IS NULL THEN cr.ultima_actividad
          WHEN cr.ultima_actividad >= pt.ultima_actividad THEN cr.ultima_actividad
          ELSE pt.ultima_actividad
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
    return this.actualizarPermisosEmpleadosTbl(administrador, dto);
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
        : Prisma.sql`AND tu.id_usu::text IN (${Prisma.join(usuarioIdsDto)})`;
      const usuariosObjetivo = await tx.$queryRaw<
        Array<{ usuario_id: string }>
      >(Prisma.sql`
        SELECT DISTINCT tu.id_usu::text AS usuario_id
        FROM public.tbl_usuarios tu
        JOIN public.tbl_usuarios_organizaciones uo
          ON uo.usu_id = tu.id_usu
         AND uo.urg_activo
         AND uo.org_id = ${orgId}::uuid
        JOIN public.tbl_roles rol ON rol.id_rol = uo.rol_id
        WHERE rol.rol_tip::text = 'COBRADOR'
          ${filtroUsuarios}
      `);

      if (usuariosObjetivo.length === 0) {
        throw new BadRequestException('Selecciona al menos un empleado');
      }

      const [rolCobrador] = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT id_rol::text AS id
          FROM public.tbl_roles
          WHERE rol_tip::text = 'COBRADOR'
          LIMIT 1
        `,
      );

      if (!rolCobrador) {
        throw new ConflictException(
          'No existe el rol COBRADOR en el esquema tbl_*',
        );
      }

      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_roles_recursos rol_recurso
        USING public.tbl_roles rol, public.tbl_recursos recurso
        WHERE rol.id_rol = rol_recurso.rol_id
          AND recurso.id_rec = rol_recurso.rec_id
          AND rol.rol_tip::text = 'COBRADOR'
          AND recurso.rec_interface = 'WEB'
          AND recurso.nom IN (${Prisma.join(permisosEmpleadoCodigos)})
      `);

      if (permisos.length === 0) {
        return;
      }

      const recursosPermiso = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT id_rec::text AS id
          FROM public.tbl_recursos
          WHERE rec_interface = 'WEB'
            AND nom IN (${Prisma.join(permisos)})
        `,
      );

      if (recursosPermiso.length !== permisos.length) {
        throw new ConflictException(
          'Faltan recursos de permisos en el esquema tbl_*',
        );
      }

      await tx.$executeRaw(Prisma.sql`
        INSERT INTO public.tbl_roles_recursos (rol_id, rec_id)
        SELECT ${rolCobrador.id}::uuid, recurso.id_rec
        FROM public.tbl_recursos recurso
        WHERE recurso.rec_interface = 'WEB'
          AND recurso.nom IN (${Prisma.join(permisos)})
        ON CONFLICT (rec_id, rol_id) DO NOTHING
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
         AND uo.org_id = ${orgId}::uuid
        JOIN public.tbl_roles rol ON rol.id_rol = uo.rol_id
        WHERE tu.id_usu = ${empleadoId}::uuid
          AND rol.rol_tip::text = 'COBRADOR'
        LIMIT 1
      `);

      if (!empleado) {
        throw new NotFoundException('Empleado no encontrado');
      }

      const [existenteUsuario, existenteCorreo] = await Promise.all([
        tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
          SELECT tu.id_usu::text AS id
          FROM public.tbl_usuarios
          WHERE lower(usu_usuario) = lower(${nombreUsuario})
            AND id_usu <> ${empleadoId}::uuid
          LIMIT 1
        `),
        tx.$queryRaw<Array<{ id: string }>>(Prisma.sql`
          SELECT id_usu::text AS id
          FROM public.tbl_usuarios tu
          JOIN public.tbl_personas p ON p.id_per = tu.persona_id
          WHERE lower(p.per_email) = lower(${correo})
            AND tu.id_usu <> ${empleadoId}::uuid
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
        WHERE id_per = ${empleado.persona_id}::uuid
      `);

      if (passwordHash) {
        await tx.$executeRaw(Prisma.sql`
          UPDATE public.tbl_usuarios
          SET
            usu_usuario = ${nombreUsuario},
            usu_password = ${passwordHash}
          WHERE id_usu = ${empleadoId}::uuid
        `);
        return;
      }

      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_usuarios
        SET usu_usuario = ${nombreUsuario}
        WHERE id_usu = ${empleadoId}::uuid
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
         AND uo.org_id = ${orgId}::uuid
        JOIN public.tbl_roles rol ON rol.id_rol = uo.rol_id
        WHERE tu.id_usu = ${empleadoId}::uuid
          AND rol.rol_tip::text = 'COBRADOR'
        LIMIT 1
      `);

      if (!empleados[0]) {
        throw new NotFoundException('Empleado no encontrado');
      }

      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_usuarios
        SET usu_activo = ${dto.activo}
        WHERE id_usu = ${empleadoId}::uuid
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

    return this.actualizarEstadoEmpleadoTbl(administrador, empleadoId, dto);
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
      organizacionId: null,
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

  private requerirSuperAdmin(usuario: AuthenticatedUser) {
    if (!usuario.roles.includes('SUPER_ADMIN')) {
      throw new ForbiddenException(
        'Solo SUPER_ADMIN puede administrar instituciones',
      );
    }
  }

  private async requerirEsquemaTblSuperAdmin() {}

  private requerirIdTbl(value: string, mensaje: string) {
    if (!this.esIdTbl(value)) {
      throw new NotFoundException(mensaje);
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
    return this.crearUsuarioTbl(dto, rolCodigo, administrador);
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
            persona_id
          )
          VALUES (
            ${nombreUsuario},
            ${passwordHash},
            ${persona.id}::uuid
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
          ${rol.id}::uuid,
          ${usuarioCreado.id}::uuid,
          ${orgId}::uuid
        )
      `);

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
    const filtroOrganizacionSesion =
      administrador?.organizacionId &&
      this.esIdTbl(administrador.organizacionId)
        ? Prisma.sql`AND uo.org_id = ${administrador.organizacionId}::uuid`
        : Prisma.empty;
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
           AND NOT COALESCE(org.org_es_sistema, FALSE)
           AND (
             org.org_acceso_hasta IS NULL
             OR org.org_acceso_hasta >= CURRENT_DATE
           )
          WHERE tu.usu_activo
            ${filtroOrganizacionSesion}
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
            AND NOT COALESCE(org_es_sistema, FALSE)
            AND (
              org_acceso_hasta IS NULL
              OR org_acceso_hasta >= CURRENT_DATE
            )
          ORDER BY id_org ASC
          LIMIT 1
        `);

    if (!scope) {
      throw new ConflictException('No existe una organizacion activa');
    }

    return scope.org_id;
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
        FROM public.tbl_usuarios tu
        JOIN public.tbl_personas p ON p.id_per = tu.persona_id
        WHERE lower(p.per_email) = ${correo}
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

    this.validarAccesoUsuarioTbl(usuarioTbl);

    if (this.passwords.needsRehash(usuarioTbl.passwordHash)) {
      const upgradedHash = await this.passwords.hash(contrasena);
      await this.prisma.$executeRaw`
        UPDATE public.tbl_usuarios
        SET usu_password = ${upgradedHash}
        WHERE id_usu = ${usuarioTbl.id}::uuid
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
        COALESCE(p.per_email, '') AS correo,
        tu.usu_activo AS activo,
        scope.org_id::text AS "organizacionId",
        scope.org_id IS NOT NULL AS "tieneAccesoOrganizacion",
        EXISTS (
          SELECT 1
          FROM public.tbl_usuarios_organizaciones uo_suspendida
          JOIN public.tbl_organizaciones org_suspendida
            ON org_suspendida.id_org = uo_suspendida.org_id
          WHERE uo_suspendida.usu_id = tu.id_usu
            AND uo_suspendida.urg_activo
            AND NOT COALESCE(org_suspendida.org_es_sistema, FALSE)
            AND (
              NOT org_suspendida.org_activo
              OR (
                org_suspendida.org_acceso_hasta IS NOT NULL
                AND org_suspendida.org_acceso_hasta < CURRENT_DATE
              )
            )
        ) AS "organizacionSuspendida",
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
      LEFT JOIN LATERAL (
        SELECT uo_scope.org_id
        FROM public.tbl_usuarios_organizaciones uo_scope
        JOIN public.tbl_organizaciones org_scope
          ON org_scope.id_org = uo_scope.org_id
        WHERE uo_scope.usu_id = tu.id_usu
          AND uo_scope.urg_activo
          AND org_scope.org_activo
          AND NOT COALESCE(org_scope.org_es_sistema, FALSE)
          AND (
            org_scope.org_acceso_hasta IS NULL
            OR org_scope.org_acceso_hasta >= CURRENT_DATE
          )
        ORDER BY uo_scope.id_urg ASC
        LIMIT 1
      ) scope ON TRUE
      LEFT JOIN public.tbl_usuarios_organizaciones uo
        ON uo.usu_id = tu.id_usu
       AND uo.urg_activo
       AND (scope.org_id IS NULL OR uo.org_id = scope.org_id)
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
        p.per_email,
        tu.usu_activo,
        scope.org_id
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
        COALESCE(p.per_email, '') AS correo,
        tu.usu_activo AS activo,
        scope.org_id::text AS "organizacionId",
        scope.org_id IS NOT NULL AS "tieneAccesoOrganizacion",
        EXISTS (
          SELECT 1
          FROM public.tbl_usuarios_organizaciones uo_suspendida
          JOIN public.tbl_organizaciones org_suspendida
            ON org_suspendida.id_org = uo_suspendida.org_id
          WHERE uo_suspendida.usu_id = tu.id_usu
            AND uo_suspendida.urg_activo
            AND NOT COALESCE(org_suspendida.org_es_sistema, FALSE)
            AND (
              NOT org_suspendida.org_activo
              OR (
                org_suspendida.org_acceso_hasta IS NOT NULL
                AND org_suspendida.org_acceso_hasta < CURRENT_DATE
              )
            )
        ) AS "organizacionSuspendida",
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
      LEFT JOIN LATERAL (
        SELECT uo_scope.org_id
        FROM public.tbl_usuarios_organizaciones uo_scope
        JOIN public.tbl_organizaciones org_scope
          ON org_scope.id_org = uo_scope.org_id
        WHERE uo_scope.usu_id = tu.id_usu
          AND uo_scope.urg_activo
          AND org_scope.org_activo
          AND NOT COALESCE(org_scope.org_es_sistema, FALSE)
          AND (
            org_scope.org_acceso_hasta IS NULL
            OR org_scope.org_acceso_hasta >= CURRENT_DATE
          )
        ORDER BY uo_scope.id_urg ASC
        LIMIT 1
      ) scope ON TRUE
      LEFT JOIN public.tbl_usuarios_organizaciones uo
        ON uo.usu_id = tu.id_usu
       AND uo.urg_activo
       AND (scope.org_id IS NULL OR uo.org_id = scope.org_id)
      LEFT JOIN public.tbl_roles tr ON tr.id_rol = uo.rol_id
      LEFT JOIN public.tbl_roles_recursos rr ON rr.rol_id = tr.id_rol
      LEFT JOIN public.tbl_recursos rec ON rec.id_rec = rr.rec_id
      WHERE tu.id_usu = ${usuarioId}::uuid
      GROUP BY
        tu.id_usu,
        tu.usu_usuario,
        tu.usu_password,
        p.per_primer_nombre,
        p.per_apellido,
        p.per_email,
        tu.usu_activo,
        scope.org_id
      LIMIT 1
    `;

    return usuarios[0] ?? null;
  }

  private esIdTbl(value: string) {
    return /^[1-9]\d{0,18}$/.test(value) || /^[0-9a-fA-F-]{36}$/.test(value);
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


  private formatearUsuarioTbl(usuario: UsuarioTblAuth): AuthUserResponse {
    const roles = usuario.roles.filter((rol) => !esPermisoEmpleado(rol));
    const esAdministrador = roles.includes('ADMINISTRADOR');
    const esSuperAdmin = roles.includes('SUPER_ADMIN');
    const permisosDesdeRecursos = usuario.permisos.filter((permiso) =>
      esPermisoEmpleado(permiso),
    );
    const permisos = permisosDesdeRecursos;

    return {
      id: usuario.id,
      usuario: usuario.usuario,
      nombreCompleto: `${usuario.nombres} ${usuario.apellidos}`.trim(),
      correo: usuario.correo,
      roles,
      organizacionId: usuario.organizacionId,
      esAdministrador,
      esSuperAdmin,
      activo: usuario.activo,
      estado: {
        codigo: usuario.activo ? 'ACTIVO' : 'INACTIVO',
        nombre: usuario.activo ? 'Activo' : 'Inactivo',
      },
      permisos:
        esAdministrador || esSuperAdmin ? permisosEmpleadoCodigos : permisos,
    };
  }

  private validarAccesoUsuarioTbl(usuario: UsuarioTblAuth) {
    if (usuario.roles.includes('SUPER_ADMIN')) {
      return;
    }

    if (usuario.tieneAccesoOrganizacion) {
      return;
    }

    if (usuario.organizacionSuspendida) {
      throw new UnauthorizedException(
        'La institucion a la que pertenece esta suspendida',
      );
    }

    throw new UnauthorizedException('No tienes una institucion activa');
  }

  private async obtenerOrganizacionSuperAdminPorId(organizacionId: string) {
    const rows = await this.prisma.$queryRaw<
      OrganizacionSuperAdminRow[]
    >(Prisma.sql`
      SELECT
        org.id_org::text AS id,
        org.org_nombre AS nombre,
        org.org_telefono AS telefono,
        org.org_email AS correo,
        org.org_activo AS activo,
        COALESCE(org.org_es_sistema, FALSE) AS es_sistema,
        org.org_monto_plan AS monto_plan,
        org.org_moneda_plan AS moneda_plan,
        org.org_acceso_hasta AS acceso_hasta,
        org.org_suspendida_en AS suspendida_en,
        org.org_motivo_suspension AS motivo_suspension,
        COUNT(DISTINCT uo.usu_id)::int AS usuarios_total,
        COUNT(DISTINCT uo.usu_id) FILTER (WHERE tu.usu_activo)::int
          AS usuarios_activos,
        COALESCE(
          array_agg(DISTINCT tu.usu_usuario)
            FILTER (
              WHERE rol.rol_tip::text = 'ADMINISTRADOR'
                AND tu.usu_usuario IS NOT NULL
            ),
          ARRAY[]::text[]
        ) AS administradores,
        (
          NOT org.org_activo
          OR (
            org.org_acceso_hasta IS NOT NULL
            AND org.org_acceso_hasta < CURRENT_DATE
          )
        ) AS suspendida,
        CASE
          WHEN org.org_acceso_hasta IS NULL THEN NULL
          ELSE (org.org_acceso_hasta - CURRENT_DATE)::int
        END AS dias_restantes
      FROM public.tbl_organizaciones org
      LEFT JOIN public.tbl_usuarios_organizaciones uo
        ON uo.org_id = org.id_org
       AND uo.urg_activo
      LEFT JOIN public.tbl_usuarios tu ON tu.id_usu = uo.usu_id
      LEFT JOIN public.tbl_roles rol ON rol.id_rol = uo.rol_id
      WHERE org.id_org = ${organizacionId}::uuid
        AND NOT COALESCE(org.org_es_sistema, FALSE)
      GROUP BY org.id_org
      LIMIT 1
    `);

    if (!rows[0]) {
      throw new NotFoundException('Institucion no encontrada');
    }

    return this.formatearOrganizacionSuperAdmin(rows[0]);
  }

  private formatearOrganizacionSuperAdmin(row: OrganizacionSuperAdminRow) {
    return {
      id: row.id,
      nombre: row.nombre,
      telefono: row.telefono,
      correo: row.correo,
      activo: row.activo,
      esSistema: row.es_sistema,
      montoPlan: this.numero(row.monto_plan),
      monedaPlan: row.moneda_plan ?? 'COP',
      accesoHasta: this.fechaIsoCorta(row.acceso_hasta),
      suspendidaEn: this.fechaIso(row.suspendida_en),
      motivoSuspension: row.motivo_suspension,
      suspendida: row.suspendida,
      diasRestantes: row.dias_restantes,
      usuariosTotal: this.entero(row.usuarios_total),
      usuariosActivos: this.entero(row.usuarios_activos),
      administradores: row.administradores ?? [],
    };
  }

  private fechaIsoCorta(value: Date | string | null) {
    if (!value) {
      return null;
    }

    if (value instanceof Date) {
      return value.toISOString().slice(0, 10);
    }

    return value.slice(0, 10);
  }

  private fechaIso(value: Date | string | null) {
    if (!value) {
      return null;
    }

    if (value instanceof Date) {
      return value.toISOString();
    }

    return value;
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
}

