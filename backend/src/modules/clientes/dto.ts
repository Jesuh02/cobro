import { Type } from 'class-transformer';
import {
  IsEmail,
  IsNumber,
  IsOptional,
  IsString,
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
  cedula?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(180)
  nombreComercial?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(220)
  direccion?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-90)
  @Max(90)
  latitud?: number | null;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  @Min(-180)
  @Max(180)
  longitud?: number | null;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notas?: string | null;

  @IsOptional()
  @IsEmail()
  @MaxLength(180)
  correo?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  telefono?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  whatsapp?: string | null;
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
