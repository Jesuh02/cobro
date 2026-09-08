import { BadRequestException, PipeTransform } from '@nestjs/common';

export const resourceIdPattern =
  /^(?:[1-9]\d{0,18}|[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$/i;

export function resourceIdMessage() {
  return 'El identificador debe ser un UUID o un entero positivo valido';
}

const paymentResourceIdPattern = new RegExp(
  `^pago-(?:${resourceIdPattern.source.slice(1, -1)})$`,
  'i',
);

export class ResourceIdPipe implements PipeTransform<unknown, string> {
  constructor(private readonly allowPaymentPrefix = false) {}

  transform(value: unknown) {
    if (
      typeof value !== 'string' ||
      value.length > 64 ||
      (!resourceIdPattern.test(value) &&
        !(this.allowPaymentPrefix && paymentResourceIdPattern.test(value)))
    ) {
      throw new BadRequestException('Identificador no valido');
    }

    return value;
  }
}
