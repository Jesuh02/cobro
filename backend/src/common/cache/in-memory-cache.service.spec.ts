import { ConfigService } from '@nestjs/config';

import { InMemoryCacheService } from './in-memory-cache.service';

describe('InMemoryCacheService', () => {
  afterEach(() => {
    jest.useRealTimers();
  });

  it('returns cached values until the ttl expires', () => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-01-01T00:00:00.000Z'));

    const cache = createCache({ CACHE_TTL_MS: 10 });

    cache.set('key', 'value');
    expect(cache.get<string>('key')).toEqual({ hit: true, value: 'value' });

    jest.advanceTimersByTime(11);
    expect(cache.get<string>('key')).toEqual({ hit: false });
  });

  it('shares one loader promise for concurrent misses', async () => {
    const cache = createCache();
    let resolveLoader: ((value: string) => void) | undefined;
    const loader = jest.fn(
      () =>
        new Promise<string>((resolve) => {
          resolveLoader = resolve;
        }),
    );

    const first = cache.remember('key', loader);
    const second = cache.remember('key', loader);

    resolveLoader?.('value');

    await expect(first).resolves.toBe('value');
    await expect(second).resolves.toBe('value');
    expect(loader).toHaveBeenCalledTimes(1);
  });

  it('does not store stale loader results after invalidation', async () => {
    const cache = createCache();
    let resolveLoader: ((value: string) => void) | undefined;
    const loading = cache.remember(
      'key',
      () =>
        new Promise<string>((resolve) => {
          resolveLoader = resolve;
        }),
    );

    cache.delete('key');
    resolveLoader?.('stale');

    await expect(loading).resolves.toBe('stale');
    expect(cache.get<string>('key')).toEqual({ hit: false });
  });

  it('does not overwrite a fresh value with an older loader result', async () => {
    const cache = createCache();
    let resolveLoader: ((value: string) => void) | undefined;
    const loading = cache.remember(
      'key',
      () =>
        new Promise<string>((resolve) => {
          resolveLoader = resolve;
        }),
    );

    cache.set('key', 'fresh');
    resolveLoader?.('stale');

    await expect(loading).resolves.toBe('stale');
    expect(cache.get<string>('key')).toEqual({ hit: true, value: 'fresh' });
  });
});

function createCache(config: Record<string, number> = {}) {
  return new InMemoryCacheService(new ConfigService(config));
}
