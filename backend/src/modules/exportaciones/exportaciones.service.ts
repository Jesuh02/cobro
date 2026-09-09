import { Injectable } from '@nestjs/common';
import { Workbook, type Worksheet } from 'exceljs';
import { Buffer } from 'node:buffer';

import { DomainError } from '../../common/domain/domain-error';
import { ExportacionesR2Service } from './exportaciones-r2.service';
import {
  ColumnaExportacion,
  ExportacionExcel,
  ExportacionVistaPrevia,
  FilaExportacion,
} from './exportaciones.types';

export const maxExportRows = 10_000;

@Injectable()
export class ExportacionesService {
  constructor(private readonly exportacionesR2: ExportacionesR2Service) {}

  asegurarTamanoExportacion(rowCount: number) {
    if (rowCount > maxExportRows) {
      throw DomainError.validation(
        `La exportacion supera el maximo de ${maxExportRows} filas; aplica filtros mas especificos`,
        'EXPORTACION_DEMASIADO_GRANDE',
      );
    }
  }

  formatearHojaExportacion(sheet: Worksheet, columnasMonetarias: string[]) {
    sheet.views = [{ state: 'frozen', ySplit: 1 }];
    sheet.getRow(1).height = 22;
    sheet.getRow(1).eachCell((cell) => {
      cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
      cell.fill = {
        type: 'pattern',
        pattern: 'solid',
        fgColor: { argb: 'FF1F2937' },
      };
      cell.alignment = { vertical: 'middle' };
    });

    for (const key of columnasMonetarias) {
      sheet.getColumn(key).numFmt = '#,##0.##########';
    }

    sheet.eachRow((row, rowNumber) => {
      if (rowNumber === 1) {
        return;
      }

      row.eachCell((cell) => {
        cell.alignment = { vertical: 'top', wrapText: true };
      });
    });
  }

  crearVistaPreviaExportacion(
    columnas: ColumnaExportacion[],
    filas: FilaExportacion[],
  ): ExportacionVistaPrevia {
    return {
      columnas: columnas.map((columna) => columna.header),
      filas: filas.slice(0, 50).map((fila) =>
        columnas.map((columna) => {
          const valor = fila[columna.key];
          if (valor === undefined) {
            return null;
          }
          return valor;
        }),
      ),
    };
  }

  async subirWorkbookExportacion(input: {
    workbook: Workbook;
    carpeta: string;
    nombreBase: string;
    filas: number;
    vistaPrevia: ExportacionVistaPrevia;
  }): Promise<ExportacionExcel> {
    const contenido = Buffer.from(await input.workbook.xlsx.writeBuffer());
    const nombreArchivo = `${input.nombreBase}-${this.timestampArchivo()}.xlsx`;
    const resultado = await this.exportacionesR2.subirExcel({
      carpeta: input.carpeta,
      nombreArchivo,
      contenido,
    });

    return {
      ...resultado,
      filas: input.filas,
      generadoEn: new Date().toISOString(),
      vistaPrevia: input.vistaPrevia,
    };
  }

  async generarYSubirExcel(input: {
    carpeta: string;
    nombreBase: string;
    hojaNombre: string;
    columnas: ColumnaExportacion[];
    filas: FilaExportacion[];
    columnasMonetarias: string[];
  }): Promise<ExportacionExcel> {
    this.asegurarTamanoExportacion(input.filas.length);

    const workbook = new Workbook();
    workbook.creator = 'Cobro';
    workbook.created = new Date();

    const sheet = workbook.addWorksheet(input.hojaNombre);
    sheet.columns = input.columnas;
    sheet.addRows(input.filas);

    this.formatearHojaExportacion(sheet, input.columnasMonetarias);
    const vistaPrevia = this.crearVistaPreviaExportacion(
      input.columnas,
      input.filas,
    );

    return this.subirWorkbookExportacion({
      workbook,
      carpeta: input.carpeta,
      nombreBase: input.nombreBase,
      filas: input.filas.length,
      vistaPrevia,
    });
  }

  private timestampArchivo() {
    return new Date().toISOString().replace(/[:.]/g, '-');
  }
}
