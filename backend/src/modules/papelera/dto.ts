import { IsOptional, IsString } from 'class-validator';

export class ListarPapeleraQueryDto {
  @IsOptional()
  @IsString()
  search?: string;
}
