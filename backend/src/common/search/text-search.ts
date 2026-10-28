const combiningMarksPattern = /[\u0300-\u036f]/g;
const nonAlphanumericPattern = /[^a-z0-9]/g;

/**
 * Produces the canonical value used by tolerant text searches.
 *
 * The database expression must follow the same rules: lowercase, remove
 * Spanish diacritics, and ignore whitespace and punctuation.
 */
export function normalizeSearchText(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(combiningMarksPattern, '')
    .replace(nonAlphanumericPattern, '');
}
