import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDefined,
  IsIn,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

import {
  resourceIdMessage,
  resourceIdPattern,
} from '../../common/validation/resource-id';

export class PuntoRutaDto {
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  latitude!: number;

  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  longitude!: number;
}

export class EstimarTrayectosDto {
  @IsDefined()
  @IsObject()
  @ValidateNested()
  @Type(() => PuntoRutaDto)
  origin!: PuntoRutaDto;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(24)
  @ValidateNested({ each: true })
  @Type(() => PuntoRutaDto)
  destinations!: PuntoRutaDto[];
}

export class TrazarRutaDto {
  @IsDefined()
  @IsObject()
  @ValidateNested()
  @Type(() => PuntoRutaDto)
  origin!: PuntoRutaDto;

  @IsDefined()
  @IsObject()
  @ValidateNested()
  @Type(() => PuntoRutaDto)
  destination!: PuntoRutaDto;
}

export class TrazarRutaCompletaDto {
  @IsDefined()
  @IsObject()
  @ValidateNested()
  @Type(() => PuntoRutaDto)
  origin!: PuntoRutaDto;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => PuntoRutaDto)
  destinations!: PuntoRutaDto[];
}

export class ListarCobrosRutaQueryDto {
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
}
