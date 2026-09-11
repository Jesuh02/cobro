# WhatsApp Gateway (Evolution API)

Stack de infraestructura para la pasarela de notificaciones de WhatsApp de Cobro mediante **Evolution API v2.3.7** (basado en el motor WebSocket nativo **Baileys**).

## Estructura

```text
docker/whatsapp/
├── docker-compose.yml   # Definición de contenedores (PostgreSQL + Evolution API)
├── .env.example         # Plantilla de variables de entorno
├── .env                 # Variables locales (ignorado en Git)
├── start.sh             # Script de arranque e inicialización automática
└── README.md            # Esta documentación
```

## Requisitos
- Docker y Docker Compose instalados en el sistema.

## Arranque Rápido

Para levantar los contenedores y preparar la instancia:
```bash
./docker/whatsapp/start.sh
```

El script:
1. Inicia PostgreSQL 15 y Evolution API 2.3.7.
2. Espera a que los servicios estén listos y saludables.
3. Registra la instancia `cobrod` con motor Baileys.
4. Te muestra la URL para escanear el código QR en el navegador:
   `http://localhost:8080/instance/connect/cobrod`

## Comandos Útiles

- **Ver logs en tiempo real:**
  ```bash
  docker compose -f docker/whatsapp/docker-compose.yml logs -f evolution-api
  ```
- **Detener el stack:**
  ```bash
  docker compose -f docker/whatsapp/docker-compose.yml down
  ```
- **Reiniciar el stack:**
  ```bash
  docker compose -f docker/whatsapp/docker-compose.yml restart
  ```

