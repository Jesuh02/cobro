import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaClient } from '@prisma/client';

const envPath = resolve(process.cwd(), '.env');
if (existsSync(envPath)) {
  const content = readFileSync(envPath, 'utf8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx !== -1) {
      const key = trimmed.slice(0, eqIdx).trim();
      let val = trimmed.slice(eqIdx + 1).trim();
      if (
        (val.startsWith('"') && val.endsWith('"')) ||
        (val.startsWith("'") && val.endsWith("'"))
      ) {
        val = val.slice(1, -1);
      }
      if (!process.env[key]) {
        process.env[key] = val;
      }
    }
  }
}

const prisma = new PrismaClient();

async function main() {
  console.log('Conectando a la base de datos...');
  await prisma.$connect();
  console.log('Conexión exitosa.');

  console.log('Aplicando DDL para tbl_papelera...');
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS public.tbl_papelera (
      id_pap UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      org_id UUID NOT NULL REFERENCES public.tbl_organizaciones (id_org) ON DELETE CASCADE,
      usu_id UUID NOT NULL REFERENCES public.tbl_usuarios (id_usu) ON DELETE RESTRICT,
      cli_id UUID NOT NULL REFERENCES public.tbl_clientes (id_cli) ON DELETE CASCADE,
      cre_id UUID REFERENCES public.tbl_creditos (id_cre) ON DELETE SET NULL,
      rut_id UUID REFERENCES public.tbl_rutas (id_rut) ON DELETE SET NULL,
      pap_fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
      pap_motivo VARCHAR(255),
      pap_datos JSONB DEFAULT '{}'
    );
  `);

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS ix_tbl_papelera_org_fecha
      ON public.tbl_papelera (org_id, pap_fecha DESC);
  `);

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS ix_tbl_papelera_cliente
      ON public.tbl_papelera (cli_id);
  `);

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS ix_tbl_papelera_credito
      ON public.tbl_papelera (cre_id);
  `);

  console.log('Tabla tbl_papelera e índices creados o verificados.');

  console.log('Inyectando recurso VER_PAPELERA...');
  await prisma.$executeRawUnsafe(`
    INSERT INTO public.tbl_recursos (nom, rec_orden, rec_interface)
    VALUES ('VER_PAPELERA', 110, 'WEB')
    ON CONFLICT (rec_interface, nom) DO UPDATE SET rec_orden = 110;
  `);

  await prisma.$executeRawUnsafe(`
    INSERT INTO public.tbl_roles_recursos (rol_id, rec_id)
    SELECT rol.id_rol, recurso.id_rec
    FROM public.tbl_roles rol
    JOIN public.tbl_recursos recurso ON recurso.rec_interface = 'WEB'
    WHERE rol.rol_tip = 'ADMINISTRADOR'
      AND recurso.nom = 'VER_PAPELERA'
    ON CONFLICT (rec_id, rol_id) DO NOTHING;
  `);

  console.log('Recurso VER_PAPELERA asignado a ADMINISTRADOR.');
}

main()
  .catch((err) => {
    console.error('Error aplicando DDL:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
