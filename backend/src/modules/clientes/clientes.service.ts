import { randomUUID } from 'node:crypto';
import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { InMemoryCacheService } from '../../common/cache/in-memory-cache.service';
import { DomainError } from '../../common/domain/domain-error';
import { PrismaService } from '../../common/prisma/prisma.service';
import {
  PrismaExecutor,
  TenantScopeService,
} from '../../common/tenancy/tenant-scope.service';
import { AuthenticatedUser } from '../auth/auth.types';
import {
  PermisoEmpleadoCodigo,
  permisosEmpleadoPorCodigo,
} from '../auth/permissions';
import { RutasService } from '../rutas/rutas.service';
import {
  ActualizarClienteDto,
  ActualizarUbicacionClienteDto,
  CrearClienteDto,
  ListarClientesQueryDto,
} from './dto';

type ClienteTblRow = {
  id: string;
  nombre_completo: string;
  nombre_comercial: string | null;
  notas: string | null;
  cedula: string;
  direccion: string | null;
  correo?: string | null;
  latitud: Prisma.Decimal | null;
  longitud: Prisma.Decimal | null;
  telefono: string | null;
  creado_en: Date;
  actualizado_en: Date;
  activo: boolean;
};

type ClienteUbicacionTblRow = {
  persona_id: string;
  direccion: string | null;
};

type ClienteTblDetalleRow = ClienteTblRow & {
  persona_id: string;
};

@Injectable()
export class ClientesService {

  constructor(
    private readonly prisma: PrismaService,
    private readonly tenantScope: TenantScopeService,
    private readonly rutas: RutasService,
    private readonly cache: InMemoryCacheService,
  ) {}

  async listarClientes(
    query: ListarClientesQueryDto,
    usuario: AuthenticatedUser,
  ) {
    return this.listarClientesTbl(query, usuario);
  }

  async listarClientesTbl(
    query: ListarClientesQueryDto,
    usuario: AuthenticatedUser,
  ) {
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);
    const search = this.normalizarTextoOpcional(query.search);
    const conditions: Prisma.Sql[] = [
      Prisma.sql`c.org_id = ${scope.organizacionId}::uuid`,
    ];

    if (!this.tenantScope.puedeVerDatosOrganizacion(usuario)) {
      conditions.push(Prisma.sql`EXISTS (
        SELECT 1
        FROM public.tbl_rutas_clientes rc_acl
        JOIN public.tbl_rutas r_acl ON r_acl.id_rut = rc_acl.rut_id
        WHERE rc_acl.cli_id = c.id_cli
          AND rc_acl.rcl_activo
          AND r_acl.org_id = c.org_id
          AND r_acl.usu_id = ${scope.usuarioId}::uuid
      )`);
    }

    if (search) {
      const pattern = `%${search}%`;
      conditions.push(Prisma.sql`(
        CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido) ILIKE ${pattern}
        OR p.per_documento ILIKE ${pattern}
        OR p.per_direccion ILIKE ${pattern}
        OR p.per_num_celular ILIKE ${pattern}
        OR c.cli_referencia ILIKE ${pattern}
      )`);
    }

    const where =
      conditions.length > 0
        ? Prisma.sql`WHERE ${Prisma.join(conditions, ' AND ')}`
        : Prisma.empty;
    const rows = await this.prisma.$queryRaw<ClienteTblRow[]>(Prisma.sql`
      SELECT
        c.id_cli::text AS id,
        TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS nombre_completo,
        c.cli_referencia AS nombre_comercial,
        NULL::text AS notas,
        p.per_documento AS cedula,
        p.per_direccion AS direccion,
        p.per_latitud AS latitud,
        p.per_longitud AS longitud,
        p.per_num_celular AS telefono,
        p.per_email AS correo,
        c.cli_creacion AS creado_en,
        c.cli_creacion AS actualizado_en,
        c.cli_activo AS activo
      FROM public.tbl_clientes c
      JOIN public.tbl_personas p ON p.id_per = c.cli_persona
      ${where}
      ORDER BY nombre_completo ASC
    `);

    return rows.map((cliente) => this.formatearClienteTbl(cliente));
  }

  async crearCliente(dto: CrearClienteDto, usuario: AuthenticatedUser) {
    return this.crearClienteTbl(dto, usuario);
  }

  async crearClienteTbl(
    input: CrearClienteDto,
    usuario: AuthenticatedUser,
  ) {
    const latitud = input.latitud;
    const longitud = input.longitud;
    if (
      [latitud, longitud].some(
        (value: unknown) =>
          value !== undefined &&
          (typeof value !== 'number' || !Number.isFinite(value)),
      )
    ) {
      throw DomainError.validation(
        'Las coordenadas deben ser números finitos',
        'COORDENADAS_INVALIDAS',
      );
    }

    const nombrePersona = this.dividirNombrePersonaTbl(input.nombreCompleto);
    const telefono = input.telefono ?? input.whatsapp;
    const cedula = input.cedula ?? this.generarDocumentoClienteTbl();

    const clienteId = await this.prisma.$transaction(
      async (tx) => {
        const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(
          usuario,
          tx,
        );

        if (input.cedula) {
          const [duplicado] = await tx.$queryRaw<Array<{ existe: boolean }>>(
            Prisma.sql`
              SELECT EXISTS (
                SELECT 1
                FROM public.tbl_clientes c
                JOIN public.tbl_personas p ON p.id_per = c.cli_persona
                WHERE p.per_documento = ${input.cedula}
                  AND c.org_id = ${scope.organizacionId}::uuid
              ) AS existe
            `,
          );

          if (duplicado?.existe) {
            throw DomainError.conflict(
              'Ya existe un cliente con esta cedula',
              'CEDULA_YA_REGISTRADA',
            );
          }
        }

        const [persona] = await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
            INSERT INTO public.tbl_personas (
              per_primer_nombre,
              per_apellido,
              per_documento,
              per_direccion,
              per_num_celular,
              per_latitud,
              per_longitud
            )
            VALUES (
              ${nombrePersona.nombres},
              ${nombrePersona.apellidos},
              ${cedula},
              ${input.direccion},
              ${telefono},
              ${input.latitud ?? null},
              ${input.longitud ?? null}
            )
            RETURNING id_per::text AS id
          `,
        );

        const [cliente] = await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
            INSERT INTO public.tbl_clientes (
              cli_referencia,
              org_id,
              cli_persona
            )
            VALUES (
              ${input.nombreComercial},
              ${scope.organizacionId}::uuid,
              ${persona.id}::uuid
            )
            RETURNING id_cli::text AS id
          `,
        );

        const rutaId = await this.rutas.obtenerOCrearRutaCreditoTbl(
          tx,
          undefined,
          scope.organizacionId,
          scope.usuarioId,
          usuario.usuario,
        );

        await tx.$executeRaw(Prisma.sql`
          INSERT INTO public.tbl_rutas_clientes (rut_id, cli_id)
          VALUES (${rutaId}::uuid, ${cliente.id}::uuid)
          ON CONFLICT (rut_id, cli_id) DO UPDATE
          SET rcl_activo = TRUE
        `);

        
        return cliente.id;
      },
      { maxWait: 10_000, timeout: 10_000 },
    );

    const creados = await this.prisma.$queryRaw<ClienteTblRow[]>(Prisma.sql`
      SELECT
        c.id_cli::text AS id,
        TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS nombre_completo,
        c.cli_referencia AS nombre_comercial,
        NULL::text AS notas,
        p.per_documento AS cedula,
        p.per_direccion AS direccion,
        p.per_latitud AS latitud,
        p.per_longitud AS longitud,
        p.per_num_celular AS telefono,
        c.cli_creacion AS creado_en,
        c.cli_creacion AS actualizado_en,
        c.cli_activo AS activo
      FROM public.tbl_clientes c
      JOIN public.tbl_personas p ON p.id_per = c.cli_persona
      WHERE c.id_cli::text = ${clienteId}
    `);
    const cliente = creados[0];

    if (!cliente) {
      throw DomainError.notFound(
        'Cliente no encontrado despues de crear',
        'CLIENTE_NO_ENCONTRADO',
      );
    }

    this.invalidarCacheLecturas();
    return this.formatearClienteTbl(cliente);
  }

  async actualizarCliente(
    clienteId: string,
    dto: ActualizarClienteDto,
    usuario: AuthenticatedUser,
  ) {
    return this.actualizarClienteTbl(clienteId, dto, usuario);
  }

  async actualizarClienteTbl(
    clienteId: string,
    dto: ActualizarClienteDto,
    usuario: AuthenticatedUser,
  ) {
    this.asegurarPermiso(usuario, 'MODIFICAR_CLIENTES');

    const nombreCompleto = this.requerirTexto(
      dto.nombreCompleto,
      'El nombre del cliente es obligatorio',
    );
    const cedula = this.normalizarTextoOpcional(dto.cedula);
    const nombreComercial = this.normalizarTextoOpcional(dto.nombreComercial);
    const direccion = this.normalizarTextoOpcional(dto.direccion);
    const telefono = this.normalizarTextoOpcional(dto.telefono);
    const latitud = dto.latitud;
    const longitud = dto.longitud;
    if (
      [latitud, longitud].some(
        (value: unknown) =>
          value !== undefined &&
          (typeof value !== 'number' || !Number.isFinite(value)),
      )
    ) {
      throw DomainError.validation(
        'Las coordenadas deben ser números finitos',
        'COORDENADAS_INVALIDAS',
      );
    }
    if ((latitud === undefined) !== (longitud === undefined)) {
      throw DomainError.validation(
        'La latitud y la longitud deben enviarse juntas',
        'COORDENADAS_INCOMPLETAS',
      );
    }
    if (latitud !== undefined && !direccion) {
      throw DomainError.validation(
        'La dirección es obligatoria cuando se envían coordenadas',
        'DIRECCION_COORDENADAS_REQUERIDA',
      );
    }
    const nombrePersona = this.dividirNombrePersonaTbl(nombreCompleto);
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);

    await this.prisma.$transaction(
      async (tx) => {
        const rows = await tx.$queryRaw<ClienteTblDetalleRow[]>(Prisma.sql`
          SELECT
            c.id_cli::text AS id,
            c.cli_persona::text AS persona_id,
            TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS nombre_completo,
            c.cli_referencia AS nombre_comercial,
            NULL::text AS notas,
            p.per_documento AS cedula,
            p.per_direccion AS direccion,
            p.per_latitud AS latitud,
            p.per_longitud AS longitud,
            p.per_num_celular AS telefono,
            c.cli_creacion AS creado_en,
            c.cli_creacion AS actualizado_en,
            c.cli_activo AS activo
          FROM public.tbl_clientes c
          JOIN public.tbl_personas p ON p.id_per = c.cli_persona
          WHERE c.id_cli::text = ${clienteId}
            AND c.org_id = ${scope.organizacionId}::uuid
          FOR UPDATE OF c, p
        `);
        const actual = rows[0];

        if (!actual) {
          throw DomainError.notFound(
            'Cliente no encontrado',
            'CLIENTE_NO_ENCONTRADO',
          );
        }

        const cedulaFinal = cedula ?? actual.cedula;
        const latitudFinal =
          latitud ??
          (actual.latitud === null
            ? null
            : this.decimalANumero(actual.latitud));
        const longitudFinal =
          longitud ??
          (actual.longitud === null
            ? null
            : this.decimalANumero(actual.longitud));
        if (cedulaFinal !== actual.cedula) {
          const duplicados = await tx.$queryRaw<Array<{ existe: boolean }>>(
            Prisma.sql`
              SELECT EXISTS (
                SELECT 1
                FROM public.tbl_clientes c
                JOIN public.tbl_personas p ON p.id_per = c.cli_persona
                WHERE p.per_documento = ${cedulaFinal}
                  AND c.org_id = ${scope.organizacionId}::uuid
                  AND c.id_cli::text <> ${clienteId}
              ) AS existe
            `,
          );

          if (duplicados[0]?.existe) {
            throw DomainError.conflict(
              'Ya existe un cliente con esta cedula',
              'CEDULA_YA_REGISTRADA',
            );
          }
        }

        await tx.$executeRaw(Prisma.sql`
          UPDATE public.tbl_personas
          SET
            per_primer_nombre = ${nombrePersona.nombres},
            per_apellido = ${nombrePersona.apellidos},
            per_documento = ${cedulaFinal},
            per_direccion = ${direccion},
            per_latitud = ${latitudFinal},
            per_longitud = ${longitudFinal},
            per_num_celular = ${telefono}
          WHERE id_per::text = ${actual.persona_id}
        `);

        await tx.$executeRaw(Prisma.sql`
          UPDATE public.tbl_clientes
          SET cli_referencia = ${nombreComercial}
          WHERE id_cli::text = ${clienteId}
        `);

              },
      { maxWait: 10_000, timeout: 10_000 },
    );

    const actualizados = await this.prisma.$queryRaw<
      ClienteTblRow[]
    >(Prisma.sql`
      SELECT
        c.id_cli::text AS id,
        TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS nombre_completo,
        c.cli_referencia AS nombre_comercial,
        NULL::text AS notas,
        p.per_documento AS cedula,
        p.per_direccion AS direccion,
        p.per_latitud AS latitud,
        p.per_longitud AS longitud,
        p.per_num_celular AS telefono,
        c.cli_creacion AS creado_en,
        c.cli_creacion AS actualizado_en,
        c.cli_activo AS activo
      FROM public.tbl_clientes c
      JOIN public.tbl_personas p ON p.id_per = c.cli_persona
      WHERE c.id_cli::text = ${clienteId}
        AND c.org_id = ${scope.organizacionId}::uuid
    `);
    const cliente = actualizados[0];

    if (!cliente) {
      throw DomainError.notFound(
        'Cliente no encontrado despues de modificar',
        'CLIENTE_NO_ENCONTRADO',
      );
    }

    this.invalidarCacheLecturas();
    return this.formatearClienteTbl(cliente);
  }

  async eliminarCliente(clienteId: string, usuario: AuthenticatedUser) {
    return this.eliminarClienteTbl(clienteId, usuario);
  }

  async eliminarClienteTbl(clienteId: string, usuario: AuthenticatedUser) {
    this.asegurarAdministrador(usuario);
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);

    await this.prisma.$transaction(async (tx) => {
      const rows = await tx.$queryRaw<ClienteTblDetalleRow[]>(Prisma.sql`
        SELECT
          c.id_cli::text AS id,
          c.cli_persona::text AS persona_id,
          TRIM(CONCAT_WS(' ', p.per_primer_nombre, p.per_apellido)) AS nombre_completo,
          c.cli_referencia AS nombre_comercial,
          NULL::text AS notas,
          p.per_documento AS cedula,
          p.per_direccion AS direccion,
          p.per_latitud AS latitud,
          p.per_longitud AS longitud,
          p.per_num_celular AS telefono,
          c.cli_creacion AS creado_en,
          c.cli_creacion AS actualizado_en,
          c.cli_activo AS activo
        FROM public.tbl_clientes c
        JOIN public.tbl_personas p ON p.id_per = c.cli_persona
        WHERE c.id_cli::text = ${clienteId}
          AND c.org_id = ${scope.organizacionId}::uuid
        FOR UPDATE OF c, p
      `);
      const cliente = rows[0];

      if (!cliente) {
        throw DomainError.notFound(
          'Cliente no encontrado',
          'CLIENTE_NO_ENCONTRADO',
        );
      }

      const relaciones = await tx.$queryRaw<
        Array<{ creditos: number; pagos: number }>
      >(Prisma.sql`
        SELECT
          COUNT(DISTINCT cr.id_cre)::int AS creditos,
          COUNT(DISTINCT pa.id_pag)::int AS pagos
        FROM public.tbl_clientes c
        LEFT JOIN public.tbl_creditos cr ON cr.cli_id = c.id_cli
        LEFT JOIN public.tbl_cuotas cu ON cu.cre_id = cr.id_cre
        LEFT JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
        LEFT JOIN public.tbl_pagos pa ON pa.id_pag = cp.pagos_id
        WHERE c.id_cli::text = ${clienteId}
          AND c.org_id = ${scope.organizacionId}::uuid
      `);
      const conteo = relaciones[0];

      if ((conteo?.creditos ?? 0) > 0 || (conteo?.pagos ?? 0) > 0) {
        throw DomainError.conflict(
          'No se puede eliminar un cliente con creditos o pagos registrados',
          'CLIENTE_CON_MOVIMIENTOS_NO_ELIMINABLE',
        );
      }

      
      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_rutas_clientes
        USING public.tbl_rutas r
        WHERE tbl_rutas_clientes.rut_id = r.id_rut
          AND tbl_rutas_clientes.cli_id::text = ${clienteId}
          AND r.org_id = ${scope.organizacionId}::uuid
      `);
      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_clientes
        WHERE id_cli::text = ${clienteId}
          AND org_id = ${scope.organizacionId}::uuid
      `);
      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_personas
        WHERE id_per::text = ${cliente.persona_id}
      `);
    });

    this.invalidarCacheLecturas();
    return { ok: true };
  }

  async actualizarUbicacionCliente(
    clienteId: string,
    dto: ActualizarUbicacionClienteDto,
    usuario: AuthenticatedUser,
  ) {
    return this.actualizarUbicacionClienteTbl(clienteId, dto, usuario);
  }

  async actualizarUbicacionClienteTbl(
    clienteId: string,
    dto: ActualizarUbicacionClienteDto,
    usuario: AuthenticatedUser,
  ) {
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);
    const rows = await this.prisma.$queryRaw<
      ClienteUbicacionTblRow[]
    >(Prisma.sql`
      SELECT
        p.id_per::text AS persona_id,
        p.per_direccion AS direccion
      FROM public.tbl_clientes c
      JOIN public.tbl_personas p ON p.id_per = c.cli_persona
      WHERE c.id_cli::text = ${clienteId}
        AND c.org_id = ${scope.organizacionId}::uuid
        AND ${
          this.tenantScope.esAdministrador(usuario)
            ? Prisma.sql`TRUE`
            : Prisma.sql`(
              EXISTS (
                SELECT 1
                FROM public.tbl_creditos cr
                JOIN public.tbl_usuarios tu ON tu.id_usu = cr.usu_id
                WHERE cr.cli_id = c.id_cli
                  AND UPPER(cr.cre_estado::text) <> 'ANULADO'
                  AND tu.usu_usuario = ${usuario.usuario}
              )
              OR EXISTS (
                SELECT 1
                FROM public.tbl_rutas_clientes rc
                JOIN public.tbl_rutas r ON r.id_rut = rc.rut_id
                JOIN public.tbl_usuarios tu ON tu.id_usu = r.usu_id
                WHERE rc.cli_id = c.id_cli
                  AND r.org_id = c.org_id
                  AND rc.rcl_activo
                  AND tu.usu_usuario = ${usuario.usuario}
              )
            )`
        }
      LIMIT 1
    `);
    const cliente = rows[0];
    if (!cliente) {
      throw DomainError.notFound(
        'Cliente no encontrado',
        'CLIENTE_NO_ENCONTRADO',
      );
    }

    const direccion =
      this.normalizarTextoOpcional(dto.direccion) ?? cliente.direccion;
    if (!direccion) {
      throw DomainError.validation(
        'La dirección es obligatoria para guardar la ubicación',
        'DIRECCION_COORDENADAS_REQUERIDA',
      );
    }

    await this.prisma.$executeRaw(Prisma.sql`
      UPDATE public.tbl_personas
      SET
        per_direccion = ${direccion},
        per_latitud = ${dto.latitud},
        per_longitud = ${dto.longitud}
      WHERE id_per::text = ${cliente.persona_id}
    `);

    return {
      clienteId,
      direccion,
      latitud: dto.latitud,
      longitud: dto.longitud,
    };
  }

  private formatearClienteTbl(cliente: ClienteTblRow) {
    const cedula = this.esDocumentoClienteGeneradoTbl(cliente.cedula)
      ? null
      : cliente.cedula;

    return {
      id: cliente.id,
      nombreCompleto: cliente.nombre_completo,
      nombreComercial: cliente.nombre_comercial,
      notas: cliente.notas,
      cedula,
      direccion: cliente.direccion,
      correo: cliente.correo ?? null,
      telefono: cliente.telefono,
      whatsapp: cliente.telefono,
      estado: {
        codigo: cliente.activo ? 'ACTIVO' : 'INACTIVO',
        nombre: cliente.activo ? 'Activo' : 'Inactivo',
      },
      documentos: [
        ...(cedula
          ? [
              {
                id: `doc-${cliente.id}`,
                tipo: { id: 1, codigo: 'CC', nombre: 'Documento' },
                numeroDocumento: cedula,
                expedidoEn: null,
              },
            ]
          : []),
      ],
      direcciones: cliente.direccion
        ? [
            {
              id: `dir-${cliente.id}`,
              tipo: { id: 1, codigo: 'CASA', nombre: 'Direccion' },
              direccion: cliente.direccion,
              barrio: null,
              municipio: '',
              departamento: '',
              pais: 'Colombia',
              referencia: null,
              latitud:
                cliente.latitud === null
                  ? null
                  : this.decimalANumero(cliente.latitud),
              longitud:
                cliente.longitud === null
                  ? null
                  : this.decimalANumero(cliente.longitud),
              esPrincipal: true,
            },
          ]
        : [],
      creadoEn: cliente.creado_en.toISOString(),
      actualizadoEn: cliente.actualizado_en.toISOString(),
    };
  }

  private generarDocumentoClienteTbl(): string {
    return `AUTO-CLIENTE-${randomUUID()}`;
  }

  private esDocumentoClienteGeneradoTbl(value: string | null): boolean {
    return value?.startsWith('AUTO-CLIENTE-') ?? false;
  }

  private dividirNombrePersonaTbl(nombreCompleto: string) {
    const partes = nombreCompleto.split(/\s+/).filter(Boolean);

    if (partes.length <= 1) {
      return { nombres: nombreCompleto, apellidos: '-' };
    }

    return {
      nombres: partes.slice(0, -1).join(' '),
      apellidos: partes[partes.length - 1],
    };
  }

  private asegurarPermiso(
    usuario: AuthenticatedUser,
    permiso: PermisoEmpleadoCodigo,
  ) {
    if (
      this.tenantScope.esAdministrador(usuario) ||
      usuario.permisos?.includes(permiso)
    ) {
      return;
    }

    const nombrePermiso =
      permisosEmpleadoPorCodigo.get(permiso)?.nombre ?? 'esta accion';
    throw new ForbiddenException(
      `No tienes permiso para ${nombrePermiso.toLowerCase()}`,
    );
  }

  private asegurarAdministrador(usuario: AuthenticatedUser) {
    if (!this.tenantScope.esAdministrador(usuario)) {
      throw new ForbiddenException(
        'Solo administradores pueden realizar esta accion',
      );
    }
  }

  private invalidarCacheLecturas() {
    this.cache.deleteByPrefix('cobros:');
  }

  private decimalANumero(value: Prisma.Decimal | null): number {
    if (value === null) {
      return 0;
    }
    return Number(value.toString());
  }

  private normalizarTextoOpcional(value?: string | null): string | null {
    if (value === undefined || value === null) {
      return null;
    }
    const normalized = value.trim();
    return normalized.length > 0 ? normalized : null;
  }

  private normalizarCorreo(value?: string | null): string | null {
    return this.normalizarTextoOpcional(value)?.toLowerCase() ?? null;
  }

  private requerirTexto(value: string, message: string): string {
    const normalized = value.trim();
    if (!normalized) {
      throw DomainError.validation(message);
    }
    return normalized;
  }
}
