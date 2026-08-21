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
  IsUUID,
  Length,
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
  @IsUUID()
  rutaId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;
}

export class CrearCreditoDto {
  @IsUUID()
  clienteId!: string;

  @IsOptional()
  @IsUUID()
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
  @IsUUID()
  cajaMenorId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class RegistrarPagoDto {
  @IsUUID()
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
  @IsUUID()
  cajaMenorId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;
}

export class ExportarMovimientosCajaQueryDto extends ListarMovimientosCajaQueryDto {
  @IsOptional()
  @IsIn(['todos', 'entradas', 'salidas'])
  tipo?: 'todos' | 'entradas' | 'salidas';

  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @IsOptional()
  @IsDateString()
  fechaHasta?: string;
}

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
}

export class CrearMovimientoCajaDto {
  @IsUUID()
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
