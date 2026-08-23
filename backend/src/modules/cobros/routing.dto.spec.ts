import 'reflect-metadata';

import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';

import {
  EstimarTrayectosDto,
  TrazarRutaCompletaDto,
  TrazarRutaDto,
} from './dto';

const point = { latitude: 11.544, longitude: -72.907 };

describe('DTO de enrutamiento', () => {
  it('rechaza una matriz sin origen', async () => {
    const dto = plainToInstance(EstimarTrayectosDto, {
      destinations: [point],
    });

    const errors = await validate(dto);

    expect(errors.some((error) => error.property === 'origin')).toBe(true);
  });

  it.each([
    ['origin', { destination: point }],
    ['destination', { origin: point }],
  ])('rechaza una ruta sin %s', async (property, payload) => {
    const dto = plainToInstance(TrazarRutaDto, payload);

    const errors = await validate(dto);

    expect(errors.some((error) => error.property === property)).toBe(true);
  });

  it('acepta puntos completos dentro de rango', async () => {
    const dto = plainToInstance(TrazarRutaDto, {
      origin: point,
      destination: { latitude: 11.56, longitude: -72.9 },
    });

    await expect(validate(dto)).resolves.toHaveLength(0);
  });

  it('acepta una ruta completa con varias paradas', async () => {
    const dto = plainToInstance(TrazarRutaCompletaDto, {
      origin: point,
      destinations: [
        { latitude: 11.55, longitude: -72.9 },
        { latitude: 11.56, longitude: -72.91 },
      ],
    });

    await expect(validate(dto)).resolves.toHaveLength(0);
  });
});
