import { Transform } from 'class-transformer';
import {
  IsEmail,
  IsString,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

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
  @MinLength(8)
  @MaxLength(128)
  contrasena!: string;

  @IsEmail()
  @MaxLength(180)
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  correo!: string;
}
