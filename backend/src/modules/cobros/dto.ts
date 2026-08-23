import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
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
const maxCreditDays = 3_650;

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

export class ListarCreditosQueryDto extends ListarCobrosRutaQueryDto {
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

export class ObtenerPresupuestoQueryDto {
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
