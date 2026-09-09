import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
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
} from 'class-validator';

import { resourceIdPattern } from '../../common/validation/resource-id';

export const maxMoneyValue = 999_999_999_999;
export const maxCreditDays = 3_650;

export function resourceIdMessage() {
  return 'El identificador debe ser un UUID o un entero positivo valido';
}

export class ListarCreditosQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(resourceIdPattern, { message: resourceIdMessage() })
  rutaId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;

  @IsOptional()
  @IsIn(['todos', 'AL_DIA', 'PENDIENTE', 'ATRASADO', 'PAGADO'])
  estadoCobro?: 'todos' | 'AL_DIA' | 'PENDIENTE' | 'ATRASADO' | 'PAGADO';

  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(resourceIdPattern, { message: resourceIdMessage() })
  cajaMenorId?: string;

  @IsOptional()
  @IsIn(['todos', 'activos', 'inactivos'])
  estado?: 'todos' | 'activos' | 'inactivos';

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

export class CrearCreditoDto {
  @IsString()
  @MaxLength(64)
  @Matches(resourceIdPattern, { message: resourceIdMessage() })
  clienteId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(resourceIdPattern, { message: resourceIdMessage() })
  rutaId?: string;

  @IsString()
  @Length(3, 3)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  monedaCodigo!: string;

  @IsInt()
  @Min(1)
  frecuenciaPagoId!: number;

  @IsDateString()
  fechaInicio!: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  @Max(maxMoneyValue)
  valorPrincipal!: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  @Max(1_000)
  porcentajeInteres!: number;

  @IsInt()
  @Min(1)
  @Max(maxCreditDays)
  plazoDias!: number;

  @IsOptional()
  @IsBoolean()
  omitirDomingos?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(resourceIdPattern, { message: resourceIdMessage() })
  cajaMenorId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class ActualizarCreditoDto extends CrearCreditoDto {}

export class RefinanciarCreditoDto {
  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(resourceIdPattern, { message: resourceIdMessage() })
  rutaId?: string;

  @IsOptional()
  @IsString()
  @Length(3, 3)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  monedaCodigo?: string;

  @IsInt()
  @Min(1)
  frecuenciaPagoId!: number;

  @IsDateString()
  fechaInicio!: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  @Max(maxMoneyValue)
  valorPrincipal!: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  @Max(1_000)
  porcentajeInteres!: number;

  @IsInt()
  @Min(1)
  @Max(maxCreditDays)
  plazoDias!: number;

  @IsOptional()
  @IsBoolean()
  omitirDomingos?: boolean;

  @IsString()
  @MaxLength(64)
  @Matches(resourceIdPattern, { message: resourceIdMessage() })
  cajaMenorId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class RegistrarPagoDto {
  @IsString()
  @MaxLength(64)
  @Matches(resourceIdPattern, { message: resourceIdMessage() })
  creditoCuotaId!: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  @Max(maxMoneyValue)
  montoPagado!: number;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toUpperCase() : value,
  )
  medioPagoCodigo?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  referenciaExterna?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

