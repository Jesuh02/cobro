type CacheKeyValue = boolean | number | string | null | undefined;

export function cacheKeyFromCriteria(criteria: Record<string, CacheKeyValue>) {
  const parts = Object.entries(criteria)
    .filter(([, value]) => value !== undefined && value !== null)
    .map(([key, value]) => [
      key,
      encodeURIComponent(String(value).trim().toLowerCase()),
    ])
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${key}=${value}`);

  return parts.length === 0 ? 'all' : parts.join('&');
}
