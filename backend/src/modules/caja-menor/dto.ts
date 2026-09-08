import { Transform, Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

import {
  resourceIdMessage,
  resourceIdPattern,
} from '../../common/validation/resource-id';

const maxMoneyValue = 999_999_999_999;

export class ListarMovimientosCajaQueryDto {
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
  @IsIn(['todos', 'entradas', 'salidas'])
  tipo?: 'todos' | 'entradas' | 'salidas';

  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @IsOptional()
  @IsDateString()
  fechaHasta?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number;
}

export class ExportarMovimientosCajaQueryDto extends ListarMovimientosCajaQueryDto {}

export class CrearCajaMenorDto {
  @IsOptional()
  @IsString()
  @Length(3, 3)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  monedaCodigo?: string;

  @IsString()
  @MinLength(2)
  @MaxLength(120)
  nombre!: string;

  @IsOptional()
  @IsDateString()
  fechaApertura?: string;

  @IsOptional()
  @IsDateString()
  fechaCierre?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(resourceIdPattern, { message: resourceIdMessage() })
  responsableUsuarioId?: string;
}

export class CrearMovimientoCajaDto {
  @IsString()
  @MaxLength(64)
  @Matches(resourceIdPattern, { message: resourceIdMessage() })
  cajaMenorId!: string;

  @IsString()
  @MaxLength(30)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  tipoMovimientoCodigo!: string;

  @IsDateString()
  fechaMovimiento!: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  @Max(maxMoneyValue)
  monto!: number;

  @IsString()
  @MinLength(2)
  @MaxLength(500)
  motivo!: string;
}

export class ActualizarMovimientoCajaDto extends CrearMovimientoCajaDto {}
