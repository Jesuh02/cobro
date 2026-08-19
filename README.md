# Cobro

Monorepo para una app de cobros conectada a PostgreSQL/Supabase.

- Backend: TypeScript, NestJS, Prisma y PostgreSQL.
- Frontend: Flutter + Dart para Web, Android, iOS y escritorio.

## Estructura

```text
backend/
  src/
    modules/
      cobros/
    common/
    config/
  prisma/
  database/

frontend/
  lib/
    app/
    core/
    features/
```

## Base De Datos

La aplicacion usa exclusivamente PostgreSQL en Supabase. No hay base de datos
local soportada por el proyecto.

El modelo principal vive en el esquema `public` y usa nombres en espanol:
clientes, rutas, creditos, planes de pago, cuotas, pagos, caja menor, gastos y
presupuesto.

El DDL 4FN esta en:

```text
backend/database/ddl_cobros_4fn.sql
```

La migracion inicial usa ese mismo DDL:

```text
backend/prisma/migrations/20260817000000_init/migration.sql
```

La vista `cobros.vista_presupuesto_actual` calcula:

```text
PRESUPUESTO = CAJA MENOR + RECAUDADO - GASTOS - CREDITOS
```

## Backend

```bash
cd backend
cp .env.example .env
npm install
npm run prisma:generate
npm run prisma:migrate
npm run seed
npm run start:dev
```

Antes de iniciar, configura `DATABASE_URL` con el connection string de Supabase:

```text
postgresql://postgres:<DB_PASSWORD>@db.<PROJECT_REF>.supabase.co:5432/postgres?schema=public
```

API base:

```text
http://localhost:3000/api/v1
```

Autenticacion:

- `POST /api/v1/auth/login`
- `POST /api/v1/auth/bootstrap-admin` solo crea un administrador si no existe uno con contrasena valida.
- `POST /api/v1/usuarios` crea empleados y requiere usuario administrador.

El seed crea un administrador inicial si no existe. Puedes cambiarlo con
`ADMIN_USERNAME`, `ADMIN_PASSWORD`, `ADMIN_EMAIL` y `ADMIN_FULL_NAME`.
Los endpoints de negocio requieren `Authorization: Bearer <token>`.

Endpoints principales:

- `GET /api/v1/catalogos`
- `GET|POST /api/v1/clientes`
- `GET /api/v1/rutas`
- `GET /api/v1/cobros/ruta`
- `POST /api/v1/creditos`
- `GET /api/v1/creditos/:id/cuotas`
- `POST /api/v1/pagos`
- `GET|POST /api/v1/caja-menor/movimientos`
- `GET /api/v1/presupuesto`

## Notificaciones al cliente

El backend envia notificaciones transaccionales despues de confirmar en base de
datos estos eventos:

- credito aprobado;
- cada pago o abono registrado, con saldo, cuotas restantes y proxima fecha;
- credito finalizado.

El correo usa Resend como proveedor principal y Brevo SMTP como respaldo. Los
mensajes de WhatsApp se envian con YCloud. Activa y configura las variables del
bloque `Notificaciones transaccionales` de `backend/.env.example` en tu archivo
local `backend/.env`.

Para mensajes de WhatsApp iniciados por la empresa se recomienda crear tres
plantillas de categoria `Utility`, idioma `es_CO`, y registrar sus nombres en:

- `YCLOUD_TEMPLATE_CREDIT_APPROVED`: 6 variables en este orden: nombre, monto
  aprobado, total, numero de cuotas, valor de cuota y fecha de primera cuota.
- `YCLOUD_TEMPLATE_PAYMENT_RECEIVED`: 6 variables: nombre, monto pagado, cuotas
  restantes, saldo, valor de proxima cuota y fecha de proxima cuota.
- `YCLOUD_TEMPLATE_CREDIT_COMPLETED`: 3 variables: nombre, monto del credito y
  nombre de la empresa.

Si la cuenta YCloud tiene habilitado Direct Send, se puede usar el texto
completo sin plantillas estableciendo `YCLOUD_USE_DIRECT_SEND=true`.

## Frontend

```bash
cd frontend
flutter create . --platforms=web,android,ios
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

En Android emulator usa:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```
