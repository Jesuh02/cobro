export type DomainErrorKind = 'validation' | 'not_found' | 'conflict';

export class DomainError extends Error {
  private constructor(
    message: string,
    public readonly kind: DomainErrorKind,
    public readonly code: string,
  ) {
    super(message);
    this.name = 'DomainError';
  }

  static validation(message: string, code = 'VALIDATION_ERROR') {
    return new DomainError(message, 'validation', code);
  }

  static notFound(message: string, code = 'RESOURCE_NOT_FOUND') {
    return new DomainError(message, 'not_found', code);
  }

  static conflict(message: string, code = 'RESOURCE_CONFLICT') {
    return new DomainError(message, 'conflict', code);
  }
}
