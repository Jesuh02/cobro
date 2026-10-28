import { normalizeSearchText } from './text-search';

describe('normalizeSearchText', () => {
  it('ignores accents and letter casing', () => {
    expect(normalizeSearchText('  JESÚS  ')).toBe('jesus');
  });

  it('ignores whitespace and punctuation', () => {
    expect(normalizeSearchText("Jesús A. D'Ávila-Soto")).toBe(
      'jesusadavilasoto',
    );
  });

  it('preserves letters and numbers used by usernames and documents', () => {
    expect(normalizeSearchText('  Empleado_01.23  ')).toBe('empleado0123');
  });
});
