type RawConfig = Record<string, string | undefined>;

type ValidatedConfig = {
  AUTH_TOKEN_SECRET: string;
  CACHE_MAX_ENTRIES: number;
  CACHE_TTL_MS: number;
  DATABASE_URL: string;
  NODE_ENV: 'development' | 'test' | 'production';
  PORT: number;
  CORS_ORIGIN: string;
  NOTIFICATIONS_ENABLED: boolean;
  NOTIFICATION_BRAND_NAME: string;
  NOTIFICATION_REPLY_TO?: string;
  NOTIFICATION_TIME_ZONE: string;
  RESEND_API_KEY?: string;
  RESEND_FROM_EMAIL?: string;
  BREVO_FROM_EMAIL?: string;
  BREVO_SMTP_HOST: string;
  BREVO_SMTP_PORT: number;
  BREVO_SMTP_USER?: string;
  BREVO_SMTP_PASSWORD?: string;
  R2_ACCESS_KEY_ID?: string;
  R2_ACCOUNT_ID?: string;
  R2_BUCKET_NAME?: string;
  R2_PUBLIC_URL?: string;
  R2_SECRET_ACCESS_KEY?: string;
  YCLOUD_API_KEY?: string;
  YCLOUD_BASE_URL: string;
  YCLOUD_ENABLED: boolean;
  YCLOUD_INSTANCE_ID?: string;
  YCLOUD_WHATSAPP_NUMBER?: string;
  YCLOUD_USE_DIRECT_SEND: boolean;
  YCLOUD_TEMPLATE_LANGUAGE: string;
  YCLOUD_TEMPLATE_CREDIT_APPROVED?: string;
  YCLOUD_TEMPLATE_PAYMENT_RECEIVED?: string;
  YCLOUD_TEMPLATE_CREDIT_COMPLETED?: string;
  WHATSAPP_DEFAULT_COUNTRY_CODE: string;
};

const allowedEnvironments = ['development', 'test', 'production'] as const;

export function validateEnv(config: RawConfig): ValidatedConfig {
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

  assertSupabaseDatabaseUrl(config.DATABASE_URL);

  const port = Number(config.PORT ?? 3000);

  if (!Number.isInteger(port) || port <= 0) {
    throw new Error('PORT must be a positive integer');
  }

  const authTokenSecret =
    config.AUTH_TOKEN_SECRET ?? 'local-development-secret-change-me-please';

  if (nodeEnv === 'production' && authTokenSecret.length < 32) {
    throw new Error('AUTH_TOKEN_SECRET must have at least 32 characters');
  }

  const notificationsEnabled = readBoolean(
    config.NOTIFICATIONS_ENABLED,
    'NOTIFICATIONS_ENABLED',
    false,
  );
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
    ycloudEnabled &&
    (!config.YCLOUD_API_KEY || !config.YCLOUD_WHATSAPP_NUMBER)
  ) {
    throw new Error(
      'YCLOUD_API_KEY and YCLOUD_WHATSAPP_NUMBER are required when YCLOUD_ENABLED is true',
    );
  }

  const ycloudBaseUrl = config.YCLOUD_BASE_URL ?? 'https://api.ycloud.com/v2';
  assertHttpUrl(ycloudBaseUrl, 'YCLOUD_BASE_URL');
  const r2PublicUrl = optional(config.R2_PUBLIC_URL);

  if (r2PublicUrl) {
    assertHttpUrl(r2PublicUrl, 'R2_PUBLIC_URL');
  }

  return {
    AUTH_TOKEN_SECRET: authTokenSecret,
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
    DATABASE_URL: config.DATABASE_URL,
    CORS_ORIGIN: config.CORS_ORIGIN ?? '*',
    NOTIFICATIONS_ENABLED: notificationsEnabled,
    NOTIFICATION_BRAND_NAME: config.NOTIFICATION_BRAND_NAME?.trim() || 'Cobro',
    NOTIFICATION_REPLY_TO: optional(config.NOTIFICATION_REPLY_TO),
    NOTIFICATION_TIME_ZONE:
      config.NOTIFICATION_TIME_ZONE?.trim() || 'America/Bogota',
    RESEND_API_KEY: optional(config.RESEND_API_KEY),
    RESEND_FROM_EMAIL: optional(config.RESEND_FROM_EMAIL),
    BREVO_FROM_EMAIL: optional(config.BREVO_FROM_EMAIL),
    BREVO_SMTP_HOST:
      config.BREVO_SMTP_HOST?.trim() || 'smtp-relay.sendinblue.com',
    BREVO_SMTP_PORT: readOptionalPositiveInteger(
      config.BREVO_SMTP_PORT,
      'BREVO_SMTP_PORT',
      587,
    ),
    BREVO_SMTP_USER: optional(config.BREVO_SMTP_USER),
    BREVO_SMTP_PASSWORD: optional(config.BREVO_SMTP_PASSWORD),
    R2_ACCESS_KEY_ID: optional(config.R2_ACCESS_KEY_ID),
    R2_ACCOUNT_ID: optional(config.R2_ACCOUNT_ID),
    R2_BUCKET_NAME: optional(config.R2_BUCKET_NAME),
    R2_PUBLIC_URL: r2PublicUrl,
    R2_SECRET_ACCESS_KEY: optional(config.R2_SECRET_ACCESS_KEY),
    YCLOUD_API_KEY: optional(config.YCLOUD_API_KEY),
    YCLOUD_BASE_URL: ycloudBaseUrl,
    YCLOUD_ENABLED: ycloudEnabled,
    YCLOUD_INSTANCE_ID: optional(config.YCLOUD_INSTANCE_ID),
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

function assertHttpUrl(value: string, name: string) {
  let parsed: URL;

  try {
    parsed = new URL(value);
  } catch {
    throw new Error(`${name} must be a valid URL`);
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error(`${name} must use HTTP or HTTPS`);
  }
}

function assertSupabaseDatabaseUrl(databaseUrl: string) {
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
      'DATABASE_URL must point to Supabase, not a local database',
    );
  }

  if (
    !hostname.endsWith('.supabase.co') &&
    !hostname.endsWith('.supabase.com')
  ) {
    throw new Error('DATABASE_URL must point to a Supabase database host');
  }
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
