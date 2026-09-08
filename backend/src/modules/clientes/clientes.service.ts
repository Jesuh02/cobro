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

type ClienteConRelaciones = Prisma.ClienteGetPayload<{
  include: {
    estadoCliente: true;
    contactos: { include: { tipoContacto: true } };
    documentos: { include: { tipoDocumento: true } };
    direcciones: { include: { tipoDireccion: true } };
  };
}>;

@Injectable()
export class ClientesService {
  private esquemaTblDisponible?: boolean;
  private readonly tablaExisteCache = new Map<string, boolean>();

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
    if (await this.usarEsquemaTbl()) {
      return this.listarClientesTbl(query, usuario);
    }

    const search = this.normalizarTextoOpcional(query.search);
    const where: Prisma.ClienteWhereInput =
      this.tenantScope.puedeVerDatosOrganizacion(usuario)
        ? {}
        : { creadoPorUsuarioId: usuario.usuarioId };

    if (search) {
      where.OR = [
        { nombreCompleto: { contains: search, mode: 'insensitive' } },
        { nombreComercial: { contains: search, mode: 'insensitive' } },
        {
          contactos: {
            some: { valor: { contains: search, mode: 'insensitive' } },
          },
        },
        {
          documentos: { some: { numeroDocumento: { contains: search } } },
        },
        {
          direcciones: {
            some: { direccion: { contains: search, mode: 'insensitive' } },
          },
        },
      ];
    }

    const clientes = await this.prisma.cliente.findMany({
      where,
      include: {
        estadoCliente: true,
        contactos: { include: { tipoContacto: true } },
        documentos: { include: { tipoDocumento: true } },
        direcciones: { include: { tipoDireccion: true } },
      },
      orderBy: { nombreCompleto: 'asc' },
    });

    return clientes.map((cliente) => this.formatearCliente(cliente));
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
    const nombreCompleto = this.requerirTexto(
      dto.nombreCompleto,
      'El nombre del cliente es obligatorio',
    );
    const cedula = this.normalizarTextoOpcional(dto.cedula);
    const nombreComercial = this.normalizarTextoOpcional(dto.nombreComercial);
    const direccion = this.normalizarTextoOpcional(dto.direccion);
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
    const notas = this.normalizarTextoOpcional(dto.notas);
    const correo = this.normalizarCorreo(dto.correo);
    const telefono = this.normalizarTextoOpcional(dto.telefono);
    const whatsapp = this.normalizarTextoOpcional(dto.whatsapp);

    if (await this.usarEsquemaTbl()) {
      return this.crearClienteTbl(
        {
          nombreCompleto,
          cedula,
          nombreComercial,
          direccion,
          notas,
          correo,
          telefono,
          whatsapp,
          latitud,
          longitud,
        },
        usuario,
      );
    }

    const cliente = await this.prisma.$transaction(async (tx) => {
      const estadoActivo = await tx.estadoCliente.findUnique({
        where: { codigo: 'ACTIVO' },
      });

      if (!estadoActivo) {
        throw DomainError.notFound(
          'No existe el estado de cliente ACTIVO en los catalogos',
          'ESTADO_CLIENTE_ACTIVO_NO_EXISTE',
        );
      }

      const created = await tx.cliente.create({
        data: {
          estadoClienteId: estadoActivo.estadoClienteId,
          creadoPorUsuarioId: usuario.usuarioId,
          nombreCompleto,
          nombreComercial,
          notas,
        },
      });

      await this.crearDocumentoCliente(tx, created.clienteId, 'CC', cedula);
      await this.crearContactoCliente(tx, created.clienteId, 'CORREO', correo);
      await this.crearContactoCliente(
        tx,
        created.clienteId,
        'TELEFONO',
        telefono,
      );
      await this.crearContactoCliente(
        tx,
        created.clienteId,
        'WHATSAPP',
        whatsapp,
      );
      await this.crearDireccionCliente(
        tx,
        created.clienteId,
        direccion,
        latitud,
        longitud,
      );

      const completo = await tx.cliente.findUnique({
        where: { clienteId: created.clienteId },
        include: {
          estadoCliente: true,
          contactos: { include: { tipoContacto: true } },
          documentos: { include: { tipoDocumento: true } },
          direcciones: { include: { tipoDireccion: true } },
        },
      });

      if (!completo) {
        throw DomainError.notFound(
          'Cliente no encontrado despues de crear',
          'CLIENTE_NO_ENCONTRADO',
        );
      }

      return completo;
    });

    return this.formatearCliente(cliente);
  }

  async crearClienteTbl(
    input: {
      nombreCompleto: string;
      cedula: string | null;
      nombreComercial: string | null;
      direccion: string | null;
      notas: string | null;
      correo: string | null;
      telefono: string | null;
      whatsapp: string | null;
      latitud?: number;
      longitud?: number;
    },
    usuario: AuthenticatedUser,
  ) {
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
                FROM public.tbl_personas
                WHERE per_documento = ${input.cedula}
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

        await this.registrarAuditoria(tx, {
          usuarioId: usuario.usuarioId,
          tabla: 'tbl_clientes',
          registroId: cliente.id,
          accion: 'CREAR',
          descripcion: `Se creo cliente ${input.nombreCompleto}`,
          valoresNuevos: {
            nombreCompleto: input.nombreCompleto,
            cedula: input.cedula,
            nombreComercial: input.nombreComercial,
            direccion: input.direccion,
            notas: input.notas,
            correo: input.correo,
            telefono,
            latitud: input.latitud ?? null,
            longitud: input.longitud ?? null,
            organizacionId: scope.organizacionId,
          },
        });

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
    this.asegurarAdministrador(usuario);

    if (await this.usarEsquemaTbl()) {
      return this.actualizarClienteTbl(clienteId, dto, usuario);
    }

    const nombreCompleto = this.requerirTexto(
      dto.nombreCompleto,
      'El nombre del cliente es obligatorio',
    );
    const cedula = this.normalizarTextoOpcional(dto.cedula);
    const nombreComercial = this.normalizarTextoOpcional(dto.nombreComercial);
    const direccion = this.normalizarTextoOpcional(dto.direccion);
    const notas = this.normalizarTextoOpcional(dto.notas);
    const correo = this.normalizarCorreo(dto.correo);
    const telefono = this.normalizarTextoOpcional(dto.telefono);
    const whatsapp = this.normalizarTextoOpcional(dto.whatsapp);
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

    await this.prisma.$transaction(
      async (tx) => {
        const actual = await tx.cliente.findUnique({
          where: { clienteId },
          include: {
            estadoCliente: true,
            contactos: { include: { tipoContacto: true } },
            documentos: { include: { tipoDocumento: true } },
            direcciones: { include: { tipoDireccion: true } },
          },
        });

        if (!actual) {
          throw DomainError.notFound(
            'Cliente no encontrado',
            'CLIENTE_NO_ENCONTRADO',
          );
        }

        await tx.cliente.update({
          where: { clienteId },
          data: {
            nombreCompleto,
            nombreComercial,
            notas,
            actualizadoEn: new Date(),
          },
        });

        await this.reemplazarDocumentoCliente(tx, clienteId, 'CC', cedula);
        await this.reemplazarContactoCliente(tx, clienteId, 'CORREO', correo);
        await this.reemplazarContactoCliente(
          tx,
          clienteId,
          'TELEFONO',
          telefono,
        );
        await this.reemplazarContactoCliente(
          tx,
          clienteId,
          'WHATSAPP',
          whatsapp,
        );
        const direccionPrincipal =
          actual.direcciones.find((item) => item.esPrincipal) ??
          actual.direcciones[0];
        const latitudFinal =
          latitud ??
          (direccionPrincipal?.latitud === null ||
          direccionPrincipal?.latitud === undefined
            ? null
            : this.decimalANumero(direccionPrincipal.latitud));
        const longitudFinal =
          longitud ??
          (direccionPrincipal?.longitud === null ||
          direccionPrincipal?.longitud === undefined
            ? null
            : this.decimalANumero(direccionPrincipal.longitud));
        await this.reemplazarDireccionCliente(
          tx,
          clienteId,
          direccion,
          latitudFinal,
          longitudFinal,
        );

        await this.registrarAuditoria(tx, {
          usuarioId: usuario.usuarioId,
          tabla: 'cliente',
          registroId: clienteId,
          accion: 'MODIFICAR',
          descripcion: `Se modifico cliente ${actual.nombreCompleto}`,
          valoresAnteriores: this.formatearCliente(actual),
          valoresNuevos: {
            nombreCompleto,
            cedula,
            nombreComercial,
            direccion,
            notas,
            correo,
            telefono,
            whatsapp,
            latitud: latitudFinal,
            longitud: longitudFinal,
          },
        });
      },
      { maxWait: 10_000, timeout: 10_000 },
    );

    const cliente = await this.prisma.cliente.findUnique({
      where: { clienteId },
      include: {
        estadoCliente: true,
        contactos: { include: { tipoContacto: true } },
        documentos: { include: { tipoDocumento: true } },
        direcciones: { include: { tipoDireccion: true } },
      },
    });

    if (!cliente) {
      throw DomainError.notFound(
        'Cliente no encontrado despues de modificar',
        'CLIENTE_NO_ENCONTRADO',
      );
    }

    this.invalidarCacheLecturas();
    return this.formatearCliente(cliente);
  }

  async actualizarClienteTbl(
    clienteId: string,
    dto: ActualizarClienteDto,
    usuario: AuthenticatedUser,
  ) {
    this.asegurarAdministrador(usuario);

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
                FROM public.tbl_personas
                WHERE per_documento = ${cedulaFinal}
                  AND id_per::text <> ${actual.persona_id}
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

        await this.registrarAuditoria(tx, {
          usuarioId: usuario.usuarioId,
          tabla: 'tbl_clientes',
          registroId: clienteId,
          accion: 'MODIFICAR',
          descripcion: `Se modifico cliente ${actual.nombre_completo}`,
          valoresAnteriores: this.formatearClienteTbl(actual),
          valoresNuevos: {
            nombreCompleto,
            cedula: cedulaFinal,
            nombreComercial,
            direccion,
            telefono,
            latitud: latitudFinal,
            longitud: longitudFinal,
          },
        });
      },
      { maxWait: 10_000, timeout: 10_000 },
    );

    const actualizados = await this.prisma.$queryRaw<ClienteTblRow[]>(Prisma.sql`
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
    this.asegurarAdministrador(usuario);

    if (await this.usarEsquemaTbl()) {
      return this.eliminarClienteTbl(clienteId, usuario);
    }

    await this.prisma.$transaction(async (tx) => {
      const cliente = await tx.cliente.findUnique({
        where: { clienteId },
        include: {
          estadoCliente: true,
          contactos: { include: { tipoContacto: true } },
          documentos: { include: { tipoDocumento: true } },
          direcciones: { include: { tipoDireccion: true } },
        },
      });

      if (!cliente) {
        throw DomainError.notFound(
          'Cliente no encontrado',
          'CLIENTE_NO_ENCONTRADO',
        );
      }

      const [creditos, pagos] = await Promise.all([
        tx.credito.count({ where: { clienteId } }),
        tx.pago.count({ where: { clienteId } }),
      ]);

      if (creditos > 0 || pagos > 0) {
        throw DomainError.conflict(
          'No se puede eliminar un cliente con creditos o pagos registrados',
          'CLIENTE_CON_MOVIMIENTOS_NO_ELIMINABLE',
        );
      }

      await this.registrarAuditoria(tx, {
        usuarioId: usuario.usuarioId,
        tabla: 'cliente',
        registroId: clienteId,
        accion: 'ELIMINAR',
        descripcion: `Se elimino cliente ${cliente.nombreCompleto}`,
        valoresAnteriores: this.formatearCliente(cliente),
      });

      await tx.rutaCliente.deleteMany({ where: { clienteId } });
      await tx.cliente.delete({ where: { clienteId } });
    });

    this.invalidarCacheLecturas();
    return { ok: true };
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

      await this.registrarAuditoria(tx, {
        usuarioId: usuario.usuarioId,
        tabla: 'tbl_clientes',
        registroId: clienteId,
        accion: 'ELIMINAR',
        descripcion: `Se elimino cliente ${cliente.nombre_completo}`,
        valoresAnteriores: this.formatearClienteTbl(cliente),
      });

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
    if (
      !Number.isFinite(dto.latitud) ||
      !Number.isFinite(dto.longitud) ||
      dto.latitud < -90 ||
      dto.latitud > 90 ||
      dto.longitud < -180 ||
      dto.longitud > 180
    ) {
      throw DomainError.validation(
        'Las coordenadas no son válidas',
        'COORDENADAS_INVALIDAS',
      );
    }

    if (await this.usarEsquemaTbl()) {
      return this.actualizarUbicacionClienteTbl(clienteId, dto, usuario);
    }

    const direccionSolicitada = this.normalizarTextoOpcional(dto.direccion);
    return this.prisma.$transaction(async (tx) => {
      const cliente = await tx.cliente.findUnique({
        where: { clienteId },
        include: {
          direcciones: {
            orderBy: [{ esPrincipal: 'desc' }, { direccion: 'asc' }],
          },
        },
      });
      if (!cliente) {
        throw DomainError.notFound(
          'Cliente no encontrado',
          'CLIENTE_NO_ENCONTRADO',
        );
      }

      if (!this.tenantScope.esAdministrador(usuario)) {
        const creditoVisible = await tx.credito.findFirst({
          where: {
            clienteId,
            OR: [
              { creadoPorUsuarioId: usuario.usuarioId },
              { ruta: { responsableUsuarioId: usuario.usuarioId } },
            ],
          },
          select: { creditoId: true },
        });
        if (!creditoVisible) {
          throw new ForbiddenException('No tienes acceso a este cliente');
        }
      }

      const direccionActual = cliente.direcciones[0];
      const direccion = direccionSolicitada ?? direccionActual?.direccion;
      if (!direccion) {
        throw DomainError.validation(
          'La dirección es obligatoria para guardar la ubicación',
          'DIRECCION_COORDENADAS_REQUERIDA',
        );
      }

      if (direccionActual) {
        await tx.clienteDireccion.update({
          where: {
            clienteDireccionId: direccionActual.clienteDireccionId,
          },
          data: {
            direccion,
            latitud: dto.latitud,
            longitud: dto.longitud,
            esPrincipal: true,
          },
        });
      } else {
        const tipoDireccion = await tx.tipoDireccion.findUnique({
          where: { codigo: 'CASA' },
        });
        if (!tipoDireccion) {
          throw DomainError.notFound(
            'No existe el tipo de dirección CASA',
            'TIPO_DIRECCION_NO_EXISTE',
          );
        }
        await tx.clienteDireccion.create({
          data: {
            clienteId,
            tipoDireccionId: tipoDireccion.tipoDireccionId,
            direccion,
            municipio: 'No especificado',
            departamento: 'No especificado',
            latitud: dto.latitud,
            longitud: dto.longitud,
            esPrincipal: true,
          },
        });
      }

      return {
        clienteId,
        direccion,
        latitud: dto.latitud,
        longitud: dto.longitud,
      };
    });
  }

  async actualizarUbicacionClienteTbl(
    clienteId: string,
    dto: ActualizarUbicacionClienteDto,
    usuario: AuthenticatedUser,
  ) {
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);
    const rows = await this.prisma.$queryRaw<ClienteUbicacionTblRow[]>(Prisma.sql`
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

  private async usarEsquemaTbl(): Promise<boolean> {
    if (this.esquemaTblDisponible !== undefined) {
      return this.esquemaTblDisponible;
    }

    try {
      const rows = await this.prisma.$queryRaw<Array<{ disponible: boolean }>>`
        SELECT COUNT(*) = 3 AS disponible
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name IN (
            'tbl_usuarios',
            'tbl_organizaciones',
            'tbl_clientes'
          )
      `;
      this.esquemaTblDisponible = rows[0]?.disponible ?? false;
    } catch {
      this.esquemaTblDisponible = false;
    }

    return this.esquemaTblDisponible;
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

  private formatearCliente(cliente: ClienteConRelaciones) {
    const contactoPrincipal = (codigo: string) =>
      cliente.contactos.find(
        (contacto) =>
          contacto.tipoContacto.codigo === codigo && contacto.esPrincipal,
      ) ??
      cliente.contactos.find(
        (contacto) => contacto.tipoContacto.codigo === codigo,
      );
    const documentoPrincipal = (codigo: string) =>
      cliente.documentos.find(
        (documento) => documento.tipoDocumento.codigo === codigo,
      );
    const direccionPrincipal =
      cliente.direcciones.find((direccion) => direccion.esPrincipal) ??
      cliente.direcciones[0];

    return {
      id: cliente.clienteId,
      nombreCompleto: cliente.nombreCompleto,
      nombreComercial: cliente.nombreComercial,
      notas: cliente.notas,
      cedula: documentoPrincipal('CC')?.numeroDocumento ?? null,
      direccion: direccionPrincipal?.direccion ?? null,
      correo: contactoPrincipal('CORREO')?.valor ?? null,
      telefono: contactoPrincipal('TELEFONO')?.valor ?? null,
      whatsapp: contactoPrincipal('WHATSAPP')?.valor ?? null,
      estado: {
        codigo: cliente.estadoCliente.codigo,
        nombre: cliente.estadoCliente.nombre,
      },
      documentos: cliente.documentos.map((documento) => ({
        id: documento.clienteDocumentoId,
        tipo: {
          id: documento.tipoDocumentoId,
          codigo: documento.tipoDocumento.codigo,
          nombre: documento.tipoDocumento.nombre,
        },
        numeroDocumento: documento.numeroDocumento,
        expedidoEn: documento.expedidoEn,
      })),
      direcciones: cliente.direcciones.map((direccion) => ({
        id: direccion.clienteDireccionId,
        tipo: {
          id: direccion.tipoDireccionId,
          codigo: direccion.tipoDireccion.codigo,
          nombre: direccion.tipoDireccion.nombre,
        },
        direccion: direccion.direccion,
        barrio: direccion.barrio,
        municipio: direccion.municipio,
        departamento: direccion.departamento,
        pais: direccion.pais,
        referencia: direccion.referencia,
        latitud:
          direccion.latitud === null
            ? null
            : this.decimalANumero(direccion.latitud),
        longitud:
          direccion.longitud === null
            ? null
            : this.decimalANumero(direccion.longitud),
        esPrincipal: direccion.esPrincipal,
      })),
      creadoEn: cliente.creadoEn.toISOString(),
      actualizadoEn: cliente.actualizadoEn.toISOString(),
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

  private asegurarAdministrador(usuario: AuthenticatedUser) {
    if (!this.tenantScope.esAdministrador(usuario)) {
      throw new ForbiddenException(
        'Solo administradores pueden realizar esta accion',
      );
    }
  }

  private async registrarAuditoria(
    tx: PrismaExecutor,
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
    if (!(await this.tablaExiste(tx, 'public.auditoria'))) {
      return;
    }

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

  private async tablaExiste(client: PrismaExecutor, nombre: string) {
    const enCache = this.tablaExisteCache.get(nombre);
    if (enCache !== undefined) {
      return enCache;
    }

    const resultado = await client.$queryRaw<Array<{ nombre: string | null }>>(
      Prisma.sql`SELECT to_regclass(${nombre})::text AS nombre`,
    );

    const existe = resultado[0]?.nombre !== null;
    this.tablaExisteCache.set(nombre, existe);
    return existe;
  }

  private invalidarCacheLecturas() {
    this.cache.deleteByPrefix('cobros:');
  }

  private async crearContactoCliente(
    tx: Prisma.TransactionClient,
    clienteId: string,
    codigoTipo: string,
    valor: string | null,
  ) {
    if (!valor) {
      return;
    }

    const tipo = await tx.tipoContacto.findUnique({
      where: { codigo: codigoTipo },
    });

    if (!tipo) {
      throw DomainError.notFound(
        `No existe el tipo de contacto ${codigoTipo}`,
        'TIPO_CONTACTO_NO_EXISTE',
      );
    }

    await tx.clienteContacto.create({
      data: {
        clienteId,
        tipoContactoId: tipo.tipoContactoId,
        valor,
        esPrincipal: true,
      },
    });
  }

  private async reemplazarContactoCliente(
    tx: Prisma.TransactionClient,
    clienteId: string,
    codigoTipo: string,
    valor: string | null,
  ) {
    const tipo = await tx.tipoContacto.findUnique({
      where: { codigo: codigoTipo },
    });

    if (!tipo) {
      throw DomainError.notFound(
        `No existe el tipo de contacto ${codigoTipo}`,
        'TIPO_CONTACTO_NO_EXISTE',
      );
    }

    await tx.clienteContacto.deleteMany({
      where: { clienteId, tipoContactoId: tipo.tipoContactoId },
    });

    if (!valor) {
      return;
    }

    await tx.clienteContacto.create({
      data: {
        clienteId,
        tipoContactoId: tipo.tipoContactoId,
        valor,
        esPrincipal: true,
      },
    });
  }

  private async crearDocumentoCliente(
    tx: Prisma.TransactionClient,
    clienteId: string,
    codigoTipo: string,
    numeroDocumento: string | null,
  ) {
    if (!numeroDocumento) {
      return;
    }

    const tipo = await tx.tipoDocumento.findUnique({
      where: { codigo: codigoTipo },
    });

    if (!tipo) {
      throw DomainError.notFound(
        `No existe el tipo de documento ${codigoTipo}`,
        'TIPO_DOCUMENTO_NO_EXISTE',
      );
    }

    const existente = await tx.clienteDocumento.findFirst({
      where: {
        tipoDocumentoId: tipo.tipoDocumentoId,
        numeroDocumento,
      },
      select: { clienteId: true },
    });

    if (existente) {
      throw DomainError.conflict(
        'Ya existe un cliente con esta cedula',
        'CEDULA_YA_REGISTRADA',
      );
    }

    await tx.clienteDocumento.create({
      data: {
        clienteId,
        tipoDocumentoId: tipo.tipoDocumentoId,
        numeroDocumento,
      },
    });
  }

  private async reemplazarDocumentoCliente(
    tx: Prisma.TransactionClient,
    clienteId: string,
    codigoTipo: string,
    numeroDocumento: string | null,
  ) {
    const tipo = await tx.tipoDocumento.findUnique({
      where: { codigo: codigoTipo },
    });

    if (!tipo) {
      throw DomainError.notFound(
        `No existe el tipo de documento ${codigoTipo}`,
        'TIPO_DOCUMENTO_NO_EXISTE',
      );
    }

    if (numeroDocumento) {
      const existente = await tx.clienteDocumento.findFirst({
        where: {
          tipoDocumentoId: tipo.tipoDocumentoId,
          numeroDocumento,
          NOT: { clienteId },
        },
        select: { clienteId: true },
      });

      if (existente) {
        throw DomainError.conflict(
          'Ya existe un cliente con esta cedula',
          'CEDULA_YA_REGISTRADA',
        );
      }
    }

    await tx.clienteDocumento.deleteMany({
      where: { clienteId, tipoDocumentoId: tipo.tipoDocumentoId },
    });

    if (!numeroDocumento) {
      return;
    }

    await tx.clienteDocumento.create({
      data: {
        clienteId,
        tipoDocumentoId: tipo.tipoDocumentoId,
        numeroDocumento,
      },
    });
  }

  private async crearDireccionCliente(
    tx: Prisma.TransactionClient,
    clienteId: string,
    direccion: string | null,
    latitud?: number,
    longitud?: number,
  ) {
    if (!direccion) {
      return;
    }

    const tipo = await tx.tipoDireccion.findUnique({
      where: { codigo: 'CASA' },
    });

    if (!tipo) {
      throw DomainError.notFound(
        'No existe el tipo de direccion CASA',
        'TIPO_DIRECCION_NO_EXISTE',
      );
    }

    await tx.clienteDireccion.create({
      data: {
        clienteId,
        tipoDireccionId: tipo.tipoDireccionId,
        direccion,
        municipio: 'No especificado',
        departamento: 'No especificado',
        latitud,
        longitud,
        esPrincipal: true,
      },
    });
  }

  private async reemplazarDireccionCliente(
    tx: Prisma.TransactionClient,
    clienteId: string,
    direccion: string | null,
    latitud?: number | null,
    longitud?: number | null,
  ) {
    const tipo = await tx.tipoDireccion.findUnique({
      where: { codigo: 'CASA' },
    });

    if (!tipo) {
      throw DomainError.notFound(
        'No existe el tipo de direccion CASA',
        'TIPO_DIRECCION_NO_EXISTE',
      );
    }

    await tx.clienteDireccion.deleteMany({
      where: { clienteId, tipoDireccionId: tipo.tipoDireccionId },
    });

    if (!direccion) {
      return;
    }

    await tx.clienteDireccion.create({
      data: {
        clienteId,
        tipoDireccionId: tipo.tipoDireccionId,
        direccion,
        municipio: 'No especificado',
        departamento: 'No especificado',
        latitud: latitud ?? undefined,
        longitud: longitud ?? undefined,
        esPrincipal: true,
      },
    });
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
