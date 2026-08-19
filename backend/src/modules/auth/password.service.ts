import { Injectable } from '@nestjs/common';
import { randomBytes, scrypt, timingSafeEqual } from 'crypto';
import { promisify } from 'util';

const scryptAsync = promisify(scrypt);
const keyLength = 64;

@Injectable()
export class PasswordService {
  async hash(password: string) {
    const salt = randomBytes(24).toString('base64url');
    const key = (await scryptAsync(password, salt, keyLength)) as Buffer;
    return `scrypt$${salt}$${key.toString('base64url')}`;
  }

  async verify(password: string, storedHash: string) {
    const [scheme, salt, hash] = storedHash.split('$');

    if (scheme !== 'scrypt' || !salt || !hash) {
      return false;
    }

    const stored = Buffer.from(hash, 'base64url');
    const derived = (await scryptAsync(
      password,
      salt,
      stored.length,
    )) as Buffer;

    return stored.length === derived.length && timingSafeEqual(stored, derived);
  }
}
