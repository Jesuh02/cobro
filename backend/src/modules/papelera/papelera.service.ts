import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../common/prisma/prisma.service';
import { TenantScopeService } from '../../common/tenancy/tenant-scope.service';
import { InMemoryCacheService } from '../../common/cache/in-memory-cache.service';
import { DomainError } from '../../common/domain/domain-error';
import { AuthenticatedUser } from '../auth/auth.types';
import { ListarPapeleraQueryDto } from './dto';

export interface PapeleraItemRow {
  id_pap: string;
  pap_fecha: Date;
  pap_motivo: string | null;
  pap_datos: unknown;
  // Cliente
  cli_id: string;
  cliente_nombre: string;
  cliente_documento: string;
  cliente_telefono: string | null;
  cliente_direccion: string | null;
  cliente_negocio: string | null;
  // Crédito vinculado
  cre_id: string | null;
  cre_total: Prisma.Decimal | null;
  cre_total_pagar: Prisma.Decimal | null;
  cre_saldo: Prisma.Decimal | null;
  moneda_codigo: string | null;
  // Ruta
  rut_id: string | null;
  ruta_nombre: string | null;
  // Usuario que eliminó
  usu_id: string;
  usuario_login: string;
  usuario_nombre: string;
}

@Injectable()
export class PapeleraService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenantScope: TenantScopeService,
    private readonly cache: InMemoryCacheService,
  ) {}

  private asegurarAdministrador(usuario: AuthenticatedUser) {
    if (!this.tenantScope.esAdministrador(usuario)) {
      throw new ForbiddenException(
        'Solo los administradores pueden gestionar la papelera',
      );
    }
  }

  private invalidarCaches() {
    this.cache.deleteByPrefix('cobros:');
  }

  async listarPapelera(
    query: ListarPapeleraQueryDto,
    usuario: AuthenticatedUser,
  ) {
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);
    const esAdmin = this.tenantScope.esAdministrador(usuario);

    const conditions: Prisma.Sql[] = [
      Prisma.sql`p.org_id = ${scope.organizacionId}::uuid`,
    ];

    // Si no es administrador, solo puede ver lo que él mismo eliminó
    if (!esAdmin) {
      conditions.push(Prisma.sql`p.usu_id = ${scope.usuarioId}::uuid`);
    }

    if (query.search && query.search.trim()) {
      const pattern = `%${query.search.trim().toLowerCase()}%`;
      conditions.push(Prisma.sql`(
        LOWER(CONCAT_WS(' ', per.per_primer_nombre, per.per_apellido)) LIKE ${pattern}
        OR LOWER(per.per_documento) LIKE ${pattern}
        OR LOWER(COALESCE(c.cli_referencia, '')) LIKE ${pattern}
        OR LOWER(COALESCE(r.rut_nombre, '')) LIKE ${pattern}
        OR LOWER(u.usu_usuario) LIKE ${pattern}
        OR LOWER(CONCAT_WS(' ', u_per.per_primer_nombre, u_per.per_apellido)) LIKE ${pattern}
      )`);
    }

    const where = Prisma.sql`WHERE ${Prisma.join(conditions, ' AND ')}`;

    const rows = await this.prisma.$queryRaw<PapeleraItemRow[]>(Prisma.sql`
      SELECT
        p.id_pap::text AS id_pap,
        p.pap_fecha,
        p.pap_motivo,
        p.pap_datos,
        c.id_cli::text AS cli_id,
        TRIM(CONCAT_WS(' ', per.per_primer_nombre, per.per_apellido)) AS cliente_nombre,
        per.per_documento AS cliente_documento,
        per.per_num_celular AS cliente_telefono,
        per.per_direccion AS cliente_direccion,
        c.cli_referencia AS cliente_negocio,
        cr.id_cre::text AS cre_id,
        cr.cre_total,
        cr.cre_total_pagar,
        GREATEST(
          cr.cre_total_pagar - COALESCE(abonos.total_pagado, 0),
          0
        ) AS cre_saldo,
        COALESCE(m.mon_codigo, 'COP') AS moneda_codigo,
        r.id_rut::text AS rut_id,
        r.rut_nombre AS ruta_nombre,
        u.id_usu::text AS usu_id,
        u.usu_usuario AS usuario_login,
        TRIM(CONCAT_WS(' ', u_per.per_primer_nombre, u_per.per_apellido)) AS usuario_nombre
      FROM public.tbl_papelera p
      JOIN public.tbl_clientes c ON c.id_cli = p.cli_id
      JOIN public.tbl_personas per ON per.id_per = c.cli_persona
      JOIN public.tbl_usuarios u ON u.id_usu = p.usu_id
      JOIN public.tbl_personas u_per ON u_per.id_per = u.persona_id
      LEFT JOIN public.tbl_creditos cr ON cr.id_cre = p.cre_id
      LEFT JOIN public.tbl_monedas m ON m.id_mon = cr.mon_id
      LEFT JOIN public.tbl_rutas r ON r.id_rut = p.rut_id
      LEFT JOIN LATERAL (
        SELECT COALESCE(SUM(cp.cpa_total), 0) AS total_pagado
        FROM public.tbl_cuotas cu
        JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
        WHERE cu.cre_id = cr.id_cre
      ) abonos ON TRUE
      ${where}
      ORDER BY p.pap_fecha DESC
    `);

    return rows.map((r) => ({
      id: r.id_pap,
      fecha: r.pap_fecha.toISOString(),
      motivo: r.pap_motivo,
      cliente: {
        id: r.cli_id,
        nombreCompleto: r.cliente_nombre,
        documento: r.cliente_documento,
        telefono: r.cliente_telefono,
        direccion: r.cliente_direccion,
        negocio: r.cliente_negocio,
      },
      credito: r.cre_id
        ? {
            id: r.cre_id,
            total: Number(r.cre_total ?? 0),
            totalPagar: Number(r.cre_total_pagar ?? 0),
            saldoPendiente: Number(r.cre_saldo ?? 0),
            monedaCodigo: r.moneda_codigo ?? 'COP',
          }
        : null,
      ruta: r.rut_id
        ? {
            id: r.rut_id,
            nombre: r.ruta_nombre ?? 'Ruta asignada',
          }
        : null,
      eliminadoPor: {
        id: r.usu_id,
        usuario: r.usuario_login,
        nombreCompleto: r.usuario_nombre,
      },
    }));
  }

  async restaurarCliente(papeleraId: string, usuario: AuthenticatedUser) {
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);
    const esAdmin = this.tenantScope.esAdministrador(usuario);

    return this.prisma.$transaction(async (tx) => {
      const rows = await tx.$queryRaw<
        Array<{
          id_pap: string;
          cli_id: string;
          cre_id: string | null;
          rut_id: string | null;
        }>
      >(Prisma.sql`
        SELECT
          id_pap::text,
          cli_id::text,
          cre_id::text,
          rut_id::text
        FROM public.tbl_papelera
        WHERE id_pap = ${papeleraId}::uuid
          AND org_id = ${scope.organizacionId}::uuid
          ${esAdmin ? Prisma.sql`` : Prisma.sql`AND usu_id = ${scope.usuarioId}::uuid`}
        FOR UPDATE
      `);

      const papelera = rows[0];
      if (!papelera) {
        throw DomainError.notFound(
          'Registro de papelera no encontrado o no autorizado',
          'PAPELERA_NO_ENCONTRADO',
        );
      }

      // 1. Reactivar cliente
      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_clientes
        SET cli_activo = true
        WHERE id_cli = ${papelera.cli_id}::uuid
          AND org_id = ${scope.organizacionId}::uuid
      `);

      // 2. Reactivar crédito activo si existía
      if (papelera.cre_id) {
        await tx.$executeRaw(Prisma.sql`
          UPDATE public.tbl_creditos
          SET cre_estado = 'ACTIVO'::public.credito_estado_enum
          WHERE id_cre = ${papelera.cre_id}::uuid
        `);
      }

      // 3. Restaurar ruta del cliente si existía
      if (papelera.rut_id) {
        await tx.$executeRaw(Prisma.sql`
          INSERT INTO public.tbl_rutas_clientes (rut_id, cli_id, rcl_activo, rcl_creacion)
          VALUES (
            ${papelera.rut_id}::uuid,
            ${papelera.cli_id}::uuid,
            true,
            NOW()
          )
          ON CONFLICT (rut_id, cli_id) DO UPDATE
          SET rcl_activo = true
        `);
      }

      // 4. Eliminar entrada de tbl_papelera
      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_papelera
        WHERE id_pap = ${papeleraId}::uuid
      `);

      this.invalidarCaches();

      return {
        ok: true,
        mensaje: 'Cliente y registros vinculados restaurados exitosamente',
        clienteId: papelera.cli_id,
        creditoId: papelera.cre_id,
        rutaId: papelera.rut_id,
      };
    });
  }

  async eliminarDefinitivo(papeleraId: string, usuario: AuthenticatedUser) {
    this.asegurarAdministrador(usuario);
    const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(usuario);

    return this.prisma.$transaction(async (tx) => {
      const rows = await tx.$queryRaw<
        Array<{
          id_pap: string;
          cli_id: string;
          persona_id: string;
        }>
      >(Prisma.sql`
        SELECT
          p.id_pap::text,
          p.cli_id::text,
          c.cli_persona::text AS persona_id
        FROM public.tbl_papelera p
        JOIN public.tbl_clientes c ON c.id_cli = p.cli_id
        WHERE p.id_pap = ${papeleraId}::uuid
          AND p.org_id = ${scope.organizacionId}::uuid
        FOR UPDATE OF p, c
      `);

      const registro = rows[0];
      if (!registro) {
        throw DomainError.notFound(
          'Registro de papelera no encontrado',
          'PAPELERA_NO_ENCONTRADO',
        );
      }

      // Verificar si tiene pagos registrados
      const pagosCheck = await tx.$queryRaw<Array<{ count: number }>>(Prisma.sql`
        SELECT COUNT(pa.id_pag)::int AS count
        FROM public.tbl_creditos cr
        JOIN public.tbl_cuotas cu ON cu.cre_id = cr.id_cre
        JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
        JOIN public.tbl_pagos pa ON pa.id_pag = cp.pagos_id
        WHERE cr.cli_id = ${registro.cli_id}::uuid
      `);

      if ((pagosCheck[0]?.count ?? 0) > 0) {
        throw DomainError.conflict(
          'No se puede eliminar definitivamente un cliente con pagos registrados en el historial contable',
          'CLIENTE_CON_PAGOS_NO_PURGABLE',
        );
      }

      // 1. Eliminar de papelera
      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_papelera
        WHERE id_pap = ${papeleraId}::uuid
      `);

      // 2. Eliminar rutas asociadas
      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_rutas_clientes
        WHERE cli_id = ${registro.cli_id}::uuid
      `);

      // 3. Eliminar cuotas y créditos
      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_cuotas
        WHERE cre_id IN (
          SELECT id_cre FROM public.tbl_creditos WHERE cli_id = ${registro.cli_id}::uuid
        )
      `);

      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_creditos
        WHERE cli_id = ${registro.cli_id}::uuid
      `);

      // 4. Eliminar cliente y persona
      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_clientes
        WHERE id_cli = ${registro.cli_id}::uuid
      `);

      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_personas
        WHERE id_per = ${registro.persona_id}::uuid
      `);

      this.invalidarCaches();

      return {
        ok: true,
        mensaje: 'Registro purgado definitivamente',
      };
    });
  }
}
