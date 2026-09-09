import {
  IsDateString,
  IsIn,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

import { resourceIdPattern } from '../../common/validation/resource-id';

function resourceIdMessage() {
  return 'El identificador debe ser un UUID o un entero positivo valido';
}

export class ObtenerPresupuestoQueryDto {
  @IsOptional()
  @IsIn(['cobrador'])
  alcance?: 'cobrador';

  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(resourceIdPattern, { message: resourceIdMessage() })
  cajaMenorId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;

  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @IsOptional()
  @IsDateString()
  fechaHasta?: string;
}

