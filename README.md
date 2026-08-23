# Cobro

Monorepo de una aplicación de cobros conectada a PostgreSQL/Supabase.

- Backend: TypeScript, NestJS, Prisma y PostgreSQL.
- Frontend: Flutter para Web, Android, iOS y escritorio.

## Desarrollo local

```bash
cd backend
cp .env.example .env
npm install
npm run prisma:generate
npm run prisma:migrate
npm run seed
npm run start:dev
```

El seed es el único mecanismo para crear el primer administrador. Configura
`ADMIN_USERNAME`, `ADMIN_PASSWORD`, `ADMIN_EMAIL` y `ADMIN_FULL_NAME` antes de
ejecutarlo. No existe un endpoint público para crear administradores.

La API local queda en `http://127.0.0.1:3000/api/v1`. Todos los endpoints de
negocio requieren `Authorization: Bearer <token>`; el acceso inicial se obtiene
con `POST /api/v1/auth/login`.

Para el frontend:

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

En el emulador de Android puede usarse
`http://10.0.2.2:3000/api/v1`. Una compilación release rechaza HTTP salvo para
direcciones de loopback.

## Controles de seguridad incluidos

- Consultas SQL parametrizadas con Prisma y reglas de lint que prohíben las API
  SQL inseguras. Los identificadores de ruta también tienen formato y longitud
  limitados.
- Autenticación con tokens firmados de corta duración, algoritmo y claims
  estrictos, revalidación del usuario en cada solicitud y contraseñas con
  `scrypt` endurecido. Los hashes anteriores se actualizan al iniciar sesión.
- Autorización por rol y permiso en el backend. Ocultar un botón en Flutter no
  se considera una barrera de seguridad.
- Límite de intentos global y más estricto para login; límites de cuerpo,
  tiempos de espera HTTP y tope de filas/tamaño en exportaciones.
- CORS por lista explícita, cabeceras de Helmet, HTTPS forzado en producción,
  errores públicos genéricos y registros sin cuerpos ni credenciales.
- Webhooks de YCloud validados con HMAC, marca de tiempo, endpoint y protección
  contra repetición.
- Archivos R2 privados y descargas mediante URL firmada de expiración corta.
- RLS habilitado y acceso de Supabase `anon`/`authenticated` revocado en las
  tablas del backend.
- CSP y otras cabeceras defensivas para el frontend web en `frontend/web/_headers`.

Ejecuta estos controles antes de integrar o desplegar:

```bash
cd backend
npm run lint
npm test -- --runInBand
npm run build
npm run security:audit
```

## Despliegue seguro

1. Crea secretos aleatorios nuevos; no copies los valores de desarrollo. En
   producción `AUTH_TOKEN_SECRET` debe tener al menos 64 caracteres y
   `ADMIN_PASSWORD` debe ser única y tener entre 12 y 128 caracteres.
2. Aplica las migraciones como propietario con `npx prisma migrate deploy`.
   Después ejecuta una vez `backend/database/runtime_role.sql.example`,
   reemplazando la contraseña de ejemplo.
3. Cambia `DATABASE_URL` para utilizar exclusivamente el usuario sin privilegios
   `cobro_api`, con `sslmode=require` o `verify-full`. La aplicación rechaza al
   superusuario `postgres` en producción.
4. Define `NODE_ENV=production`, un `CORS_ORIGIN` HTTPS exacto,
   `ENFORCE_HTTPS=true` y `TRUST_PROXY_HOPS` con el número real de proxies de
   confianza. No expongas el puerto de NestJS directamente a Internet.
5. Mantén R2 privado. Configura `R2_SIGNED_URL_TTL_SECONDS` entre 60 y 900
   segundos y concede a su credencial solo acceso al bucket requerido.
6. Si activas YCloud, configura `YCLOUD_WEBHOOK_SECRET` y
   `YCLOUD_WEBHOOK_ENDPOINT_ID`, y registra en YCloud el endpoint HTTPS exacto.
7. Sirve Flutter detrás de un proveedor que aplique `frontend/web/_headers`.
   Verifica las cabeceras en la URL pública; algunos hosts ignoran ese archivo.
8. Conserva los secretos en el gestor del proveedor, nunca en Git, imágenes
   Docker, logs ni artefactos. Rota cualquier secreto que alguna vez haya sido
   compartido o publicado.
9. Ejecuta pruebas, auditoría de dependencias, copia de seguridad y restauración
   ensayada antes de cada despliegue.

El limitador incluido funciona por proceso. Si se ejecutan varias réplicas,
configura un almacenamiento compartido (por ejemplo Redis en el adaptador de
throttling) y aplica límites adicionales en el proxy, WAF o CDN. También deben
existir alertas de autenticación fallida, errores 5xx y consumo anormal.

## Base de datos

El modelo principal está en el esquema `public`. El DDL inicial y las
migraciones se encuentran en:

```text
backend/database/ddl_cobros_4fn.sql
backend/prisma/migrations/
```

La vista de presupuesto calcula:

```text
PRESUPUESTO = CAJA MENOR + RECAUDADO - CREDITOS - GASTOS
```

## Notificaciones

El correo usa Resend y puede usar Brevo SMTP como respaldo. WhatsApp usa YCloud.
Las variables y sus valores seguros de ejemplo están documentados en
`backend/.env.example`. Para mensajes iniciados por la empresa deben emplearse
plantillas `Utility` aprobadas:

- `YCLOUD_TEMPLATE_CREDIT_APPROVED`
- `YCLOUD_TEMPLATE_PAYMENT_RECEIVED`
- `YCLOUD_TEMPLATE_CREDIT_COMPLETED`

`YCLOUD_USE_DIRECT_SEND` debe permanecer desactivado salvo que la cuenta y el
caso de uso lo requieran expresamente.
