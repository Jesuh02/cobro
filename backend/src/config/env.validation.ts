import { isIP } from 'node:net';

type RawConfig = Record<string, string | undefined>;

type ValidatedConfig = {
  AUTH_TOKEN_SECRET: string;
  AUTH_TOKEN_TTL_SECONDS: number;
  CACHE_MAX_ENTRIES: number;
  CACHE_TTL_MS: number;
  DATABASE_URL: string;
  ENFORCE_HTTPS: boolean;
  HOST: string;
  NODE_ENV: 'development' | 'test' | 'production';
  PORT: number;
  CORS_ORIGIN: string;
  TRUST_PROXY_HOPS: number;
  NOTIFICATIONS_ENABLED: boolean;
  NOTIFICATION_BRAND_NAME: string;
  NOTIFICATION_REPLY_TO?: string;
  NOTIFICATION_TIME_ZONE: string;
  OSRM_BASE_URL: string;
  OSRM_TIMEOUT_MS: number;
  SMTP_HOST: string;
  SMTP_PORT: number;
  SMTP_SECURE: boolean;
  SMTP_USER?: string;
  SMTP_PASSWORD?: string;
  SMTP_FROM_NAME: string;
  SMTP_FROM_EMAIL?: string;
  SMTP_REPLY_TO?: string;
  R2_ACCESS_KEY_ID?: string;
  R2_ACCOUNT_ID?: string;
  R2_BUCKET_NAME?: string;
  R2_SIGNED_URL_TTL_SECONDS: number;
  R2_SECRET_ACCESS_KEY?: string;
  WHATSAPP_PROVIDER: 'evolution' | 'ycloud';
  EVOLUTION_ENABLED: boolean;
  EVOLUTION_BASE_URL: string;
  EVOLUTION_API_KEY?: string;
  EVOLUTION_INSTANCE_NAME: string;
  YCLOUD_API_KEY?: string;
  YCLOUD_BASE_URL: string;
  YCLOUD_ENABLED: boolean;
  YCLOUD_INSTANCE_ID?: string;
  YCLOUD_WEBHOOK_ENDPOINT_ID?: string;
  YCLOUD_WEBHOOK_SECRET?: string;
  YCLOUD_WEBHOOK_TOLERANCE_SECONDS: number;
  YCLOUD_WHATSAPP_NUMBER?: string;
  YCLOUD_USE_DIRECT_SEND: boolean;
  YCLOUD_TEMPLATE_LANGUAGE: string;
  YCLOUD_TEMPLATE_CREDIT_APPROVED?: string;
  YCLOUD_TEMPLATE_PAYMENT_RECEIVED?: string;
  YCLOUD_TEMPLATE_CREDIT_COMPLETED?: string;
  WHATSAPP_DEFAULT_COUNTRY_CODE: string;
};

const allowedEnvironments = ['development', 'test', 'production'] as const;

export function validateEnv(rawConfig: RawConfig): ValidatedConfig {
  const config: RawConfig = { ...process.env, ...rawConfig };
  const nodeEnv = config.NODE_ENV ?? 'development';

  if (!allowedEnvironments.includes(nodeEnv as ValidatedConfig['NODE_ENV'])) {
    throw new Error('NODE_ENV must be development, test or production');
  }

  if (!config.DATABASE_URL) {
    throw new Error('DATABASE_URL is required');
  }

  if (config.DATABASE_URL.includes('<') || config.DATABASE_URL.includes('>')) {
    throw new Error('DATABASE_URL contains unresolved placeholders');
  }

  assertRuntimeDatabaseUrl(config.DATABASE_URL, nodeEnv);

  const port = Number(config.PORT ?? 3000);

  if (!Number.isInteger(port) || port <= 0 || port > 65_535) {
    throw new Error('PORT must be an integer between 1 and 65535');
  }

  const host =
    config.HOST?.trim() || (nodeEnv === 'production' ? '0.0.0.0' : '127.0.0.1');
  assertListenHost(host);

  const authTokenSecret =
    config.AUTH_TOKEN_SECRET ?? 'local-development-secret-change-me-please';

  if (
    nodeEnv === 'production' &&
    (authTokenSecret.length < 64 ||
      authTokenSecret === 'local-development-secret-change-me-please')
  ) {
    throw new Error(
      'AUTH_TOKEN_SECRET must be a unique secret with at least 64 characters',
    );
  }

  const authTokenTtlSeconds = readIntegerInRange(
    config.AUTH_TOKEN_TTL_SECONDS,
    'AUTH_TOKEN_TTL_SECONDS',
    nodeEnv === 'production' ? 3600 : 43_200,
    300,
    86_400,
  );
  const trustProxyHops = readIntegerInRange(
    config.TRUST_PROXY_HOPS,
    'TRUST_PROXY_HOPS',
    nodeEnv === 'production' ? 1 : 0,
    0,
    5,
  );
  const enforceHttps = readBoolean(
    config.ENFORCE_HTTPS,
    'ENFORCE_HTTPS',
    nodeEnv === 'production',
  );

  if (enforceHttps && trustProxyHops === 0) {
    throw new Error(
      'TRUST_PROXY_HOPS must be at least 1 when ENFORCE_HTTPS is true',
    );
  }

  const corsOrigin = validateCorsOrigins(config.CORS_ORIGIN, nodeEnv);

  const notificationsEnabled = readBoolean(
    config.NOTIFICATIONS_ENABLED,
    'NOTIFICATIONS_ENABLED',
    false,
  );
  const whatsappProvider = (
    config.WHATSAPP_PROVIDER?.trim().toLowerCase() || 'evolution'
  ) as 'evolution' | 'ycloud';
  if (!['evolution', 'ycloud'].includes(whatsappProvider)) {
    throw new Error('WHATSAPP_PROVIDER must be "evolution" or "ycloud"');
  }

  const evolutionEnabled = readBoolean(
    config.EVOLUTION_ENABLED,
    'EVOLUTION_ENABLED',
    true,
  );
  const evolutionBaseUrl =
    config.EVOLUTION_BASE_URL?.trim() || 'http://127.0.0.1:8080';
  assertHttpUrl(evolutionBaseUrl, 'EVOLUTION_BASE_URL', nodeEnv);
  const evolutionApiKey = optional(config.EVOLUTION_API_KEY);
  const evolutionInstanceName =
    config.EVOLUTION_INSTANCE_NAME?.trim() || 'cobrod';

  const ycloudEnabled = readBoolean(
    config.YCLOUD_ENABLED,
    'YCLOUD_ENABLED',
    false,
  );
  const ycloudUseDirectSend = readBoolean(
    config.YCLOUD_USE_DIRECT_SEND,
    'YCLOUD_USE_DIRECT_SEND',
    false,
  );

  if (
    whatsappProvider === 'ycloud' &&
    ycloudEnabled &&
    (!config.YCLOUD_API_KEY || !config.YCLOUD_WHATSAPP_NUMBER)
  ) {
    throw new Error(
      'YCLOUD_API_KEY and YCLOUD_WHATSAPP_NUMBER are required when YCLOUD_ENABLED is true and WHATSAPP_PROVIDER is ycloud',
    );
  }

  const ycloudBaseUrl = config.YCLOUD_BASE_URL ?? 'https://api.ycloud.com/v2';
  assertHttpUrl(ycloudBaseUrl, 'YCLOUD_BASE_URL', nodeEnv);
  if (
    nodeEnv === 'production' &&
    ycloudEnabled &&
    new URL(ycloudBaseUrl).hostname.toLowerCase() !== 'api.ycloud.com'
  ) {
    throw new Error('YCLOUD_BASE_URL must use the official YCloud API host');
  }
  const osrmBaseUrl =
    optional(config.OSRM_BASE_URL) ?? 'https://router.project-osrm.org';
  assertHttpUrl(osrmBaseUrl, 'OSRM_BASE_URL', nodeEnv);

  if (nodeEnv === 'production') {
    if (!optional(config.OSRM_BASE_URL)) {
      throw new Error(
        'OSRM_BASE_URL is required in production; use a controlled routing service',
      );
    }
    if (new URL(osrmBaseUrl).hostname === 'router.project-osrm.org') {
      throw new Error(
        'The public OSRM demo cannot be used in production; configure a controlled routing service',
      );
    }
  }

  const webhookSecret = optional(config.YCLOUD_WEBHOOK_SECRET);
  if (webhookSecret && webhookSecret.length < 32) {
    throw new Error('YCLOUD_WEBHOOK_SECRET must have at least 32 characters');
  }

  assertEmailLike(
    optional(config.NOTIFICATION_REPLY_TO),
    'NOTIFICATION_REPLY_TO',
  );
  assertEmailLike(optional(config.SMTP_FROM_EMAIL), 'SMTP_FROM_EMAIL');
  assertEmailLike(optional(config.SMTP_REPLY_TO), 'SMTP_REPLY_TO');
  assertEmailLike(optional(config.SMTP_USER), 'SMTP_USER');
  assertSafeHeaderValue(
    config.NOTIFICATION_BRAND_NAME?.trim() || 'Cobro',
    'NOTIFICATION_BRAND_NAME',
    80,
  );
  assertSafeHeaderValue(
    config.SMTP_FROM_NAME?.trim() ||
      config.NOTIFICATION_BRAND_NAME?.trim() ||
      'Cobro',
    'SMTP_FROM_NAME',
    80,
  );

  const smtpHost = config.SMTP_HOST?.trim() || 'smtp.gmail.com';
  assertHostname(smtpHost, 'SMTP_HOST');

  const smtpPort = readOptionalPositiveInteger(
    config.SMTP_PORT,
    'SMTP_PORT',
    465,
  );

  const smtpSecure =
    config.SMTP_SECURE !== undefined
      ? readBoolean(config.SMTP_SECURE, 'SMTP_SECURE', smtpPort === 465)
      : smtpPort === 465;

  return {
    AUTH_TOKEN_SECRET: authTokenSecret,
    AUTH_TOKEN_TTL_SECONDS: authTokenTtlSeconds,
    CACHE_MAX_ENTRIES: readOptionalPositiveInteger(
      config.CACHE_MAX_ENTRIES,
      'CACHE_MAX_ENTRIES',
      2000,
    ),
    CACHE_TTL_MS: readOptionalPositiveInteger(
      config.CACHE_TTL_MS,
      'CACHE_TTL_MS',
      30000,
    ),
    NODE_ENV: nodeEnv as ValidatedConfig['NODE_ENV'],
    PORT: port,
    HOST: host,
    DATABASE_URL: config.DATABASE_URL,
    CORS_ORIGIN: corsOrigin,
    ENFORCE_HTTPS: enforceHttps,
    TRUST_PROXY_HOPS: trustProxyHops,
    NOTIFICATIONS_ENABLED: notificationsEnabled,
    NOTIFICATION_BRAND_NAME: config.NOTIFICATION_BRAND_NAME?.trim() || 'Cobro',
    NOTIFICATION_REPLY_TO: optional(config.NOTIFICATION_REPLY_TO),
    NOTIFICATION_TIME_ZONE:
      config.NOTIFICATION_TIME_ZONE?.trim() || 'America/Bogota',
    OSRM_BASE_URL: osrmBaseUrl,
    OSRM_TIMEOUT_MS: readOptionalPositiveInteger(
      config.OSRM_TIMEOUT_MS,
      'OSRM_TIMEOUT_MS',
      9000,
    ),
    SMTP_HOST: smtpHost,
    SMTP_PORT: smtpPort,
    SMTP_SECURE: smtpSecure,
    SMTP_USER: optional(config.SMTP_USER),
    SMTP_PASSWORD: optional(config.SMTP_PASSWORD),
    SMTP_FROM_NAME:
      config.SMTP_FROM_NAME?.trim() ||
      config.NOTIFICATION_BRAND_NAME?.trim() ||
      'Cobro',
    SMTP_FROM_EMAIL:
      optional(config.SMTP_FROM_EMAIL) || optional(config.SMTP_USER),
    SMTP_REPLY_TO:
      optional(config.SMTP_REPLY_TO) || optional(config.NOTIFICATION_REPLY_TO),
    R2_ACCESS_KEY_ID: optional(config.R2_ACCESS_KEY_ID),
    R2_ACCOUNT_ID: optional(config.R2_ACCOUNT_ID),
    R2_BUCKET_NAME: optional(config.R2_BUCKET_NAME),
    R2_SIGNED_URL_TTL_SECONDS: readIntegerInRange(
      config.R2_SIGNED_URL_TTL_SECONDS,
      'R2_SIGNED_URL_TTL_SECONDS',
      300,
      60,
      900,
    ),
    R2_SECRET_ACCESS_KEY: optional(config.R2_SECRET_ACCESS_KEY),
    WHATSAPP_PROVIDER: whatsappProvider,
    EVOLUTION_ENABLED: evolutionEnabled,
    EVOLUTION_BASE_URL: evolutionBaseUrl,
    EVOLUTION_API_KEY: evolutionApiKey,
    EVOLUTION_INSTANCE_NAME: evolutionInstanceName,
    YCLOUD_API_KEY: optional(config.YCLOUD_API_KEY),
    YCLOUD_BASE_URL: ycloudBaseUrl,
    YCLOUD_ENABLED: ycloudEnabled,
    YCLOUD_INSTANCE_ID: optional(config.YCLOUD_INSTANCE_ID),
    YCLOUD_WEBHOOK_ENDPOINT_ID: optional(config.YCLOUD_WEBHOOK_ENDPOINT_ID),
    YCLOUD_WEBHOOK_SECRET: webhookSecret,
    YCLOUD_WEBHOOK_TOLERANCE_SECONDS: readIntegerInRange(
      config.YCLOUD_WEBHOOK_TOLERANCE_SECONDS,
      'YCLOUD_WEBHOOK_TOLERANCE_SECONDS',
      300,
      30,
      900,
    ),
    YCLOUD_WHATSAPP_NUMBER: optional(config.YCLOUD_WHATSAPP_NUMBER),
    YCLOUD_USE_DIRECT_SEND: ycloudUseDirectSend,
    YCLOUD_TEMPLATE_LANGUAGE:
      config.YCLOUD_TEMPLATE_LANGUAGE?.trim() || 'es_CO',
    YCLOUD_TEMPLATE_CREDIT_APPROVED: optional(
      config.YCLOUD_TEMPLATE_CREDIT_APPROVED,
    ),
    YCLOUD_TEMPLATE_PAYMENT_RECEIVED: optional(
      config.YCLOUD_TEMPLATE_PAYMENT_RECEIVED,
    ),
    YCLOUD_TEMPLATE_CREDIT_COMPLETED: optional(
      config.YCLOUD_TEMPLATE_CREDIT_COMPLETED,
    ),
    WHATSAPP_DEFAULT_COUNTRY_CODE:
      config.WHATSAPP_DEFAULT_COUNTRY_CODE?.replace(/\D/g, '') || '57',
  };
}

function optional(value: string | undefined) {
  const normalized = value?.trim();
  return normalized ? normalized : undefined;
}

function readBoolean(
  rawValue: string | undefined,
  name: string,
  fallback: boolean,
) {
  if (rawValue === undefined) {
    return fallback;
  }

  if (rawValue.toLowerCase() === 'true') {
    return true;
  }

  if (rawValue.toLowerCase() === 'false') {
    return false;
  }

  throw new Error(`${name} must be true or false`);
}

function assertHttpUrl(value: string, name: string, nodeEnv: string) {
  let parsed: URL;

  try {
    parsed = new URL(value);
  } catch {
    throw new Error(`${name} must be a valid URL`);
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error(`${name} must use HTTP or HTTPS`);
  }

  const isInternalHost = [
    '127.0.0.1',
    'localhost',
    'evolution-api',
    'host.docker.internal',
  ].includes(parsed.hostname.toLowerCase());

  if (nodeEnv === 'production' && parsed.protocol !== 'https:' && !isInternalHost) {
    throw new Error(`${name} must use HTTPS in production`);
  }

  if (parsed.username || parsed.password || parsed.hash) {
    throw new Error(`${name} cannot contain credentials or URL fragments`);
  }
}

function assertRuntimeDatabaseUrl(databaseUrl: string, nodeEnv: string) {
  let parsedUrl: URL;

  try {
    parsedUrl = new URL(databaseUrl);
  } catch {
    throw new Error('DATABASE_URL must be a valid PostgreSQL URL');
  }

  if (!['postgresql:', 'postgres:'].includes(parsedUrl.protocol)) {
    throw new Error('DATABASE_URL must use the PostgreSQL protocol');
  }

  const hostname = parsedUrl.hostname.toLowerCase();
  const forbiddenLocalHosts = new Set(['localhost', '127.0.0.1', '::1']);

  if (
    forbiddenLocalHosts.has(hostname) ||
    hostname.startsWith('10.') ||
    hostname.startsWith('192.168.') ||
    /^172\.(1[6-9]|2\d|3[0-1])\./.test(hostname)
  ) {
    throw new Error(
      'DATABASE_URL must point to a remote managed database, not a local database',
    );
  }

  const isSupabaseHost =
    hostname.endsWith('.supabase.co') || hostname.endsWith('.supabase.com');
  const isCockroachCloudHost = hostname.endsWith('.cockroachlabs.cloud');

  if (!isSupabaseHost && !isCockroachCloudHost) {
    throw new Error(
      'DATABASE_URL must point to a supported database host: Supabase or CockroachDB Cloud',
    );
  }

  if (nodeEnv === 'production') {
    const sslMode = parsedUrl.searchParams.get('sslmode')?.toLowerCase();
    if (!['require', 'verify-ca', 'verify-full'].includes(sslMode ?? '')) {
      throw new Error(
        'DATABASE_URL must set sslmode=require or stronger in production',
      );
    }

    const username = decodeURIComponent(parsedUrl.username).toLowerCase();
    const privilegedUser =
      username === 'postgres' ||
      username === 'root' ||
      username.startsWith('postgres.');
    if (privilegedUser) {
      throw new Error(
        'DATABASE_URL must use a dedicated least-privilege runtime role, not a privileged database user',
      );
    }
  }
}

function validateCorsOrigins(rawValue: string | undefined, nodeEnv: string) {
  const fallback = nodeEnv === 'production' ? '' : '*';
  const value = rawValue?.trim() || fallback;

  if (!value) {
    throw new Error('CORS_ORIGIN is required in production');
  }

  if (value === '*') {
    if (nodeEnv === 'production') {
      throw new Error('CORS_ORIGIN cannot be wildcard in production');
    }
    return value;
  }

  const origins = [...new Set(value.split(',').map((item) => item.trim()))];
  if (
    origins.length === 0 ||
    origins.length > 20 ||
    origins.some((item) => !item)
  ) {
    throw new Error('CORS_ORIGIN must contain between 1 and 20 origins');
  }

  for (const origin of origins) {
    let parsed: URL;
    try {
      parsed = new URL(origin);
    } catch {
      throw new Error(`CORS_ORIGIN contains an invalid origin: ${origin}`);
    }

    if (
      parsed.origin !== origin ||
      parsed.username ||
      parsed.password ||
      parsed.pathname !== '/' ||
      parsed.search ||
      parsed.hash
    ) {
      throw new Error(
        `CORS_ORIGIN must contain origins without paths: ${origin}`,
      );
    }

    if (
      !['http:', 'https:'].includes(parsed.protocol) ||
      (nodeEnv === 'production' && parsed.protocol !== 'https:')
    ) {
      throw new Error(`CORS_ORIGIN must use HTTPS in production: ${origin}`);
    }
  }

  return origins.join(',');
}

function assertListenHost(value: string) {
  if (
    value !== 'localhost' &&
    isIP(value) === 0 &&
    !/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)*[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/i.test(
      value,
    )
  ) {
    throw new Error('HOST must be a valid IP address or hostname');
  }
}

function assertHostname(value: string, name: string) {
  if (
    isIP(value) === 0 &&
    !/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/i.test(
      value,
    )
  ) {
    throw new Error(`${name} must be a valid hostname`);
  }
}

function assertSafeHeaderValue(value: string, name: string, maxLength: number) {
  if (!value || value.length > maxLength || /[\r\n\0]/.test(value)) {
    throw new Error(`${name} contains invalid characters or is too long`);
  }
}

function assertEmailLike(value: string | undefined, name: string) {
  if (!value) {
    return;
  }
  assertSafeHeaderValue(value, name, 254);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
    throw new Error(`${name} must be a valid email address`);
  }
}

function readIntegerInRange(
  rawValue: string | undefined,
  name: string,
  fallback: number,
  minimum: number,
  maximum: number,
) {
  if (rawValue === undefined) {
    return fallback;
  }
  const value = Number(rawValue);
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new Error(
      `${name} must be an integer between ${minimum} and ${maximum}`,
    );
  }
  return value;
}

function readOptionalPositiveInteger(
  rawValue: string | undefined,
  name: string,
  fallback: number,
) {
  if (rawValue === undefined) {
    return fallback;
  }

  const value = Number(rawValue);

  if (!Number.isInteger(value) || value <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }

  return value;
}
