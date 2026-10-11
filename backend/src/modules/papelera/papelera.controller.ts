import {
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { AuthenticatedUser } from '../auth/auth.types';
import { ResourceIdPipe } from '../../common/validation/resource-id';
import { PapeleraService } from './papelera.service';
import { ListarPapeleraQueryDto } from './dto';

@Controller('papelera')
@UseGuards(AuthGuard)
export class PapeleraController {
  constructor(private readonly papelera: PapeleraService) {}

  @Get()
  listarPapelera(
    @CurrentUser() usuario: AuthenticatedUser,
    @Query() query: ListarPapeleraQueryDto,
  ) {
    return this.papelera.listarPapelera(query, usuario);
  }

  @Post(':id/restaurar')
  restaurarCliente(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
  ) {
    return this.papelera.restaurarCliente(id, usuario);
  }

  @Delete(':id')
  eliminarDefinitivo(
    @CurrentUser() usuario: AuthenticatedUser,
    @Param('id', new ResourceIdPipe()) id: string,
  ) {
    return this.papelera.eliminarDefinitivo(id, usuario);
  }
}
