import { PrismaClient } from '@prisma/client';
import { randomBytes, scrypt } from 'crypto';
import { promisify } from 'util';

const prisma = new PrismaClient();
const scryptAsync = promisify(scrypt);

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
  const contrasena = process.env.ADMIN_PASSWORD ?? 'Admin12345!';
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
        passwordHash: await hashPassword(contrasena),
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
      passwordHash: await hashPassword(contrasena),
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

async function hashPassword(password: string) {
  const salt = randomBytes(24).toString('base64url');
  const key = (await scryptAsync(password, salt, 64)) as Buffer;
  return `scrypt$${salt}$${key.toString('base64url')}`;
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
