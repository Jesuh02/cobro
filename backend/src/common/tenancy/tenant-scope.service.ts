import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { AuthenticatedUser } from '../../modules/auth/auth.types';

export type PrismaExecutor = Pick<
  Prisma.TransactionClient,
  '$executeRaw' | '$queryRaw'
>;

export type OrganizacionScopeTbl = {
  usuarioId: string;
  organizacionId: string;
};

@Injectable()
export class TenantScopeService {
  constructor(private readonly prisma: PrismaService) {}

  esIdTbl(value: string): boolean {
    return /^\d+$/.test(value) || /^[0-9a-fA-F-]{36}$/.test(value);
  }

  esAdministrador(usuario: AuthenticatedUser): boolean {
    return (
      usuario.roles.includes('ADMINISTRADOR') ||
      usuario.roles.includes('SUPER_ADMIN')
    );
  }

  puedeVerDatosOrganizacion(usuario: AuthenticatedUser): boolean {
    return this.esAdministrador(usuario) || usuario.roles.includes('AUDITOR');
  }

  async obtenerScopeOrganizacionTbl(
    usuario: AuthenticatedUser,
    executor: PrismaExecutor = this.prisma,
  ): Promise<OrganizacionScopeTbl> {
    const conditions: Prisma.Sql[] = [Prisma.sql`tu.usu_activo`];

    if (this.esIdTbl(usuario.usuarioId)) {
      conditions.push(Prisma.sql`tu.id_usu = ${usuario.usuarioId}::uuid`);
    } else {
      conditions.push(
        Prisma.sql`lower(tu.usu_usuario) = lower(${usuario.usuario})`,
      );
    }

    if (usuario.organizacionId && this.esIdTbl(usuario.organizacionId)) {
      conditions.push(
        Prisma.sql`uo.org_id = ${usuario.organizacionId}::uuid`,
      );
    }

    const [scope] = await executor.$queryRaw<
      Array<{ usuario_id: string; organizacion_id: string }>
    >(Prisma.sql`
      SELECT
        tu.id_usu::text AS usuario_id,
        uo.org_id::text AS organizacion_id
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
      WHERE ${Prisma.join(conditions, ' AND ')}
      ORDER BY uo.id_urg ASC
      LIMIT 1
    `);

    if (!scope) {
      throw new ForbiddenException('No tienes una institucion activa');
    }

    return {
      usuarioId: scope.usuario_id,
      organizacionId: scope.organizacion_id,
    };
  }
}
