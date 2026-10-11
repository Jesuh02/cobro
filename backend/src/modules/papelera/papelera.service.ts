import { ForbiddenException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../common/prisma/prisma.service';
import { TenantScopeService } from '../../common/tenancy/tenant-scope.service';
import { InMemoryCacheService } from '../../common/cache/in-memory-cache.service';
import { DomainError } from '../../common/domain/domain-error';
import { AuthenticatedUser } from '../auth/auth.types';
import { ListarPapeleraQueryDto, UnificarCreditoPapeleraDto } from './dto';
import {
  calcularPlanPendiente,
  redondear,
} from '../creditos/creditos-amortizacion.util';

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
  cre_tasa_interes: Prisma.Decimal | null;
  cre_fecha_inicio: Date | null;
  cre_fecha_fin: Date | null;
  frecuencia_codigo: string | null;
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
        cr.cre_tasa_interes,
        cr.cre_fecha_inicio,
        cr.cre_fecha_fin,
        pc.pcr_frecuencia::text AS frecuencia_codigo,
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
      LEFT JOIN public.tbl_productos_creditos pc ON pc.id_pcr = cr.pcr_id
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
      tipo:
        (r.pap_datos as { tipo?: string } | null)?.tipo ??
        (r.cre_id ? 'CREDITO' : 'CLIENTE'),
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
            frecuencia: r.frecuencia_codigo ?? 'DIARIO',
            tasaInteres: Number(r.cre_tasa_interes ?? 0),
            fechaInicio: r.cre_fecha_inicio ? r.cre_fecha_inicio.toISOString() : null,
            fechaFin: r.cre_fecha_fin ? r.cre_fecha_fin.toISOString() : null,
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
          pap_datos: unknown;
        }>
      >(Prisma.sql`
        SELECT
          p.id_pap::text,
          p.cli_id::text,
          p.cre_id::text,
          p.rut_id::text,
          p.pap_datos
        FROM public.tbl_papelera p
        WHERE p.id_pap = ${papeleraId}::uuid
          AND org_id = ${scope.organizacionId}::uuid
          ${esAdmin ? Prisma.sql`` : Prisma.sql`AND p.usu_id = ${scope.usuarioId}::uuid`}
        FOR UPDATE
      `);

      const papelera = rows[0];
      if (!papelera) {
        throw DomainError.notFound(
          'Registro de papelera no encontrado o no autorizado',
          'PAPELERA_NO_ENCONTRADO',
        );
      }

      const datos = papelera.pap_datos as { tipo?: string } | null;
      const esSoloCredito = datos?.tipo === 'CREDITO';

      if (esSoloCredito) {
        // Validar si el cliente asociado está activo y no se encuentra en la papelera
        const [cliente] = await tx.$queryRaw<
          Array<{ id_cli: string; cli_activo: boolean }>
        >(Prisma.sql`
          SELECT id_cli::text, cli_activo
          FROM public.tbl_clientes
          WHERE id_cli = ${papelera.cli_id}::uuid
            AND org_id = ${scope.organizacionId}::uuid
        `);

        if (!cliente) {
          throw DomainError.notFound(
            'El cliente asociado a este crédito no existe',
            'CLIENTE_NO_ENCONTRADO',
          );
        }

        const clienteEnPapelera = await tx.$queryRaw<
          Array<{ id_pap: string }>
        >(Prisma.sql`
          SELECT id_pap::text
          FROM public.tbl_papelera
          WHERE cli_id = ${papelera.cli_id}::uuid
            AND id_pap != ${papelera.id_pap}::uuid
            AND (pap_datos->>'tipo' IS NULL OR pap_datos->>'tipo' = 'CLIENTE')
          LIMIT 1
        `);

        if (!cliente.cli_activo || clienteEnPapelera.length > 0) {
          throw DomainError.conflict(
            'No se puede restaurar el crédito porque su cliente asociado se encuentra en la papelera. Primero debe restaurar al cliente.',
            'CLIENTE_ELIMINADO_RESTAURAR_PRIMERO',
          );
        }

        // 1. Reactivar crédito a ACTIVO
        if (papelera.cre_id) {
          const [creditoActivo] = await tx.$queryRaw<
            Array<{ id_cre: string }>
          >(Prisma.sql`
            SELECT id_cre::text
            FROM public.tbl_creditos
            WHERE cli_id = ${papelera.cli_id}::uuid
              AND UPPER(cre_estado::text) = 'ACTIVO'
            LIMIT 1
          `);

          if (creditoActivo) {
            throw DomainError.conflict(
              'El cliente ya posee un crédito activo. Debe unificarlo para restaurar este crédito.',
              'CLIENTE_YA_TIENE_CREDITO_ACTIVO',
            );
          }

          await tx.$executeRaw(Prisma.sql`
            UPDATE public.tbl_creditos
            SET cre_estado = 'ACTIVO'::public.credito_estado_enum
            WHERE id_cre = ${papelera.cre_id}::uuid
          `);
        }

        // 2. Restaurar ruta si existía
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

        // 3. Eliminar registro del crédito de tbl_papelera
        await tx.$executeRaw(Prisma.sql`
          DELETE FROM public.tbl_papelera
          WHERE id_pap = ${papeleraId}::uuid
        `);

        this.invalidarCaches();

        return {
          ok: true,
          mensaje: 'Crédito restaurado exitosamente',
          creditoId: papelera.cre_id,
          clienteId: papelera.cli_id,
          rutaId: papelera.rut_id,
        };
      }

      // Si es restauración de un CLIENTE:
      // 1. Reactivar cliente
      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_clientes
        SET cli_activo = true
        WHERE id_cli = ${papelera.cli_id}::uuid
          AND org_id = ${scope.organizacionId}::uuid
      `);

      // 2. Reactivar crédito activo si este registro tenía un crédito vinculado en cadena
      if (papelera.cre_id) {
        const [creditoActivo] = await tx.$queryRaw<
          Array<{ id_cre: string }>
        >(Prisma.sql`
          SELECT id_cre::text
          FROM public.tbl_creditos
          WHERE cli_id = ${papelera.cli_id}::uuid
            AND UPPER(cre_estado::text) = 'ACTIVO'
          LIMIT 1
        `);

        if (creditoActivo) {
          throw DomainError.conflict(
            'El cliente ya posee un crédito activo. Debe unificarlo para restaurar este crédito.',
            'CLIENTE_YA_TIENE_CREDITO_ACTIVO',
          );
        }

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
          cre_id: string | null;
          persona_id: string;
          pap_datos: unknown;
        }>
      >(Prisma.sql`
        SELECT
          p.id_pap::text,
          p.cli_id::text,
          p.cre_id::text,
          c.cli_persona::text AS persona_id,
          p.pap_datos
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

      const datos = registro.pap_datos as { tipo?: string } | null;
      const esSoloCredito = datos?.tipo === 'CREDITO';

      if (esSoloCredito && registro.cre_id) {
        // Verificar si este crédito específico tiene pagos registrados
        const pagosCheck = await tx.$queryRaw<Array<{ count: number }>>(Prisma.sql`
          SELECT COUNT(pa.id_pag)::int AS count
          FROM public.tbl_cuotas cu
          JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
          JOIN public.tbl_pagos pa ON pa.id_pag = cp.pagos_id
          WHERE cu.cre_id = ${registro.cre_id}::uuid
        `);

        if ((pagosCheck[0]?.count ?? 0) > 0) {
          throw DomainError.conflict(
            'No se puede eliminar definitivamente un crédito con pagos registrados en el historial contable',
            'CREDITO_CON_PAGOS_NO_PURGABLE',
          );
        }

        // 1. Eliminar de papelera
        await tx.$executeRaw(Prisma.sql`
          DELETE FROM public.tbl_papelera
          WHERE id_pap = ${papeleraId}::uuid
        `);

        // 2. Revertir movimientos de caja si existían
        const movimientos = await tx.$queryRaw<
          Array<{ id: string; monto: Prisma.Decimal; sca_id: string | null }>
        >(Prisma.sql`
          SELECT
            id_mca::text AS id,
            mca_monto AS monto,
            sca_id::text AS sca_id
          FROM public.tbl_movimientos_cajas
          WHERE mca_referencia_id = ${registro.cre_id}::uuid
            AND mca_referencia_tipo::text = 'CREDITO'
        `);

        for (const mov of movimientos) {
          if (mov.sca_id) {
            await tx.$executeRaw(Prisma.sql`
              UPDATE public.tbl_sesiones_cajas
              SET sca_total_gasto = GREATEST(sca_total_gasto - ${mov.monto}, 0)
              WHERE id_sca = ${mov.sca_id}::uuid
            `);
          }
          await tx.$executeRaw(Prisma.sql`
            DELETE FROM public.tbl_movimientos_cajas
            WHERE id_mca = ${mov.id}::uuid
          `);
        }

        // 3. Eliminar cuotas y crédito (el cliente activo permanece intacto)
        await tx.$executeRaw(Prisma.sql`
          DELETE FROM public.tbl_cuotas
          WHERE cre_id = ${registro.cre_id}::uuid
        `);

        await tx.$executeRaw(Prisma.sql`
          DELETE FROM public.tbl_creditos
          WHERE id_cre = ${registro.cre_id}::uuid
        `);

        this.invalidarCaches();

        return {
          ok: true,
          mensaje: 'Crédito purgado definitivamente',
        };
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

  private decimal(valor: number, decimales = 2): Prisma.Decimal {
    return new Prisma.Decimal(valor.toFixed(decimales));
  }

  private decimalANumero(valor?: Prisma.Decimal | number | null): number {
    if (valor === null || valor === undefined) return 0;
    return typeof valor === 'number' ? valor : Number(valor);
  }

  async unificarYRefinanciarCredito(
    papeleraId: string,
    dto: UnificarCreditoPapeleraDto,
    usuario: AuthenticatedUser,
  ) {
    return this.unificarYRefinanciarCreditoTbl(papeleraId, dto, usuario);
  }

  private async unificarYRefinanciarCreditoTbl(
    papeleraId: string,
    dto: UnificarCreditoPapeleraDto,
    usuario: AuthenticatedUser,
  ) {
    const resultado = await this.prisma.$transaction(async (tx) => {
      const scope = await this.tenantScope.obtenerScopeOrganizacionTbl(
        usuario,
        tx,
      );

      // 1. Obtener registro de papelera
      const [papelera] = await tx.$queryRaw<
        Array<{
          id_pap: string;
          cli_id: string;
          cre_id: string | null;
          rut_id: string | null;
          usu_id: string;
          pap_datos: unknown;
        }>
      >(Prisma.sql`
        SELECT
          id_pap::text,
          cli_id::text,
          cre_id::text,
          rut_id::text,
          usu_id::text,
          pap_datos
        FROM public.tbl_papelera
        WHERE id_pap = ${papeleraId}::uuid
          AND org_id = ${scope.organizacionId}::uuid
        FOR UPDATE
      `);

      if (!papelera) {
        throw DomainError.notFound(
          'Registro de papelera no encontrado',
          'PAPELERA_NO_ENCONTRADO',
        );
      }

      if (!papelera.cre_id) {
        throw DomainError.validation(
          'El registro de papelera no contiene un crédito para unificar',
          'PAPELERA_SIN_CREDITO',
        );
      }

      // Validar permisos
      const esAdmin = this.tenantScope.esAdministrador(usuario);
      const esCreador = papelera.usu_id === scope.usuarioId;
      if (!esAdmin && !esCreador) {
        throw new ForbiddenException(
          'No tienes permiso para unificar este registro',
        );
      }

      // 2. Obtener el crédito de la papelera
      const [creditoPapelera] = await tx.$queryRaw<
        Array<{
          id_cre: string;
          cli_id: string;
          cre_total: Prisma.Decimal;
          cre_tasa_interes: Prisma.Decimal;
          cre_total_pagar: Prisma.Decimal;
          cre_estado: string;
          mon_id: string;
          pcr_id: string;
          frecuencia_codigo: string;
        }>
      >(Prisma.sql`
        SELECT
          cr.id_cre::text,
          cr.cli_id::text,
          cr.cre_total,
          cr.cre_tasa_interes,
          cr.cre_total_pagar,
          cr.cre_estado::text,
          cr.mon_id::text,
          cr.pcr_id::text,
          pc.pcr_frecuencia::text AS frecuencia_codigo
        FROM public.tbl_creditos cr
        JOIN public.tbl_productos_creditos pc ON pc.id_pcr = cr.pcr_id
        WHERE cr.id_cre = ${papelera.cre_id}::uuid
        FOR UPDATE
      `);

      if (!creditoPapelera) {
        throw DomainError.notFound(
          'El crédito de la papelera no existe en base de datos',
          'CREDITO_PAPELERA_NO_ENCONTRADO',
        );
      }

      // Abonos previos al crédito de la papelera
      const [abonosPapelera] = await tx.$queryRaw<
        Array<{ capital_abonado: Prisma.Decimal; total_pagado: Prisma.Decimal }>
      >(Prisma.sql`
        SELECT
          COALESCE(SUM(cp.cpa_capital), 0) AS capital_abonado,
          COALESCE(SUM(cp.cpa_total), 0) AS total_pagado
        FROM public.tbl_cuotas cu
        JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
        WHERE cu.cre_id = ${papelera.cre_id}::uuid
      `);

      let capAbonadoPap = this.decimalANumero(abonosPapelera?.capital_abonado);
      const totalPagadoPap = this.decimalANumero(abonosPapelera?.total_pagado);
      if (capAbonadoPap === 0 && totalPagadoPap > 0) {
        capAbonadoPap = totalPagadoPap;
      }
      const principalPapelera = this.decimalANumero(creditoPapelera.cre_total);
      const capitalPendientePapelera = redondear(
        Math.max(0, principalPapelera - capAbonadoPap),
        2,
      );

      // 3. Obtener el crédito ACTIVO del cliente
      const [creditoActivo] = await tx.$queryRaw<
        Array<{
          id_cre: string;
          cli_id: string;
          cre_total: Prisma.Decimal;
          cre_tasa_interes: Prisma.Decimal;
          cre_total_pagar: Prisma.Decimal;
          cre_estado: string;
          mon_id: string;
          pcr_id: string;
          frecuencia_codigo: string;
          decimales: number | bigint;
        }>
      >(Prisma.sql`
        SELECT
          cr.id_cre::text,
          cr.cli_id::text,
          cr.cre_total,
          cr.cre_tasa_interes,
          cr.cre_total_pagar,
          cr.cre_estado::text,
          cr.mon_id::text,
          cr.pcr_id::text,
          pc.pcr_frecuencia::text AS frecuencia_codigo,
          m.mon_decimales AS decimales
        FROM public.tbl_creditos cr
        JOIN public.tbl_productos_creditos pc ON pc.id_pcr = cr.pcr_id
        JOIN public.tbl_monedas m ON m.id_mon = cr.mon_id
        WHERE cr.cli_id = ${papelera.cli_id}::uuid
          AND UPPER(cr.cre_estado::text) = 'ACTIVO'
        FOR UPDATE OF cr
        LIMIT 1
      `);

      if (!creditoActivo) {
        throw DomainError.conflict(
          'El cliente no tiene un crédito activo con el cual unificar',
          'CLIENTE_SIN_CREDITO_ACTIVO',
        );
      }

      if (creditoActivo.mon_id !== creditoPapelera.mon_id) {
        throw DomainError.conflict(
          'No se pueden unificar créditos con diferente moneda',
          'MONEDAS_INCOMPATIBLES',
        );
      }

      const decimales = Number(creditoActivo.decimales ?? 2);

      // 4. Determinar la frecuencia seleccionada (Diario, Semanal, etc.)
      const frecuenciaDeseada = (
        dto.frecuenciaCodigo?.trim().toUpperCase() ||
        creditoActivo.frecuencia_codigo
      );

      const [producto] = await tx.$queryRaw<
        Array<{ id: string; dias_intervalo: number; pcr_frecuencia: string }>
      >(Prisma.sql`
        SELECT
          pc.id_pcr::text AS id,
          CASE pc.pcr_frecuencia::text
            WHEN 'SEMANAL' THEN 7
            WHEN 'QUINCENAL' THEN 15
            WHEN 'MENSUAL' THEN 30
            ELSE 1
          END AS dias_intervalo,
          pc.pcr_frecuencia::text AS pcr_frecuencia
        FROM public.tbl_productos_creditos pc
        WHERE pc.pcr_frecuencia::text = ${frecuenciaDeseada}
        ORDER BY (pc.pcr_frecuencia::text = ${frecuenciaDeseada}) DESC
        LIMIT 1
      `);

      if (!producto) {
        throw DomainError.notFound(
          'Frecuencia de pago no encontrada',
          'FRECUENCIA_NO_ENCONTRADA',
        );
      }

      // 5. Cuotas y abonos del crédito ACTIVO
      const cuotasActivas = await tx.$queryRaw<
        Array<{
          id: string;
          numero: number | bigint;
          valor: Prisma.Decimal;
          total_pagado: Prisma.Decimal;
          estado: string;
        }>
      >(Prisma.sql`
        SELECT
          cu.id_cuo::text AS id,
          cu.cuo_numero::int AS numero,
          cu.cuo_valor AS valor,
          cu.cuo_total_pagado AS total_pagado,
          UPPER(cu.cuo_estado::text) AS estado
        FROM public.tbl_cuotas cu
        WHERE cu.cre_id = ${creditoActivo.id_cre}::uuid
        ORDER BY cu.cuo_numero ASC
      `);

      const [abonosActivo] = await tx.$queryRaw<
        Array<{ capital_abonado: Prisma.Decimal; interes_abonado: Prisma.Decimal }>
      >(Prisma.sql`
        SELECT
          COALESCE(SUM(cp.cpa_capital), 0) AS capital_abonado,
          COALESCE(SUM(cp.cpa_interes), 0) AS interes_abonado
        FROM public.tbl_cuotas cu
        JOIN public.tbl_cuotas_pagos cp ON cp.cuo_id = cu.id_cuo
        WHERE cu.cre_id = ${creditoActivo.id_cre}::uuid
      `);

      let capAbonadoAct = this.decimalANumero(abonosActivo?.capital_abonado);
      let intAbonadoAct = this.decimalANumero(abonosActivo?.interes_abonado);
      const totalAbonadoAct = cuotasActivas.reduce(
        (acc, c) => acc + this.decimalANumero(c.total_pagado),
        0,
      );
      if (capAbonadoAct === 0 && intAbonadoAct === 0 && totalAbonadoAct > 0) {
        capAbonadoAct = totalAbonadoAct;
      }

      const ultimoNumeroCuota = cuotasActivas.reduce(
        (max, c) => Math.max(max, Number(c.numero)),
        0,
      );

      // 6. Nuevo capital consolidado y cálculo del plan reiniciado (Opción B)
      const principalActivo = this.decimalANumero(creditoActivo.cre_total);
      const valorNuevo = redondear(
        principalActivo + capitalPendientePapelera,
        decimales,
      );
      const porcentajeInteres = this.decimalANumero(
        creditoActivo.cre_tasa_interes,
      );

      let plazoDias = dto.plazoDias;
      if (!plazoDias || plazoDias <= 0) {
        if (producto.pcr_frecuencia === 'SEMANAL') {
          plazoDias = 28;
        } else if (producto.pcr_frecuencia === 'QUINCENAL') {
          plazoDias = 30;
        } else if (producto.pcr_frecuencia === 'MENSUAL') {
          plazoDias = 30;
        } else {
          plazoDias = 30;
        }
      }

      const fechaInicio = new Date();

      const totalNuevo = redondear(
        valorNuevo + valorNuevo * (porcentajeInteres / 100),
        decimales,
      );
      const interesNuevo = redondear(totalNuevo - valorNuevo, decimales);
      const capitalPendiente = redondear(
        Math.max(0, valorNuevo - capAbonadoAct),
        decimales,
      );
      const interesPendiente = redondear(
        Math.max(0, interesNuevo - intAbonadoAct),
        decimales,
      );

      const planPendiente = calcularPlanPendiente({
        fechaInicio,
        valorCapital: capitalPendiente,
        valorInteres: interesPendiente,
        plazoDias,
        diasIntervalo: Number(producto.dias_intervalo),
        omitirDomingos: true,
        decimales,
      });

      // 7. En el crédito ACTIVO: anular cuotas pendientes no pagadas
      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_cuotas
        SET cuo_estado = 'ANULADA'::public.cuota_estado_enum
        WHERE cre_id = ${creditoActivo.id_cre}::uuid
          AND UPPER(cuo_estado::text) != 'PAGADA'
          AND cuo_total_pagado < cuo_valor
      `);

      // 8. Insertar nuevas cuotas reiniciadas
      for (let i = 0; i < planPendiente.cuotas.length; i++) {
        const cuota = planPendiente.cuotas[i];
        await tx.$executeRaw(Prisma.sql`
          INSERT INTO public.tbl_cuotas (
            cuo_numero,
            cuo_valor,
            cuo_total_pagado,
            cuo_estado,
            cuo_fecha_vencimiento,
            cre_id
          )
          VALUES (
            ${ultimoNumeroCuota + i + 1},
            ${this.decimal(cuota.valorCapital + cuota.valorInteres, decimales)},
            0,
            'PENDIENTE'::public.cuota_estado_enum,
            ${cuota.fechaVencimiento}::date,
            ${creditoActivo.id_cre}::uuid
          )
        `);
      }

      // 9. Actualizar crédito ACTIVO con nuevos totales y producto/frecuencia
      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_creditos
        SET
          cre_total = ${this.decimal(valorNuevo, decimales)},
          cre_tasa_interes = ${this.decimal(porcentajeInteres, 4)},
          cre_interes_total = ${this.decimal(interesNuevo, decimales)},
          cre_total_pagar = ${this.decimal(totalNuevo, decimales)},
          cre_fecha_inicio = ${fechaInicio}::date,
          cre_fecha_fin = ${planPendiente.fechaMaxima}::date,
          pcr_id = ${producto.id}::uuid,
          cre_estado = 'ACTIVO'::public.credito_estado_enum,
          cre_observacion = CONCAT(
            COALESCE(cre_observacion, ''),
            ' [Unificado con deuda de papelera ', ${papelera.cre_id}::text, ']'
          )
        WHERE id_cre = ${creditoActivo.id_cre}::uuid
      `);

      // 10. En el crédito de la PAPELERA: anular cuotas y marcar como ANULADO
      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_cuotas
        SET cuo_estado = 'ANULADA'::public.cuota_estado_enum
        WHERE cre_id = ${papelera.cre_id}::uuid
          AND UPPER(cuo_estado::text) != 'PAGADA'
      `);

      await tx.$executeRaw(Prisma.sql`
        UPDATE public.tbl_creditos
        SET
          cre_estado = 'ANULADO'::public.credito_estado_enum,
          cre_observacion = CONCAT(
            COALESCE(cre_observacion, ''),
            ' [Unificado y refinanciado en crédito ', ${creditoActivo.id_cre}::text, ']'
          )
        WHERE id_cre = ${papelera.cre_id}::uuid
      `);

      // 11. Eliminar la entrada de tbl_papelera
      await tx.$executeRaw(Prisma.sql`
        DELETE FROM public.tbl_papelera
        WHERE id_pap = ${papeleraId}::uuid
      `);

      return {
        ok: true,
        mensaje: 'Crédito unificado y refinanciado exitosamente',
        creditoActivoId: creditoActivo.id_cre,
        creditoPapeleraId: papelera.cre_id,
        valorNuevo,
        frecuencia: producto.pcr_frecuencia,
        numeroCuotas: planPendiente.numeroCuotas,
        valorCuota: planPendiente.valorCuota,
        fechaFin: planPendiente.fechaMaxima,
      };
    });

    this.invalidarCaches();
    return resultado;
  }
}
