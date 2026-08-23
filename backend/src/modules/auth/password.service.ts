import { Injectable } from '@nestjs/common';
import { randomBytes, scrypt, timingSafeEqual } from 'node:crypto';

const keyLength = 64;
const cost = 32_768;
const blockSize = 8;
const parallelization = 3;
const maxMemory = 64 * 1024 * 1024;

type PasswordHash = {
  blockSize: number;
  cost: number;
  hash: Buffer;
  parallelization: number;
  salt: string;
  version: 'legacy' | 'v2';
};

@Injectable()
export class PasswordService {
  private readonly dummyHashPromise = this.hash(
    randomBytes(48).toString('base64url'),
  );

  async hash(password: string) {
    const salt = randomBytes(24).toString('base64url');
    const key = await this.derive(password, salt, {
      cost,
      blockSize,
      parallelization,
    });
    return `scrypt$v2$${cost}$${blockSize}$${parallelization}$${salt}$${key.toString('base64url')}`;
  }

  async verify(password: string, storedHash: string) {
    const parsed = this.parse(storedHash);
    const target = parsed ?? this.parse(await this.dummyHashPromise);

    if (!target) {
      return false;
    }

    const derived = await this.derive(password, target.salt, target);
    const matches =
      target.hash.length === derived.length &&
      timingSafeEqual(target.hash, derived);
    return parsed !== null && matches;
  }

  needsRehash(storedHash: string) {
    const parsed = this.parse(storedHash);
    return (
      parsed === null ||
      parsed.version !== 'v2' ||
      parsed.cost !== cost ||
      parsed.blockSize !== blockSize ||
      parsed.parallelization !== parallelization ||
      parsed.hash.length !== keyLength
    );
  }

  private derive(
    password: string,
    salt: string,
    parameters: Pick<PasswordHash, 'blockSize' | 'cost' | 'parallelization'>,
  ) {
    return new Promise<Buffer>((resolve, reject) => {
      scrypt(
        password,
        salt,
        keyLength,
        {
          N: parameters.cost,
          r: parameters.blockSize,
          p: parameters.parallelization,
          maxmem: maxMemory,
        },
        (error, derivedKey) => {
          if (error) {
            reject(error);
            return;
          }
          resolve(derivedKey);
        },
      );
    });
  }

  private parse(value: string): PasswordHash | null {
    const parts = value.split('$');

    if (parts.length === 3 && parts[0] === 'scrypt') {
      return this.parsedHash({
        version: 'legacy',
        cost: 16_384,
        blockSize: 8,
        parallelization: 1,
        salt: parts[1],
        encodedHash: parts[2],
      });
    }

    if (parts.length === 7 && parts[0] === 'scrypt' && parts[1] === 'v2') {
      return this.parsedHash({
        version: 'v2',
        cost: Number(parts[2]),
        blockSize: Number(parts[3]),
        parallelization: Number(parts[4]),
        salt: parts[5],
        encodedHash: parts[6],
      });
    }

    return null;
  }

  private parsedHash(input: {
    blockSize: number;
    cost: number;
    encodedHash: string;
    parallelization: number;
    salt: string;
    version: PasswordHash['version'];
  }): PasswordHash | null {
    if (
      !input.salt ||
      !/^[A-Za-z0-9_-]{16,128}$/.test(input.salt) ||
      !/^[A-Za-z0-9_-]{32,256}$/.test(input.encodedHash) ||
      ![input.cost, input.blockSize, input.parallelization].every(
        (value) => Number.isInteger(value) && value > 0,
      ) ||
      input.cost > 131_072 ||
      input.blockSize > 16 ||
      input.parallelization > 4
    ) {
      return null;
    }

    const hash = Buffer.from(input.encodedHash, 'base64url');
    if (hash.length !== keyLength) {
      return null;
    }

    return { ...input, hash };
  }
}
