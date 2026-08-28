import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  IsEmail,
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
  Min,
} from 'class-validator';

import { resourceIdPattern } from '../../common/validation/resource-id';

const usuarioPattern = /^[a-zA-Z0-9._-]+$/;

export class LoginDto {
  @IsString()
  @MinLength(3)
  @MaxLength(60)
  @Matches(usuarioPattern, {
    message:
      'El usuario solo puede tener letras, numeros, puntos, guiones y guion bajo',
  })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  usuario!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(128)
  contrasena!: string;
}

export class RegistrarInstitucionDto {
  @IsString()
  @MinLength(3)
  @MaxLength(160)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  institucion!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(180)
  nombreCompleto!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(60)
  @Matches(usuarioPattern, {
    message:
      'El usuario solo puede tener letras, numeros, puntos, guiones y guion bajo',
  })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  usuario!: string;

  @IsString()
  @MinLength(12)
  @MaxLength(128)
  contrasena!: string;

  @IsEmail()
  @MaxLength(180)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  correo!: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  telefono?: string;
}

export class CrearUsuarioDto {
  @IsString()
  @MinLength(3)
  @MaxLength(180)
  nombreCompleto!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(60)
  @Matches(usuarioPattern, {
    message:
      'El usuario solo puede tener letras, numeros, puntos, guiones y guion bajo',
  })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  usuario!: string;

  @IsString()
  @MinLength(12)
  @MaxLength(128)
  contrasena!: string;

  @IsEmail()
  @MaxLength(180)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  correo!: string;
}

export class ActualizarUsuarioDto {
  @IsString()
  @MinLength(3)
  @MaxLength(180)
  nombreCompleto!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(60)
  @Matches(usuarioPattern, {
    message:
      'El usuario solo puede tener letras, numeros, puntos, guiones y guion bajo',
  })
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  usuario!: string;

  @IsEmail()
  @MaxLength(180)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  correo!: string;

  @IsOptional()
  @IsString()
  @MinLength(12)
  @MaxLength(128)
  contrasena?: string;
}

export class ActualizarPermisosUsuariosDto {
  @IsOptional()
  @IsBoolean()
  todos?: boolean;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(200)
  @IsString({ each: true })
  @MaxLength(64, { each: true })
  @Matches(resourceIdPattern, {
    each: true,
    message: 'Cada usuarioId debe ser un identificador valido',
  })
  usuarioIds?: string[];

  @IsArray()
  @ArrayMaxSize(20)
  @IsString({ each: true })
  @MaxLength(60, { each: true })
  permisos!: string[];
}

export class ActualizarEstadoUsuarioDto {
  @IsBoolean()
  activo!: boolean;
}

export class ActualizarOrganizacionSuperAdminDto {
  @IsOptional()
  @IsBoolean()
  activo?: boolean;

  @IsOptional()
  @IsDateString()
  accesoHasta?: string | null;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  montoPlan?: number;

  @IsOptional()
  @IsString()
  @IsIn(['COP', 'USD'])
  monedaPlan?: string;

  @IsOptional()
  @IsString()
  @MaxLength(220)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  motivoSuspension?: string | null;
}

export class ExtenderAccesoOrganizacionDto {
  @IsInt()
  @Min(1)
  dias!: number;
}
