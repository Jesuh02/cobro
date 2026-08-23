import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsEmail,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

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

export class ListarCobrosRutaQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(64)
  rutaId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;

  @IsOptional()
  @IsIn(['todos', 'AL_DIA', 'PENDIENTE', 'ATRASADO'])
  estadoCobro?: 'todos' | 'AL_DIA' | 'PENDIENTE' | 'ATRASADO';
}

export class ListarCreditosQueryDto extends ListarCobrosRutaQueryDto {
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
  clienteId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
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
  valorPrincipal!: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  porcentajeInteres!: number;

  @IsInt()
  @Min(1)
  plazoDias!: number;

  @IsOptional()
  @IsBoolean()
  omitirDomingos?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(64)
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
  valorPrincipal!: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  porcentajeInteres!: number;

  @IsInt()
  @Min(1)
  plazoDias!: number;

  @IsOptional()
  @IsBoolean()
  omitirDomingos?: boolean;

  @IsString()
  @MaxLength(64)
  cajaMenorId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class RegistrarPagoDto {
  @IsString()
  @MaxLength(64)
  creditoCuotaId!: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
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
  monto!: number;

  @IsString()
  @MinLength(2)
  @MaxLength(500)
  motivo!: string;
}

export class ActualizarMovimientoCajaDto extends CrearMovimientoCajaDto {}
