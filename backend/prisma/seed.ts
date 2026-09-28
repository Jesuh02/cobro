import { Prisma, PrismaClient } from '@prisma/client';
import { PasswordService } from '../src/modules/auth/password.service';

const prisma = new PrismaClient();
const passwordService = new PasswordService();

async function main() {
  await poblarCatalogosSistema();
  await crearAdministradorInicial();
}

async function poblarCatalogosSistema() {
  // 1. Monedas
  await prisma.$executeRaw`
    INSERT INTO public.tbl_monedas (mon_codigo, mon_nombre, mon_simbolo, mon_decimales)
    VALUES
      ('COP', 'Peso colombiano', '$', 2),
      ('USD', 'Dolar estadounidense', '$', 2)
    ON CONFLICT (mon_codigo) DO NOTHING;
  `;

  // 2. Roles
  await prisma.$executeRaw`
    INSERT INTO public.tbl_roles (rol_tip, rol_nivel)
    VALUES
      ('ADMINISTRADOR', 1),
      ('COBRADOR', 2),
      ('AUDITOR', 3),
      ('SUPER_ADMIN', 4)
    ON CONFLICT (rol_tip) DO UPDATE SET rol_nivel = EXCLUDED.rol_nivel;
  `;

  // 3. Recursos
  const countRecursos = await prisma.$queryRaw<Array<{count: bigint}>>`SELECT count(*) FROM public.tbl_recursos`;
  if (Number(countRecursos[0].count) === 0) {
    await prisma.$executeRaw`
      INSERT INTO public.tbl_recursos (nom, rec_orden, rec_interface)
      VALUES
        ('VER_EMPLEADOS', 10, 'WEB'),
        ('CREAR_CAJA_MENOR', 20, 'WEB'),
        ('REGISTRAR_FLUJO_CAJA', 30, 'WEB'),
        ('CREAR_CREDITOS', 40, 'WEB'),
        ('REFINANCIAR_CREDITOS', 50, 'WEB'),
        ('MODIFICAR_CREDITOS', 60, 'WEB'),
        ('ELIMINAR_CREDITOS', 70, 'WEB'),
        ('MODIFICAR_CLIENTES', 75, 'WEB'),
        ('AGREGAR_CUOTA', 80, 'WEB'),
        ('MODIFICAR_MOVIMIENTOS', 90, 'WEB'),
        ('ELIMINAR_MOVIMIENTOS', 100, 'WEB');
    `;
  }

  // 4. Roles Recursos
  const countRolRecurso = await prisma.$queryRaw<Array<{count: bigint}>>`SELECT count(*) FROM public.tbl_roles_recursos`;
  if (Number(countRolRecurso[0].count) === 0) {
    await prisma.$executeRaw`
      INSERT INTO public.tbl_roles_recursos (rol_id, rec_id)
      SELECT rol.id_rol, recurso.id_rec
      FROM public.tbl_roles rol
      JOIN public.tbl_recursos recurso ON recurso.rec_interface = 'WEB'
      WHERE rol.rol_tip = 'ADMINISTRADOR'
        AND recurso.nom IN ('VER_EMPLEADOS', 'CREAR_CAJA_MENOR', 'REGISTRAR_FLUJO_CAJA', 'CREAR_CREDITOS', 'REFINANCIAR_CREDITOS', 'MODIFICAR_CREDITOS', 'ELIMINAR_CREDITOS', 'MODIFICAR_CLIENTES', 'AGREGAR_CUOTA', 'MODIFICAR_MOVIMIENTOS', 'ELIMINAR_MOVIMIENTOS')
    `;
    await prisma.$executeRaw`
      INSERT INTO public.tbl_roles_recursos (rol_id, rec_id)
      SELECT rol.id_rol, recurso.id_rec
      FROM public.tbl_roles rol
      JOIN public.tbl_recursos recurso ON recurso.rec_interface = 'WEB'
      WHERE rol.rol_tip = 'AUDITOR' AND recurso.nom = 'VER_EMPLEADOS'
    `;
    await prisma.$executeRaw`
      INSERT INTO public.tbl_roles_recursos (rol_id, rec_id)
      SELECT rol.id_rol, recurso.id_rec
      FROM public.tbl_roles rol
      JOIN public.tbl_recursos recurso ON recurso.rec_interface = 'WEB'
      WHERE rol.rol_tip = 'COBRADOR'
        AND recurso.nom IN ('CREAR_CAJA_MENOR', 'REGISTRAR_FLUJO_CAJA', 'CREAR_CREDITOS', 'REFINANCIAR_CREDITOS', 'MODIFICAR_CREDITOS', 'ELIMINAR_CREDITOS', 'AGREGAR_CUOTA', 'MODIFICAR_MOVIMIENTOS', 'ELIMINAR_MOVIMIENTOS')
    `;
  }

  // 5. Productos Creditos
  await prisma.$executeRaw`
    INSERT INTO public.tbl_productos_creditos (pcr_nombre, pcr_frecuencia, pcr_tasa_interes)
    VALUES
      ('Credito diario', 'DIARIO', 20.0000),
      ('Credito semanal', 'SEMANAL', 20.0000),
      ('Credito quincenal', 'QUINCENAL', 20.0000),
      ('Credito mensual', 'MENSUAL', 20.0000)
    ON CONFLICT (pcr_nombre) DO UPDATE SET pcr_frecuencia = EXCLUDED.pcr_frecuencia, pcr_tasa_interes = EXCLUDED.pcr_tasa_interes;
  `;

  // 6. Medios Pagos
  await prisma.$executeRaw`
    INSERT INTO public.tbl_medios_pagos (med_nombre, med_tipo)
    VALUES
      ('Efectivo', 'EFECTIVO'),
      ('Transferencia', 'TRANSFERENCIA'),
      ('Tarjeta', 'TARJETA'),
      ('Billetera', 'BILLETERA'),
      ('Otro', 'OTRO')
    ON CONFLICT (med_tipo) DO NOTHING;
  `;

  // 7. Categorias Gastos
  await prisma.$executeRaw`
    INSERT INTO public.tbl_categorias_gastos (cga_nombre, cga_descripcion)
    VALUES
      ('TRANSPORTE', 'Gastos de transporte'),
      ('PAPELERIA', 'Papeleria e insumos'),
      ('COMISION', 'Comisiones operativas'),
      ('OTRO', 'Otros gastos')
    ON CONFLICT (cga_nombre) DO NOTHING;
  `;
}

async function crearAdministradorInicial() {
  const adminRoleType = 'ADMINISTRADOR';

  // Verificamos si ya existe algun usuario activo con rol ADMINISTRADOR
  const admins = await prisma.$queryRaw<Array<{ id_usu: string }>>`
    SELECT u.id_usu::text
    FROM public.tbl_usuarios u
    JOIN public.tbl_usuarios_organizaciones uo ON u.id_usu = uo.usu_id
    JOIN public.tbl_roles r ON uo.rol_id = r.id_rol
    WHERE r.rol_tip = ${adminRoleType}
      AND u.usu_activo = true
      AND u.usu_password != 'disabled'
    LIMIT 1
  `;

  if (admins.length > 0) {
    console.info('Ya existe un administrador en la base de datos. Omitiendo creacion.');
    return;
  }

  const nombreCompleto = process.env.SUPERADMIN_NOMBRE || 'Administrador Cobro';
  const nombreUsuario = process.env.SUPERADMIN_USUARIO || 'prueba';
  const correo = process.env.SUPERADMIN_CORREO || 'admin@demo.com';
  const passwordPlano = process.env.SUPERADMIN_PASSWORD || 'adminprueba!BB';

  const passwordHash = await passwordService.hash(passwordPlano);
  const nombre = separarNombre(nombreCompleto);

  await prisma.$transaction(async (tx) => {
    const [persona] = await tx.$queryRaw<Array<{ id: string }>>`
      INSERT INTO public.tbl_personas (per_primer_nombre, per_apellido, per_documento, per_email)
      VALUES (${nombre.nombres}, ${nombre.apellidos || ' '}, ${'admin-seed-' + nombreUsuario}, ${correo})
      RETURNING id_per::text AS id
    `;

    const [usuario] = await tx.$queryRaw<Array<{ id: string }>>`
      INSERT INTO public.tbl_usuarios (usu_usuario, usu_password, persona_id)
      VALUES (${nombreUsuario}, ${passwordHash}, ${persona.id}::uuid)
      RETURNING id_usu::text AS id
    `;

    const [organizacion] = await tx.$queryRaw<Array<{ id: string }>>`
      INSERT INTO public.tbl_organizaciones (org_nombre, org_activo, org_es_sistema)
      VALUES ('Organizacion Demo', true, false)
      RETURNING id_org::text AS id
    `;

    const [rol] = await tx.$queryRaw<Array<{ id: string }>>`
      SELECT id_rol::text AS id FROM public.tbl_roles WHERE rol_tip = 'ADMINISTRADOR' LIMIT 1
    `;

    await tx.$executeRaw`
      INSERT INTO public.tbl_usuarios_organizaciones (usu_id, org_id, rol_id)
      VALUES (${usuario.id}::uuid, ${organizacion.id}::uuid, ${rol.id}::uuid)
    `;
    
    console.info(`Administrador inicial creado exitosamente: ${nombreUsuario}`);
  });
}

function separarNombre(nombreCompleto: string) {
  const partes = nombreCompleto.trim().split(/\s+/);
  if (partes.length === 1) return { nombres: partes[0], apellidos: '' };
  const primerNombre = partes[0];
  const apellidos = partes.slice(1).join(' ');
  return { nombres: primerNombre, apellidos };
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
