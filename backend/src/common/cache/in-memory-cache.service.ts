import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

type CacheEntry<T> = {
  expiresAt: number;
  touchedAt: number;
  value: T;
};

type CacheHit<T> = {
  hit: true;
  value: T;
};

type CacheMiss = {
  hit: false;
};

type RememberOptions = {
  ttlMs?: number;
};

@Injectable()
export class InMemoryCacheService {
  private readonly defaultTtlMs: number;
  private readonly maxEntries: number;
  private readonly inFlight = new Map<string, Promise<unknown>>();
  private readonly store = new Map<string, CacheEntry<unknown>>();

  constructor(config: ConfigService) {
    this.defaultTtlMs = readPositiveInteger(
      config.get<number>('CACHE_TTL_MS'),
      30_000,
    );
    this.maxEntries = readPositiveInteger(
      config.get<number>('CACHE_MAX_ENTRIES'),
      2_000,
    );
  }

  get<T>(key: string): CacheHit<T> | CacheMiss {
    const entry = this.store.get(key);

    if (!entry) {
      return { hit: false };
    }

    const now = Date.now();
    if (entry.expiresAt <= now) {
      this.store.delete(key);
      return { hit: false };
    }

    entry.touchedAt = now;
    return { hit: true, value: entry.value as T };
  }

  async remember<T>(
    key: string,
    loader: () => Promise<T>,
    options: RememberOptions = {},
  ): Promise<T> {
    const cached = this.get<T>(key);

    if (cached.hit) {
      return cached.value;
    }

    const running = this.inFlight.get(key);

    if (running) {
      return (await running) as T;
    }

    const promise = loader()
      .then((value) => {
        if (this.inFlight.get(key) === promise) {
          this.write(key, value, options);
        }

        return value;
      })
      .finally(() => {
        if (this.inFlight.get(key) === promise) {
          this.inFlight.delete(key);
        }
      });

    this.inFlight.set(key, promise);
    return promise;
  }

  set<T>(key: string, value: T, options: RememberOptions = {}) {
    this.inFlight.delete(key);
    this.write(key, value, options);
  }

  delete(key: string) {
    this.store.delete(key);
    this.inFlight.delete(key);
  }

  deleteByPrefix(prefix: string) {
    for (const key of this.store.keys()) {
      if (key.startsWith(prefix)) {
        this.store.delete(key);
      }
    }

    for (const key of this.inFlight.keys()) {
      if (key.startsWith(prefix)) {
        this.inFlight.delete(key);
      }
    }
  }

  clear() {
    this.store.clear();
    this.inFlight.clear();
  }

  private write<T>(key: string, value: T, options: RememberOptions = {}) {
    const ttlMs = readPositiveInteger(options.ttlMs, this.defaultTtlMs);
    const now = Date.now();

    this.store.set(key, {
      value,
      expiresAt: now + ttlMs,
      touchedAt: now,
    });

    this.evictExpired(now);
    this.enforceMaxEntries();
  }

  private evictExpired(now: number) {
    for (const [key, entry] of this.store.entries()) {
      if (entry.expiresAt <= now) {
        this.store.delete(key);
      }
    }
  }

  private enforceMaxEntries() {
    if (this.store.size <= this.maxEntries) {
      return;
    }

    const entriesByAge = [...this.store.entries()].sort(
      ([, left], [, right]) => left.touchedAt - right.touchedAt,
    );
    const entriesToRemove = this.store.size - this.maxEntries;

    for (const [key] of entriesByAge.slice(0, entriesToRemove)) {
      this.store.delete(key);
    }
  }
}

function readPositiveInteger(value: number | undefined, fallback: number) {
  if (typeof value === 'number' && Number.isInteger(value) && value > 0) {
    return value;
  }

  return fallback;
}
