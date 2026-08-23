import { Prisma, PrismaClient } from '@prisma/client';

import { PasswordService } from '../src/modules/auth/password.service';

const prisma = new PrismaClient();
const passwords = new PasswordService();

const permisosEmpleadoSeed = [
  {
    codigo: 'VER_EMPLEADOS',
    nombre: 'Ver empleados',
    rolNombre: 'Permiso ver empleados',
  },
  {
    codigo: 'CREAR_CAJA_MENOR',
    nombre: 'Crear caja menor',
    rolNombre: 'Permiso crear caja menor',
  },
  {
    codigo: 'REGISTRAR_FLUJO_CAJA',
    nombre: 'Registrar flujo en caja menor',
    rolNombre: 'Permiso registrar flujo en caja menor',
  },
  {
    codigo: 'CREAR_CREDITOS',
    nombre: 'Crear creditos',
    rolNombre: 'Permiso crear creditos',
  },
  {
    codigo: 'REFINANCIAR_CREDITOS',
    nombre: 'Refinanciar creditos',
    rolNombre: 'Permiso refinanciar creditos',
  },
  {
    codigo: 'MODIFICAR_CREDITOS',
    nombre: 'Modificar creditos',
    rolNombre: 'Permiso modificar creditos',
  },
  {
    codigo: 'ELIMINAR_CREDITOS',
    nombre: 'Eliminar creditos',
    rolNombre: 'Permiso eliminar creditos',
  },
  {
    codigo: 'AGREGAR_CUOTA',
    nombre: 'Agregar cuota',
    rolNombre: 'Permiso agregar cuota',
  },
  {
    codigo: 'MODIFICAR_MOVIMIENTOS',
    nombre: 'Modificar movimientos',
    rolNombre: 'Permiso modificar movimientos',
  },
  {
    codigo: 'ELIMINAR_MOVIMIENTOS',
    nombre: 'Eliminar movimientos',
    rolNombre: 'Permiso eliminar movimientos',
  },
] as const;

async function main() {
  await prisma.moneda.createMany({
    data: [
      {
        codigoMoneda: 'COP',
        nombre: 'Peso colombiano',
        simbolo: '$',
        decimales: 2,
      },
      {
        codigoMoneda: 'USD',
        nombre: 'Dolar estadounidense',
        simbolo: '$',
        decimales: 2,
      },
    ],
    skipDuplicates: true,
  });

  await prisma.estadoUsuario.createMany({
    data: [
      { codigo: 'ACTIVO', nombre: 'Activo' },
      { codigo: 'INACTIVO', nombre: 'Inactivo' },
    ],
    skipDuplicates: true,
  });

  await prisma.rol.createMany({
    data: [
      { codigo: 'ADMINISTRADOR', nombre: 'Administrador' },
      { codigo: 'COBRADOR', nombre: 'Cobrador' },
      { codigo: 'AUDITOR', nombre: 'Auditor' },
    ],
    skipDuplicates: true,
  });

  await sincronizarPermisosEmpleado();

  await prisma.estadoCliente.createMany({
    data: [
      { codigo: 'ACTIVO', nombre: 'Activo' },
      { codigo: 'SUSPENDIDO', nombre: 'Suspendido' },
      { codigo: 'BLOQUEADO', nombre: 'Bloqueado' },
    ],
    skipDuplicates: true,
  });

  await prisma.tipoDocumento.createMany({
    data: [
      { codigo: 'CC', nombre: 'Cedula de ciudadania' },
      { codigo: 'CE', nombre: 'Cedula de extranjeria' },
      { codigo: 'NIT', nombre: 'NIT' },
      { codigo: 'PASAPORTE', nombre: 'Pasaporte' },
    ],
    skipDuplicates: true,
  });

  await prisma.tipoContacto.createMany({
    data: [
      { codigo: 'TELEFONO', nombre: 'Telefono' },
      { codigo: 'WHATSAPP', nombre: 'WhatsApp' },
      { codigo: 'CORREO', nombre: 'Correo electronico' },
    ],
    skipDuplicates: true,
  });

  await prisma.tipoDireccion.createMany({
    data: [
      { codigo: 'CASA', nombre: 'Casa' },
      { codigo: 'NEGOCIO', nombre: 'Negocio' },
      { codigo: 'OTRA', nombre: 'Otra' },
    ],
    skipDuplicates: true,
  });

  await prisma.estadoRuta.createMany({
    data: [
      { codigo: 'ABIERTA', nombre: 'Abierta' },
      { codigo: 'CERRADA', nombre: 'Cerrada' },
      { codigo: 'PAUSADA', nombre: 'Pausada' },
    ],
    skipDuplicates: true,
  });

  await prisma.frecuenciaPago.createMany({
    data: [
      { codigo: 'DIARIO', nombre: 'Diario', diasIntervalo: 1 },
      { codigo: 'SEMANAL', nombre: 'Semanal', diasIntervalo: 7 },
      { codigo: 'QUINCENAL', nombre: 'Quincenal', diasIntervalo: 15 },
      { codigo: 'MENSUAL', nombre: 'Mensual', diasIntervalo: 30 },
    ],
    skipDuplicates: true,
  });

  await prisma.estadoCredito.createMany({
    data: [
      { codigo: 'CONFIGURADO', nombre: 'Configurado' },
      { codigo: 'ACTIVO', nombre: 'Activo' },
      { codigo: 'PAGADO', nombre: 'Pagado' },
      { codigo: 'VENCIDO', nombre: 'Vencido' },
      { codigo: 'ANULADO', nombre: 'Anulado' },
    ],
    skipDuplicates: true,
  });

  await prisma.estadoCuota.createMany({
    data: [
      { codigo: 'PENDIENTE', nombre: 'Pendiente' },
      { codigo: 'PAGADA', nombre: 'Pagada' },
      { codigo: 'VENCIDA', nombre: 'Vencida' },
      { codigo: 'ANULADA', nombre: 'Anulada' },
    ],
    skipDuplicates: true,
  });

  await prisma.medioPago.createMany({
    data: [
      { codigo: 'EFECTIVO', nombre: 'Efectivo' },
      { codigo: 'TRANSFERENCIA', nombre: 'Transferencia' },
      { codigo: 'TARJETA', nombre: 'Tarjeta' },
      { codigo: 'OTRO', nombre: 'Otro' },
    ],
    skipDuplicates: true,
  });

  await prisma.tipoMovimientoCaja.createMany({
    data: [
      {
        codigo: 'AJUSTE_ENTRADA',
        nombre: 'Ajuste de entrada',
        naturaleza: 'E',
      },
      { codigo: 'RECAUDO', nombre: 'Recaudo', naturaleza: 'E' },
      {
        codigo: 'DESEMBOLSO_CREDITO',
        nombre: 'Desembolso de credito',
        naturaleza: 'S',
      },
      { codigo: 'GASTO', nombre: 'Gasto', naturaleza: 'S' },
      { codigo: 'AJUSTE_SALIDA', nombre: 'Ajuste de salida', naturaleza: 'S' },
    ],
    skipDuplicates: true,
  });
  await prisma.tipoMovimientoCaja.updateMany({
    where: { codigo: { in: ['GASTO', 'DESEMBOLSO_CREDITO', 'AJUSTE_SALIDA'] } },
    data: { naturaleza: 'S' },
  });
  await prisma.tipoMovimientoCaja.updateMany({
    where: { codigo: { in: ['RECAUDO', 'AJUSTE_ENTRADA'] } },
    data: { naturaleza: 'E' },
  });

  await prisma.categoriaGasto.createMany({
    data: [
      { codigo: 'TRANSPORTE', nombre: 'Transporte' },
      { codigo: 'PAPELERIA', nombre: 'Papeleria' },
      { codigo: 'COMISION', nombre: 'Comision' },
      { codigo: 'OTRO', nombre: 'Otro' },
    ],
    skipDuplicates: true,
  });

  await crearAdministradorInicial();
}

async function sincronizarPermisosEmpleado() {
  const rolAdministrador = await prisma.rol.findUnique({
    where: { codigo: 'ADMINISTRADOR' },
  });

  for (const permiso of permisosEmpleadoSeed) {
    const [rol, recurso] = await Promise.all([
      prisma.rol.upsert({
        where: { codigo: permiso.codigo },
        create: { codigo: permiso.codigo, nombre: permiso.rolNombre },
        update: { nombre: permiso.rolNombre },
      }),
      prisma.$queryRaw<Array<{ recurso_id: number }>>(Prisma.sql`
        INSERT INTO public.recurso (codigo, nombre)
        VALUES (${permiso.codigo}, ${permiso.nombre})
        ON CONFLICT (codigo) DO UPDATE
        SET nombre = EXCLUDED.nombre,
            actualizado_en = now()
        RETURNING recurso_id
      `),
    ]);
    const recursoId = recurso[0]?.recurso_id;

    if (!recursoId) {
      throw new Error(`No existe el recurso ${permiso.codigo}`);
    }

    await prisma.$executeRaw(Prisma.sql`
      INSERT INTO public.rol_recurso (rol_id, recurso_id)
      VALUES (${rol.rolId}, ${recursoId})
      ON CONFLICT DO NOTHING
    `);

    if (rolAdministrador) {
      await prisma.$executeRaw(Prisma.sql`
        INSERT INTO public.rol_recurso (rol_id, recurso_id)
        VALUES (${rolAdministrador.rolId}, ${recursoId})
        ON CONFLICT DO NOTHING
      `);
    }
  }
}

async function crearAdministradorInicial() {
  const administradores = await prisma.usuario.count({
    where: {
      passwordHash: { not: 'disabled' },
      roles: {
        some: {
          rol: { codigo: 'ADMINISTRADOR' },
        },
      },
    },
  });

  if (administradores > 0) {
    return;
  }

  const [estadoActivo, rolAdministrador] = await Promise.all([
    prisma.estadoUsuario.findUnique({ where: { codigo: 'ACTIVO' } }),
    prisma.rol.findUnique({ where: { codigo: 'ADMINISTRADOR' } }),
  ]);

  if (!estadoActivo || !rolAdministrador) {
    throw new Error('Faltan catalogos base para crear el administrador');
  }

  const nombreUsuario = (process.env.ADMIN_USERNAME ?? 'admin')
    .trim()
    .toLowerCase();
  const correo = (process.env.ADMIN_EMAIL ?? 'admin@cobro.local')
    .trim()
    .toLowerCase();
  const contrasena =
    process.env.ADMIN_PASSWORD ?? 'Admin-local-development-12345!';
  if (
    contrasena.length < 12 ||
    contrasena.length > 128 ||
    (process.env.NODE_ENV === 'production' && !process.env.ADMIN_PASSWORD)
  ) {
    throw new Error(
      'ADMIN_PASSWORD is required in production and must have 12 to 128 characters',
    );
  }
  const nombreCompleto = process.env.ADMIN_FULL_NAME ?? 'Administrador Cobro';
  const nombre = separarNombre(nombreCompleto);
  const existente = await prisma.usuario.findUnique({
    where: { nombreUsuario },
  });

  if (existente) {
    await prisma.usuario.update({
      where: { usuarioId: existente.usuarioId },
      data: {
        estadoUsuarioId: estadoActivo.estadoUsuarioId,
        passwordHash: await passwords.hash(contrasena),
      },
    });
    await prisma.usuarioRol.upsert({
      where: {
        usuarioId_rolId: {
          usuarioId: existente.usuarioId,
          rolId: rolAdministrador.rolId,
        },
      },
      create: {
        usuarioId: existente.usuarioId,
        rolId: rolAdministrador.rolId,
      },
      update: {},
    });
    return;
  }

  await prisma.usuario.create({
    data: {
      estadoUsuarioId: estadoActivo.estadoUsuarioId,
      nombreUsuario,
      passwordHash: await passwords.hash(contrasena),
      nombres: nombre.nombres,
      apellidos: nombre.apellidos,
      correo,
      roles: {
        create: {
          rolId: rolAdministrador.rolId,
        },
      },
    },
  });

  console.info(`Administrador inicial creado: ${nombreUsuario}`);
}

function separarNombre(nombreCompleto: string) {
  const partes = nombreCompleto.trim().split(/\s+/);

  if (partes.length === 1) {
    return { nombres: partes[0], apellidos: '' };
  }

  return {
    nombres: partes.slice(0, -1).join(' '),
    apellidos: partes[partes.length - 1],
  };
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (error: unknown) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
