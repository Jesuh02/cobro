import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsDefined,
  IsEmail,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsObject,
  IsString,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

import { resourceIdPattern } from '../../common/validation/resource-id';

const maxMoneyValue = 999_999_999_999;

function resourceIdMessage() {
  return 'El identificador debe ser un UUID o un entero positivo valido';
}

export class ListarClientesQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;
}

export class CrearClienteDto {
  @IsString()
  @MinLength(2)
  @MaxLength(180)
  nombreCompleto!: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  cedula?: string;

  @IsOptional()
  @IsString()
  @MaxLength(180)
  nombreComercial?: string;

  @IsOptional()
  @IsString()
  @MaxLength(220)
  direccion?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  latitud?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  longitud?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notas?: string;

  @IsOptional()
  @IsEmail()
  @MaxLength(180)
  correo?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  telefono?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  whatsapp?: string;
}

export class ActualizarClienteDto extends CrearClienteDto {}

export class ActualizarUbicacionClienteDto {
  @IsOptional()
  @IsString()
  @MaxLength(220)
  direccion?: string;

  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  latitud!: number;

  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  longitud!: number;
}

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

export { ListarCreditosQueryDto } from '../creditos/dto';

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

export {
  ActualizarCreditoDto,
  CrearCreditoDto,
  RefinanciarCreditoDto,
  RegistrarPagoDto,
} from '../creditos/dto';

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
