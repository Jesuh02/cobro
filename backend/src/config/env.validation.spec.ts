import { validateEnv } from './env.validation';

const productionConfig = {
  NODE_ENV: 'production',
  DATABASE_URL:
    'postgresql://cobro_api:strong-password@db.abcdefghijklmnopqrst.supabase.co:5432/postgres?schema=public&sslmode=require',
  AUTH_TOKEN_SECRET: 'a'.repeat(64),
  CORS_ORIGIN: 'https://app.example.com',
  OSRM_BASE_URL: 'https://routing.example.com',
};

describe('validateEnv security policy', () => {
  it('accepts a hardened production configuration', () => {
    expect(validateEnv(productionConfig)).toMatchObject({
      AUTH_TOKEN_TTL_SECONDS: 3600,
      CORS_ORIGIN: 'https://app.example.com',
      ENFORCE_HTTPS: true,
      TRUST_PROXY_HOPS: 1,
    });
  });

  it('rejects wildcard CORS in production', () => {
    expect(() =>
      validateEnv({ ...productionConfig, CORS_ORIGIN: '*' }),
    ).toThrow('CORS_ORIGIN cannot be wildcard');
  });

  it('rejects privileged database users in production', () => {
    expect(() =>
      validateEnv({
        ...productionConfig,
        DATABASE_URL:
          'postgresql://postgres:password@db.abcdefghijklmnopqrst.supabase.co:5432/postgres?schema=public&sslmode=require',
      }),
    ).toThrow('least-privilege');
  });

  it('rejects database connections without TLS in production', () => {
    expect(() =>
      validateEnv({
        ...productionConfig,
        DATABASE_URL:
          'postgresql://cobro_api:password@db.abcdefghijklmnopqrst.supabase.co:5432/postgres?schema=public',
      }),
    ).toThrow('sslmode=require');
  });

  it('rejects short token secrets in production', () => {
    expect(() =>
      validateEnv({ ...productionConfig, AUTH_TOKEN_SECRET: 'too-short' }),
    ).toThrow('at least 64 characters');
  });
});
