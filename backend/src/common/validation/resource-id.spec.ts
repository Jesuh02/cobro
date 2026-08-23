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

  it('allows validated payment identifiers only when requested', () => {
    const paymentPipe = new ResourceIdPipe(true);
    const value = 'pago-8d3f8c14-276f-4fd4-a55c-63fe4c179cca';

    expect(paymentPipe.transform(value)).toBe(value);
    expect(() => pipe.transform(value)).toThrow(BadRequestException);
  });
});
