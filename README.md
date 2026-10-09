# Sistema de Cobro & Cartera (CobroD)

Monorepo integral para la gestión y administración financiera de microcréditos, cobranza en ruta, tesorería (caja menor), ruteo georreferenciado y notificaciones transaccionales multicanal.

---

## 💡 ¿Qué problema resuelve este proyecto?

En el modelo tradicional de **microcréditos y cobranza en ruta** (puerta a puerta / cartera diaria), la operativa suele gestionarse de manera manual o empírica (planillas de papel, cuadernos o mensajería informal). Esto genera descontrol financiero, pérdida de capital y riesgos operativos.

**CobroD** sistematiza y asegura todo el ciclo operativo resolviendo los siguientes problemas críticos:

1. **Descuadres de caja y fuga de dinero**:
   - *Problema*: Dificultad para conciliar al final del día el dinero recaudado frente a los nuevos créditos desembolsados y los gastos en ruta (combustible, viáticos) de cada cobrador.
   - *Solución*: Módulo estricto de **Caja Menor y Arqueo Diario** con validación de saldos en tiempo real mediante la ecuación contable:
     $$\text{PRESUPUESTO} = \text{CAJA MENOR} + \text{RECAUDADO} - \text{CRÉDITOS} - \text{GASTOS}$$

2. **Inconsistencias, fraude y cobros duplicados en campo**:
   - *Problema*: Mala conectividad celular en ruta que provoca registros repetidos, o cobradores que no pueden validar el estado de cuenta real del cliente.
   - *Solución*: Backend con **bloqueos pesimistas (`FOR UPDATE`)**, **ventana de idempotencia de 30 segundos** y **cola de mutaciones offline en Flutter** que almacena abonos localmente y sincroniza de forma segura al recuperar la señal.

3. **Ineficiencia logística y sobrecostos de transporte**:
   - *Problema*: Cobradores recorriendo la ciudad sin un orden geográfico, perdiendo tiempo y dinero en traslados desordenados.
   - *Solución*: **Georreferenciación GPS** de clientes en mapa interactivo y cálculo de **ruta diaria óptima** mediante el algoritmo **Dijkstra** integrado con el motor **OSRM**.

4. **Falta de comprobantes y desconfianza del cliente**:
   - *Problema*: Los clientes no reciben constancia inmediata o clara de sus abonos y saldos pendientes.
   - *Solución*: Generación y despacho automático de recibos transaccionales por **WhatsApp a costo \$0** (usando Evolution API / Baileys) y por correo electrónico.

5. **Complejidad y errores en liquidación financiera**:
   - *Problema*: Cálculo manual erróneo de amortizaciones, intereses, cuotas dominicales o penalizaciones por mora.
   - *Solución*: Motor financiero automatizado de amortización (cuotas fijas, liquidación en cascada, refinanciación asistida) y **reportes contables exportables a Excel (`exceljs`)**.

---

## 1. Arquitectura del Monorepo

![Diagrama de Arquitectura](arquitectura.svg)

El repositorio está organizado en aplicaciones y servicios desacoplados:

- **Backend (`backend/`)**: API REST construida con **NestJS**, **TypeScript**, **Prisma ORM** y **CockroachDB** en producción (**PostgreSQL 15** en Docker local). Implementa arquitectura modular, transacciones ACID con bloqueos pesimistas, control de concurrencia y validaciones de seguridad de grado financiero.
- **Frontend App (`frontend/`)**: Cliente multiplataforma desarrollado en **Flutter (Dart 3)**, orientado principalmente a Web (CanvasKit/HTML) y adaptable a dispositivos móviles (Android/iOS). Incluye ruteo interactivo sobre mapas, soporte para mutaciones offline y componentes neomórficos.

- **Infraestructura Docker (`docker-compose.yml` y `docker/`)**: Entorno contenerizado para despliegue local inmediato (plug-and-play) y pasarela de mensajería independiente con **Evolution API v2** (WhatsApp vía Baileys a costo \$0).

---

## 2. Base de Datos: Arquitectura y Compatibilidad

### Motor en Producción: CockroachDB Cloud
En producción, el sistema opera sobre **CockroachDB Cloud**, garantizando resiliencia, alta disponibilidad y distribución geográfica con compatibilidad ANSI SQL / PostgreSQL.

### Motor en Desarrollo Local: PostgreSQL 15
Para el desarrollo local ágil, autónomo y desconectado, se utiliza **PostgreSQL 15** (`postgres:15-alpine` vía Docker Compose).

- **Estandarización y Portabilidad**: El esquema DDL original (`backend/database/cockroach_init_cobrod.sql`) y el modelo unificado Prisma (`tbl_*`) son 100% compatibles tanto con CockroachDB Cloud en producción como con PostgreSQL 15 en Docker local.

- **Sincronización Ágil y Restricciones CHECK**: Se utiliza `pnpm exec prisma db push` para mantener sincronizado el esquema. Dado que Prisma no gestiona restricciones `CHECK` de forma nativa en su esquema, el script `backend/prisma/seed.ts` las inyecta de forma idempotente (`gas_monto > 0`, `cre_total > 0`, saldos no negativos, etc.).

---

## 3. Despliegue Rápido Local con Docker (Plug & Play)

El proyecto incluye un entorno preconfigurado que levanta la base de datos, la API y la aplicación web en un solo comando:

```bash
docker compose up -d --build
```

### Servicios incluidos:
1. **`postgres-db`**: Base de datos PostgreSQL 15 (`postgres:15-alpine`) en el puerto `5432`, con persistencia en el volumen `cobro_pg_data` y alias de red `postgres-db.supabase.co`.
2. **`backend`**: Servidor NestJS en el puerto `3000`. Al iniciar, sincroniza automáticamente la base de datos (`npx prisma db push`), ejecuta el seed compilado e inicializa la API.
3. **`frontend`**: Cliente Flutter Web compilado en modo producción y servido a través de un contenedor ligero de Nginx en el puerto `8081`.

### Acceso inmediato:
- **Aplicación Web**: [`http://localhost:8081/app/`](http://localhost:8081/app/)
- **API Backend**: [`http://127.0.0.1:3000/api/v1`](http://127.0.0.1:3000/api/v1)

### Credenciales iniciales por defecto:
- **Usuario**: `prueba`
- **Contraseña**: `adminprueba!BB`
- **Rol**: `ADMINISTRADOR`

*(Para detener el entorno: `docker compose down`, o `docker compose down -v` para reiniciar datos desde cero).*

---

## 4. Desarrollo Local Manual

Si prefieres ejecutar los servicios de forma individual en tu máquina local:

### 4.1 Backend (NestJS + Prisma)

Requisitos: Node.js 22+, pnpm y una instancia de PostgreSQL en ejecución.

```bash
cd backend
cp .env.example .env
pnpm install
pnpm run prisma:generate
pnpm exec prisma db push
pnpm run seed
pnpm run start:dev
```

- La API local quedará disponible en `http://127.0.0.1:3000/api/v1`.
- El script de seed creará los catálogos y el administrador inicial utilizando las variables `ADMIN_USERNAME`, `ADMIN_PASSWORD`, etc., definidas en `.env`.

### 4.2 Frontend (Flutter Web)

Requisitos: Flutter SDK (canal `stable` ^3.6.0) y Google Chrome o Brave.

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

*(En emulador de Android puede utilizarse `--dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1`).*


## 5. Módulos y Funcionalidades Principales

- **Autenticación y Tenancy**: Soporte multi-organización, tokens JWT de corta duración, control de acceso basado en roles (`ADMINISTRADOR`, `COBRADOR`, `AUDITOR`, `SUPER_ADMIN`) y contraseñas protegidas mediante `scrypt$v2` nativo (`node:crypto`).
- **Logística de Rutas y Ruteo Inteligente**: Asignación de cartera diaria por cobrador, geolocalización GPS de clientes, mapas interactivos con FlutterMap y cálculo de ruta óptima en tiempo real utilizando el algoritmo **Dijkstra** y el motor **OSRM**.
- **Gestión Integral de Créditos**: Simulación y amortización financiera (cuotas fijas, desglose exacto de capital e intereses, exclusión de domingos), validación de fondos en caja menor antes del desembolso y refinanciación de saldos.
- **Recaudo Transaccional Seguro**: Aplicación de pagos con bloqueo pesimista `FOR UPDATE`, ventana de idempotencia de 30 segundos para evitar cobros dobles por latencia de red y liquidación automática de cuotas en cascada.
- **Caja Menor y Presupuesto**: Apertura y arqueo diario de caja, vigencia horaria con cierre automático, registro de gastos operativos con validación de saldo disponible y consolidación contable en tiempo real:
  $$\text{PRESUPUESTO} = \text{CAJA MENOR} + \text{RECAUDADO} - \text{CRÉDITOS} - \text{GASTOS}$$
- **Exportaciones Contables en Excel**: Generación de reportes operativos (Cobros de Ruta, Créditos, Movimientos de Caja Menor) formateados con `exceljs`, visor interactivo previo a la descarga y almacenamiento en Cloudflare R2 con URLs presignadas.
- **Notificaciones Multicanal**:
  - **WhatsApp**: Conector desacoplado con soporte para **Evolution API v2** (`docker/whatsapp/`, Baileys WebSocket a costo \$0) y conector corporativo con **Meta Cloud API / YCloud**.
  - **Correo Electrónico**: Servidor SMTP con soporte para alias y plantillas HTML dinámicas (Gmail / Nodemailer).

---

## 6. Controles de Seguridad Incluidos

- **Consultas Parametrizadas**: Consultas SQL protegidas y tipadas mediante Prisma y TypeORM/SQL nativo parametrizado, con identificadores normalizados a formato UUID.
- **Contraseñas Endurecidas**: Algoritmo `scrypt` con parámetros de alto costo computacional ($N=32768, r=8, p=3$), generación de salt aleatorio criptográfico y re-hashing automático en login si se detectan parámetros obsoletos.
- **Protección de Red y Cabeceras**: Helmet habilitado, CORS con lista blanca estricta, rate-limiting global y reforzado para endpoints sensibles de autenticación (`/auth/login`).
- **Resiliencia Offline en Campo**: Cola de mutaciones offline en el cliente Flutter para registrar abonos y clientes en zonas sin cobertura celular, sincronizando en segundo plano al reconectar.
- **Almacenamiento Seguro**: Archivos temporales y reportes protegidos en buckets privados de Cloudflare R2 mediante firmas temporales de corta expiración (TTL entre 60 y 900 segundos).
- **Validación de Webhooks**: Verificación estricta de firmas HMAC y marcas de tiempo para webhooks entrantes de pasarelas de pago y mensajería.

