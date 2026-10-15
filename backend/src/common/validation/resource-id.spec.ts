import { BadRequestException } from '@nestjs/common';

import { ResourceIdPipe } from './resource-id';

describe('ResourceIdPipe', () => {
  const pipe = new ResourceIdPipe();

  it.each(['8d3f8c14-276f-4fd4-a55c-63fe4c179cca', '123456789'])(
    'accepts supported identifiers: %s',
    (value) => {
      expect(pipe.transform(value)).toBe(value);
    },
  );

  it.each(["' OR 1=1 --", '../admin', 'pago-not-an-id', '', '0', '01'])(
    'rejects malformed identifiers: %s',
    (value) => {
      expect(() => pipe.transform(value)).toThrow(BadRequestException);
    },
  );

  it('allows validated payment and movement identifiers only when requested', () => {
    const prefixedPipe = new ResourceIdPipe(true);
    const pagoValue = 'pago-8d3f8c14-276f-4fd4-a55c-63fe4c179cca';
    const movValue = 'mov-8d3f8c14-276f-4fd4-a55c-63fe4c179cca';

    expect(prefixedPipe.transform(pagoValue)).toBe(pagoValue);
    expect(prefixedPipe.transform(movValue)).toBe(movValue);
    expect(() => pipe.transform(pagoValue)).toThrow(BadRequestException);
    expect(() => pipe.transform(movValue)).toThrow(BadRequestException);
  });
});
