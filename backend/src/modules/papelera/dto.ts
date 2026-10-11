import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class ListarPapeleraQueryDto {
  @IsOptional()
  @IsString()
  search?: string;
}

export class UnificarCreditoPapeleraDto {
  @IsOptional()
  @IsString()
  frecuenciaCodigo?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  plazoDias?: number;
}
