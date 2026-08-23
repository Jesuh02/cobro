import { PasswordService } from './password.service';

describe('PasswordService', () => {
  const service = new PasswordService();

  it('creates a parameterized scrypt hash and verifies it', async () => {
    const hash = await service.hash('a-strong-password-123');

    expect(hash).toMatch(/^scrypt\$v2\$32768\$8\$3\$/);
    await expect(service.verify('a-strong-password-123', hash)).resolves.toBe(
      true,
    );
    await expect(service.verify('wrong-password', hash)).resolves.toBe(false);
    expect(service.needsRehash(hash)).toBe(false);
  });

  it('performs dummy work for malformed hashes and rejects them', async () => {
    await expect(
      service.verify('a-strong-password-123', 'disabled'),
    ).resolves.toBe(false);
    expect(service.needsRehash('disabled')).toBe(true);
  });
});
